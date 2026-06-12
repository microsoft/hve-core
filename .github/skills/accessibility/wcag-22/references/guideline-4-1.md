---
title: "Guideline 4.1 — Compatible"
description: "Guideline 4.1 (Compatible) requires that content be robust enough to work with current and future user agents and assistive technologies."
---

# Guideline 4.1 — Compatible

Guideline 4.1 (Compatible) requires that content be robust enough to work with current and future user agents and assistive technologies. Note that SC 4.1.1 Parsing has been removed in WCAG 2.2 (marked obsolete) and is included here only for traceability.

Source: W3C Web Content Accessibility Guidelines (WCAG) 2.2, Guideline 4.1, <https://www.w3.org/TR/WCAG22/#compatible>.

## sc-4-1-1

**SC 4.1.1 Parsing (Obsolete in WCAG 2.2)**

This success criterion has been removed in WCAG 2.2 because modern user agents recover from the kinds of parsing issues it covered. Existing audits referencing this criterion should be retargeted to the responsible robustness criteria (notably SC 4.1.2).

**Assessment heuristics**:

* Do not raise new findings against SC 4.1.1; treat outstanding 2.1 findings as resolved when the underlying behaviour now passes 4.1.2.

Source: <https://www.w3.org/TR/WCAG22/#parsing>

## sc-4-1-2

**SC 4.1.2 Name, Role, Value (Level A)**

For all user-interface components, the name and role can be programmatically determined; states, properties, and values that can be set by the user can be programmatically set; and notification of changes to these items is available to user agents and assistive technologies.

**Assessment heuristics**:

* Confirm every interactive element exposes a non-empty accessible name (via label, `aria-label`, or `aria-labelledby`).
* Confirm custom controls implement the appropriate ARIA role and corresponding required ARIA properties.
* Confirm state changes (expanded, checked, selected, pressed) are reflected in ARIA attributes synchronously with the visual state.

Source: <https://www.w3.org/TR/WCAG22/#name-role-value>

## sc-4-1-3

**SC 4.1.3 Status Messages (Level AA)**

Status messages can be programmatically determined through role or properties so they can be presented to the user by assistive technology without receiving focus.

**Assessment heuristics**:

* Confirm form-validation summaries, toast notifications, and async loading messages use ARIA live regions (`role="status"`, `role="alert"`, or `aria-live`).
* Confirm status updates do not steal focus and that polite vs. assertive live-region policies match the urgency of the message.

Source: <https://www.w3.org/TR/WCAG22/#status-messages>

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
