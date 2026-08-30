# Phase Zero 6.0.3 — iPhone Full-Screen Canvas Fix

## Symptom

The installed iPhone build rendered the application inside a centered 3:2 rectangle with large black bars on both sides. The screenshot geometry is consistent with iOS falling back to its legacy 480×320 compatibility canvas rather than providing the modern edge-to-edge iPhone landscape window.

## Root cause addressed

The cloud-built app relied only on the newer `UILaunchScreen` dictionary. Some sideload/re-sign pipelines and compatibility paths do not reliably preserve or recognize that configuration early enough for device-family sizing.

Version 6.0.3 switches the cloud build to a compiled launch storyboard:

- Adds `Sources/AppModule/Resources/LaunchScreen.storyboard`.
- Sets `UILaunchStoryboardName` to `LaunchScreen` in both plist paths.
- Explicitly puts the storyboard in Xcode's Resources build phase.
- Verifies that `LaunchScreen.storyboardc` exists in the built `.app` and final IPA.
- Verifies that the final Info.plist contains iPhone in `UIDeviceFamily` and both landscape orientations.
- Uploads `fullscreen-diagnostics.txt` beside the IPA.

The Bundle ID remains `com.asher.phasezero.ios26hangarradio600`, so existing MusicKit service configuration does not need to be recreated.

## Installation note

Install 6.0.3 over the existing build first. If iOS continues showing the cached compatibility window, remove the old app, restart the iPhone, and install 6.0.3 again. Removing the app also removes local progression unless it has been backed up.
