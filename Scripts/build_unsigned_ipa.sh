#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUILD_DIR="$ROOT/build"
DIST_DIR="$ROOT/dist"
PROJECT="$ROOT/PhaseZero.xcodeproj"
SCHEME="PhaseZero"

mkdir -p "$BUILD_DIR" "$DIST_DIR"

# Old repositories may still contain the pre-V6 Apple Music prototype. XcodeGen
# discovers every Swift file below Sources/AppModule, so remove the incompatible
# files locally before generating the project. This does not alter the GitHub
# repository; it only cleans the runner's disposable checkout.
STALE_FILES=(
  "Sources/AppModule/Model/MusicModels.swift"
  "Sources/AppModule/Services/MusicPlayerService.swift"
  "Sources/AppModule/Views/MusicPlayerView.swift"
)
for stale in "${STALE_FILES[@]}"; do
  if [[ -e "$stale" ]]; then
    echo "Removing stale pre-V6 source: $stale"
    rm -f "$stale"
  fi
done

required=(
  "project.yml"
  "BuildSupport/Info.plist"
  "Sources/AppModule/PhaseZeroPlaygroundApp.swift"
  "Sources/AppModule/Services/AppleMusicService.swift"
  "Sources/AppModule/Services/GameBridge.swift"
  "Sources/AppModule/Resources/Web/phase_zero_native.html"
)
for path in "${required[@]}"; do
  if [[ ! -e "$path" ]]; then
    echo "::error file=$path::Required build input is missing. Upload the extracted repository contents, not the ZIP as one file."
    exit 2
  fi
done

rm -rf "$BUILD_DIR/DerivedData" "$PROJECT" "$DIST_DIR/Payload"
rm -f "$DIST_DIR"/*.ipa "$DIST_DIR"/*.sha256

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "::error::XcodeGen is not installed."
  exit 3
fi

xcodegen generate --spec project.yml

set +e
set -o pipefail
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY='' \
  DEVELOPMENT_TEAM='' \
  clean build 2>&1 | tee "$BUILD_DIR/xcodebuild.log"
status=${PIPESTATUS[0]}
set -e

if [[ $status -ne 0 ]]; then
  echo
  echo "========== condensed compiler errors =========="
  grep -E "(^|[[:space:]])(error:|fatal error:)|BUILD FAILED" "$BUILD_DIR/xcodebuild.log" | tail -n 120 || true
  echo "==============================================="
  exit "$status"
fi

APP_PATH="$(python3 - "$BUILD_DIR/DerivedData/Build/Products/Release-iphoneos" <<'PY'
import glob
import os
import sys
root = sys.argv[1]
apps = sorted(path for path in glob.glob(os.path.join(root, "*.app")) if os.path.isdir(path))
print(apps[0] if apps else "")
PY
)"
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "::error::Xcode reported success but no Release-iphoneos .app was found."
  exit 4
fi

HTML_PATH="$(python3 - "$APP_PATH" <<'PY'
import os
import sys
for root, _, files in os.walk(sys.argv[1]):
    if "phase_zero_native.html" in files:
        print(os.path.join(root, "phase_zero_native.html"))
        break
PY
)"
if [[ -z "$HTML_PATH" || ! -f "$HTML_PATH" ]]; then
  echo "::error::The app was built without phase_zero_native.html. The app would launch into an empty WebKit surface."
  exit 5
fi

PAYLOAD_DIR="$DIST_DIR/Payload"
mkdir -p "$PAYLOAD_DIR"
/usr/bin/ditto "$APP_PATH" "$PAYLOAD_DIR/$(basename "$APP_PATH")"

IPA="$DIST_DIR/PhaseZero-HangarRadio-6.0.1-unsigned.ipa"
(
  cd "$DIST_DIR"
  /usr/bin/zip -qry "$(basename "$IPA")" Payload
)
shasum -a 256 "$IPA" > "$IPA.sha256"

# Basic artifact sanity checks. An unsigned IPA is expected here; SideStore,
# AltStore, Signulous, or a later signed archive step supplies the signature.
/usr/bin/unzip -tq "$IPA"
test -s "$IPA"

echo "Built: $IPA"
cat "$IPA.sha256"
