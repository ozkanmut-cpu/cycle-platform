#!/usr/bin/env python3
from __future__ import annotations

import datetime as dt
import importlib.util
import plistlib
import tempfile
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).with_name("verify_patient_healthkit_signing.py")
spec = importlib.util.spec_from_file_location("healthkit_signing", MODULE_PATH)
assert spec and spec.loader
healthkit_signing = importlib.util.module_from_spec(spec)
spec.loader.exec_module(healthkit_signing)


class HealthKitSigningVerifierTest(unittest.TestCase):
    bundle_id = "com.cyclehealth.cyclePatient"

    def _profile(self, *, healthkit: object = True, bundle_id: str | None = None, expires_days: int = 30):
        return {
            "Entitlements": {
                healthkit_signing.HEALTHKIT_ENTITLEMENT: healthkit,
                "application-identifier": f"TEAM123.{bundle_id or self.bundle_id}",
            },
            "ExpirationDate": dt.datetime.now(dt.timezone.utc) + dt.timedelta(days=expires_days),
        }

    def test_runner_tests_bundle_id_is_ignored(self):
        project = f"""
        PRODUCT_BUNDLE_IDENTIFIER = {self.bundle_id};
        PRODUCT_BUNDLE_IDENTIFIER = {self.bundle_id}.RunnerTests;
        """
        self.assertEqual(healthkit_signing._project_bundle_ids(project), {self.bundle_id})

    def test_valid_profile_passes(self):
        healthkit_signing.verify_profile(self._profile(), self.bundle_id)

    def test_profile_without_healthkit_fails(self):
        with self.assertRaisesRegex(SystemExit, "HealthKit capability"):
            healthkit_signing.verify_profile(self._profile(healthkit=False), self.bundle_id)

    def test_profile_bundle_id_mismatch_fails(self):
        with self.assertRaisesRegex(SystemExit, "does not match"):
            healthkit_signing.verify_profile(
                self._profile(bundle_id="com.cyclehealth.other"), self.bundle_id
            )

    def test_expired_profile_fails(self):
        with self.assertRaisesRegex(SystemExit, "expired"):
            healthkit_signing.verify_profile(self._profile(expires_days=-1), self.bundle_id)

    def test_project_contract_passes_with_runner_and_runner_tests(self):
        with tempfile.TemporaryDirectory() as tmp:
            app_dir = Path(tmp)
            runner = app_dir / "ios/Runner"
            project = app_dir / "ios/Runner.xcodeproj"
            runner.mkdir(parents=True)
            project.mkdir(parents=True)

            with (runner / "Runner.entitlements").open("wb") as handle:
                plistlib.dump({healthkit_signing.HEALTHKIT_ENTITLEMENT: True}, handle)
            with (runner / "Info.plist").open("wb") as handle:
                plistlib.dump({"NSHealthShareUsageDescription": "Read health data."}, handle)
            (project / "project.pbxproj").write_text(
                "\n".join(
                    [
                        healthkit_signing.CODE_SIGN_LINE,
                        f"PRODUCT_BUNDLE_IDENTIFIER = {self.bundle_id};",
                        f"PRODUCT_BUNDLE_IDENTIFIER = {self.bundle_id}.RunnerTests;",
                    ]
                ),
                encoding="utf-8",
            )

            self.assertEqual(healthkit_signing.verify_project(app_dir), self.bundle_id)

    def test_project_without_healthkit_entitlement_fails(self):
        with tempfile.TemporaryDirectory() as tmp:
            app_dir = Path(tmp)
            runner = app_dir / "ios/Runner"
            project = app_dir / "ios/Runner.xcodeproj"
            runner.mkdir(parents=True)
            project.mkdir(parents=True)

            with (runner / "Runner.entitlements").open("wb") as handle:
                plistlib.dump({}, handle)
            with (runner / "Info.plist").open("wb") as handle:
                plistlib.dump({"NSHealthShareUsageDescription": "Read health data."}, handle)
            (project / "project.pbxproj").write_text(
                f"{healthkit_signing.CODE_SIGN_LINE}\nPRODUCT_BUNDLE_IDENTIFIER = {self.bundle_id};\n",
                encoding="utf-8",
            )

            with self.assertRaisesRegex(SystemExit, "does not enable HealthKit"):
                healthkit_signing.verify_project(app_dir)


if __name__ == "__main__":
    unittest.main()
