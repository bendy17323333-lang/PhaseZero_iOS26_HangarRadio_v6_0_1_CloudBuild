#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUILD_DIR="$ROOT/build"
DIST_DIR="$ROOT/dist"
PROJECT="$ROOT/PhaseZero.xcodeproj"
PBXPROJ="$PROJECT/project.pbxproj"
SCHEME="PhaseZero"
INFO_SOURCE="BuildSupport/Info.plist"

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
LAUNCH_STORYBOARD_SOURCE="Sources/AppModule/Resources/LaunchScreen.storyboard"

required=(
  "project.yml"
  "$INFO_SOURCE"
  "Scripts/repair_built_info_plist.py"
  "Sources/AppModule/PhaseZeroPlaygroundApp.swift"
  "Sources/AppModule/Model/RadioSystems.swift"
  "Sources/AppModule/Model/SettingsStore.swift"
  "Sources/AppModule/Services/AppleMusicService.swift"
  "Sources/AppModule/Services/GameBridge.swift"
  "Sources/AppModule/Views/HangarView.swift"
  "Sources/AppModule/Views/PhaseRadioView.swift"
  "$HTML_SOURCE"
  "$PRIVACY_SOURCE"
  "$ASSETS_SOURCE/Contents.json"
  "$LAUNCH_STORYBOARD_SOURCE"
)
for path in "${required[@]}"; do
  if [[ ! -e "$path" ]]; then
    echo "::error file=$path::Required build input is missing. Upload the extracted repository contents, not the ZIP as one file."
    exit 2
  fi
done

rm -rf "$BUILD_DIR/DerivedData" "$PROJECT" "$DIST_DIR/Payload"
rm -f \
  "$DIST_DIR"/*.ipa \
  "$DIST_DIR"/*.sha256 \
  "$DIST_DIR/source-plist-diagnostics.txt" \
  "$DIST_DIR/fullscreen-diagnostics.txt" \
  "$DIST_DIR/ipa-metadata-diagnostics.txt"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "::error::XcodeGen is not installed."
  exit 3
fi

# V6.0.4 exposed the actual issue: targets.<name>.info tells XcodeGen to
# generate and overwrite a plist at that path. V6.0.6 preserves the INFOPLIST_FILE pipeline
# instead. Validate the source plist before and after project generation so
# this can never silently regress again.
SOURCE_PLIST_DIAGNOSTICS="$DIST_DIR/source-plist-diagnostics.txt"
python3 - "$INFO_SOURCE" "$SOURCE_PLIST_DIAGNOSTICS" <<'PYSOURCE'
import plistlib
import sys
from pathlib import Path

source_path = Path(sys.argv[1])
report_path = Path(sys.argv[2])
with source_path.open("rb") as handle:
    info = plistlib.load(handle)

required_strings = [
    "NSAppleMusicUsageDescription",
    "NSMotionUsageDescription",
    "UILaunchStoryboardName",
]
missing = [
    key
    for key in required_strings
    if not isinstance(info.get(key), str) or not info.get(key).strip()
]
landscape = {
    "UIInterfaceOrientationLandscapeLeft",
    "UIInterfaceOrientationLandscapeRight",
}
orientations = set(info.get("UISupportedInterfaceOrientations", []))
lines = [
    f"source={source_path}",
    f"NSAppleMusicUsageDescription present={bool(info.get('NSAppleMusicUsageDescription'))}",
    f"NSMotionUsageDescription present={bool(info.get('NSMotionUsageDescription'))}",
    f"UILaunchStoryboardName={info.get('UILaunchStoryboardName')!r}",
    f"UISupportedInterfaceOrientations={info.get('UISupportedInterfaceOrientations')!r}",
]
report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
print("Source Info.plist preflight:")
for line in lines:
    print("  " + line)
if missing:
    raise SystemExit(f"source Info.plist is missing required string keys: {missing!r}")
if info.get("UILaunchStoryboardName") != "LaunchScreen":
    raise SystemExit("source Info.plist must use UILaunchStoryboardName=LaunchScreen")
if not landscape.issubset(orientations):
    raise SystemExit("source Info.plist must advertise both landscape orientations")
PYSOURCE
/usr/bin/plutil -lint "$INFO_SOURCE"
INFO_HASH_BEFORE="$(shasum -a 256 "$INFO_SOURCE" | awk '{print $1}')"
echo "Source Info.plist SHA-256 before XcodeGen: $INFO_HASH_BEFORE" | tee -a "$SOURCE_PLIST_DIAGNOSTICS"

xcodegen generate --spec project.yml

INFO_HASH_AFTER="$(shasum -a 256 "$INFO_SOURCE" | awk '{print $1}')"
echo "Source Info.plist SHA-256 after XcodeGen:  $INFO_HASH_AFTER" | tee -a "$SOURCE_PLIST_DIAGNOSTICS"
if [[ "$INFO_HASH_BEFORE" != "$INFO_HASH_AFTER" ]]; then
  echo "::error file=project.yml::XcodeGen modified BuildSupport/Info.plist. Remove targets.PhaseZero.info and set INFOPLIST_FILE directly."
  exit 10
fi

if ! grep -Fq "INFOPLIST_FILE" "$PBXPROJ" || ! grep -Fq "BuildSupport/Info.plist" "$PBXPROJ"; then
  echo "::error file=project.yml::Generated project is not using BuildSupport/Info.plist through INFOPLIST_FILE."
  exit 11
fi

# Fail before the expensive compile if XcodeGen did not actually put the game
# resources into the generated project.
for expected in "phase_zero_native.html" "Assets.xcassets" "PrivacyInfo.xcprivacy" "LaunchScreen.storyboard"; do
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

APP_PATH="$(python3 - "$BUILD_DIR/DerivedData/Build/Products/Release-iphoneos" <<'PYAPP'
import glob
import os
import sys
root = sys.argv[1]
apps = sorted(path for path in glob.glob(os.path.join(root, "*.app")) if os.path.isdir(path))
print(apps[0] if apps else "")
PYAPP
)"
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "::error::Xcode reported success but no Release-iphoneos .app was found."
  exit 4
fi

find_resource() {
  local name="$1"
  python3 - "$APP_PATH" "$name" <<'PYFIND'
import os
import sys
root, target = sys.argv[1], sys.argv[2]
for current, _, files in os.walk(root):
    if target in files:
        print(os.path.join(current, target))
        break
PYFIND
}

HTML_PATH="$(find_resource phase_zero_native.html)"
if [[ -z "$HTML_PATH" || ! -f "$HTML_PATH" ]]; then
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

LAUNCH_STORYBOARDC="$(find "$APP_PATH" -maxdepth 2 -type d -name 'LaunchScreen.storyboardc' -print -quit)"
if [[ -z "$LAUNCH_STORYBOARDC" || ! -d "$LAUNCH_STORYBOARDC" ]]; then
  echo "::error::The app bundle does not contain LaunchScreen.storyboardc. Without it, modern iPhones can fall back to the legacy 480x320 compatibility canvas."
  exit 9
fi

# Preserve Xcode's expanded bundle/version metadata while restoring any runtime
# fields that did not survive processing. The script contains independent
# fallbacks for the two privacy strings as a second line of defence.
python3 Scripts/repair_built_info_plist.py \
  "$INFO_SOURCE" \
  "$APP_PATH/Info.plist"
/usr/bin/plutil -lint "$APP_PATH/Info.plist"

FULLSCREEN_DIAGNOSTICS="$DIST_DIR/fullscreen-diagnostics.txt"
python3 - "$APP_PATH/Info.plist" "$FULLSCREEN_DIAGNOSTICS" <<'PYINFO'
import plistlib
import sys

info_path, report_path = sys.argv[1], sys.argv[2]
with open(info_path, "rb") as handle:
    info = plistlib.load(handle)
launch_name = info.get("UILaunchStoryboardName")
families = info.get("UIDeviceFamily", [])
orientations = info.get("UISupportedInterfaceOrientations", [])
lines = [
    f"UILaunchStoryboardName={launch_name!r}",
    f"UIDeviceFamily={families!r}",
    f"UISupportedInterfaceOrientations={orientations!r}",
    f"MinimumOSVersion={info.get('MinimumOSVersion')!r}",
    f"NSAppleMusicUsageDescription present={bool(info.get('NSAppleMusicUsageDescription'))}",
    f"NSMotionUsageDescription present={bool(info.get('NSMotionUsageDescription'))}",
]
with open(report_path, "w", encoding="utf-8") as report:
    report.write("\n".join(lines) + "\n")
print("Fullscreen metadata check:")
for line in lines:
    print("  " + line)
if launch_name != "LaunchScreen":
    raise SystemExit("Final app Info.plist is missing UILaunchStoryboardName=LaunchScreen")
if 1 not in families:
    raise SystemExit("Final app UIDeviceFamily does not include iPhone (1)")
required = {"UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"}
if not required.issubset(set(orientations)):
    raise SystemExit("Final app does not advertise both landscape orientations for iPhone")
if not info.get("NSAppleMusicUsageDescription"):
    raise SystemExit("Final app lost NSAppleMusicUsageDescription")
if not info.get("NSMotionUsageDescription"):
    raise SystemExit("Final app lost NSMotionUsageDescription")
PYINFO

for packaged in "$HTML_PATH" "$PRIVACY_PATH" "$APP_PATH/Assets.car"; do
  if [[ ! -s "$packaged" ]]; then
    echo "::error file=$packaged::Required packaged resource is missing or empty."
    exit 8
  fi
done

echo "Packaged resource check:"
echo "  HTML:    ${HTML_PATH#$APP_PATH/}"
echo "  Privacy: ${PRIVACY_PATH#$APP_PATH/}"
echo "  Assets:  Assets.car"
echo "  Launch:  ${LAUNCH_STORYBOARDC#$APP_PATH/}"

PAYLOAD_DIR="$DIST_DIR/Payload"
mkdir -p "$PAYLOAD_DIR"
/usr/bin/ditto "$APP_PATH" "$PAYLOAD_DIR/$(basename "$APP_PATH")"

IPA="$DIST_DIR/PhaseZero-HangarRadio-6.0.6-unsigned.ipa"
(
  cd "$DIST_DIR"
  /usr/bin/zip -qry "$(basename "$IPA")" Payload
)
shasum -a 256 "$IPA" > "$IPA.sha256"
/usr/bin/unzip -tq "$IPA"
test -s "$IPA"

IPA_METADATA_DIAGNOSTICS="$DIST_DIR/ipa-metadata-diagnostics.txt"
python3 - "$IPA" "$IPA_METADATA_DIAGNOSTICS" <<'PYIPA'
import plistlib
import sys
import zipfile

ipa_path, report_path = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(ipa_path) as archive:
    names = archive.namelist()
    plist_entries = [
        name
        for name in names
        if name.startswith("Payload/") and name.endswith(".app/Info.plist")
    ]
    if len(plist_entries) != 1:
        raise SystemExit(
            f"expected exactly one app Info.plist in IPA, found {plist_entries!r}"
        )
    info = plistlib.loads(archive.read(plist_entries[0]))

launch = info.get("UILaunchStoryboardName")
families = info.get("UIDeviceFamily", [])
orientations = info.get("UISupportedInterfaceOrientations", [])
landscape = {
    "UIInterfaceOrientationLandscapeLeft",
    "UIInterfaceOrientationLandscapeRight",
}
resources = {
    "phase_zero_native.html": any(
        name.endswith("/phase_zero_native.html") for name in names
    ),
    "PrivacyInfo.xcprivacy": any(
        name.endswith("/PrivacyInfo.xcprivacy") for name in names
    ),
    "Assets.car": any(name.endswith("/Assets.car") for name in names),
    "LaunchScreen.storyboardc": any(
        "/LaunchScreen.storyboardc/" in name for name in names
    ),
}
lines = [
    f"Info.plist entry={plist_entries[0]!r}",
    f"UILaunchStoryboardName={launch!r}",
    f"UIDeviceFamily={families!r}",
    f"UISupportedInterfaceOrientations={orientations!r}",
    "UISupportedInterfaceOrientations~ipad="
    f"{info.get('UISupportedInterfaceOrientations~ipad')!r}",
    "NSAppleMusicUsageDescription present="
    f"{bool(info.get('NSAppleMusicUsageDescription'))}",
    "NSMotionUsageDescription present="
    f"{bool(info.get('NSMotionUsageDescription'))}",
]
for key, value in resources.items():
    lines.append(f"resource {key}={value}")
with open(report_path, "w", encoding="utf-8") as report:
    report.write("\n".join(lines) + "\n")
print("Final IPA metadata check:")
for line in lines:
    print("  " + line)

if launch != "LaunchScreen":
    raise SystemExit("IPA lost UILaunchStoryboardName=LaunchScreen")
if 1 not in families:
    raise SystemExit("IPA lost iPhone UIDeviceFamily support")
if not landscape.issubset(set(orientations)):
    raise SystemExit("IPA lost the two landscape orientations")
if not info.get("NSAppleMusicUsageDescription"):
    raise SystemExit("IPA lost NSAppleMusicUsageDescription")
if not info.get("NSMotionUsageDescription"):
    raise SystemExit("IPA lost NSMotionUsageDescription")
if not all(resources.values()):
    raise SystemExit(f"IPA resource check failed: {resources!r}")
PYIPA

echo "Built: $IPA"
cat "$IPA.sha256"
