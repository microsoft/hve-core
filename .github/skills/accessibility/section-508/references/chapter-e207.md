---
title: "Chapter E207: Software"
description: "Chapter E207 governs accessibility for software applications, operating systems, and graphical user interfaces."
---

# Chapter E207: Software

Chapter E207 governs accessibility for software applications, operating systems, and graphical user interfaces. It carries forward the WCAG 2.0 conformance baseline established in E205 and adapts it to non-web software contexts where HTML and browser APIs may be unavailable, addressing keyboard operation, focus management, contrast, controls, text customisation, and motion. Software in scope includes desktop applications, mobile applications, embedded systems, and any user-facing application or platform component.

Source: US Access Board, ICT Accessibility 508 Standards, Chapter E207, <https://www.access-board.gov/ict/#e207-software>.

## clause-e207-1

**E207.1 Scope**

Defines the scope of chapter E207 as all custom and third-party software components with a user interface, including desktop applications, mobile applications, browser extensions, authoring tools, and middleware that surface user-facing functionality.

**Applies to**: Any software component a user interacts with directly or indirectly through an interface.

**WCAG cross-reference**: n/a (scoping clause).

**Assessment heuristics**:

* Enumerate first-party and third-party software in the assessment, including embedded or OEM components.
* Treat documentation and support material accompanying covered software as covered by E208 rather than excluded.

Source: <https://www.access-board.gov/ict/#e207-software>

## clause-e207-2

**E207.2 General Exceptions**

Permits narrow exceptions for software that is not user-facing or for which accessibility is technically infeasible, provided the exception is documented and does not reduce conformance expectations for the broader product.

**Applies to**: Backend services, administrative tools, and embedded subsystems claimed to be out of scope.

**WCAG cross-reference**: n/a (exception clause).

**Assessment heuristics**:

* Require every exception to document its rationale, its mitigation (alternative access path), and a review cadence.
* Re-evaluate each exception when supporting technology changes or when the in-scope user base changes.

Source: <https://www.access-board.gov/ict/#e207-software>

## clause-e207-3

**E207.3 User Interface Standards**

Requires software user interfaces to conform to applicable platform accessibility standards (Windows UI Automation, macOS Accessibility, Android Accessibility Framework, iOS UIAccessibility, ARIA for web-based UIs) and to follow platform interaction guidelines.

**Applies to**: All user interface code for covered software.

**WCAG cross-reference**: [sc-1-4-3](../../wcag-22/references/guideline-1-4.md#sc-1-4-3), [sc-2-1-1](../../wcag-22/references/guideline-2-1.md#sc-2-1-1).

**Assessment heuristics**:

* Inspect the UI tree with the platform's accessibility inspector and confirm names, roles, states, and values are exposed.
* Confirm web-based interfaces use ARIA roles only where native HTML semantics do not already provide the correct affordance.

Source: <https://www.access-board.gov/ict/#e207-software>

## clause-e207-4

**E207.4 Keyboard**

Requires every software function to be operable through a keyboard interface without requiring specific timings for individual keystrokes, and prohibits keyboard traps that prevent the user from moving focus away from a component.

**Applies to**: All keyboard-operable workflows in covered software.

**WCAG cross-reference**: [sc-2-1-1](../../wcag-22/references/guideline-2-1.md#sc-2-1-1), [sc-2-1-2](../../wcag-22/references/guideline-2-1.md#sc-2-1-2).

**Assessment heuristics**:

* Walk every primary task with the keyboard only, verifying that focus reaches and operates every interactive component.
* Confirm modal dialogs, embedded pickers, and custom widgets release focus when dismissed.

Source: <https://www.access-board.gov/ict/#e207-software>

## clause-e207-5

**E207.5 Keyboard Focus**

Requires the current keyboard focus to be visibly indicated and to move through interactive components in a logical, predictable order; focus must not move unexpectedly without an explicit user action.

**Applies to**: All software with keyboard navigation.

**WCAG cross-reference**: [sc-2-4-3](../../wcag-22/references/guideline-2-4.md#sc-2-4-3), [sc-2-4-7](../../wcag-22/references/guideline-2-4.md#sc-2-4-7).

**Assessment heuristics**:

* Confirm the focus indicator has sufficient contrast against both focused and unfocused backgrounds, and is not suppressed by the application's stylesheet.
* Verify tab order matches the logical reading order of the interface rather than the DOM source order.

Source: <https://www.access-board.gov/ict/#e207-software>

## clause-e207-6

**E207.6 Status, Prompts, and Results**

Requires software to provide clear status messages, prompts, and result feedback so that assistive technology users can perceive system state changes without losing keyboard focus.

**Applies to**: All software workflows that produce user-visible status, error, or confirmation messages.

**WCAG cross-reference**: [sc-3-2-1](../../wcag-22/references/guideline-3-2.md#sc-3-2-1), [sc-3-2-2](../../wcag-22/references/guideline-3-2.md#sc-3-2-2), [sc-4-1-3](../../wcag-22/references/guideline-4-1.md#sc-4-1-3).

**Assessment heuristics**:

* Confirm transient messages (toasts, banners) use `aria-live` regions or platform-equivalent announcement APIs.
* Confirm error messages describe the problem and recommend a remedy in plain language.

Source: <https://www.access-board.gov/ict/#e207-software>

## clause-e207-7

**E207.7 Contrast**

Requires text and meaningful UI elements to meet minimum contrast ratios: 4.5:1 for body text and 3:1 for large text and non-text UI components such as borders, icons, and focus indicators.

**Applies to**: All visible UI elements in covered software.

**WCAG cross-reference**: [sc-1-4-3](../../wcag-22/references/guideline-1-4.md#sc-1-4-3).

**Assessment heuristics**:

* Audit screens with a contrast analyser, sampling primary and secondary themes (light, dark, high-contrast).
* Confirm disabled states are still distinguishable from enabled states without dropping below contrast thresholds for elements that remain readable.

Source: <https://www.access-board.gov/ict/#e207-software>

## clause-e207-8

**E207.8 Flashing**

Prohibits software animations, progress indicators, and auto-refreshing content from flashing more than three times per second.

**Applies to**: All animated and auto-updating UI elements.

**WCAG cross-reference**: [sc-2-3-1](../../wcag-22/references/guideline-2-3.md#sc-2-3-1), [sc-2-3-2](../../wcag-22/references/guideline-2-3.md#sc-2-3-2).

**Assessment heuristics**:

* Review progress indicators, loading spinners, and notification animations for flash rates above 3 Hz.
* Provide a mechanism to pause or disable any content that flashes near the threshold.

Source: <https://www.access-board.gov/ict/#e207-software>

## clause-e207-9

**E207.9 Controls**

Requires interactive controls (buttons, checkboxes, sliders, menu items) to be operable by keyboard and by standard input devices, with consistent activation semantics across the application.

**Applies to**: All interactive UI controls in covered software.

**WCAG cross-reference**: [sc-2-1-1](../../wcag-22/references/guideline-2-1.md#sc-2-1-1), [sc-2-5-5](../../wcag-22/references/guideline-2-5.md#sc-2-5-5), [sc-3-2-1](../../wcag-22/references/guideline-3-2.md#sc-3-2-1), [sc-3-2-4](../../wcag-22/references/guideline-3-2.md#sc-3-2-4).

**Assessment heuristics**:

* Confirm controls follow platform conventions (Enter or Space for buttons, Space for checkboxes, arrow keys for sliders and option lists).
* Confirm similarly named controls behave consistently across screens, especially in long-form workflows.

Source: <https://www.access-board.gov/ict/#e207-software>

## clause-e207-10

**E207.10 Text Properties**

Requires software to allow customisation of text presentation (line height, letter spacing, word spacing, alignment) without loss of content or functionality.

**Applies to**: All text-presenting software where user-controlled text properties are technically possible.

**WCAG cross-reference**: [sc-1-4-12](../../wcag-22/references/guideline-1-4.md#sc-1-4-12).

**Assessment heuristics**:

* Verify the application honours OS-level text scaling and contrast settings.
* Confirm text reflows rather than truncating when spacing or font size is increased.

Source: <https://www.access-board.gov/ict/#e207-software>

## clause-e207-11

**E207.11 Animation and Motion**

Requires software to avoid auto-playing animations that may disorient users with vestibular conditions and to honour user preferences such as the operating system's reduced-motion setting.

**Applies to**: All software with animated transitions, parallax effects, or auto-playing motion.

**WCAG cross-reference**: [sc-2-3-3](../../wcag-22/references/guideline-2-3.md#sc-2-3-3).

**Assessment heuristics**:

* Confirm the application respects `prefers-reduced-motion` (or platform equivalent) and disables or shortens non-essential animation.
* Provide an in-application setting to disable decorative motion independent of the OS preference.

Source: <https://www.access-board.gov/ict/#e207-software>

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
