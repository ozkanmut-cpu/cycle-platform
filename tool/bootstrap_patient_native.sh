#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/apps/patient"

cd "$APP_DIR"
flutter create \
  --platforms=android,ios \
  --org com.cyclehealth \
  --project-name cycle_patient \
  .

python3 - <<'PY'
from pathlib import Path
import plistlib

app = Path.cwd()

main_activity = app / "android/app/src/main/kotlin/com/cyclehealth/cycle_patient/MainActivity.kt"
main_activity.parent.mkdir(parents=True, exist_ok=True)
main_activity.write_text(
    "package com.cyclehealth.cycle_patient\n\n"
    "import io.flutter.embedding.android.FlutterFragmentActivity\n\n"
    "class MainActivity : FlutterFragmentActivity()\n",
    encoding="utf-8",
)

manifest = app / "android/app/src/main/AndroidManifest.xml"
text = manifest.read_text(encoding="utf-8")
permission = '<uses-permission android:name="android.permission.USE_BIOMETRIC" />'
if permission not in text:
    text = text.replace(
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
        '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n    ' + permission,
        1,
    )
manifest.write_text(text, encoding="utf-8")

settings = app / "android/settings.gradle.kts"
settings_text = settings.read_text(encoding="utf-8")
settings_text = settings_text.replace(
    'id("com.android.application") version "9.1.0" apply false',
    'id("com.android.application") version "9.1.1" apply false',
)
settings.write_text(settings_text, encoding="utf-8")

android_build = app / "android/app/build.gradle.kts"
build_text = android_build.read_text(encoding="utf-8")
build_text = build_text.replace(
    "compileSdk = flutter.compileSdkVersion",
    "compileSdk = 37",
)
android_build.write_text(build_text, encoding="utf-8")

info = app / "ios/Runner/Info.plist"
with info.open("rb") as handle:
    plist = plistlib.load(handle)
plist["NSFaceIDUsageDescription"] = (
    "Cycle uses Face ID to unlock private reproductive health data."
)
with info.open("wb") as handle:
    plistlib.dump(plist, handle, fmt=plistlib.FMT_XML, sort_keys=False)

entitlements = {
    "keychain-access-groups": [],
}
for name in ("DebugProfile.entitlements", "Release.entitlements"):
    path = app / "ios/Runner" / name
    with path.open("wb") as handle:
        plistlib.dump(entitlements, handle, fmt=plistlib.FMT_XML, sort_keys=False)
PY

echo "Patient Android/iOS shell configured for local authentication, API 37, and Keychain storage."
