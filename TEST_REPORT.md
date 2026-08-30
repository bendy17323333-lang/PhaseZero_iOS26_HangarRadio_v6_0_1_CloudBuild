# Phase Zero 6.0.6 local/static verification

## Passed

- Swift 6.2.1 parser: all application Swift files
- Swift parser: `Package.swift`
- JavaScript syntax: extracted inline game script
- Headless Chromium runtime: HTML boot, native bridge initialization, soundtrack commands, settings command, start/move/aim/phase/dash/pause/resume
- Headless Chromium page errors: 0
- Headless Chromium console errors: 0
- Property lists: `AppInfo.plist`, `BuildSupport/Info.plist`, `PrivacyInfo.xcprivacy`
- Asset catalog JSON: all `Contents.json`
- GitHub Actions YAML
- Bash build script syntax
- Python metadata repair script syntax
- Native-to-JavaScript command pairing, including `soundtrack`
- Version consistency: 6.0.6 / build 16

## Source checks

- Hangar leading toolbar status item absent
- Phase Radio leading toolbar status item absent
- Built-in soundtrack library always rendered
- Game soundtrack selection persisted in `SettingsStore`
- Apple Music queue operations serialized through one cancellable task
- Superseded queue errors ignored using request IDs
- Playback-active state clears stale error banners
- Soundtrack noise and tones routed through `musicGain`

## Not available in this environment

- Xcode 26 type checking and linking
- MusicKit entitlement verification
- Apple Music account authorization
- Real `ApplicationMusicPlayer` queue behavior
- iPhone audio-session and route-change testing

The final Apple-specific checks must be performed by Swift Playground or the GitHub Actions macOS/Xcode runner and then on a signed iOS 26 device.
