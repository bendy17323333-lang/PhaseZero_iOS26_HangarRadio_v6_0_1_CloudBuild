#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUILD_DIR="$ROOT/build"
DIST_DIR="$ROOT/dist"
PROJECT="$ROOT/PhaseZero.xcodeproj"
PBXPROJ="$PROJECT/project.pbxproj"
SCHEME="PhaseZero"

mkdir -p "$BUILD_DIR" "$DIST_DIR"

# Old repositories may still contain the pre-V6 Apple Music prototype. XcodeGen
# discovers every Swift file below Sources/AppModule, so remove the incompatible
# files locally before generating the project. This only touches the runner's
# disposable checkout.
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

HTML_SOURCE="Sources/AppModule/Resources/Web/phase_zero_native.html"
PRIVACY_SOURCE="Sources/AppModule/Resources/PrivacyInfo.xcprivacy"
ASSETS_SOURCE="Sources/AppModule/Resources/Assets.xcassets"

required=(
  "project.yml"
  "BuildSupport/Info.plist"
  "Sources/AppModule/PhaseZeroPlaygroundApp.swift"
  "Sources/AppModule/Services/AppleMusicService.swift"
  "Sources/AppModule/Services/GameBridge.swift"
  "$HTML_SOURCE"
  "$PRIVACY_SOURCE"
  "$ASSETS_SOURCE/Contents.json"
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

# Fail before the expensive compile if XcodeGen did not actually put the game
# resource and asset catalog into the generated project.
for expected in "phase_zero_native.html" "Assets.xcassets" "PrivacyInfo.xcprivacy"; do
  if ! grep -Fq "$expected" "$PBXPROJ"; then
    echo "::error file=project.yml::Generated Xcode project is missing $expected. Check the resource entries under targets.PhaseZero.sources."
    exit 6
  fi
done

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

find_resource() {
  local name="$1"
  python3 - "$APP_PATH" "$name" <<'PY'
import os
import sys
root, target = sys.argv[1], sys.argv[2]
for current, _, files in os.walk(root):
    if target in files:
        print(os.path.join(current, target))
        break
PY
}

HTML_PATH="$(find_resource phase_zero_native.html)"
if [[ -z "$HTML_PATH" || ! -f "$HTML_PATH" ]]; then
  # The project spec should already copy this resource. This fallback keeps the
  # unsigned artifact usable even if a future XcodeGen version changes folder
  # handling. The later signer will seal the copied file into the final bundle.
  echo "::warning::Xcode build omitted phase_zero_native.html; applying deterministic unsigned-bundle fallback copy."
  mkdir -p "$APP_PATH/Web"
  /usr/bin/ditto "$HTML_SOURCE" "$APP_PATH/Web/phase_zero_native.html"
  HTML_PATH="$APP_PATH/Web/phase_zero_native.html"
fi

PRIVACY_PATH="$(find_resource PrivacyInfo.xcprivacy)"
if [[ -z "$PRIVACY_PATH" || ! -f "$PRIVACY_PATH" ]]; then
  echo "::warning::Xcode build omitted PrivacyInfo.xcprivacy; copying it into the unsigned app bundle."
  /usr/bin/ditto "$PRIVACY_SOURCE" "$APP_PATH/PrivacyInfo.xcprivacy"
  PRIVACY_PATH="$APP_PATH/PrivacyInfo.xcprivacy"
fi

if [[ ! -f "$APP_PATH/Assets.car" ]]; then
  echo "::error::The app bundle does not contain Assets.car. The app icon and launch assets were not compiled."
  exit 7
fi

for packaged in "$HTML_PATH" "$PRIVACY_PATH" "$APP_PATH/Assets.car"; do
  if [[ ! -s "$packaged" ]]; then
    echo "::error file=$packaged::Required packaged resource is missing or empty."
    exit 8
  fi
done

echo "Packaged resource check:"
echo "  HTML:   ${HTML_PATH#$APP_PATH/}"
echo "  Privacy:${PRIVACY_PATH#$APP_PATH/}"
echo "  Assets: Assets.car"

PAYLOAD_DIR="$DIST_DIR/Payload"
mkdir -p "$PAYLOAD_DIR"
/usr/bin/ditto "$APP_PATH" "$PAYLOAD_DIR/$(basename "$APP_PATH")"

IPA="$DIST_DIR/PhaseZero-HangarRadio-6.0.2-unsigned.ipa"
(
  cd "$DIST_DIR"
  /usr/bin/zip -qry "$(basename "$IPA")" Payload
)
shasum -a 256 "$IPA" > "$IPA.sha256"

# Basic artifact sanity checks. An unsigned IPA is expected here; SideStore,
# AltStore, Signulous, or a later signed archive step supplies the signature.
/usr/bin/unzip -tq "$IPA"
test -s "$IPA"
/usr/bin/unzip -l "$IPA" | grep -Fq "phase_zero_native.html"
/usr/bin/unzip -l "$IPA" | grep -Fq "PrivacyInfo.xcprivacy"
/usr/bin/unzip -l "$IPA" | grep -Fq "Assets.car"

echo "Built: $IPA"
cat "$IPA.sha256"
