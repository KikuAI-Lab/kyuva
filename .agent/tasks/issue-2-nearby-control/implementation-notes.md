# Implementation notes

lazy-senior check:
- lower rung: system `.txt` share/import for scripts; custom code only for the missing immediate remote
- GitHub prior art: `gh search` plus `saagarjha/AppleConnect` showed Bonjour + TLS-PSK; adoption=borrow architecture, not its LGPL code or dependency
- new code justified: existing WatchConnectivity cannot connect iPhone to Mac, and plaintext/local auto-accept would violate the product contract

The independent Luna architecture review rejected MultipeerConnectivity because
Apple's current documentation routes new work to Network.framework. It proposed
a persistent shared key delivered through a share item. The coordinator narrowed
that design to a fresh 80-bit typed code per session: no Keychain schema, no
persistent trust state, no pairing-file document type, and no revocation UI.

Script content deliberately stays out of the custom protocol. Apple's standard
plain-text share and file-import surfaces cover transfer with less code, clearer
user intent, and no conflict-resolution or data-loss surface.

The macOS sandbox needs both network directions for this narrowly scoped
feature: `network.server` permits the incoming TCP session, while Bonjour's
mDNS advertisement sends UDP and therefore also needs `network.client`. The
application has no general internet client code, backend, or third-party SDK;
release inspection and source scans verify that boundary.

On current macOS, a listener-only registration can wait for local-network
privacy without presenting the consent UI. While the user-started remote is
starting, Kyuva therefore runs an `NWBrowser` authorization probe for the same
declared `_kyuva._tcp` service. It consumes no results, opens no connection,
and is cancelled as soon as Bonjour reports the listener registered.

The transport deliberately does not set `includePeerToPeer`: this slice promises
the same local network, not an infrastructure-free AWDL link. Omitting the flag
avoids an extra peer-to-peer discovery surface and keeps ordinary Bonjour/mDNS
behavior deterministic.

Implementation hardening completed on 2026-08-25:
- response decoding validates raw JSON progress before `PlaybackSnapshot` can
  clamp it, including boolean and out-of-range rejection
- the iPhone preserves visible connect failures while restarting discovery and
  fails an in-flight request after five seconds instead of silently hanging
- text import reads at most 1 MiB plus one byte, and exported names remove
  duplicate `.txt` suffixes, control characters, slashes, and colons
- the Mac listener has a 20-second startup deadline with a Local Network
  recovery message; an unauthenticated connection has a 10-second deadline
- all temporary discovery logging was removed before the final builds

Current macOS local-network behavior is an honest release gap, not a protocol
fallback. A fresh sandboxed QA identity reached the 20-second recovery state,
but macOS did not present or register the Local Network consent entry. The app
therefore did not obtain a real Bonjour listener proof on this Mac. No private
TCC database was edited and no plaintext transport was introduced.

The final iPhone simulator build did discover a host-advertised
`Kyuva Remote` Bonjour service and retained a visible error after a TLS-only
connection timeout. Unit tests separately prove matching TLS-PSK succeeds and a
mismatched PSK never reaches ready. These are supporting checks only; they do
not replace the physical-device criteria.
