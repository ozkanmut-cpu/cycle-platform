#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as dt
import plistlib
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

HEALTHKIT_ENTITLEMENT = "com.apple.developer.healthkit"
CODE_SIGN_LINE = "CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;"


def _load_plist(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise SystemExit(f"Missing plist: {path}")
    with path.open("rb") as handle:
        value = plistlib.load(handle)
    if not isinstance(value, dict):
        raise SystemExit(f"Invalid plist root: {path}")
    return value


def _extract_plist_bytes(value: bytes, label: str) -> bytes:
    payload = value.strip()
    if payload.startswith(b"bplist00"):
        return payload

    xml_start = payload.find(b"<?xml")
    plist_start = payload.find(b"<plist")
    starts = [index for index in (xml_start, plist_start) if index >= 0]
    if not starts:
        raise SystemExit(f"Unable to locate {label} plist payload.")

    start = min(starts)
    end_marker = b"</plist>"
    end = payload.find(end_marker, start)
    if end < 0:
        raise SystemExit(f"Unable to locate end of {label} plist payload.")
    return payload[start : end + len(end_marker)]


def _load_plist_bytes(value: bytes, label: str) -> dict[str, Any]:
    payload = _extract_plist_bytes(value, label)
    try:
        parsed = plistlib.loads(payload)
    except Exception as exc:  # pragma: no cover - platform command diagnostics
        raise SystemExit(f"Unable to parse {label} plist: {exc}") from exc
    if not isinstance(parsed, dict):
        raise SystemExit(f"Invalid {label} plist root.")
    return parsed


def _healthkit_enabled(value: Any) -> bool:
    if value is True:
        return True
    if isinstance(value, list):
        return len(value) > 0
    return False


def _project_bundle_ids(project_text: str) -> set[str]:
    bundle_ids = {
        match.strip()
        for match in re.findall(r"PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;]+);", project_text)
        if match.strip() and "$" not in match
    }
    # Flutter's generated RunnerTests target has its own bundle identifier. It is
    # not the signed application target and must not make the app identity
    # ambiguous for this signing gate.
    return {
        bundle_id for bundle_id in bundle_ids if not bundle_id.endswith(".RunnerTests")
    }


def verify_project(app_dir: Path) -> str:
    entitlements_path = app_dir / "ios/Runner/Runner.entitlements"
    project_path = app_dir / "ios/Runner.xcodeproj/project.pbxproj"
    info_path = app_dir / "ios/Runner/Info.plist"

    entitlements = _load_plist(entitlements_path)
    if not _healthkit_enabled(entitlements.get(HEALTHKIT_ENTITLEMENT)):
        raise SystemExit("Runner.entitlements does not enable HealthKit.")

    if not project_path.is_file():
        raise SystemExit(f"Missing Xcode project file: {project_path}")
    project_text = project_path.read_text(encoding="utf-8")
    if CODE_SIGN_LINE not in project_text:
        raise SystemExit("Patient target is not wired to Runner/Runner.entitlements.")

    info = _load_plist(info_path)
    usage = info.get("NSHealthShareUsageDescription")
    if not isinstance(usage, str) or not usage.strip():
        raise SystemExit("NSHealthShareUsageDescription is missing or empty.")

    bundle_ids = _project_bundle_ids(project_text)
    if not bundle_ids:
        raise SystemExit("No concrete PRODUCT_BUNDLE_IDENTIFIER found in Patient Xcode project.")
    if len(bundle_ids) != 1:
        raise SystemExit(
            "Patient Xcode project contains multiple concrete app bundle identifiers: "
            + ", ".join(sorted(bundle_ids))
        )
    return next(iter(bundle_ids))


def decode_mobileprovision(profile: Path) -> dict[str, Any]:
    if not profile.is_file():
        raise SystemExit(f"Provisioning profile not found: {profile}")
    if sys.platform != "darwin":
        raise SystemExit(
            "Decoding a .mobileprovision requires macOS security(1). "
            "Run the signed-profile gate on a macOS runner."
        )
    result = subprocess.run(
        ["security", "cms", "-D", "-i", str(profile)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        message = result.stderr.decode("utf-8", errors="replace").strip()
        raise SystemExit(f"Unable to decode provisioning profile: {message}")
    return _load_plist_bytes(result.stdout, "provisioning profile")


def verify_profile(profile_plist: dict[str, Any], bundle_id: str) -> None:
    entitlements = profile_plist.get("Entitlements")
    if not isinstance(entitlements, dict):
        raise SystemExit("Provisioning profile has no Entitlements dictionary.")
    if not _healthkit_enabled(entitlements.get(HEALTHKIT_ENTITLEMENT)):
        raise SystemExit("Provisioning profile does not include the HealthKit capability.")

    application_identifier = entitlements.get("application-identifier")
    if not isinstance(application_identifier, str) or "." not in application_identifier:
        raise SystemExit("Provisioning profile has no valid application-identifier.")
    profile_bundle_id = application_identifier.split(".", 1)[1]
    if profile_bundle_id != bundle_id:
        raise SystemExit(
            f"Provisioning profile bundle id {profile_bundle_id!r} does not match "
            f"Patient bundle id {bundle_id!r}."
        )

    expiration = profile_plist.get("ExpirationDate")
    if not isinstance(expiration, dt.datetime):
        raise SystemExit("Provisioning profile has no valid ExpirationDate.")
    if expiration.tzinfo is None:
        expiration = expiration.replace(tzinfo=dt.timezone.utc)
    if expiration <= dt.datetime.now(dt.timezone.utc):
        raise SystemExit(f"Provisioning profile expired at {expiration.isoformat()}.")


def verify_signed_app(app_path: Path, expected_bundle_id: str) -> None:
    if sys.platform != "darwin":
        raise SystemExit("Signed .app verification requires macOS codesign(1).")
    if not app_path.is_dir() or app_path.suffix != ".app":
        raise SystemExit(f"Signed app bundle not found: {app_path}")

    info = _load_plist(app_path / "Info.plist")
    signed_bundle_id = info.get("CFBundleIdentifier")
    if signed_bundle_id != expected_bundle_id:
        raise SystemExit(
            f"Signed app bundle id {signed_bundle_id!r} does not match "
            f"Patient bundle id {expected_bundle_id!r}."
        )

    result = subprocess.run(
        ["codesign", "-d", "--entitlements", ":-", str(app_path)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if result.returncode != 0:
        message = result.stderr.decode("utf-8", errors="replace").strip()
        raise SystemExit(f"Unable to read signed app entitlements: {message}")

    candidates = [result.stdout, result.stderr, result.stdout + b"\n" + result.stderr]
    entitlements: dict[str, Any] | None = None
    errors: list[str] = []
    for candidate in candidates:
        if not candidate.strip():
            continue
        try:
            entitlements = _load_plist_bytes(candidate, "signed app entitlements")
            break
        except SystemExit as exc:
            errors.append(str(exc))
    if entitlements is None:
        detail = "; ".join(errors) or "no entitlement payload returned"
        raise SystemExit(f"Unable to parse signed app entitlements: {detail}")

    if not _healthkit_enabled(entitlements.get(HEALTHKIT_ENTITLEMENT)):
        raise SystemExit("Signed app does not include the HealthKit entitlement.")

    embedded_profile = app_path / "embedded.mobileprovision"
    verify_profile(decode_mobileprovision(embedded_profile), expected_bundle_id)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Verify Cycle Patient HealthKit project and signed provisioning capability."
    )
    parser.add_argument(
        "--app-dir",
        type=Path,
        default=Path("."),
        help="Patient app directory (default: current directory).",
    )
    parser.add_argument(
        "--provisioning-profile",
        type=Path,
        help="Apple .mobileprovision file to decode and verify.",
    )
    parser.add_argument(
        "--profile-plist",
        type=Path,
        help="Already-decoded provisioning profile plist (test/diagnostic use).",
    )
    parser.add_argument(
        "--signed-app",
        type=Path,
        help="Signed Runner.app bundle; verifies codesigned HealthKit entitlement and embedded profile.",
    )
    args = parser.parse_args()

    bundle_id = verify_project(args.app_dir.resolve())
    print(f"HealthKit project signing configuration verified for {bundle_id}.")

    if args.provisioning_profile and args.profile_plist:
        raise SystemExit("Choose only one of --provisioning-profile or --profile-plist.")
    if args.provisioning_profile:
        verify_profile(decode_mobileprovision(args.provisioning_profile), bundle_id)
        print("Signed provisioning profile HealthKit capability verified.")
    elif args.profile_plist:
        verify_profile(_load_plist(args.profile_plist), bundle_id)
        print("Decoded provisioning profile HealthKit capability verified.")

    if args.signed_app:
        verify_signed_app(args.signed_app.resolve(), bundle_id)
        print("Signed app HealthKit entitlement and embedded provisioning profile verified.")


if __name__ == "__main__":
    main()
