# Privacy Policy for Kyuva

**Effective Date:** January 5, 2026  
**Last Updated:** August 28, 2026

## Overview

Kyuva ("the App") is a teleprompter for Mac and iPhone with a dependent Apple Watch remote, published by Mykyta Dudnichenko. Its source is public. This policy explains how the applications handle data.

## Data Collection

### What We Collect
**Nothing.** The developer does not receive your scripts, settings, or other personal data. Script content stays in the local app container on the Mac or iPhone where it was created.

### Local Data Only
- **Scripts:** Your scripts and a last known-good backup are stored in Kyuva's local Application Support directory. App Store builds use Kyuva's sandbox container on each device.
- **Recovery:** If the main scripts file cannot be decoded, Kyuva preserves the corrupt file and attempts to load the last known-good local backup.
- **Settings:** Your preferences are stored locally using Apple UserDefaults.
- **Watch remote:** The paired Watch receives the current script title, play/pause state, pace label, and progress from the iPhone and sends control commands back through Apple's WatchConnectivity framework. Kyuva does not send this information to the developer or to a Kyuva server.
- **iPhone-to-Mac remote:** The iPhone app does not discover or connect to Macs. Its remote-control path is limited to the paired Watch through WatchConnectivity.
- **Mac network access:** Mac build `4` does not open network connections or request network access.
- **Text transfer:** You can deliberately import or share a plain-text script through Apple's system Files, Share, or AirDrop surfaces. Kyuva does not automatically sync or upload the file.
- **No Cloud Sync:** We do not sync scripts or settings to external servers.

### Audio and Speech
- Mac App Store version 1.0 does not request microphone or speech-recognition access.
- Current development builds include an optional Voice Follow control. It requests microphone and Speech permission only when you turn that feature on.
- Voice Follow requires Apple's on-device recognition support for the selected script language. Kyuva does not fall back to cloud recognition.
- Microphone buffers are passed directly to Apple's on-device speech recognizer while Voice Follow is active. Kyuva does not save the audio or send it to the developer or a Kyuva server.

## Capture Visibility

Kyuva uses normal app windows and screens. Its prompt may appear in screen shares or recordings. Verify the preview before presenting; Kyuva does not promise capture exclusion.

## Third-Party Services

Kyuva does not integrate with any third-party analytics, advertising, or tracking services.

Mac App Store version 1.0 has no StoreKit or Pro purchase path. Current development source contains a disabled lifetime Pro entitlement foundation for future review and testing. While commerce is disabled, it makes no StoreKit product request and all prepared Pro features remain an open preview. Any future public purchase activation requires an updated release and privacy review. The repository does not depend on analytics, advertising, or any cloud backend.

## Data Sharing

We do not share any data with third parties because we do not collect any data.

## Data Security

Since script data remains in local app containers:
- Your scripts are protected by the security of your Apple device and operating system.
- Kyuva has no developer-operated script backend.
- Mac removal may leave local support data behind; deleting the iPhone app normally removes its local app container according to iOS behavior.

## Children's Privacy

Kyuva does not knowingly collect data from children. Since we collect no data at all, this is not applicable.

## Your Rights

You have complete control over your data:
- **Access:** Direct Mac builds use `~/Library/Application Support/Kyuva/`; App Store builds use sandboxed Application Support containers.
- **Delete:** On Mac, quit Kyuva and remove its Application Support data and preferences. On iPhone, delete individual scripts in Kyuva or remove the app and its local data through iOS.
- **Export:** Both Mac and iPhone include deliberate plain-text import and export through system file and share surfaces.

## Changes to This Policy

If this policy changes, updates will be made in this repository.

## Contact

Project questions can be submitted through the GitHub repository.

Repository:
- **GitHub:** https://github.com/kiku-jw/kyuva

---

**Summary:** Kyuva is a privacy-first app. We collect nothing. Scripts stay on devices you control, system sharing is deliberate, Watch communication stays paired to iPhone, and optional Voice Follow is constrained to Apple's supported on-device recognizers.
