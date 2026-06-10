---
title: "Clause 11: Software"
description: "Clause 11 of EN 301 549 V3.2.1 carries WCAG 2.1 Level A and AA success criteria into the native software application context, covering desktop applications, mobile apps, embedded firmware UIs, and ..."
---

# Clause 11: Software

Clause 11 of EN 301 549 V3.2.1 carries WCAG 2.1 Level A and AA success criteria into the native software application context, covering desktop applications, mobile apps, embedded firmware UIs, and kiosk software. Where Clause 9 binds WCAG to web content, Clause 11 binds the same criteria to UI built on platform toolkits and exposes them through the operating-system accessibility APIs (UIA, AT-SPI, ATK, AXAPI, Android `AccessibilityService`, iOS `UIAccessibility`, Java Access Bridge). Each sub-clause below restates the WCAG outcome in software-UI terms; the linked WCAG cross-reference in the sibling [`wcag-22`](../../wcag-22/SKILL.md) skill carries the full technical detail and test procedure.

Source: ETSI / CEN / CENELEC, EN 301 549 V3.2.1, Clause 11, <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>. Summaries below are paraphrased; consult the official document for normative wording.

## clause-11-1-1-1

**11.1.1.1 Non-text content**

Software shall expose a text alternative for every non-text UI element (icon button, status glyph, decorative image, chart, captcha) through the platform accessibility API so assistive technologies can read the alternative in place of the graphic. Purely decorative graphics shall be marked so AT can skip them.

**Applies to**: UI graphics and icons rendered by the application or its UI toolkit.

**WCAG cross-reference**: [sc-1-1-1](../../wcag-22/references/guideline-1-1.md#sc-1-1-1).

**Assessment heuristics**:

* Enumerate every icon, image, and graphical control and confirm each has an accessible name exposed through the platform API.
* Run a screen reader (NVDA, JAWS, VoiceOver, TalkBack, Orca) over each window and verify the announced name matches the visual purpose.
* Mark decorative-only graphics as hidden from AT so they do not clutter the accessibility tree.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-11-1-3-1

**11.1.3.1 Info and relationships**

Software shall expose UI structure (groupings, lists, tables, headings, form fields and their labels, landmarks) through the platform accessibility API so the relationships conveyed visually are also available programmatically. Toolkit controls shall use the correct semantic roles rather than visually styled generic containers.

**Applies to**: UI structure across windows, dialogs, panes, and complex composite controls.

**WCAG cross-reference**: [sc-1-3-1](../../wcag-22/references/guideline-1-3.md#sc-1-3-1).

**Assessment heuristics**:

* Inspect the accessibility tree (Accessibility Insights, Accerciser, Xcode Accessibility Inspector, Android Layout Inspector) and confirm each visible group maps to a structural element with the correct role.
* Verify form fields are programmatically associated with their labels rather than relying on adjacency alone.
* Confirm data tables expose row and column relationships and that headings expose level information.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-11-1-3-2

**11.1.3.2 Meaningful sequence**

The reading and navigation order presented through the accessibility tree shall match the order in which the user is expected to perceive and operate the UI. Visual reflow, RTL mirroring, and asynchronous panel insertion shall not produce an AT traversal order that contradicts the visual sequence.

**Applies to**: Order of UI components as presented to assistive technology.

**WCAG cross-reference**: [sc-1-3-2](../../wcag-22/references/guideline-1-3.md#sc-1-3-2).

**Assessment heuristics**:

* Traverse each window with screen-reader navigation commands and confirm the announced order matches the intended visual reading order.
* Tab through controls and confirm focus moves in the same order an unsupported sighted user would scan.
* Re-check after locale changes, window resizing, and dynamic panel updates.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-11-1-3-3

**11.1.3.3 Sensory characteristics**

In-app instructions and prompts shall not rely solely on shape, size, visual location, orientation, or sound to identify the control or action being referenced. Wording shall identify targets by accessible name or position in the structural model so users without that sensory channel can still follow.

**Applies to**: In-app instructions, tutorials, error messages, and tooltips.

**WCAG cross-reference**: [sc-1-3-3](../../wcag-22/references/guideline-1-3.md#sc-1-3-3).

**Assessment heuristics**:

* Scan instructional text for phrases like "the round button", "the icon on the right", or "press the button that beeps" and replace them with accessible-name references.
* When spatial directions are unavoidable, pair them with the accessible name of the target.
* Validate that audio cues are mirrored by a visible state change.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-11-1-4-1

**11.1.4.1 Use of color**

Color shall not be the only visual means of conveying information, indicating an action, prompting a response, or distinguishing a UI state in the application's visual design. A non-color cue (icon, text, pattern, shape, position) shall accompany every color-coded distinction.

**Applies to**: Visual design of the application — status indicators, validation feedback, chart series, theme states.

**WCAG cross-reference**: [sc-1-4-1](../../wcag-22/references/guideline-1-4.md#sc-1-4-1).

**Assessment heuristics**:

* Render each screen in monochrome (or in a high-contrast simulator) and confirm all state distinctions remain perceivable.
* Pair color-coded validation errors with an icon and explicit text.
* For charts, supply patterns, markers, or labels in addition to series color.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-11-1-4-2

**11.1.4.2 Audio control**

Where the application plays audio automatically for more than three seconds, it shall provide a mechanism to pause, stop, or independently adjust the application's audio volume separately from overall system volume. Background audio shall not block use of speech output from AT.

**Applies to**: Application audio output — alerts, ambient sound, autoplaying media.

**WCAG cross-reference**: [sc-1-4-2](../../wcag-22/references/guideline-1-4.md#sc-1-4-2).

**Assessment heuristics**:

* Inventory every auto-playing audio source and confirm an in-app control mutes or pauses it within reach of the first focusable control.
* Verify the in-app volume slider is independent of the OS master volume.
* Confirm screen-reader speech remains intelligible while application audio is active.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-11-1-4-3

**11.1.4.3 Contrast (minimum)**

Text and images of text rendered by the application shall meet a contrast ratio of at least 4.5:1 against their background, or 3:1 for large text (18 pt regular or 14 pt bold and larger). Inactive controls, pure decoration, and incidental text are exempt.

**Applies to**: Application contrast ratio for text rendered in the UI.

**WCAG cross-reference**: [sc-1-4-3](../../wcag-22/references/guideline-1-4.md#sc-1-4-3).

**Assessment heuristics**:

* Sample foreground and background colors with an eyedropper or contrast analyzer (Colour Contrast Analyser, axe DevTools) across every theme the app ships.
* Re-test after honoring OS dark-mode or high-contrast theme settings.
* Confirm placeholder text and helper text meet the same threshold, not just the primary body text.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-11-1-4-11

**11.1.4.11 Non-text contrast**

Visual information needed to identify UI components and their states (focus ring, selected toggle, checkbox tick, slider thumb, input border) and meaningful graphical objects (icons that convey information, chart elements) shall have a contrast ratio of at least 3:1 against adjacent colors.

**Applies to**: UI components and graphical objects rendered by the application.

**WCAG cross-reference**: [sc-1-4-11](../../wcag-22/references/guideline-1-4.md#sc-1-4-11).

**Assessment heuristics**:

* Measure the border or fill of each control state (default, hover, focused, selected, disabled) against the adjacent surface.
* Verify the focus indicator contrasts at least 3:1 with both the focused control's resting state and the surrounding background.
* For informational icons, measure the icon glyph against its background.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-11-2-1-1

**11.2.1.1 Keyboard**

All functionality of the application shall be operable through a keyboard interface without requiring specific timings for individual keystrokes, except where the underlying function requires input that depends on the path of the user's movement (for example, freehand drawing).

**Applies to**: Application keyboard access across every function exposed in the UI.

**WCAG cross-reference**: [sc-2-1-1](../../wcag-22/references/guideline-2-1.md#sc-2-1-1).

**Assessment heuristics**:

* Disconnect the pointing device and walk through every user task end to end using only the keyboard.
* Verify custom controls implement keyboard equivalents for every mouse gesture (drag, right-click, double-click, hover-reveal).
* Document and justify any path-dependent exception in the conformance report.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-11-2-1-2

**11.2.1.2 No keyboard trap**

If keyboard focus can be moved into a component, focus shall be moveable away from that component using only the keyboard, and the user shall be advised of the exit method if it is anything other than standard arrow, tab, or escape keys.

**Applies to**: Application focus management — modal dialogs, embedded controls, custom widgets, plug-in surfaces.

**WCAG cross-reference**: [sc-2-1-2](../../wcag-22/references/guideline-2-1.md#sc-2-1-2).

**Assessment heuristics**:

* Tab into every dialog, popover, embedded WebView, OLE/embedded document, and confirm Tab and Shift+Tab move focus out.
* Verify Escape dismisses modal layers and returns focus to the originating control.
* Where exit requires a non-standard key, surface the instruction on entering the trap zone.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-11-2-1-3

**11.2.1.3 Keyboard (no exception)**

All functionality of the application shall be operable through a keyboard interface without exception. This is the stricter AAA-aligned variant of 11.2.1.1 and removes the path-dependent carve-out, so even freehand and continuous gestures must have a keyboard-operable equivalent.

**Applies to**: Application keyboard-only mode, including continuous and path-dependent input flows.

**WCAG cross-reference**: [sc-2-1-3](../../wcag-22/references/guideline-2-1.md#sc-2-1-3).

**Assessment heuristics**:

* Identify every freehand, drag, and continuous-gesture interaction and pair each with a discrete keyboard equivalent (arrow-key nudge, numeric entry, step-through).
* Confirm continuous transforms (rotate, resize, pan) expose keyboard increments and a precise numeric input.
* Test with a switch-access device to validate the keyboard-only path is fully usable.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-11-2-2-1

**11.2.2.1 Timing adjustable**

For every time limit the application imposes (session timeout, response window, auto-advance, countdown), the user shall be able to turn off, adjust to at least ten times the default, or extend the limit at least once with a simple action, unless the timing is essential or shorter than 20 hours.

**Applies to**: Application timed interactions — auto-logout, transaction windows, quiz timers, slide auto-advance.

**WCAG cross-reference**: [sc-2-2-1](../../wcag-22/references/guideline-2-2.md#sc-2-2-1).

**Assessment heuristics**:

* Catalog every timer and identify the user-facing control to extend, adjust, or disable it.
* Verify the warning fires at least 20 seconds before the deadline and is announced by AT.
* Confirm session extension is reachable from keyboard focus without first dismissing other UI.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-11-2-2-2

**11.2.2.2 Pause, stop, hide**

Moving, blinking, scrolling, or auto-updating content in the application that starts automatically, lasts more than five seconds, or appears alongside other content shall be pausable, stoppable, or hidable by the user, and auto-updating content shall additionally be controllable in update frequency.

**Applies to**: Application animations and auto-updating content — splash animations, busy indicators that exceed five seconds, news tickers, live charts.

**WCAG cross-reference**: [sc-2-2-2](../../wcag-22/references/guideline-2-2.md#sc-2-2-2).

**Assessment heuristics**:

* Expose a global pause control or honor the OS reduced-motion setting (prefers-reduced-motion equivalent) for every long-running animation.
* Provide a stop or hide control on tickers, carousels, and animated status surfaces.
* Verify auto-refresh intervals can be increased or disabled by the user.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-11-2-4-3

**11.2.4.3 Focus order**

Where the application can be navigated sequentially and the order affects meaning or operation, the focus order shall preserve meaning and operability. Dynamic content insertion (newly opened panes, just-revealed wizards) shall move focus to the expected next step rather than dropping the user back to the start of the window.

**Applies to**: Application focus sequence across windows, dialogs, and dynamic panel insertion.

**WCAG cross-reference**: [sc-2-4-3](../../wcag-22/references/guideline-2-4.md#sc-2-4-3).

**Assessment heuristics**:

* Tab through each window and confirm focus traverses controls in the order a user would expect to operate them.
* When a modal opens, confirm focus moves into the modal, and when it closes, focus returns to the invoking control.
* In wizards, confirm each step begins with focus on the first actionable control of that step.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-11-2-4-6

**11.2.4.6 Headings and labels**

Headings and labels in the application shall describe topic or purpose. Generic strings such as "Button 1", "Input", or unlabeled toolbar buttons shall be replaced with descriptive accessible names so AT users can distinguish controls by their announced name alone.

**Applies to**: Application labels — control labels, section headings, group labels, accessible names exposed to AT.

**WCAG cross-reference**: [sc-2-4-6](../../wcag-22/references/guideline-2-4.md#sc-2-4-6).

**Assessment heuristics**:

* Run a screen reader and list every announced label; flag any non-descriptive or duplicated label for rewording.
* Confirm icon-only buttons carry a tooltip or accessible name that describes the action, not the icon.
* Verify section headings within a window describe the content that follows.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-11-2-4-7

**11.2.4.7 Focus visible**

Any keyboard-operable UI component shall have a visible focus indicator whenever it receives keyboard focus. The indicator shall be distinguishable from the control's unfocused appearance and shall not be suppressed by custom theming.

**Applies to**: Application focus indication on every focusable control.

**WCAG cross-reference**: [sc-2-4-7](../../wcag-22/references/guideline-2-4.md#sc-2-4-7).

**Assessment heuristics**:

* Tab through every screen and confirm the currently focused control is visually distinguishable in every theme.
* Replace any CSS or toolkit override that suppresses the default focus ring with an equivalent or stronger indicator.
* Confirm focus visibility on custom controls, embedded WebViews, and surfaces that override platform rendering.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-11-3-1-1

**11.3.1.1 Language of software**

The default human language of each application shall be programmatically determinable so AT (and especially screen readers) can select the correct pronunciation, voice, and braille table. The platform locale or accessibility-API language attribute shall reflect the language actually rendered.

**Applies to**: UI language setting reported through the accessibility API or platform locale.

**WCAG cross-reference**: [sc-3-1-1](../../wcag-22/references/guideline-3-1.md#sc-3-1-1).

**Assessment heuristics**:

* Confirm the application sets a language attribute that AT can query (platform locale, NSLocale, `setLanguage`, UIA `LocalizedControlType`).
* When the user switches in-app language, verify the AT-readable language attribute updates accordingly.
* Test with a non-default-language screen reader voice and confirm pronunciation matches the rendered content.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-11-3-2-1

**11.3.2.1 On focus**

Receiving focus on a UI component shall not trigger a change of context (opening a new window, moving focus elsewhere, submitting a form, navigating to a different view). Focus shall be a passive event from the user's point of view.

**Applies to**: Application predictable behavior on focus events.

**WCAG cross-reference**: [sc-3-2-1](../../wcag-22/references/guideline-3-2.md#sc-3-2-1).

**Assessment heuristics**:

* Tab through every control and confirm nothing opens, closes, navigates, or submits purely on focus.
* Audit auto-focusing behaviors on dialog open and confirm they reposition focus only, without triggering side effects.
* Verify dropdown menus do not commit selection on focus alone — selection must require an explicit activation key.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-11-3-2-2

**11.3.2.2 On input**

Changing the value or state of a UI control shall not automatically cause a change of context unless the user has been advised of the behavior before interacting. Combo-box selection, radio-button toggling, and text entry shall not auto-submit or auto-navigate without explicit warning.

**Applies to**: Application input behavior on value-change events.

**WCAG cross-reference**: [sc-3-2-2](../../wcag-22/references/guideline-3-2.md#sc-3-2-2).

**Assessment heuristics**:

* Change every control's value and confirm no context change occurs unless the user activates a separate submit affordance.
* When auto-submit is essential, surface a visible and AT-announced warning before the user interacts.
* Verify combo-boxes and listboxes only commit selection on enter or activate, not on highlight.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-11-3-2-4

**11.3.2.4 Consistent identification**

Components that have the same functionality within the application shall be identified consistently. Save, print, search, cancel, and similar actions shall use the same label, icon, position, and accessible name across every window where they appear.

**Applies to**: Application consistent UI patterns across screens, dialogs, and panes.

**WCAG cross-reference**: [sc-3-2-4](../../wcag-22/references/guideline-3-2.md#sc-3-2-4).

**Assessment heuristics**:

* Compare the labeling and iconography of equivalent actions across every window and flag inconsistencies.
* Maintain a component or token library that enforces consistent accessible names and icons for shared actions.
* Verify keyboard shortcuts for the same action match across surfaces.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-11-3-3-1

**11.3.3.1 Error identification**

When an input error is automatically detected in the application, the item in error shall be identified and the error shall be described to the user in text rendered both visually and through the accessibility API. Coloring the field alone or relying on iconography alone is insufficient.

**Applies to**: Application error messages on form validation, command failures, and constraint violations.

**WCAG cross-reference**: [sc-3-3-1](../../wcag-22/references/guideline-3-3.md#sc-3-3-1).

**Assessment heuristics**:

* Trigger each validation error and confirm a text message identifies both the field and the nature of the problem.
* Verify AT announces the error (via `aria-describedby` equivalent, accessible description, or live-region equivalent).
* Confirm focus or AT attention is directed to the first errored field after submission.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-11-3-3-2

**11.3.3.2 Labels or instructions**

When the application requires user input, labels or instructions shall be provided so the user knows what data is expected, the required format, and any constraints. Placeholder-only labeling is insufficient because placeholder text disappears on focus and is unreliable through AT.

**Applies to**: Application guidance — input field labels, format hints, required-field markers, help text.

**WCAG cross-reference**: [sc-3-3-2](../../wcag-22/references/guideline-3-3.md#sc-3-3-2).

**Assessment heuristics**:

* Confirm every input has a persistent visible label programmatically associated with the field.
* Surface format constraints (date pattern, length, character set) before the user submits.
* Mark required fields with both a visible indicator and an AT-readable required state.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-11-4-1-2

**11.4.1.2 Name, role, value**

For every UI component in the application, the name and role shall be programmatically determinable; states, properties, and values that can be set by the user shall be programmatically settable; and notification of changes to these items shall be available to assistive technology through the platform accessibility API.

**Applies to**: Application API accessibility — every focusable or interactive control, including custom-drawn widgets.

**WCAG cross-reference**: [sc-4-1-2](../../wcag-22/references/guideline-4-1.md#sc-4-1-2).

**Assessment heuristics**:

* Inspect every custom control in the accessibility tree and confirm it exposes role, name, value, and state through the platform API rather than as visual-only attributes.
* Verify state changes (expanded/collapsed, checked/unchecked, selected/unselected) fire accessibility events.
* Walk the UI with a screen reader and confirm role announcements match the rendered control type.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

## clause-11-4-1-3

**11.4.1.3 Status messages**

Status messages that inform the user of success, progress, or other non-modal state shall be programmatically determinable through role or properties so AT can present them without requiring the user to move focus to the message.

**Applies to**: Application state changes — toast notifications, progress updates, validation summaries, save confirmations.

**WCAG cross-reference**: [sc-4-1-3](../../wcag-22/references/guideline-4-1.md#sc-4-1-3).

**Assessment heuristics**:

* Mark non-modal status surfaces with the platform's live-region or notification role so AT announces them automatically.
* Verify progress, success, and warning messages reach AT without stealing keyboard focus.
* Confirm transient toasts persist long enough to be announced and inspected, or offer a history surface.

Source: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
