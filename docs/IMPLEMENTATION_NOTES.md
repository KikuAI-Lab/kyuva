# Implementation Notes

> Live decision record for non-obvious product and implementation tradeoffs. Issue #2 owns delivery state; code and tests own behavior. Update this file only when a decision or residual risk changes.

## 2026-08-30 — Core experience reset

### Decision

Replace the Mac Settings-led utility and iPhone dropdown editor with one legible sequence: library, editor, prompt. Keep Kyuva local-first and dependency-free. Pause Store submission, commerce activation, recording, cloud sync, team features, and new remote transports until the redesigned daily flow passes owner testing.

### Evidence

- Current Mac source launches into the camera overlay; script editing is buried in a five-tab Settings window.
- Current iPhone source combines script selection, editing, file actions, settings, and presentation in one dense screen.
- The installed Teleprompter.com Mac app and its current official product pages make library, search, script entry, and prompting separate, recognizable states. Relevant public references: <https://www.teleprompter.com/platform-features>, <https://www.teleprompter.com/features/voice-scrolling>, and <https://apps.apple.com/us/app/teleprompter-com/id1420515755>.

No private competitor script content is copied into Kyuva, fixtures, screenshots, or documentation.

### Boundaries

- Preserve one local `ScriptManager`, on-device speech recognition, truthful capture behavior, fixed/WPM/duration pacing, mirroring, stage directions, WatchConnectivity, and disabled Release commerce.
- Do not restore Bonjour, network entitlements, iPhone-to-Mac remote behavior, account requirements, analytics, or a backend.
- User acceptance is required on the final Mac and iPhone builds before any new App Store submission.
