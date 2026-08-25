# Issue #2 — Apple suite

Status: frozen on 2026-08-25.

## Goal

Implement and verify Kyuva as a simple, free teleprompter suite, completing the macOS release draft first and then adding an iPhone teleprompter and a dependent Apple Watch remote. Preserve the completed macOS App Store draft and do not add it to App Review or release it without a separate owner approval.

## Scope

- Reuse the existing `Script`, `ScriptManager`, `LocalStore`, and `ScrollController` behavior where it is portable.
- Add one iPhone-only SwiftUI app target using the existing `com.kikuai.kyuva` bundle identifier so it can become another platform of the same App Store record.
- Add one single-target dependent watchOS app with bundle identifier `com.kikuai.kyuva.watchkitapp`.
- Use WatchConnectivity for immediate play/pause, reset, faster, and slower commands plus a compact playback-state reply.
- Keep scripts local to each app container. The Watch app is a remote, not a second editor.
- Reuse the existing Liquid Glass icon and privacy manifest.

## Acceptance criteria

- **AC1 — macOS regression safety:** the existing macOS app still builds for its supported architectures and all existing Swift package tests pass.
- **AC2 — iPhone editor:** the iPhone app can create, select, rename, edit, and delete local scripts through an accessible SwiftUI interface, and the latest edit survives an app lifecycle flush/reload.
- **AC3 — iPhone prompt:** the selected script can open in a distraction-free prompt with play/pause, reset, faster/slower pacing, fixed/WPM/duration modes, font sizing, stage-direction dim/hide, mirroring, progress, remaining time, and idle-sleep prevention while presenting.
- **AC4 — Watch remote:** a dependent single-target watchOS app builds, is embedded in the iPhone product, and exposes play/pause, reset, faster, and slower controls. Its WatchConnectivity messages and playback-state replies are represented by tested property-list-safe values.
- **AC5 — Apple configuration:** iPhone and Watch targets use automatic signing with team `956F3UPBRX`, version `1.0` build `1`, required bundle relationships, the Kyuva icon, privacy manifest, and `ITSAppUsesNonExemptEncryption = false` without adding permissions unrelated to prompting.
- **AC6 — privacy and simplicity:** no account, analytics, ads, purchase, subscription, cloud backend, third-party package, microphone, speech recognition, camera capture, or custom network transport is added.
- **AC7 — fresh proof:** the canonical iPhone 17 simulator build and launch are verified, the watchOS target builds against the installed watchOS SDK, the combined iPhone product contains the Watch app, and a fresh verifier records PASS/FAIL/UNKNOWN for every criterion.
- **AC8 — owner gates:** physical iPhone/Watch communication, any iOS/watchOS App Store upload, adding a version to App Review, submission, and release remain explicit owner gates and are not claimed from simulator/build evidence.

## Constraints

- Minimum deployment: iOS 17 and watchOS 10.
- iPhone only for the first mobile release; no iPad target or iPad screenshot obligation.
- The Watch app is dependent on the companion iPhone app and intentionally short-interaction focused.
- Use native SwiftUI, Foundation, Combine, and WatchConnectivity only.
- Preserve unrelated worktree changes and the already uploaded macOS build.

## Non-goals

- Cross-device Mac/iPhone cloud synchronization.
- Script authoring or full script storage on Apple Watch.
- Recording, camera overlays, speech following, AI rewriting, collaboration, widgets, complications, subscriptions, or monetization.
- iPhone or Watch App Store metadata, screenshots, upload, submission, or release in this implementation slice.

## Assumptions

- The iPhone target shares the macOS bundle identifier as another platform in the existing App Store record.
- Immediate remote commands should fail visibly when the counterpart is unreachable rather than queueing stale commands for later delivery.
- Simulator proof is sufficient for code acceptance, while real WatchConnectivity behavior remains UNKNOWN until tested on a paired physical iPhone and Apple Watch.

## Verification plan

1. Run all existing Swift package tests in a disposable scratch directory.
2. Build the macOS scheme unsigned in disposable DerivedData.
3. Build and launch the iPhone scheme on the existing canonical iPhone 17 simulator; inspect editor and prompt states and persistence.
4. Build the watchOS target against the installed watchOS simulator SDK and inspect its product metadata.
5. Inspect the built iPhone bundle for the embedded Watch app, icon, privacy manifests, bundle identifiers, versions, and encryption declarations.
6. Run a fresh verification pass that edits no production code and records criterion-level evidence.
