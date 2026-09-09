#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_FILE="$ROOT_DIR/apps/patient/android/app/build.gradle.kts"

if [[ ! -f "$BUILD_FILE" ]]; then
  echo "Patient Android shell has not been bootstrapped." >&2
  exit 1
fi

python3 - "$BUILD_FILE" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
old = "minSdk = flutter.minSdkVersion"
new = "minSdk = 26"

if old in text:
    text = text.replace(old, new, 1)
elif new not in text:
    raise SystemExit("Could not locate Android minSdk declaration")

path.write_text(text, encoding="utf-8")
PY

echo "Patient Android minSdk verified at API 26 for Health Connect 1.2."
