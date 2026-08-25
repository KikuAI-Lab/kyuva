# Accessibility Mac contrast delta — 2026-08-25

Document class: immutable evidence for Issue #2. This receipt supersedes only
the Mac Sufficient Contrast observations in
`accessibility-audit-2026-08-25.md` and
`accessibility-max-text-delta-2026-08-25.md`. Create a new receipt after another
Mac common-task UI change or before publishing a different App Store
accessibility response.

## Evaluation contract

Apple's current Sufficient Contrast criteria ask for the common-task UI to meet
general contrast guidelines by default, usually 4.5:1 for most text. Apple also
asks evaluators to test light and dark appearance, Bold Text, Increase Contrast,
Reduce Transparency, and translucent content:

- <https://developer.apple.com/help/app-store-connect/manage-app-accessibility/sufficient-contrast-evaluation-criteria>

## Reproduced defects and fixes

The live pre-fix Mac render exposed white text on system blue at only 3.81:1 in
onboarding and about 4.10:1 in prominent controls. A tapped, dimmed stage
direction over the former yellow line fill could fall to approximately 2.78:1.

The final source:

- uses black content on fixed system cyan for onboarding actions, numbered
  steps, Start Local Remote, and Show Welcome Guide;
- uses adaptive primary text for the capture-visibility warning;
- replaces the low-contrast yellow selection fill with a two-point yellow
  outline, preserving the prompt's black reading surface;
- makes the prompt, control bar, and time badge opaque when macOS requests
  Increase Contrast or Reduce Transparency, and disables focus-edge dimming
  under Increased Contrast;
- removes decorative app, remote-status, and READY/PAUSED symbols from the
  accessibility order while preserving adjacent status text.

AppKit resolves system cyan to black-on-cyan ratios of 9.71:1 under Aqua and
11.94:1 under Dark Aqua. The final rendered dark screenshots measure between
11.80:1 and 12.20:1 for the changed cyan controls. The deterministic receipt is
`raw/logs/accessibility-mac-contrast-sampling.txt`.

## Fresh visual and semantic proof

- `raw/screenshots/macos-a11y-onboarding-dark.png`
  - Next is black on cyan;
  - the page count remains exposed as `Page 1 of 3`.
- `raw/screenshots/macos-a11y-getting-started-dark.png`
  - numbered steps and Get Started are black on cyan;
  - Back, page count, and Get Started remain named in the runtime tree.
- `raw/screenshots/macos-a11y-remote-dark.png`
  - Start Local Remote is black on cyan;
  - the decorative remote symbol is absent from the runtime tree, while
    `Control this Mac` and `Remote is off` remain.
- `raw/screenshots/macos-a11y-about-dark.png`
  - capture visibility uses adaptive primary text;
  - Show Welcome Guide is black on cyan;
  - the decorative app icon is absent from the runtime tree, while the app name
    and version remain.
- `raw/screenshots/macos-a11y-overlay-dark.png`
  - default prompt text, dimmed stage direction, reading highlight, progress,
    and time badge remain visible;
  - the runtime tree exposes `READY`, remaining time, progress, and script text
    without separately announcing the adjacent play symbol.

## Verification and conservative boundary

- `swift test --disable-sandbox --scratch-path <scratch>/SwiftPM`
  - PASS: 30 tests, 0 failures.
- Unsigned macOS Debug QA build from the final source
  - PASS: `xcodebuild` exit 0.
- Unsigned macOS Release build from the final source
  - PASS: `xcodebuild` exit 0.
- `git diff --check`
  - PASS.

Apple Accessibility Inspector could inspect the host Mac, but the unsigned
temporary Kyuva QA process did not appear in its target-process menu. The
checked runtime accessibility trees and rendered screenshots therefore provide
the live proof for this slice; this receipt does not claim a successful
Inspector Audit run.

Mac Sufficient Contrast remains `HOLD`, not `READY`: a complete common-task pass
with Bold Text, Increase Contrast, and Reduce Transparency enabled on the host
has not occurred. App Store Connect was not changed, and no accessibility
response was saved or published. The uploaded Mac build remains older than this
source delta.
