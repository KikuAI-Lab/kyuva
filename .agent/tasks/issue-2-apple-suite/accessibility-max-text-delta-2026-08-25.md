# Accessibility max-text and contrast delta — 2026-08-25

Document class: immutable evidence for Issue #2. This receipt supersedes the
iPhone maximum-text and cyan-control observations in
`accessibility-audit-2026-08-25.md`; it does not replace that audit's full
device matrix. Create a new receipt after another common-task UI change.

## Test configuration

- Canonical simulator: iPhone 17, iOS 26.5
- Preferred content size: `accessibility-extra-extra-extra-large`
- Increase Contrast: enabled
- Appearance: tested in both light and dark
- Watch companion: Kyuva Watch, watchOS 26.5

The Watch runtime reported `unsupported` for `simctl ui` appearance, Increase
Contrast, and Dynamic Type controls. Watch results below are therefore visual
and source evidence, not a maximum-text system-setting claim.

## Reproduced defects and fixes

The first maximum-text pass found two visible defects in common tasks:

- the fixed 40-point pace slot wrapped `60` onto two lines;
- white Present/Play artwork on the light cyan accent had weak visual contrast
  even while Increase Contrast was enabled.

The final source:

- keeps the pace value on one line with adaptive width and layout priority;
- renders Present and Play content in black on cyan on iPhone and Watch;
- keeps Mac Remote status and inactive-prompt copy in adaptive system text
  colors instead of applying low-contrast green or orange to the words;
- uses a navigation picker for Pace mode instead of a crowded segmented
  control;
- uses an inline Prompt Settings title so the form retains more usable height
  at accessibility sizes.

## Fresh visual and accessibility proof

- `raw/screenshots/ios-max-text-light-editor.png`
  - light interface, Increase Contrast, maximum accessibility text;
  - script selection, title editing, script text, and Present remain visible;
  - Present uses black content on cyan.
- `raw/screenshots/ios-max-text-prompt-controls.png`
  - the prompt remains intentionally dark;
  - Close, settings, reset, slower, play, faster, and the single-line pace value
    fit simultaneously at the maximum accessibility size;
  - Play uses black artwork on cyan.
- `raw/screenshots/ios-max-text-settings.png`
  - Prompt Settings uses a compact inline title and a scrollable Form at the
    maximum accessibility size.
- `raw/screenshots/watch-contrast-controls.png`
  - prompt title, connection status, progress, Play, slower, pace, and faster
    remain visible;
  - Watch Play uses black artwork on cyan.
- Runtime accessibility inspection still exposes the iPhone common controls by
  name and exposes Current pace with value `60` in the maximum-text layout.
- Pixel sampling of the final PNG receipts gives black-on-cyan ratios of about
  4.60:1 on iPhone and 11.94:1 on Watch; the deterministic receipt is
  `raw/logs/accessibility-contrast-sampling.txt`.

The Simulator's macOS accessibility bridge did not expose the settings sheet
as a separate scroll target. The initial maximum-size Form layout is runtime
proof; navigation and the remaining vertically scrollable rows are compiled
SwiftUI source evidence rather than a claimed end-to-end scroll gesture.

## Label impact and boundary

- iPhone Larger Text remains `READY` with direct maximum-size common-task
  evidence.
- Sufficient Contrast remains `HOLD` for each device. The reproduced custom
  control failures are fixed, but this pass did not establish a complete
  contrast inventory with Reduce Transparency across every Mac/iPhone/Watch
  common task.
- VoiceOver and Voice Control remain `HOLD`; inspecting the accessibility tree
  is not a substitute for completing every common task with the real assistive
  technology.
- App Store Connect was not changed. The uploaded Mac build remains older than
  this source delta.
