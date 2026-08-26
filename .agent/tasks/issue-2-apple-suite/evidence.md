# Evidence

Collected from the final working tree on 2026-08-25. Production code was not
changed during this evidence pass. Raw receipts live under `raw/`.

## Result

All frozen acceptance criteria pass. Physical iPhone/Apple Watch behavior and
all mobile App Store actions remain explicitly unclaimed owner gates, as
required by AC8.

## Acceptance criteria

### AC1 — PASS — macOS regression safety

- `raw/logs/swift-test.log` records 14 tests executed with 0 failures, including
  persistence, prompt parsing, pace modes, and remote-message round trips.
- `raw/logs/macos-release.log` records a successful Release build.
- `raw/logs/product-inspection.log` records a universal macOS executable with
  `x86_64` and `arm64` slices.

### AC2 — PASS — iPhone editor

- `KyuvaMobile/UI/MobileEditorView.swift` exposes accessible create, select,
  rename, edit, delete-confirmation, and Present controls.
- `raw/logs/swift-test.log` includes
  `testCreateAndDeleteKeepAValidSelectionAndPersist` and
  `testFlushPendingSavePersistsTheLatestDebouncedEdit` as passing.
- `raw/screenshots/ios-editor-launch.png` is a fresh post-install launch on the
  canonical iPhone 17 simulator and shows the previously persisted
  `Device Persistence Check` title and content.

### AC3 — PASS — iPhone prompt

- `raw/screenshots/ios-prompt-controls.png` shows the final constrained prompt
  viewport with title, progress/remaining time, reading cue, reset,
  slower/play/faster controls, and pace value all visible.
- `KyuvaMobile/UI/MobilePromptSettingsView.swift` implements fixed speed,
  words-per-minute, finish-time, font size, stage-direction normal/dim/hidden,
  and mirror settings.
- `KyuvaMobile/UI/MobilePromptView.swift` binds those settings, reports progress
  and time remaining, and disables idle sleep only while presenting.
- Pace-mode and remaining-time behavior is covered by the passing
  `ScrollControllerTests` in `raw/logs/swift-test.log`.

### AC4 — PASS — Watch remote

- `raw/logs/watch-release.log` records a successful watchOS Release build.
- `raw/logs/ios-release.log` records successful embedded-binary validation for
  `Kyuva Watch App.app`; `raw/logs/product-inspection.log` independently confirms
  that the Watch product is embedded.
- `raw/logs/swift-test.log` records property-list command and snapshot round-trip
  tests as passing.
- `raw/logs/simulator-pair-state.log` records the paired simulators as active and
  connected. `raw/screenshots/watch-connected-final.png` shows the final Watch
  remote receiving the active script and pace. `raw/screenshots/watch-play-command.png`
  and `raw/screenshots/ios-watch-controlled.png` show a Watch play command
  changing both products to the running state and advancing iPhone progress.
- This simulator proof does not claim physical WatchConnectivity behavior.

### AC5 — PASS — Apple configuration

- `raw/logs/config-summary.json` records automatic signing, team `956F3UPBRX`,
  version `1.0`, build `1`, bundle identifiers, deployment targets, and device
  families for all three targets.
- `raw/logs/product-inspection.log` records iPhone family `1`, Watch family `4`,
  `WKApplication = true`, companion bundle `com.kikuai.kyuva`, valid privacy
  manifests, embedded `Assets.car` files, and
  `ITSAppUsesNonExemptEncryption = false`.
- The shared Liquid Glass source icon is at `Kyuva/Resources/AppIcon.icon`; the
  1024-pixel App Store render is at `AppStore/Icon/Kyuva-AppIcon-1024.png`.

### AC6 — PASS — privacy and simplicity

- `raw/logs/privacy-dependency-scan.log` records zero Swift package dependencies,
  no camera/microphone/speech/store/cloud/custom-network capability imports,
  no usage-description keys, and only the expected macOS sandbox/file-picker
  entitlements.
- The privacy manifest declares only the required UserDefaults accessed-API
  reason. There is no account, analytics, advertising, purchase, subscription,
  or backend implementation.

### AC7 — PASS — fresh proof

- `raw/logs/ios-simulator-debug.log` records a successful Debug build for the
  canonical iPhone 17 simulator.
- `raw/logs/ios-simulator-launch.log` records a successful launch of
  `com.kikuai.kyuva`.
- `raw/logs/ios-release.log`, `raw/logs/watch-release.log`, and
  `raw/logs/macos-release.log` are fresh Release receipts.
- `raw/logs/project-list.json` records the shared `Kyuva`, `Kyuva iOS`, and
  `Kyuva Watch App` schemes and targets.

### AC8 — PASS — owner gates preserved

- Physical iPhone/Watch communication is `UNKNOWN`; only paired-simulator
  behavior is claimed.
- No iPhone or Watch build was uploaded to App Store Connect.
- The prepared macOS version was not added to App Review, submitted, or
  released. Those actions still require a separate owner instruction.

## App Store draft readback

During this task, App Store Connect was reloaded and showed macOS version `1.0`
build `1` selected, five screenshots persisted, `Data Not Collected` published,
and reviewer contact saved for Mykyta Dudnichenko. The enabled `Add for Review`
action was not used. The exact five uploaded screenshot assets are retained as
`raw/screenshots/macos-store-01.png` through `macos-store-05.png`.

## Post-acceptance release update — 2026-08-25

This immutable update supersedes only the App Store build state recorded above;
the earlier acceptance evidence remains a historical snapshot.

- `raw/logs/macos-upload-build-2.log` records the authorized macOS `1.0 (2)`
  package reaching `Upload succeeded` and `EXPORT SUCCEEDED`.
- `raw/logs/app-store-build-2-readback.txt` records the authenticated App Store
  Connect readback after processing: builds `2` and `1` were both `Готово к
  отправке`, while build `1` remained selected on the version page.
- The version was not added to App Review, submitted, or released.
- Source subsequently advanced to `1.0 (3)` for the refined System Dark Liquid
  Glass icon. Build `3` remains a local candidate until a separately authorized
  upload.

## Post-acceptance release update — 2026-08-26

This update supersedes only the release state above; the original acceptance
evidence and build `2` handoff remain historical snapshots.

- `raw/logs/macos-upload-build-3.log` records the authorized macOS `1.0 (3)`
  package reaching `Upload succeeded`, `Uploaded Kyuva`, and
  `EXPORT SUCCEEDED`.
- `raw/logs/app-store-build-3-submission-readback.txt` records authenticated
  server readbacks after processing and submission: build `3` is attached to
  macOS version `1.0`, the version is `Waiting for Review`, one object was
  submitted with no remaining draft, and automatic release after approval is
  selected.
- The same readback confirms five Mac screenshots, a published `Data Not
  Collected` privacy answer, a free price, public distribution, and availability
  in 27 storefronts.
- App Review approval and public App Store availability are not yet claimed.
- No iPhone or Apple Watch build was uploaded or submitted.
