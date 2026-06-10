---
title: "Objective 4 - Help Users Avoid Mistakes and Know How to Correct Them"
description: "Objective 4 covers patterns that prevent errors before they occur and that help users recover quickly when errors do occur."
---

# Objective 4 - Help Users Avoid Mistakes and Know How to Correct Them

Objective 4 covers patterns that prevent errors before they occur and that help users recover quickly when errors do occur. The user need is "Error Prevention": users with cognitive and learning disabilities are disproportionately affected by error-prone interfaces, unforgiving forms, time pressure, hidden costs, and unexpected layout shifts. Designs that anticipate mistakes and offer painless recovery support all users.

Source: W3C, Making Content Usable for People with Cognitive and Learning Disabilities, Objective 4, <https://www.w3.org/TR/coga-usable/#objective-4>.

## control-ensure-controls-and-content-do-not-move-unexpectedly

**Control 4.1 Ensure Controls and Content Do Not Move Unexpectedly**

Layout shifts caused by deferred content loading, rotating banners, or pop-ups disorient users and cause mis-clicks. Targets must remain stable while users interact with the page.

**Design patterns**:

* Reserve space for asynchronous content so the layout does not shift when it loads.
* Avoid auto-rotating content in primary interaction areas.
* Avoid inserting content above the current scroll position after the page has loaded.
* Provide user controls (pause, dismiss) for any non-essential motion.

**Assessment heuristics**:

* Confirm Cumulative Layout Shift remains low during page load and interaction.
* Confirm content inserted asynchronously appears in reserved space.
* Confirm rotating or moving content does not interfere with users while they are interacting nearby.

Source: <https://www.w3.org/TR/coga-usable/#objective-4>.

## control-let-users-go-back

**Control 4.2 Let Users Go Back**

Users must be able to back out of any step without losing data or being trapped. Browser back, in-app back buttons, and undo affordances must all work reliably.

**Design patterns**:

* Make the browser back button work without losing state.
* Provide in-app back buttons on multi-step flows.
* Provide undo for destructive actions.
* Avoid pages that trap the user with no way out.

**Assessment heuristics**:

* Confirm the browser back button works on every page and preserves user input.
* Confirm multi-step flows include an explicit back affordance.
* Confirm destructive actions are reversible or require confirmation.

Source: <https://www.w3.org/TR/coga-usable/#objective-4>.

## control-notify-users-of-fees-and-charges-at-the-start-of-a-task

**Control 4.3 Notify Users of Fees and Charges at the Start of a Task**

Hidden fees, late-stage upsells, and surprise charges at checkout exploit users who have already invested effort and feel committed. All costs must be disclosed at the start so users can make an informed decision.

**Design patterns**:

* Disclose all fees, taxes, and charges at the start of a task.
* Show running totals throughout the flow.
* Avoid revealing additional charges only at the final confirmation step.
* Be explicit about subscriptions, renewals, and cancellation terms.

**Assessment heuristics**:

* Confirm the total price is visible before the user begins committing actions.
* Confirm any fee added late in the flow is highlighted and explained.
* Confirm subscription terms (price, frequency, cancellation) are visible before sign-up.

Source: <https://www.w3.org/TR/coga-usable/#objective-4>.

## control-design-forms-to-prevent-mistakes

**Control 4.4 Design Forms to Prevent Mistakes**

Forms are a common source of frustration. Reducing the number of required fields, providing clear labels and format examples, and validating input inline prevents most mistakes before they happen.

**Design patterns**:

* Ask only for information that is strictly required.
* Provide clear, persistent labels for every field.
* Show format examples alongside fields that require specific formats.
* Validate input inline as the user types or moves between fields.

**Assessment heuristics**:

* Confirm forms ask only for necessary fields.
* Confirm format examples appear next to fields with specific format requirements.
* Confirm validation provides actionable, polite messages.

Source: <https://www.w3.org/TR/coga-usable/#objective-4>.

## control-make-it-easy-to-undo-form-errors

**Control 4.5 Make it Easy to Undo Form Errors**

When a form fails validation, the user's input must be preserved. Forcing the user to re-enter data after a validation failure compounds frustration and increases the chance of further errors.

**Design patterns**:

* Preserve all user input across validation failures.
* Highlight errors precisely without clearing valid fields.
* Provide clear instructions for fixing each error.
* Offer autosave for long forms.

**Assessment heuristics**:

* Confirm partial form data persists after a validation failure.
* Confirm error messages identify the field, the problem, and the fix.
* Confirm long forms autosave or offer a manual save option.

Source: <https://www.w3.org/TR/coga-usable/#objective-4>.

## control-use-clear-visible-labels

**Control 4.6 Use Clear Visible Labels**

Placeholder text is not a label. Once the user begins typing, placeholder labels disappear, leaving the user with no reminder of what the field expects. Persistent visible labels are essential.

**Design patterns**:

* Provide persistent visible labels above or beside each form field.
* Avoid using placeholder text as the only label.
* Use clear, plain-language labels that say what the field expects.
* Keep the label visible after the user enters data.

**Assessment heuristics**:

* Confirm every form field has a persistent visible label.
* Confirm labels remain visible after the user enters data.
* Confirm labels describe the expected input rather than restating the placeholder.

Source: <https://www.w3.org/TR/coga-usable/#objective-4>.

## control-use-clear-step-by-step-instructions

**Control 4.7 Use Clear Step-by-step Instructions**

Multi-step instructions must be presented as discrete numbered steps with concrete examples. Burying steps in paragraphs forces users to parse the prose to extract the sequence.

**Design patterns**:

* Present multi-step tasks as numbered steps.
* Provide a concrete example for each step where helpful.
* Show progress through the steps.
* Avoid combining multiple actions in a single step.

**Assessment heuristics**:

* Confirm multi-step processes use numbered steps rather than prose.
* Confirm each step contains a single action and an optional example.
* Confirm a progress indicator shows current step and total steps.

Source: <https://www.w3.org/TR/coga-usable/#objective-4>.

## control-accept-different-input-formats

**Control 4.8 Accept Different Input Formats**

Strict input masks reject valid data formatted differently from what the form expects. Phone numbers, dates, addresses, and credit card numbers should be accepted in any common format and normalised behind the scenes.

**Design patterns**:

* Accept multiple common formats for phone numbers, dates, currency, and addresses.
* Strip non-numeric characters from numeric fields before validating.
* Avoid input masks that reject valid characters.
* Normalise data server-side rather than rejecting it client-side.

**Assessment heuristics**:

* Confirm phone, date, and credit card fields accept common formatting variants.
* Confirm whitespace and punctuation are stripped rather than rejected.
* Confirm rejection messages identify the actual issue, not the format mismatch.

Source: <https://www.w3.org/TR/coga-usable/#objective-4>.

## control-avoid-data-loss-and-timeouts

**Control 4.9 Avoid Data Loss and Timeouts**

Timeouts that discard user input penalise users who take longer to read, type, or decide. Where security or technical constraints require a timeout, the user must be warned and given the chance to extend it.

**Design patterns**:

* Avoid arbitrary timeouts on forms or session.
* Autosave user input continuously.
* Warn the user before a timeout expires and offer an extension.
* Preserve user input even if a session expires.

**Assessment heuristics**:

* Confirm forms do not impose time limits unless strictly required.
* Confirm timeout warnings appear with sufficient time for the user to respond.
* Confirm user input is preserved across session timeouts where possible.

Source: <https://www.w3.org/TR/coga-usable/#objective-4>.

## control-provide-feedback

**Control 4.10 Provide Feedback**

Every user action must produce immediate visible or audible feedback. Silent interfaces leave users unsure whether their action succeeded, prompting repeated attempts and accidental duplicates.

**Design patterns**:

* Provide a visible response to every user action.
* Use live regions to announce status changes to assistive technology.
* Confirm completion of long-running actions.
* Distinguish success, warning, and error feedback by colour, icon, and text.

**Assessment heuristics**:

* Confirm every interactive control produces visible or audible feedback within 100 milliseconds of activation.
* Confirm status changes are announced via `aria-live` regions where appropriate.
* Confirm feedback messages are distinct by category (success, warning, error).

Source: <https://www.w3.org/TR/coga-usable/#objective-4>.

## control-help-the-user-stay-safe

**Control 4.11 Help the User Stay Safe**

Destructive or costly actions must require confirmation. Where possible, actions should be reversible. Users with cognitive disabilities are especially vulnerable to interfaces that punish accidental clicks.

**Design patterns**:

* Require explicit confirmation for destructive or costly actions.
* Make actions reversible where possible (undo, restore, cancel).
* Use clear warning language before risky actions.
* Avoid making destructive actions the default option in dialogs.

**Assessment heuristics**:

* Confirm destructive actions (delete, send, purchase) require confirmation.
* Confirm reversible alternatives are offered where feasible.
* Confirm the destructive option is not the default button in confirmation dialogs.

Source: <https://www.w3.org/TR/coga-usable/#objective-4>.

## control-use-familiar-metrics-and-units

**Control 4.12 Use Familiar Metrics and Units**

Units of measurement must match the user's locale. Showing imperial units to a metric audience (or vice versa) creates avoidable cognitive friction.

**Design patterns**:

* Detect or ask for user locale and display units accordingly.
* Provide unit conversions where multiple units are common.
* Label units clearly; avoid ambiguous abbreviations.
* Allow the user to switch units explicitly.

**Assessment heuristics**:

* Confirm units match the user's locale by default.
* Confirm conversions are provided when units may be unfamiliar.
* Confirm unit abbreviations are unambiguous (for example, distinguishing kilometres from kilobytes).

Source: <https://www.w3.org/TR/coga-usable/#objective-4>.

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
