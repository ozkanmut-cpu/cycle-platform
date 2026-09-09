#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/apps/patient"

ANDROID_MANIFEST="$APP_DIR/android/app/src/main/AndroidManifest.xml"
ANDROID_ACTIVITY="$APP_DIR/android/app/src/main/kotlin/com/cyclehealth/cycle_patient/MainActivity.kt"
IOS_INFO="$APP_DIR/ios/Runner/Info.plist"
IOS_SCENE="$APP_DIR/ios/Runner/SceneDelegate.swift"

for path in "$ANDROID_MANIFEST" "$ANDROID_ACTIVITY" "$IOS_INFO" "$IOS_SCENE"; do
  test -f "$path" || { echo "Missing native security file: $path" >&2; exit 1; }
done

grep -Fq 'android.permission.USE_BIOMETRIC' "$ANDROID_MANIFEST"
grep -Fq 'FlutterFragmentActivity' "$ANDROID_ACTIVITY"
grep -Fq 'WindowManager.LayoutParams.FLAG_SECURE' "$ANDROID_ACTIVITY"
grep -Fq 'NSFaceIDUsageDescription' "$IOS_INFO"
grep -Fq 'sceneWillResignActive' "$IOS_SCENE"
grep -Fq 'privacyView' "$IOS_SCENE"
grep -Fq 'sceneDidBecomeActive' "$IOS_SCENE"

python3 - <<'PY'
from pathlib import Path
import plistlib

app = Path('apps/patient')
with (app / 'ios/Runner/Info.plist').open('rb') as handle:
    info = plistlib.load(handle)
message = info.get('NSFaceIDUsageDescription')
assert isinstance(message, str) and message.strip(), 'Face ID usage text must be present'
PY

echo "Native Patient security configuration verified."
