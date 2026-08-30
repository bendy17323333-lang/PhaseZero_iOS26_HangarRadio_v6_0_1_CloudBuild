# Build Fix Report — 6.0.1

## Source log findings

The uploaded GitHub Actions log reached Xcode 26.6 / iPhoneOS 26.5 compilation, then stopped with seven compile errors:

1. `affectsListeningHistory` required iOS 26.4 while the deployment floor was iOS 26.0.
2. `ApplicationMusicPlayer.Queue(playlist:)` required a `startingAt` entry.
3. `Bundle.module` was unavailable in the XcodeGen application target.
4. Two obsolete `MusicPlayerView.swift` initializers referenced a removed `GameViewModel.music` property.
5. `NativeCombatFXView` exceeded the Swift compiler's expression type-check budget.
6. A nested `SettingsStore` property could not be mutated through `$model.settings` because `settings` was a `let` property.

Warnings also identified a useless `@preconcurrency` conformance annotation and the iOS 26 deprecation of `UIScreen.main`.

## Applied corrections

- Kept listening-history behavior through the documented default instead of setting the newer property.
- Hydrated playlist entries and supplied the first entry to the required queue initializer.
- Added `SWIFT_PACKAGE` resource-bundle switching.
- Added a dedicated observed `SettingsStore` binding to `PhaseRadioView`.
- Extracted `ShieldRingView` from the large SwiftUI expression.
- Resolved the current screen through active `UIWindowScene` instances.
- Removed the ineffective conformance annotation.
- Excluded and defensively deletes three obsolete music prototype files.

## Local checks available in this environment

- Swift 6.2.1 parser: all 42 application Swift files passed.
- `Package.swift`: parser passed.
- Bash syntax: build script passed.
- Property-list parsing: passed.
- YAML parsing: passed.
- JavaScript syntax check: passed.

A full Apple SDK type-check still occurs in GitHub Actions because this environment is not macOS and does not contain Xcode.
