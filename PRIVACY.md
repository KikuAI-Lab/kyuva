# Privacy Policy for Kyuva

**Effective Date:** January 5, 2026  
**Last Updated:** August 24, 2026

## Overview

Kyuva ("the App") is a macOS teleprompter project developed by KikuAI. Its source is public. This policy explains how the application handles data.

## Data Collection

### What We Collect
**Nothing.** The developer does not receive or transmit your scripts, settings, or other personal data. The app stores the content you create only on your Mac.

### Local Data Only
- **Scripts:** Your scripts and a last known-good backup are stored in Kyuva's local Application Support directory. App Store builds use Kyuva's sandbox container.
- **Recovery:** If the main scripts file cannot be decoded, Kyuva preserves the corrupt file and attempts to load the last known-good local backup.
- **Settings:** Your preferences are stored locally using macOS UserDefaults.
- **No Cloud Sync:** We do not sync any data to external servers

### Audio and Speech
- Kyuva's current release does not request microphone or speech-recognition access
- No audio processing, recording, transcription, or voice-following is shipped

## Capture Visibility

The teleprompter overlay is a normal macOS window and may appear in screen shares or recordings. Verify the preview before presenting, or share a single app window that omits Kyuva. Kyuva does not promise capture exclusion.

## Third-Party Services

Kyuva does not integrate with any third-party analytics, advertising, or tracking services.

Kyuva's current release has no StoreKit or Pro purchase path. The repository does not depend on analytics, advertising, or any cloud backend.

## Data Sharing

We do not share any data with third parties because we do not collect any data.

## Data Security

Since all data remains on your device:
- Your scripts are as secure as your Mac
- No network transmission means no interception risk
- Removing the app may leave its local scripts and settings on your Mac so that an accidental uninstall does not destroy them

## Children's Privacy

Kyuva does not knowingly collect data from children. Since we collect no data at all, this is not applicable.

## Your Rights

You have complete control over your data:
- **Access:** Direct builds use `~/Library/Application Support/Kyuva/`; App Store builds use the app's sandboxed Application Support container.
- **Delete:** Quit Kyuva, then remove its Application Support data and preferences to delete local scripts and settings.
- **Export:** Use the built-in export feature to save scripts

## Changes to This Policy

If this policy changes, updates will be made in this repository.

## Contact

Project questions can be submitted through the GitHub repository.

Repository:
- **GitHub:** https://github.com/kiku-jw/kyuva

---

**Summary:** Kyuva is a privacy-first app. We collect nothing. Everything stays on your Mac.
