---
title: "Guideline 2.1 — Keyboard Accessible"
description: "Guideline 2.1 (Keyboard Accessible) requires that all functionality be available through a keyboard interface, without time-based input dependencies, so users who cannot use a mouse can operate the..."
---

# Guideline 2.1 — Keyboard Accessible

Guideline 2.1 (Keyboard Accessible) requires that all functionality be available through a keyboard interface, without time-based input dependencies, so users who cannot use a mouse can operate the experience.

Source: W3C Web Content Accessibility Guidelines (WCAG) 2.2, Guideline 2.1, <https://www.w3.org/TR/WCAG22/#keyboard-accessible>.

## sc-2-1-1

**SC 2.1.1 Keyboard (Level A)**

All functionality of the content is operable through a keyboard interface without requiring specific timings for individual keystrokes, except where the underlying function requires input that depends on the path of the user's movement (for example, freehand drawing).

**Assessment heuristics**:

* Confirm every interactive control receives focus via Tab order and activates with Enter or Space (or the role-appropriate key).
* Confirm drag-and-drop, hover-only menus, swipe gestures, and right-click context menus have a keyboard-operable equivalent.
* Confirm custom controls (`role="button"`, `role="checkbox"`) implement the expected key handling.

Source: <https://www.w3.org/TR/WCAG22/#keyboard>

## sc-2-1-2

**SC 2.1.2 No Keyboard Trap (Level A)**

When keyboard focus can be moved to a component, focus can also be moved away using only the keyboard, and the user is told how if a non-standard key is required.

**Assessment heuristics**:

* Confirm modal dialogs trap focus while open but release it on close (Escape or close button).
* Confirm embedded iframes, plugins, or third-party widgets allow Tab and Shift+Tab to exit them.
* Confirm any non-standard exit key is documented in the surrounding UI.

Source: <https://www.w3.org/TR/WCAG22/#no-keyboard-trap>

## sc-2-1-3

**SC 2.1.3 Keyboard (No Exception) (Level AAA)**

All functionality of the content is operable through a keyboard interface without exception for path-dependent input.

**Assessment heuristics**:

* Confirm freehand signature, drawing, or gesture inputs each provide a fully keyboard-driven equivalent path.

Source: <https://www.w3.org/TR/WCAG22/#keyboard-no-exception>

## sc-2-1-4

**SC 2.1.4 Character Key Shortcuts (Level A)**

If a keyboard shortcut is implemented using only letter (including upper- and lower-case letters), punctuation, number, or symbol characters, then at least one of: the shortcut can be turned off, the shortcut can be remapped, or the shortcut is active only when the relevant component has focus.

**Assessment heuristics**:

* Confirm single-key shortcuts are scoped to focused components, remappable, or have an off switch.
* Confirm modifier-key combinations (Ctrl, Alt, Cmd) used as shortcuts are not affected by this criterion but are still documented.

Source: <https://www.w3.org/TR/WCAG22/#character-key-shortcuts>

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
