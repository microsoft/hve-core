---
title: "Guideline 3.3 — Input Assistance"
description: "Guideline 3.3 (Input Assistance) requires that users be helped to avoid and correct mistakes, including error identification, labels, instructions, error suggestions, error prevention, accessible a..."
---

# Guideline 3.3 — Input Assistance

Guideline 3.3 (Input Assistance) requires that users be helped to avoid and correct mistakes, including error identification, labels, instructions, error suggestions, error prevention, accessible authentication, and redundant entry support.

Source: W3C Web Content Accessibility Guidelines (WCAG) 2.2, Guideline 3.3, <https://www.w3.org/TR/WCAG22/#input-assistance>.

## sc-3-3-1

**SC 3.3.1 Error Identification (Level A)**

When an input error is automatically detected, the item in error is identified and the error is described to the user in text.

**Assessment heuristics**:

* Confirm error messages identify the field by name and explain what is wrong in text rather than relying on colour or icon.
* Confirm validation errors are exposed to assistive technology (for example, through `aria-invalid` and an `aria-describedby` link to the message).

Source: <https://www.w3.org/TR/WCAG22/#error-identification>

## sc-3-3-2

**SC 3.3.2 Labels or Instructions (Level A)**

Labels or instructions are provided when content requires user input.

**Assessment heuristics**:

* Confirm every form control has a visible label, instructions, or an `aria-label`.
* Confirm complex inputs (date format, password rules) carry instructions before submission, not only on error.

Source: <https://www.w3.org/TR/WCAG22/#labels-or-instructions>

## sc-3-3-3

**SC 3.3.3 Error Suggestion (Level AA)**

If an input error is automatically detected and suggestions for correction are known, the suggestions are provided to the user, unless doing so would jeopardise the security or purpose of the content.

**Assessment heuristics**:

* Confirm format-specific errors (date, email, phone) include an example or suggestion.
* Confirm sensitive inputs (passwords) provide rule-based feedback rather than the specific failing characters.

Source: <https://www.w3.org/TR/WCAG22/#error-suggestion>

## sc-3-3-4

**SC 3.3.4 Error Prevention (Legal, Financial, Data) (Level AA)**

For pages that cause legal commitments or financial transactions, that modify or delete user-controllable data, or that submit user test responses, at least one of the following is true: submissions are reversible, data is checked for input errors with an opportunity to correct, or a mechanism for review and confirmation is provided.

**Assessment heuristics**:

* Confirm checkout, contract acceptance, and data deletion flows offer review-and-confirm steps.
* Confirm financial transactions surface a confirmation summary before final submission.

Source: <https://www.w3.org/TR/WCAG22/#error-prevention-legal-financial-data>

## sc-3-3-5

**SC 3.3.5 Help (Level AAA)**

Context-sensitive help is available.

**Assessment heuristics**:

* Confirm complex forms surface inline help text or links to a topic-specific help article.

Source: <https://www.w3.org/TR/WCAG22/#help>

## sc-3-3-6

**SC 3.3.6 Error Prevention (All) (Level AAA)**

For all pages that require the user to submit information, submissions are reversible, data is checked for input errors with an opportunity to correct, or a mechanism for review and confirmation is provided.

**Assessment heuristics**:

* Confirm review-and-confirm steps apply to all submission flows in AAA-targeted experiences.

Source: <https://www.w3.org/TR/WCAG22/#error-prevention-all>

## sc-3-3-7

**SC 3.3.7 Redundant Entry (Level A)**

Information previously entered by or provided to the user that is required to be entered again in the same process is either auto-populated or available for the user to select, except when re-entering the information is essential, the information is required to ensure security, or previously entered information is no longer valid.

**Assessment heuristics**:

* Confirm multi-step forms pre-populate values the user already provided.
* Confirm address fields offer a "same as billing" or saved-address selection.

Source: <https://www.w3.org/TR/WCAG22/#redundant-entry>

## sc-3-3-8

**SC 3.3.8 Accessible Authentication (Minimum) (Level AA)**

A cognitive function test (such as remembering a password or solving a puzzle) is not required for any step in an authentication process unless an alternative is provided, the test is one that recognises objects or non-text content the user provided, or the test is supported by a mechanism that assists the user.

**Assessment heuristics**:

* Confirm passwordless flows (magic link, passkey), password-manager support (`autocomplete="current-password"`), or biometric login is offered.
* Confirm CAPTCHAs offer a non-cognitive alternative such as device-based attestation or accessible audio.

Source: <https://www.w3.org/TR/WCAG22/#accessible-authentication-minimum>

## sc-3-3-9

**SC 3.3.9 Accessible Authentication (Enhanced) (Level AAA)**

A cognitive function test is not required for any step in an authentication process unless the test is to recognise objects or non-text content the user provided.

**Assessment heuristics**:

* Confirm AAA flows do not include puzzle-based or transcription-based authentication challenges.

Source: <https://www.w3.org/TR/WCAG22/#accessible-authentication-enhanced>

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
