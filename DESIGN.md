---
name: Kyuva
description: Quiet confidence from script to lens
colors:
  graphite: "#111217"
  graphite-raised: "#1B1C22"
  graphite-soft: "#272830"
  pearl: "#F6F6F8"
  pearl-muted: "#B9BAC4"
  lens-lavender: "#C9CEFF"
  lens-lavender-strong: "#AAB4FF"
  lens-indigo-interactive: "#5C61B8"
  success: "#7DD5A7"
  warning: "#E9C46A"
  destructive: "#FF7D86"
typography:
  headline:
    fontFamily: "SF Pro, -apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "24px"
    fontWeight: 700
    lineHeight: 1.15
    letterSpacing: "-0.01em"
  title:
    fontFamily: "SF Pro, -apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "17px"
    fontWeight: 600
    lineHeight: 1.25
    letterSpacing: "normal"
  body:
    fontFamily: "SF Pro, -apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.45
    letterSpacing: "normal"
  label:
    fontFamily: "SF Pro, -apple-system, BlinkMacSystemFont, sans-serif"
    fontSize: "13px"
    fontWeight: 500
    lineHeight: 1.25
    letterSpacing: "normal"
  data:
    fontFamily: "SF Mono, ui-monospace, monospace"
    fontSize: "12px"
    fontWeight: 500
    lineHeight: 1.2
    letterSpacing: "normal"
rounded:
  sm: "8px"
  md: "12px"
  lg: "16px"
  pill: "999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
  xxl: "32px"
components:
  button-primary:
    backgroundColor: "{colors.lens-lavender}"
    textColor: "{colors.graphite}"
    typography: "{typography.label}"
    rounded: "{rounded.md}"
    padding: "10px 16px"
  button-secondary:
    backgroundColor: "{colors.graphite-soft}"
    textColor: "{colors.pearl}"
    typography: "{typography.label}"
    rounded: "{rounded.md}"
    padding: "10px 14px"
  input:
    backgroundColor: "{colors.graphite-raised}"
    textColor: "{colors.pearl}"
    typography: "{typography.body}"
    rounded: "{rounded.sm}"
    padding: "10px 12px"
  script-row-selected:
    backgroundColor: "{colors.graphite-soft}"
    textColor: "{colors.pearl}"
    typography: "{typography.body}"
    rounded: "{rounded.md}"
    padding: "12px"
---

# Design System: Kyuva

> Live visual contract. SwiftUI code and visual QA own rendered truth; update this file in the same change when the shared visual language changes.

## Overview

**Creative North Star: "The quiet lens"**

Kyuva behaves like the dark space immediately around a camera lens: visually quiet, precisely aligned, and present only to help the speaker stay connected. Graphite surfaces reduce glare during delivery, while the pearl-lavender accent recalls the app icon's optical glass and marks only the current selection, reading cue, and primary action.

The editor can carry useful density, but the prompt cannot. Standard Apple affordances are preferred over invented controls. Materials are reserved for floating controls over live text; ordinary screens use tonal layers. The system explicitly rejects a Settings-window utility, a control-dense production dashboard, Teleprompter.com feature sprawl and paywall-first interruptions, neon cyan gaming controls, decorative gradients, glass on every surface, and hidden core actions.

**Key Characteristics:**

- Script-dominant layouts with a clear library-to-editor-to-prompt sequence.
- Restrained graphite neutrals with one optical lavender accent.
- Familiar Apple navigation and controls, tuned for confident large-type reading.
- Fast 150–200 ms state transitions that respect reduced motion.
- Tonal grouping instead of nested cards and decorative shadows.

## Colors

The palette is a restrained optical neutral system: near-black graphite supports focus, pearl text carries contrast, and lens lavender is rare enough to remain meaningful.

### Primary

- **Lens Lavender:** The sole primary accent for the current reading cue, primary button, focus, and selection.
- **Focused Lens Lavender:** The pressed, active, and high-emphasis variant; never a decorative glow.
- **Interactive Lens Indigo:** The same optical accent darkened only for small text, icons, sliders, and focus on light surfaces. Dark surfaces retain Lens Lavender.

### Neutral

- **Deep Graphite:** Prompt backgrounds and the darkest application canvas.
- **Raised Graphite:** Sidebars, toolbars, inputs, and inspector layers.
- **Soft Graphite:** Selected rows and secondary controls.
- **Optical Pearl:** Primary text and high-contrast symbols.
- **Muted Pearl:** Secondary labels and metadata, never long body copy on a tinted surface.

### Named Rules

**The One Lens Rule.** Lens lavender occupies no more than ten percent of an editor screen; its rarity identifies what the user can do next.

**The Reading Contrast Rule.** Prompt text is optical pearl on deep graphite. Stage directions may dim, but ordinary script text never does.

## Typography

**Display Font:** SF Pro (Apple system fallback)
**Body Font:** SF Pro (Apple system fallback)
**Label/Mono Font:** SF Mono for pace, time, and progress only

**Character:** One familiar Apple family keeps the tool out of the speaker's way. Weight and scale establish hierarchy; novelty type never competes with the script.

### Hierarchy

- **Headline** (700, 24px, 1.15): Workspace and script titles.
- **Title** (600, 17px, 1.25): Section headers, row titles, and primary controls.
- **Body** (400, 15px, 1.45): Editor text and explanatory copy; prose is capped near 70 characters per line where practical.
- **Label** (500, 13px, 1.25): Buttons, metadata, and inspector controls.
- **Data** (500, 12px, 1.2): Pace, duration, time remaining, and progress only.

### Named Rules

**The Words Own the Scale Rule.** The largest text in a prompt is always the script. App labels never compete with it.

## Elevation

Kyuva is flat by default. Depth comes from tonal layering and native separators, not ambient card shadows. Material appears only when controls must float over the prompt, and it becomes opaque when Reduce Transparency or Increased Contrast is active.

### Named Rules

**The Glass Has a Job Rule.** Glass is permitted only for controls that physically overlay moving script text. It is forbidden as decoration in libraries, editors, settings, or empty states.

## Components

### Buttons

- **Shape:** Gently curved, not pill-like unless the control is singular and compact (12px standard radius).
- **Primary:** Lens lavender with deep graphite text and a clear icon-plus-label when space allows.
- **Hover / Focus:** Slight tonal increase plus native focus indication; 150–200 ms state transition, instant under Reduce Motion.
- **Secondary / Ghost:** Soft graphite or native borderless treatment; inactive actions never use the accent.

### Cards / Containers

- **Corner Style:** Restrained 12–16px only where grouping is necessary.
- **Background:** Raised or soft graphite; the main editor remains an open canvas.
- **Shadow Strategy:** No shadow at rest.
- **Border:** Native separators or a low-contrast full outline, never a side stripe.
- **Internal Padding:** 12–16px for rows, 16–24px for major groups.

### Inputs / Fields

- **Style:** Tonal raised graphite, 8px radius, strong text contrast, and standard platform selection behavior.
- **Focus:** Native focus ring or a restrained lens-lavender outline; no glow.
- **Error / Disabled:** Text plus symbol and semantic color; never color alone.

### Navigation

Libraries use a familiar sidebar/list and editor detail on Mac, and NavigationStack list-to-editor movement on iPhone. The current script is unmistakable. Search, create, import, share, and delete remain standard controls with labels or accessibility names.

### Prompt Dock

The prompt dock is the signature component. It floats over text only while needed, groups reset, pace, playback, and settings by frequency, uses at least 44-point targets on iPhone, and recedes during active reading without hiding the tap-to-pause behavior.

## Do's and Don'ts

### Do:

- **Do** make the user's script the largest and quietest uninterrupted surface.
- **Do** use lens lavender only for the next action, current reading cue, focus, and active state.
- **Do** preserve familiar Apple list, navigation, menu, slider, and accessibility behavior.
- **Do** keep controls readable with long localized labels, Dynamic Type, Increased Contrast, and Reduce Transparency.
- **Do** keep everyday pace and presentation controls adjacent to the editor and prompt.

### Don't:

- **Don't** recreate a Settings-window utility where writing a script feels like configuring software.
- **Don't** build a control-dense production dashboard or generic SaaS card grid.
- **Don't** copy Teleprompter.com feature sprawl, account pressure, or paywall-first interruptions.
- **Don't** use neon cyan gaming controls, decorative gradients, or glass on every surface.
- **Don't** hide core actions behind hover, ambiguous symbols, or prior product knowledge.
- **Don't** pair a one-pixel border with a wide soft shadow, use side-stripe accents, over-round containers, or place cards inside cards.
