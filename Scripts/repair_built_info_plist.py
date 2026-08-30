#!/usr/bin/env python3
"""Repair runtime metadata in Xcode's processed app Info.plist.

The source plist is authoritative for ordinary runtime keys, while Xcode's
already-expanded bundle identifier, executable name, version, SDK metadata,
and other generated values remain untouched. Mandatory privacy strings and
phone-layout keys also have deterministic fallbacks so a generated plist can
never silently erase them again.
"""

from __future__ import annotations

import copy
import plistlib
import sys
from pathlib import Path
from typing import Any


LANDSCAPE = [
    "UIInterfaceOrientationLandscapeLeft",
    "UIInterfaceOrientationLandscapeRight",
]

# These are intentionally duplicated here as an independent last line of
# defence. The normal source of truth remains BuildSupport/Info.plist.
DEFAULT_MUSIC_DESCRIPTION = (
    "用于连接你的 Apple Music 资料库，在游戏中选择、播放和控制音乐。"
)
DEFAULT_MOTION_DESCRIPTION = (
    "用于陀螺仪精细瞄准，并让液态玻璃界面产生轻微的设备姿态反馈。"
)


def contains_build_variable(value: Any) -> bool:
    if isinstance(value, str):
        return "$(" in value
    if isinstance(value, list):
        return any(contains_build_variable(item) for item in value)
    if isinstance(value, dict):
        return any(contains_build_variable(item) for item in value.values())
    return False


def nonempty_string(value: Any, fallback: str) -> str:
    if isinstance(value, str) and value.strip():
        return value
    return fallback


def main() -> int:
    if len(sys.argv) != 3:
        print(
            "usage: repair_built_info_plist.py SOURCE_PLIST BUILT_PLIST",
            file=sys.stderr,
        )
        return 2

    source_path = Path(sys.argv[1])
    built_path = Path(sys.argv[2])
    if not source_path.is_file():
        raise SystemExit(f"source plist not found: {source_path}")
    if not built_path.is_file():
        raise SystemExit(f"built plist not found: {built_path}")

    with source_path.open("rb") as handle:
        source = plistlib.load(handle)
    with built_path.open("rb") as handle:
        built = plistlib.load(handle)

    if not isinstance(source, dict) or not isinstance(built, dict):
        raise SystemExit("Info.plist root must be a dictionary")

    source_music = nonempty_string(
        source.get("NSAppleMusicUsageDescription"),
        DEFAULT_MUSIC_DESCRIPTION,
    )
    source_motion = nonempty_string(
        source.get("NSMotionUsageDescription"),
        DEFAULT_MOTION_DESCRIPTION,
    )

    print("Info.plist repair input:")
    print(f"  source={source_path}")
    print(
        "  source NSAppleMusicUsageDescription present="
        f"{bool(source.get('NSAppleMusicUsageDescription'))}"
    )
    print(
        "  source NSMotionUsageDescription present="
        f"{bool(source.get('NSMotionUsageDescription'))}"
    )
    print(f"  built={built_path}")

    observed_before = {
        "UILaunchStoryboardName": built.get("UILaunchStoryboardName"),
        "UIDeviceFamily": built.get("UIDeviceFamily"),
        "UISupportedInterfaceOrientations": built.get(
            "UISupportedInterfaceOrientations"
        ),
        "UISupportedInterfaceOrientations~ipad": built.get(
            "UISupportedInterfaceOrientations~ipad"
        ),
        "NSAppleMusicUsageDescription": built.get(
            "NSAppleMusicUsageDescription"
        ),
        "NSMotionUsageDescription": built.get("NSMotionUsageDescription"),
    }

    restored: list[str] = []
    for key, value in source.items():
        # Preserve Xcode's expanded bundle ID, version, product name, executable,
        # and any future build-setting-backed value.
        if contains_build_variable(value):
            continue
        if built.get(key) != value:
            built[key] = copy.deepcopy(value)
            restored.append(key)

    forced: dict[str, Any] = {
        "UILaunchStoryboardName": "LaunchScreen",
        "UISupportedInterfaceOrientations": LANDSCAPE,
        "UISupportedInterfaceOrientations~ipad": LANDSCAPE,
        "NSAppleMusicUsageDescription": source_music,
        "NSMotionUsageDescription": source_motion,
        "CADisableMinimumFrameDurationOnPhone": True,
        "UIApplicationSupportsIndirectInputEvents": True,
        "UIStatusBarHidden": True,
        "UIViewControllerBasedStatusBarAppearance": True,
        "ITSAppUsesNonExemptEncryption": False,
    }
    for key, value in forced.items():
        if built.get(key) != value:
            built[key] = copy.deepcopy(value)
            if key not in restored:
                restored.append(key)

    families = built.get("UIDeviceFamily")
    if not isinstance(families, list):
        families = []
    normalized: list[int] = []
    for value in families:
        if isinstance(value, int) and value not in normalized:
            normalized.append(value)
    for required in (1, 2):
        if required not in normalized:
            normalized.append(required)
    if built.get("UIDeviceFamily") != normalized:
        built["UIDeviceFamily"] = normalized
        restored.append("UIDeviceFamily")

    # Xcode emits a binary plist in the app bundle. Preserve that form.
    with built_path.open("wb") as handle:
        plistlib.dump(built, handle, fmt=plistlib.FMT_BINARY, sort_keys=False)

    with built_path.open("rb") as handle:
        verified = plistlib.load(handle)

    print("Info.plist runtime metadata repair:")
    for key, value in observed_before.items():
        print(f"  before {key}={value!r}")
    if restored:
        print("  restored keys: " + ", ".join(sorted(set(restored))))
    else:
        print("  restored keys: none; processed plist was already complete")
    print(
        "  after UILaunchStoryboardName="
        f"{verified.get('UILaunchStoryboardName')!r}"
    )
    print(f"  after UIDeviceFamily={verified.get('UIDeviceFamily')!r}")
    print(
        "  after UISupportedInterfaceOrientations="
        f"{verified.get('UISupportedInterfaceOrientations')!r}"
    )
    print(
        "  after NSAppleMusicUsageDescription present="
        f"{bool(verified.get('NSAppleMusicUsageDescription'))}"
    )
    print(
        "  after NSMotionUsageDescription present="
        f"{bool(verified.get('NSMotionUsageDescription'))}"
    )

    if verified.get("UILaunchStoryboardName") != "LaunchScreen":
        raise SystemExit("failed to restore UILaunchStoryboardName=LaunchScreen")
    if 1 not in verified.get("UIDeviceFamily", []):
        raise SystemExit("failed to restore iPhone device-family support")
    if not set(LANDSCAPE).issubset(
        set(verified.get("UISupportedInterfaceOrientations", []))
    ):
        raise SystemExit("failed to restore both iPhone landscape orientations")
    if not verified.get("NSAppleMusicUsageDescription"):
        raise SystemExit("NSAppleMusicUsageDescription is missing after repair")
    if not verified.get("NSMotionUsageDescription"):
        raise SystemExit("NSMotionUsageDescription is missing after repair")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
