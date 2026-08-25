<p align="center">
  <img src="AppStore/Icon/Kyuva-AppIcon-1024.png" width="128" height="128" alt="Kyuva Icon">
</p>

<h1 align="center">Kyuva</h1>

<p align="center">
  <strong>Local-first teleprompter for Mac, iPhone, and Apple Watch</strong>
</p>

<p align="center">
  <em>Write on your device, present without an account, control the prompt from your wrist</em>
</p>

## About

Kyuva is an open-source Apple teleprompter. The Mac app keeps a compact overlay near the camera, the iPhone app provides a full-screen prompting surface, and the dependent Apple Watch app acts as a short-interaction remote.

### Capture visibility

The overlay is a normal macOS window and may appear in screen shares or recordings. Verify the preview before presenting, or share a single app window that omits Kyuva. Kyuva does not promise capture exclusion.

## Release Status

Kyuva is preparing a free first Mac App Store release for the 27 European Union storefronts. macOS version `1.0` build `1`, five screenshots, the `Data Not Collected` privacy answer, and reviewer contact are prepared in App Store Connect, but the version has not been added to App Review or submitted. Current source has advanced to build `2` for local transfer and remote testing; that newer build has not been uploaded. The iPhone and Apple Watch targets are implemented and verified locally; no mobile upload or store availability is claimed yet.

The first releases have no purchases, subscriptions, advertising, account, analytics, or required backend.

The binary attached to the historical `v1.0.0` GitHub release is a development build, not a verified App Store distribution artifact. Build the current source until a signed and verified replacement is published.

## Feature Snapshot

- Mac camera-side overlay with adjustable size, appearance, multi-display cycling, and global shortcuts
- iPhone script editor with local persistence and a distraction-free full-screen prompt
- Fixed-speed, words-per-minute, and target-duration scrolling
- Centered reading cue with progress and remaining-time feedback
- Bracketed stage-direction controls plus text-only mirroring for beam-splitter rigs
- Apple Watch play/pause, start-over, slower, and faster controls through WatchConnectivity
- Plain-text import and sharing on iPhone plus import/export on Mac through system Files, Share, and AirDrop surfaces
- Optional one-time, encrypted local iPhone remote for the active Mac prompt; script content never crosses its control channel
- Recoverable local script storage
- No account, cloud sync, analytics, or required network service

## Build From Source

```bash
git clone https://github.com/kiku-jw/kyuva.git
cd kyuva
open Kyuva.xcodeproj
```

You can also try:

```bash
swift build
```

Requirements:

- macOS 13.0+
- iOS 17.0+ for the iPhone target
- watchOS 10.0+ for the dependent Watch target
- Xcode 26.6+ for all Apple targets, including the shared Liquid Glass icon
- A compatible Swift 5.9+ toolchain for package tests

Kyuva is under active release hardening. Follow [Issue #2](https://github.com/kiku-jw/kyuva/issues/2) for the macOS, iPhone, and Apple Watch delivery gates.

## Privacy

Kyuva keeps its core behavior local:

- prompting and script editing happen locally
- scripts are stored in the Mac or iPhone app container
- the Watch exchanges only current prompt state and control commands with the paired iPhone
- text transfer happens only when you choose a system file/share action
- the optional Mac remote is explicitly started, one-time paired, encrypted, and local-network only
- no account is required
- no analytics or tracking are built in

More detail is available in [PRIVACY.md](PRIVACY.md).

## Support

See [SUPPORT.md](SUPPORT.md) for troubleshooting and the privacy-safe issue-reporting path.

## Follow the work

Project notes and new tools: [Telegram](https://t.me/kiku_ai) ·
[LinkedIn](https://www.linkedin.com/in/kiku-jw/) ·
[KikuAI](https://kikuai.dev/)

## License

This repository is released under [AGPL-3.0](LICENSE).

## Forking

Forks are welcome under the project license. Kyuva's narrow focus is simple, local-first prompting across Apple devices.

<!-- author-links:start -->
<p align="center">
  <a href="https://kikuai.dev/"><img src="https://img.shields.io/badge/Website-kikuai.dev-111827?style=for-the-badge&logo=safari&logoColor=white" alt="KikuAI website"></a>
  <a href="https://t.me/kiku_ai"><img src="https://img.shields.io/badge/Telegram-%40kiku__ai-26A5E4?style=for-the-badge&logo=telegram&logoColor=white" alt="Telegram @kiku_ai"></a>
  <a href="https://github.com/kiku-jw"><img src="https://img.shields.io/badge/GitHub-%40kiku--jw-181717?style=for-the-badge&logo=github&logoColor=white" alt="GitHub @kiku-jw"></a>
</p>
<p align="center">
  <sub>Follow new projects and updates from <a href="https://github.com/kiku-jw">@kiku-jw</a>.</sub>
</p>
<!-- author-links:end -->
