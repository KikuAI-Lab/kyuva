# Evidence — 2026-08-25

All commands ran from the repository root. Disposable build data and full logs
lived under a validated `/tmp/kyuva-final.*` root and are not committed because
they contain machine-local paths and process identifiers.

## Deterministic checks

- `swift test --scratch-path <scratch>/swiftpm`
  - PASS: 30 tests, 0 failures
  - includes matching TLS-PSK loopback handshake
  - includes inverted mismatched-PSK readiness check
  - includes strict command, version, sequence, replay, frame-size, nested-key,
    response-sequence, and raw-progress validation
  - includes UTF-8, exact 1 MiB, oversized import, and safe export-filename
    boundaries
- macOS universal Release build
  - PASS: `xcodebuild`, `** BUILD SUCCEEDED **`
  - binary architectures: `x86_64 arm64`
- iOS Release build
  - PASS: `xcodebuild`, `** BUILD SUCCEEDED **`
- watchOS Release build
  - PASS: independent `xcodebuild`, `** BUILD SUCCEEDED **`
- iPhone simulator Debug build from the final source
  - PASS: `xcodebuild`, `** BUILD SUCCEEDED **`
- existing local development signing, without provisioning updates
  - PASS: signed macOS Release build
  - PASS: signed iOS Release build with embedded signed Watch app
  - PASS: strict deep signature verification for all three products
- `git diff --check`
  - PASS
- plist lint
  - PASS for Mac/iPhone Info plists, Mac entitlements, and privacy manifest

The only build warnings were Xcode's expected “No AppIntents.framework
dependency found” metadata skip; the targets do not define App Intents.

## Product inspection

- Mac: `com.kikuai.kyuva`, version `1.0`, build `2`, `_kyuva._tcp`, Local
  Network explanation, privacy manifest, universal executable
- iPhone: `com.kikuai.kyuva`, version `1.0`, build `2`, `_kyuva._tcp`, Local
  Network explanation, privacy manifest, embedded Watch app
- Watch: `com.kikuai.kyuva.watchkitapp`, version `1.0`, build `2`, companion
  identifier `com.kikuai.kyuva`, privacy manifest
- Mac sandbox source entitlements contain app sandbox, user-selected-file
  read/write, network server, and network client only
- signed development products add only Apple's expected team/application and
  debug-task entitlements; no new capability was requested from the provider
- no Xcode package references; SwiftPM dependencies are empty
- no MultipeerConnectivity, peer-to-peer discovery, StoreKit, analytics,
  speech, camera-session, or backend runtime surfaces were found
- no multicast, camera, or audio-input entitlement was found
- generated App Store icon is 1024 × 1024 and alpha-free; Icon Composer source
  is present, and its compiled rendition is alpha-free in each product

## Interactive checks

- Final iPhone simulator build discovered a host-advertised `Kyuva Remote`
  `_kyuva._tcp` service and selected it automatically.
- A TLS-only connection to a deliberately non-responsive synthetic endpoint
  failed visibly after the bounded timeout; the error remained visible while
  discovery continued. No plaintext fallback occurred.
- Earlier in the same accepted simulator slice, WatchConnectivity connected the
  paired Watch simulator to iPhone: Watch Play started the iPhone prompt, Watch
  Faster changed the pace, and Watch progress reached 100 percent.
- A sandboxed Mac QA identity reached the new 20-second Local Network recovery
  message. macOS did not display or register a consent entry, so real Mac
  Bonjour advertisement and physical cross-device commands remain unproved.
- Simulator `.txt` import/share round-trip and a large Dynamic Type layout pass
  succeeded earlier in this slice. Physical AirDrop/Files transfer remains
  unproved.

## External-state boundary

- App Store Connect remained on the already uploaded macOS `1.0 (1)` draft.
  Source build `2` was not uploaded.
- No accessibility card was published, no Add for Review action was taken, and
  no submission, credential, OTP, 2FA, keychain password, provider change, or
  purchase occurred.
- At the final readback, the paired physical iPhone and Apple Watch were both
  reported unavailable. No current build was installed on either device.
- Task-created QA app copies were stopped and moved to Trash, so they remain
  recoverable. No user app data, provisioning profiles, archives, or device
  support files were removed.

## Post-verdict accessibility delta

After the independent verdict timestamp, the Mac source received two bounded
accessibility fixes: non-essential hover and window-resize animations now honor
Reduce Motion, and the one-time pairing code exposes its formatted value to the
accessibility tree.

- `swift test --disable-sandbox --scratch-path <scratch>/SwiftPM`
  - PASS: 30 tests, 0 failures
- `swift build -c release --scratch-path <scratch>/SwiftPMRelease`
  - PASS
- unsigned Xcode macOS Release build
  - PASS: universal `x86_64 arm64`, `** BUILD SUCCEEDED **`
- `git diff --check`
  - PASS

The verifier verdict was not reissued for this Mac-only accessibility delta.
The physical transfer, Bonjour consent, iPhone remote, and Watch gates remain
UNKNOWN/HOLD; App Store Connect was not changed.
