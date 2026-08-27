# Implementation notes

## Decision

Defer the local iPhone remote from the first Mac App Store release.

The entitlement was technically justified: `LocalRemoteServer` creates an
`NWListener`, advertises `_kyuva._tcp`, and accepts inbound encrypted control
messages. However, the submitted Mac UI directs the reviewer to an iPhone
companion that is not yet available in the App Store. A metadata-only response
would therefore leave the feature difficult to reproduce and risk another
rejection.

## Production change

- Removed the Remote tab and listener lifecycle from the macOS app.
- Removed the Mac-only remote command bridge.
- Removed the local-remote sources from the macOS Xcode target while keeping
  the protocol, server, and mobile client source in the repository for the
  later coordinated Mac + iPhone release.
- Removed the Mac network server/client entitlements and Bonjour/local-network
  purpose strings.
- Incremented only the macOS build number from 3 to 4.
- Updated CI to enforce build 4 and reject any return of Mac network
  entitlements, local-network metadata, or listener markers.
- Updated the public README to record the rejection, the local-only build 4
  boundary, and removal of the unavailable Mac Remote claim.
- Updated Support, Privacy, and the App Store release input so public guidance,
  network disclosure, build number, review notes, and automatic release mode
  match the replacement package.

No App Store Connect mutation has been made for this rejection yet.

## Prepared App Review copy

Reviewer reply draft:

> Hello App Review, thank you for the clarification. In Kyuva macOS 1.0
> (build 4), we removed the unfinished local iPhone remote feature and removed
> both the `com.apple.security.network.server` and
> `com.apple.security.network.client` entitlements. The submitted Mac app no
> longer listens for or initiates network connections. Its remaining
> entitlements are App Sandbox and user-selected read/write access, which is
> used only for script import and export. Please review build 4.

App Review Information draft:

> Kyuva 1.0 (4) is a local-only Mac teleprompter. It does not require an
> account, server, network access, or companion app. Its only entitlements are
> App Sandbox and user-selected read/write access for script import and export.

These drafts are local only. They have not been entered or sent in App Store
Connect.
