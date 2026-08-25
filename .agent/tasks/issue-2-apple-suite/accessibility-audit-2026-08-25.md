# Accessibility audit — 2026-08-25

Document class: immutable evidence for Issue #2. It derives from Apple's
current Accessibility Nutrition Label criteria, the source tree, fresh builds,
and runtime accessibility-tree inspection. Re-run and supersede this audit
after a common-task UI change or before publishing different accessibility
responses in App Store Connect.

## Evaluation boundary

Apple permits a feature to be reported only when a user can complete every
common task with that feature. The Kyuva common-task set used here is:

- Mac: complete or skip onboarding; create, select, rename, edit, delete,
  import, and export a script; configure the prompt; show, control, reposition,
  and hide the overlay.
- iPhone: create, select, rename, edit, delete, import, and share a script;
  present it; change prompt settings; and open the Mac remote.
- Apple Watch: read prompt state; play or pause; adjust pace; and start over.

This audit covers source version `1.0 (2)`. App Store Connect still has the
older Mac build `1.0 (1)` selected; these candidate responses must not be
attributed to that uploaded binary.

Primary criteria:

- <https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels/>
- <https://developer.apple.com/help/app-store-connect/manage-app-accessibility/voiceover-evaluation-criteria>
- <https://developer.apple.com/help/app-store-connect/manage-app-accessibility/voice-control-evaluation-criteria>
- <https://developer.apple.com/help/app-store-connect/manage-app-accessibility/sufficient-contrast-evaluation-criteria>
- <https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-evaluation-criteria>

`READY` below means the current local product is a candidate for that label. It
does not mean the response was published. `HOLD` means the criterion is not yet
proved across the full common-task set. `NOT OFFERED` means Apple does not offer
that device/feature combination. `DO NOT CLAIM` means the label exists, but
Kyuva has no applicable media to support.

## Device matrix

| Feature | Mac | iPhone | Apple Watch | Evidence or remaining gate |
| --- | --- | --- | --- | --- |
| VoiceOver | HOLD | HOLD | HOLD | Labels, values, ordering, and decorative-image cleanup are locally present, but an actual proficient VoiceOver-only pass of every common task has not occurred. |
| Voice Control | HOLD | HOLD | NOT OFFERED | Named controls are present, but an actual Voice Control-only pass has not occurred. Apple does not offer this label for Apple Watch. |
| Larger Text | NOT OFFERED | READY | HOLD | Apple does not offer this label for Mac. iPhone uses semantic fonts outside the prompt, supports Dynamic Type, and exposes a 22–72 point prompt setting; the large-layout simulator pass succeeded. The largest Watch layout still needs a device-level pass. |
| Dark Interface | READY | READY | READY | Mac settings follow the system appearance; the prompt surfaces are dark by design; iPhone editor follows the system and its prompt is dark; Watch uses the system dark interface. |
| Differentiate Without Color Alone | READY | READY | READY | Status and actions use text, symbols, shape, position, or control state in addition to color. |
| Sufficient Contrast | HOLD | HOLD | HOLD | The dimmed iPhone direction text now reaches about 5.28:1 on black, but the complete custom overlay and prominent-control set has not received a systematic light/dark, Increase Contrast, and Reduce Transparency audit. |
| Reduced Motion | READY | READY | READY | Mac decorative hover and resize transitions honor Reduce Motion. Prompt movement is the user-requested core behavior and always has an explicit pause control. iPhone and Watch add no problematic decorative motion. |
| Captions | DO NOT CLAIM | DO NOT CLAIM | DO NOT CLAIM | Kyuva contains no audio or video playback for which captions could be provided; Apple says not to claim this label when no captioned content is available. |
| Audio Descriptions | DO NOT CLAIM | DO NOT CLAIM | DO NOT CLAIM | Kyuva contains no time-based video content requiring an audio-description track. |

## Fresh proof

- `swift test --disable-sandbox --scratch-path <scratch>/SwiftPM`
  - PASS: 30 tests, 0 failures.
- Unsigned macOS Debug QA build from the final source
  - PASS: `xcodebuild` exit 0.
- The iPhone Debug build with the embedded Watch app was already rebuilt from
  the same accessibility delta before the Mac-only onboarding cleanup.
- Mac runtime accessibility inspection confirmed:
  - onboarding exposes its content, page number, Skip, Back, Next, and Get
    Started, without announcing decorative SF Symbol names;
  - script actions expose Delete selected script, New script, Import from file,
    and Export selected script;
  - the editor exposes Script text;
  - appearance sliders expose names and values such as Overlay width / 350
    pixels, Overlay opacity / 85 percent, and Font size / 18 points.
- iPhone runtime inspection confirmed named editor and prompt controls,
  progress, and Current pace with its value. Simulator accessibility did not
  expose the settings sheet as a separate tree, so its slider labels and values
  are supported by compiled-source evidence rather than a runtime claim.
- The Watch simulator rendered the Kyuva remote, but macOS did not expose the
  Watch app's accessibility tree. Watch semantic labels and values therefore
  remain source evidence only.

The stage-direction contrast change is intentionally narrow. White rendered at
45% opacity over black is approximately 4.42:1; 50% is approximately 5.28:1,
which clears the commonly used 4.5:1 text threshold for that exact surface.

## App Store recommendation

After source build `2` or a later build containing this delta is uploaded and
selected, the locally supported conservative Mac draft is:

- Dark Interface
- Differentiate Without Color Alone
- Reduced Motion

Keep VoiceOver, Voice Control, and Sufficient Contrast unselected until their
remaining full-task tests pass. Do not select Captions or Audio Descriptions.
Apple currently allows responses to be saved as a draft, but support can only
be published for a device with a live version. No accessibility response was
saved or published during this audit, and none should be attached to the older
uploaded build `1`.
