# Evidence

Collected from the current working tree and a fresh exported macOS package on
2026-08-27. Production code was not changed during this refreshed evidence
pass.

## Result

All frozen acceptance criteria pass. Kyuva macOS `1.0 (4)` is a verified local
candidate with the unfinished iPhone remote removed from the Mac product and no
network entitlement or listener code in the exported package. App Store Connect
still contains rejected build `3`; no external remediation action has been
performed.

## Acceptance criteria

### AC1 — PASS — listener necessity established

- The preserved future feature in `Kyuva/Platform/LocalRemoteServer.swift`
  creates an `NWListener`, advertises `_kyuva._tcp`, and accepts inbound
  connections, so build `3` genuinely required the server entitlement.
- The macOS Xcode target for build `4` no longer compiles the server, local
  protocol, local security, or shared remote-command sources. Its AppDelegate,
  overlay controller, and Settings UI no longer reference the feature.
- The exported build `4` executable contains none of the listener/service/UI
  markers listed in `raw/release-inspection.txt`.

### AC2 — PASS — Mac entitlements minimized

- The source entitlement file contains only App Sandbox and user-selected
  read/write access.
- The exported, Apple Distribution-signed app contains those two capability
  entitlements plus Apple's application/team identifiers. It contains neither
  network server nor network client.
- The exported Info.plist contains neither Bonjour services nor a local-network
  usage description.

### AC3 — PASS — review remediation is reproducible

- `implementation-notes.md` contains a factual reviewer reply and App Review
  Information draft stating that build `4` removes the unfinished local iPhone
  remote and both network entitlements.
- README, Support, Privacy, and the App Store release input no longer advertise
  or provide instructions for the unavailable Mac Remote. They distinguish
  rejected build `3` from locally prepared build `4`.
- The drafts do not claim a publicly available companion app.
- The five existing Store screenshots show the teleprompter, editor, pace,
  appearance, and hotkeys; none advertises the removed Remote feature.

### AC4 — PASS — regression and package safety

- Swift Package tests pass: 31 executed, 0 failures.
- Fresh universal macOS Release build and archive pass.
- The shared Xcode project still builds the iPhone scheme with its embedded
  Watch target in Release configuration.
- App Store package export succeeds. The exported app is version `1.0`, build
  `4`, contains `x86_64` and `arm64`, and passes strict code-signature checks.
- The macOS CI receipt now checks build `4` and fails if the removed network
  entitlements, plist keys, or executable listener markers return.

### AC5 — PASS — Store state remains honest

- App Store Connect remains at rejected macOS `1.0 (3)` under Guideline 2.4.5.
- Build `4` is prepared locally only. It is not uploaded, attached, submitted,
  approved, public, or released.
- Reviewer reply, review notes, and all mobile Store actions remain unsent.

## Primary receipt

See `raw/release-inspection.txt` for the deterministic commands, inspected
properties, package digest, and Store boundary.
