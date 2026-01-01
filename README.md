# Kyuva

**Invisible camera-side prompter that follows your voice**

> Camera cue that never leaks to screen share

## Features

- 🎯 Overlay hidden from screen sharing (Zoom, Meet, Teams, OBS)
- 🎤 Voice-follow scrolling (on-device, no cloud)
- ⌨️ Global hotkeys (Shift+←/→ for speed)
- 🖱️ Hover-to-pause
- 📝 Script library with import/export
- 🔒 100% offline, no account required

## Requirements

- macOS 13.0+
- Apple Silicon or Intel

## Build

```bash
# Using Swift Package Manager
swift build

# Or open in Xcode
open Package.swift
```

## Distribution

Available on the Mac App Store as a one-time purchase.

## Privacy

- All processing happens locally on your Mac
- No data is sent to any server
- No account or login required

## Architecture

```
Kyuva/
├── App/           # Entry point, AppDelegate
├── UI/            # Settings, Overlay window
├── Core/          # Script, Scroll, Voice-sync, Hotkeys
└── Platform/      # macOS-specific adapters
```

## License

Proprietary. © 2026 KikuAI.
