---
title: "Guideline 2.5 — Input Modalities"
description: "Guideline 2.5 (Input Modalities) requires that users can operate functionality through various inputs beyond the keyboard, including pointer, touch, motion, and voice, with adequate target size and..."
---

# Guideline 2.5 — Input Modalities

Guideline 2.5 (Input Modalities) requires that users can operate functionality through various inputs beyond the keyboard, including pointer, touch, motion, and voice, with adequate target size and cancellation.

Source: W3C Web Content Accessibility Guidelines (WCAG) 2.2, Guideline 2.5, <https://www.w3.org/TR/WCAG22/#input-modalities>.

## sc-2-5-1

**SC 2.5.1 Pointer Gestures (Level A)**

All functionality that uses multipoint or path-based gestures can be operated with a single pointer without a path-based gesture, unless a multipoint or path-based gesture is essential.

**Assessment heuristics**:

* Confirm swipe, pinch, and rotate gestures have a single-tap or single-click alternative.
* Confirm path-based interactions (drag along a curve) have an equivalent tap-based path.

Source: <https://www.w3.org/TR/WCAG22/#pointer-gestures>

## sc-2-5-2

**SC 2.5.2 Pointer Cancellation (Level A)**

For functionality operated using a single pointer, at least one of the following is true: no down-event activates the function, the function completes on up-event and a mechanism is available to abort or undo, the up-event reverses the down-event, or completing on down-event is essential.

**Assessment heuristics**:

* Confirm clicks fire on pointerup or mouseup rather than on pointerdown for non-essential actions.
* Confirm dragging off a button before release cancels the activation.

Source: <https://www.w3.org/TR/WCAG22/#pointer-cancellation>

## sc-2-5-3

**SC 2.5.3 Label in Name (Level A)**

For user-interface components with labels that include text or images of text, the accessible name contains the text that is presented visually.

**Assessment heuristics**:

* Confirm `aria-label` strings include the visible text exactly rather than rephrasing it.
* Confirm speech-input users can activate a control by saying its visible label.

Source: <https://www.w3.org/TR/WCAG22/#label-in-name>

## sc-2-5-4

**SC 2.5.4 Motion Actuation (Level A)**

Functionality that can be operated by device motion or user motion can also be operated by user-interface components, and response to motion can be disabled to prevent accidental actuation, except when motion is essential or the motion is used through an accessibility-supported interface.

**Assessment heuristics**:

* Confirm shake-to-undo and tilt-based controls have an on-screen equivalent.
* Confirm a setting disables motion-triggered actions for users with motor impairments.

Source: <https://www.w3.org/TR/WCAG22/#motion-actuation>

## sc-2-5-5

**SC 2.5.5 Target Size (Enhanced) (Level AAA)**

The size of the target for pointer inputs is at least 44 by 44 CSS pixels, except where the target is inline, user-agent-controlled, essential, or has an equivalent target meeting the size requirement.

**Assessment heuristics**:

* Confirm touch targets are at least 44x44 CSS pixels in the dominant interaction surface.

Source: <https://www.w3.org/TR/WCAG22/#target-size-enhanced>

## sc-2-5-6

**SC 2.5.6 Concurrent Input Mechanisms (Level AAA)**

Web content does not restrict the use of input modalities available on a platform except where the restriction is essential, required to ensure security of the content, or required to respect user settings.

**Assessment heuristics**:

* Confirm switching between touch, mouse, and keyboard within a session does not disable input modalities.

Source: <https://www.w3.org/TR/WCAG22/#concurrent-input-mechanisms>

## sc-2-5-7

**SC 2.5.7 Dragging Movements (Level AA)**

All functionality that uses a dragging movement for operation can be achieved by a single pointer without dragging, unless dragging is essential or determined by the user agent.

**Assessment heuristics**:

* Confirm drag-to-reorder lists offer up/down buttons or keyboard shortcuts as alternatives.
* Confirm slider controls accept tap-and-arrow input as an alternative to drag.

Source: <https://www.w3.org/TR/WCAG22/#dragging-movements>

## sc-2-5-8

**SC 2.5.8 Target Size (Minimum) (Level AA)**

The size of the target for pointer inputs is at least 24 by 24 CSS pixels, with defined exceptions for spacing, inline targets, user-agent controls, and essential presentations.

**Assessment heuristics**:

* Confirm touch targets are at least 24x24 CSS pixels or that smaller targets carry sufficient surrounding space so the effective target reaches 24x24.

Source: <https://www.w3.org/TR/WCAG22/#target-size-minimum>

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
