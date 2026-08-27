# Kyuva Support

This file is Kyuva's public support contract. Update it whenever the supported release, troubleshooting steps, or contact path changes.

## Before reporting a problem

- **Mac:** Finish the Welcome Tour, then use the menu-bar icon to show or hide the overlay, open Settings, reopen the tour, or quit. Review Settings > Hotkeys; Kyuva does not require Accessibility or Input Monitoring permission.
- **iPhone:** Select or create a script, edit it locally, and tap Present. Tap the prompt or the large play button to pause and resume; use AA for font, pace, mirroring, and stage-direction options. The script-actions menu imports or shares a UTF-8 `.txt` file through Apple's system surfaces.
- **Apple Watch:** Open a prompt on the paired iPhone, then open Kyuva on the Watch. The remote enables when both apps report a live connection.
- Kyuva uses normal app windows and screens and may appear in screen shares or recordings. Check the preview before presenting.

Apple rejected Mac build `3` because it contained a network-server entitlement for an unfinished iPhone remote. Build `4` removes that feature and all Mac network access. It was uploaded and resubmitted on 27 August 2026 and is now `Waiting for Review`; it is not yet approved or publicly available. iPhone and Apple Watch builds are currently source-build surfaces, so public mobile availability is not claimed.

## Report a problem

Open a [GitHub issue](https://github.com/kiku-jw/kyuva/issues) and include:

- the Kyuva version;
- the affected platform, operating-system version, and device model;
- the steps that reproduce the problem;
- what you expected and what happened instead.

Do not attach private scripts, recordings, credentials, or personal information. A short synthetic script is enough when text is needed to reproduce a problem.

General contact information is available on the [KikuAI About page](https://kikuai.dev/about/).

## Privacy

Kyuva's current data handling is documented in [PRIVACY.md](PRIVACY.md).
