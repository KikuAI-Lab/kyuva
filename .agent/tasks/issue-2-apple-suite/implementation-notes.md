# Implementation notes

lazy-senior check:
- lower rung: existing portable core plus native SwiftUI and WatchConnectivity
- GitHub prior art: skipped because Apple's current WatchConnectivity sample and Xcode 26 templates are the authoritative platform sources; adoption=borrow architecture
- new code justified: iPhone presentation UI and the dependent Watch remote do not exist in the repository

lazy-senior check — local StoreKit proof:
- lower rung: native Xcode StoreKit configuration plus a simulator smoke; no dependency, wrapper, parser, cache, or new test target
- prior art: Apple's current StoreKit sample supplies the configuration shape; adoption=borrow platform contract
- new code justified: a Debug-only opt-in and one local non-consumable are the smallest way to exercise the exact purchase/restore path while Release remains hard-off

The earlier Watch-specific read-only lazy-senior worker was attempted twice and produced no verdict because the configured terminal worker account returned the same rate-limit 503. No account-routing or global configuration was changed. A fresh StoreKit-focused worker later returned a platform-rung verdict; local SDK evidence overruled only its `SKTestSession` suggestion because the installed macOS SDK exposes no `StoreKitTest` module and this project has no Xcode unit-test target. The accepted lower rung is the official local configuration plus Xcode-driven iPhone and Mac smoke tests.

The Watch remote uses an explicit `requestSnapshot` handshake in addition to
application-context updates. This avoids stale or empty initial state when the
iPhone app was installed before a simulator/device pair became reachable, while
keeping play/pause, reset, faster, and slower commands immediate and visible.

The iPhone prompt measures its natural text height inside a fixed, clipped
viewport. Prompt chrome is a separate overlay, so long scripts and large text
cannot push the title or bottom controls off-screen.

Progress is republished to WatchConnectivity at one-percent boundaries instead
of every animation frame. This keeps the Watch current without turning the
60-fps prompt timer into unnecessary cross-device traffic.

## Physical mobile and upload refresh — 2026-08-30

- Installed and launched the exact current physical iPhone candidate, Kyuva
  `1.0 (4)`, built from runtime source `07b519f`. iPhone Mirroring then verified
  local script creation and selection, present/close, play/pause, progress,
  remaining time, pace adjustment, reset, mirroring, prompt settings, and the
  Voice Follow start/stop state using only the built-in welcome text and a local
  synthetic script title.
- Voice Follow reached the on-device listening state at `0%`. iPhone Mirroring
  explicitly reports that the iPhone microphone is not available from the Mac,
  and a full built-in-script playback through the Mac speakers left progress at
  `0%`. Spoken-position movement therefore still requires a short read-aloud
  outside Mirroring directly beside the physical iPhone; it is not inferred from
  the permission/listening state.
- The paired Apple Watch remains visible to CoreDevice, but a fresh read-only app
  query repeated `RemotePairingError 1001`. No Watch install, launch, control, or
  progress claim is made until the physical tunnel works.
- A deeper CoreDevice readback confirms that the paired Watch has Developer Mode
  enabled but no current transport, no developer disk image, and an unavailable
  tunnel; its last recorded connection was 2026-08-28. Further tunnel retries
  are intentionally deferred until the Watch is awake, unlocked, on Wi-Fi, and
  reachable from the Mac on the same LAN.
- Apple's uploader accepted the signed universal macOS `1.1 (6)` archive and
  reported `Upload succeeded`. App Store Connect then confirmed the binary and
  marked it ready to submit. The processed record reads back version `1.1`,
  build `6`, bundle ID `com.kikuai.kyuva`, macOS 13, `arm64` + `x86_64`, no
  non-exempt encryption, and only sandbox, microphone, user-selected-file, and
  application/team identifier entitlements. This is not treated as build
  selection, submission, approval, or release.
- App Store Connect still has no In-App Purchase product. The prepared contract
  remains one non-consumable lifetime product with
  Release commerce compiled to `false`; no agreement, tax/banking, DSA/trader,
  price, submission, or paid-availability state was changed.

## Local lifetime Pro proof — 2026-08-30

- The shared Debug schemes now opt into one local StoreKit configuration only
  through `KYUVA_LOCAL_STOREKIT_TESTING=1`. The simulated Irish storefront
  exposes exactly one non-consumable, `com.kikuai.kyuva.pro.lifetime`, at
  `€24.99`; the Xcode sheet states that the test purchase does not charge the
  account.
- On the canonical iPhone 17 simulator, the app loaded `Unlock Forever ·
  €24.99`, completed the Xcode purchase, changed to `Lifetime Pro Unlocked`,
  restored the entitlement, and retained it after stop and relaunch. The buy
  button then remained absent. An accidental second tap while the first sheet
  was opening exposed a real concurrency edge; purchase and restore now share a
  transaction-in-progress guard and disable both controls until completion.
- On Mac, the exact Xcode Debug process loaded the same product and presented
  the separate StoreKit confirmation service with the correct name, one-time
  `€24.99` charge, and explicit no-charge test disclosure. The sheet was then
  cancelled intentionally and the app read back `Purchase cancelled.` The Mac
  call uses Apple's window-confirmation overload on macOS 15.2 and later, with
  the standard StoreKit fallback retained for the macOS 13 deployment target.
- SwiftPM tests cover the explicit local-commerce access policy. Fresh Release
  bundle checks require the Mac and iPhone binaries to exclude the Debug opt-in
  string and require every shipped bundle to exclude `.storekit` files. The
  production App Store Connect product still does not exist, so none of this is
  a paid storefront activation claim.
