# Runtime Fix Report — Phase Zero 6.0.6

## User-visible regressions

1. Hangar and Phase Radio leading toolbar status items were rendered by iOS 26 Liquid Glass as pressable controls, although they had no action.
2. Once Apple Music authorization succeeded, the Phase Radio UI effectively presented only the Apple Music library; the built-in procedural soundtrack had no persistent library surface.
3. A stale `MPMusicPlayerControllerErrorDomain Code 2` message could remain visible even while the replacement queue was already playing.
4. The procedural soundtrack's noise transients bypassed the dedicated music gain bus, so ducking did not completely silence the soundtrack.

## Changes

### Toolbar semantics

- Removed the leading `ToolbarItem` from `HangarView`.
- Removed the leading authorization `ToolbarItem` from `PhaseRadioView`.
- Retained only controls with real actions in the navigation bar.
- Moved all status information into visible content panels.

### Unified radio model

Added:

- `PhaseRadioSource`
- `BuiltInSoundtrack`
- Four built-in procedural soundtrack profiles
- Persistent game soundtrack selection and enabled state
- Native controls for selecting, pausing and skipping game soundtrack profiles

The built-in soundtrack library is always rendered, independent of Apple Music authorization.

### MusicKit queue handoff

`AppleMusicService` now:

- owns a single cancellable playback command task;
- assigns a request identifier to each queue transition;
- ignores completion and errors from superseded transitions;
- publishes a temporary audio-focus state before changing the queue;
- removes the extra explicit `prepareToPlay()` call;
- treats Code 2 as a possible stale queue interruption;
- checks the real player state before retrying;
- retries once only if the replacement queue is still idle;
- clears stale errors whenever playback is demonstrably active;
- maps remaining failures to user-facing Chinese messages.

### WebAudio routing

- Added a dedicated soundtrack profile table.
- Added soundtrack selection and enable commands to the native bridge.
- Routed all soundtrack tones and noise through `musicGain`.
- Kept gameplay SFX on the master SFX path.
- `externalMusicActive` now fades only the soundtrack bus.

## Versioning

- Version: 6.0.6
- Build: 16
- Bundle ID: unchanged

## Verification boundary

The package has passed Linux-side Swift parser checks, JavaScript syntax/runtime checks, plist/YAML/asset validation and bridge pairing checks. MusicKit queue behavior still requires an iOS 26 device and a correctly entitled signed build for final confirmation.
