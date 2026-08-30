# Implementation notes

lazy-senior check:
- lower rung: existing portable core plus native SwiftUI and WatchConnectivity
- GitHub prior art: skipped because Apple's current WatchConnectivity sample and Xcode 26 templates are the authoritative platform sources; adoption=borrow architecture
- new code justified: iPhone presentation UI and the dependent Watch remote do not exist in the repository

The required read-only lazy-senior worker was attempted twice and produced no verdict because the configured terminal worker account returned the same rate-limit 503. No account-routing or global configuration was changed. The local decision therefore uses the existing core, the installed Xcode 26.6 templates, and current Apple documentation.

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
- Apple's uploader accepted the signed universal macOS `1.1 (6)` archive and
  reported `Upload succeeded`. App Store Connect then confirmed the binary and
  marked it ready to submit. The processed record reads back version `1.1`,
  build `6`, bundle ID `com.kikuai.kyuva`, macOS 13, `arm64` + `x86_64`, no
  non-exempt encryption, and only sandbox, microphone, user-selected-file, and
  application/team identifier entitlements. This is not treated as build
  selection, submission, approval, or release.
- App Store Connect still has no In-App Purchase product. The prepared contract
  remains one non-consumable lifetime product with
  `commerceEnabled = false`; no agreement, tax/banking, DSA/trader, price,
  submission, or paid-availability state was changed.
