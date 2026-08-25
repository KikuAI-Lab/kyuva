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
