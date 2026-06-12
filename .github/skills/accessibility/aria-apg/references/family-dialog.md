---
title: "ARIA APG family — Dialog"
description: "The Dialog family is the catch-all bucket per the ARIA APG source rollup."
---

# ARIA APG family — Dialog

The Dialog family is the catch-all bucket per the ARIA APG source rollup. The "true" dialog widgets (alert, alertdialog, dialog) form the core, but the rollup also groups here a wide range of patterns that did not fall into another family: live regions (alert, status, log via the notification live-region pattern), interactive form controls (switch, radio variants, checkbox variants, button), display widgets (meter, tooltip), structural primitives (window splitter, breadcrumb, feed), and landmark guidance. Sections in this file are independent; the family grouping reflects APG's rollup ordering, not a shared behavioural contract.

Source: W3C WAI-ARIA Authoring Practices Guide, Dialog and supporting patterns, <https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/>.

## pattern-alert

**Alert** is the live-region pattern for an unsolicited, important message that requires the user's attention but does not interrupt the user's task. The alert appears in the page, is announced by assistive technology immediately, and does not move focus.

**Required keyboard**

* No keyboard interaction inside the alert itself; the alert does not take focus.
* Focus may move to a dismiss control inside the alert (such as a close button), but the alert region itself is non-interactive.

**Required ARIA**

* The alert container uses `role="alert"` (which implicitly sets `aria-live="assertive"` and `aria-atomic="true"`).
* The alert text appears inside the container at the moment the alert should be announced; assistive technology announces the text on insertion.
* `aria-atomic="false"` may be set when the alert region updates progressively and only the changed portion should be announced.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/alert/>

## pattern-alert-dialog-modal

**Alert Dialog (Modal)** is a modal dialog that carries an urgent message and at least one actionable control (typically OK and Cancel). The pattern combines the alert pattern's announcement semantics with the modal dialog pattern's focus-trap and Escape-to-dismiss contract.

**Required keyboard**

* Tab and Shift+Tab move focus among the dialog's focusable controls, wrapping at the ends of the focus order to stay inside the dialog.
* Escape dismisses the dialog (and triggers the cancellation action).
* Enter on the default button activates that button.
* Focus moves into the dialog when it opens (typically to the most relevant button or to a heading inside the dialog) and returns to the triggering element when the dialog closes.

**Required ARIA**

* The dialog container uses `role="alertdialog"` with `aria-modal="true"`.
* `aria-labelledby` points at the dialog title; `aria-describedby` points at the dialog's descriptive text.
* Background content outside the dialog is removed from the accessibility tree with `inert` (or `aria-hidden="true"` when `inert` is not available).

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/alertdialog/>

## pattern-dialog-modal

**Dialog (Modal)** is the general modal dialog pattern: a window that interrupts the user's workflow, traps keyboard focus, and requires explicit dismissal before the user can interact with the rest of the page. Modal dialogs are the standard pattern for forms, confirmations, and detail editors that must complete or cancel before continuing.

**Required keyboard**

* Tab and Shift+Tab cycle focus among the dialog's focusable controls; focus wraps from the last control to the first and vice versa.
* Escape dismisses the dialog.
* Enter on the default button activates that button.
* Focus moves into the dialog when it opens (typically to the first focusable control or to a designated initial element) and returns to the triggering element when the dialog closes.

**Required ARIA**

* The dialog container uses `role="dialog"` with `aria-modal="true"`.
* `aria-labelledby` points at the dialog title; `aria-describedby` (optional) points at supplementary descriptive content.
* Background content outside the dialog is made inert with the `inert` attribute (or hidden with `aria-hidden="true"` as a fallback).

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/>

## pattern-feed

**Feed** is a scrollable list of articles, where new articles are appended (or prepended) as the user scrolls. The pattern coordinates keyboard navigation between articles and lazy-loading of additional content, while announcing the new content to assistive technology as it arrives.

**Required keyboard**

* Tab moves focus into and out of the feed.
* Page Down moves focus to the next article in the feed; Page Up moves focus to the previous article.
* Control+End moves focus to the last article currently loaded; Control+Home moves focus to the first article.
* Tab within an article moves focus among the article's interactive controls.

**Required ARIA**

* The container uses `role="feed"` with `aria-busy="true"` while loading additional articles.
* Each article uses `role="article"` with `aria-posinset` and `aria-setsize` indicating its position in the feed; `aria-labelledby` points at the article's title.
* When more articles are appended, the new articles' `aria-posinset` and `aria-setsize` reflect the updated count.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/feed/>

## pattern-breadcrumb

**Breadcrumb** is a navigation pattern that shows the user's location within the site's hierarchy as a sequence of links from the root to the current page. The current page is included as a non-link item to provide context for the user's current position.

**Required keyboard**

* Tab moves focus to each link in the breadcrumb trail in document order.
* Enter activates the focused link (standard `<a>` behaviour).

**Required ARIA**

* The container uses `nav` (or `role="navigation"`) with `aria-label="Breadcrumb"`.
* The breadcrumb items are arranged in an ordered list (`<ol>`).
* Each item except the last is a native `<a>` link; the last item represents the current page and uses `aria-current="page"`.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/breadcrumb/>

## pattern-notification-live-region

**Notification (Live Region)** covers the family of polite, non-interruptive live regions: `status`, `log`, `timer`, and the generic `aria-live="polite"` region. These regions announce updates to assistive technology without moving focus and without interrupting current speech, in contrast to `role="alert"` which interrupts.

**Required keyboard**

* No keyboard interaction with the live region itself; the region does not take focus.

**Required ARIA**

* The region uses one of `role="status"` (general advisory information), `role="log"` (a sequence of additions such as a chat transcript), `role="timer"` (an elapsed or remaining time indicator), or a bare container with `aria-live="polite"` and `aria-atomic` set appropriately.
* `aria-live="polite"` is implicit for `role="status"` and `role="log"`; the value can be overridden when the announcement urgency differs.
* `aria-atomic="true"` requests that the entire region be reannounced on every change; `aria-atomic="false"` (the default for log) announces only the additions.
* `aria-relevant` (optional) tunes which mutations trigger announcement (`additions`, `removals`, `text`, `all`).

**Source:** <https://www.w3.org/WAI/ARIA/apg/practices/live-regions/>

## pattern-switch

**Switch** is a two-state input that turns a setting on or off. The switch differs from a checkbox in its presentation (typically a sliding visual rather than a tick box) and in the semantic intent: a switch represents an immediately applied setting, whereas a checkbox represents a deferred selection.

**Required keyboard**

* Tab moves focus to and away from the switch.
* Space toggles the switch's on/off state; Enter (optional) does the same.

**Required ARIA**

* The control uses `role="switch"` (or the native `<input type="checkbox" role="switch">` pattern in some implementations).
* `aria-checked="true"` indicates the on state; `aria-checked="false"` indicates the off state.
* `aria-readonly="true"` indicates that the switch is informational and cannot be toggled by the user.
* `aria-disabled="true"` indicates that the switch is currently unavailable.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/switch/>

## pattern-radio-group

**Radio Group** is a set of mutually exclusive choices in which exactly one radio button is selected at a time. APG's reference implementation uses native focus (each radio is a separate tab stop); see `pattern-radio-group-roving-tabindex` for the variant that uses managed focus.

**Required keyboard**

* Tab moves focus to the selected radio button (or to the first radio button when none is selected), then out of the group.
* Down and Right arrows move focus to and select the next radio button in the group (wrapping to the first); Up and Left arrows do the same in reverse (wrapping to the last).
* Space selects the focused radio button if it is not already selected.

**Required ARIA**

* The group container uses `role="radiogroup"` with `aria-labelledby` or `aria-label` naming the group.
* Each radio uses `role="radio"` with `aria-checked="true"` on the selected radio and `aria-checked="false"` on the rest.
* `aria-required="true"` indicates that a selection must be made before form submission.
* `aria-disabled="true"` on individual radios indicates that they cannot currently be selected.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/radio/>

## pattern-radio-group-roving-tabindex

**Radio Group (Roving Tabindex)** is the radio group variant that uses managed focus: the entire group is one tab stop, and arrow keys move focus between radios within the group. This variant suits radio groups embedded in a composite widget (such as a toolbar) where a per-radio tab stop would disrupt the overall tab order.

**Required keyboard**

* Tab moves focus to the currently selected radio (or to the first radio when none is selected), then out of the group on the next Tab press.
* Down and Right arrows move focus to and select the next radio in the group (wrapping to the first); Up and Left arrows do the same in reverse.
* Space selects the focused radio when it is not already selected.

**Required ARIA**

* The container uses `role="radiogroup"` with an accessible name.
* Each radio uses `role="radio"` with `aria-checked`.
* Exactly one radio carries `tabindex="0"` (typically the selected one); the rest use `tabindex="-1"`.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/radio/examples/radio-activedescendant/>

## pattern-checkbox-dual-state

**Checkbox (Dual-State)** is the standard checkbox: a two-state input representing either checked or unchecked. The checkbox is the standard control for individual on/off selections that are committed as part of a form submission rather than applied immediately.

**Required keyboard**

* Tab moves focus to and away from the checkbox.
* Space toggles the checkbox between checked and unchecked.

**Required ARIA**

* The control uses `role="checkbox"` (or the native `<input type="checkbox">` element, which exposes the role implicitly).
* `aria-checked="true"` for checked; `aria-checked="false"` for unchecked.
* `aria-required="true"` indicates that the checkbox must be checked before form submission.
* `aria-disabled="true"` indicates that the checkbox is currently unavailable.
* `aria-describedby` (optional) points at supplementary descriptive text.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/checkbox/examples/checkbox/>

## pattern-checkbox-mixed-state

**Checkbox (Mixed-State)** is the tri-state checkbox: in addition to checked and unchecked, the control can be in a mixed (indeterminate) state. The mixed state suits parent checkboxes that summarise a set of child checkboxes; the parent is mixed when some but not all children are checked.

**Required keyboard**

* Tab moves focus to and away from the checkbox.
* Space cycles the checkbox among checked, mixed, and unchecked (or among checked and unchecked when the mixed state is set programmatically rather than via direct user activation).

**Required ARIA**

* The control uses `role="checkbox"`.
* `aria-checked="mixed"` represents the indeterminate state; `aria-checked="true"` and `aria-checked="false"` represent the other two states.
* When the checkbox summarises a set of children, JavaScript updates the parent's `aria-checked` value as the children's states change.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/checkbox/examples/checkbox-mixed/>

## pattern-button

**Button** is the activation primitive: a control that fires an action when activated. APG advises authors to use the native `<button>` element whenever possible because it brings the keyboard contract, the disabled-state behaviour, and the focusable behaviour for free.

**Required keyboard**

* Tab moves focus to and away from the button.
* Enter activates the button.
* Space activates the button on release (the native behaviour of `<button>`).

**Required ARIA**

* Prefer the native `<button>` element. Use `role="button"` with `tabindex="0"` only when the host element is not a button.
* `aria-pressed="true"` or `aria-pressed="false"` exposes a toggle button's state; `aria-pressed="mixed"` represents a partially pressed state.
* `aria-expanded` describes whether a button reveals an associated region (disclosure button, combobox button, menu button).
* `aria-haspopup` indicates that activation reveals a popup; the value names the popup's kind (`menu`, `listbox`, `tree`, `grid`, `dialog`).
* `aria-disabled="true"` indicates a button whose action is currently unavailable; unlike the native `disabled` attribute, an `aria-disabled` button remains focusable so users can discover the disabled state.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/button/>

## pattern-meter

**Meter** is a display widget that represents a known value within a known range, typically with semantic colour zones (low, optimal, high). The meter differs from a progressbar because it represents a static measurement rather than progress toward completion; battery level and disk usage are typical meter use cases.

**Required keyboard**

* No keyboard interaction; the meter is non-interactive and does not take focus.

**Required ARIA**

* The container uses `role="meter"` (or the native `<meter>` element, which exposes the role implicitly).
* `aria-valuenow` reflects the current value.
* `aria-valuemin` and `aria-valuemax` bound the value range.
* `aria-valuetext` provides a human-readable representation when the numeric value alone is insufficient ("Battery at 47 percent" rather than "47").
* `aria-label` or `aria-labelledby` supplies the accessible name.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/meter/>

## pattern-tooltip

**Tooltip** is a small contextual popup that appears next to an element to provide a short descriptive label or hint. APG specifies a strict contract: the tooltip appears on focus and on hover, does not take focus, dismisses on Escape, and is associated with its trigger via `aria-describedby` so that the tooltip text augments rather than replaces the trigger's accessible name.

**Required keyboard**

* Focus on the trigger element shows the tooltip; focus leaving the trigger hides the tooltip.
* Escape (while the trigger has focus) hides the tooltip without moving focus.
* No keyboard interaction with the tooltip itself; the tooltip does not take focus.

**Required ARIA**

* The tooltip container uses `role="tooltip"` with an `id`.
* The trigger element references the tooltip with `aria-describedby` pointing at the tooltip's `id`.
* The tooltip text is short and supplementary; it does not duplicate the trigger's visible label.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/tooltip/>

## pattern-window-splitter

**Window Splitter** is the resizable divider between two adjacent panes (for example, a vertical splitter between a navigation pane and a content pane). The splitter is focusable and adjustable by keyboard so that users who cannot drag with a pointer can still resize the panes.

**Required keyboard**

* Tab moves focus to and away from the splitter.
* Right or Up arrow increases the size of the leading pane by a small step; Left or Down arrow decreases it by the same step (for a vertical splitter, the arrow assignment reflects whether the splitter is horizontal or vertical).
* Page Up and Page Down change the size by a larger step.
* Home collapses the leading pane to its minimum size; End expands it to its maximum size.
* Enter (optional) toggles between the most recent size and the collapsed state.

**Required ARIA**

* The splitter uses `role="separator"` with `tabindex="0"` and `aria-orientation` describing the splitter's axis.
* `aria-valuenow` reflects the current size of the leading pane (as a percentage or absolute value).
* `aria-valuemin` and `aria-valuemax` bound the size range.
* `aria-controls` points at the pane (or panes) being resized.
* `aria-label` or `aria-labelledby` supplies an accessible name (such as "Resize navigation pane").

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/windowsplitter/>

## pattern-landmarks

**Landmarks** is the structural-navigation pattern: the page is divided into well-named regions that screen readers expose as a landmark map, so that users can jump directly to (for example) the main content, the primary navigation, or the search region. APG advises authors to use the native HTML sectioning elements (`main`, `nav`, `aside`, `header`, `footer`, `section`, `form`) wherever possible because they expose the corresponding landmark roles implicitly.

**Required keyboard**

* No keyboard interaction with the landmarks themselves; landmarks are navigated via the screen reader's landmark-navigation gestures (typically D in NVDA or VoiceOver, or the screen reader's landmark list).

**Required ARIA**

* Prefer the native sectioning elements: `<main>` (`role="main"`), `<nav>` (`role="navigation"`), `<aside>` (`role="complementary"`), `<header>` and `<footer>` (which expose `role="banner"` and `role="contentinfo"` when they are direct children of `<body>`), `<section>` with an accessible name (`role="region"`), and `<form>` with an accessible name (`role="form"`).
* Apply `aria-label` or `aria-labelledby` to differentiate landmarks of the same role (for example, two `<nav>` elements labelled "Main" and "Footer").
* Use the search landmark (`role="search"`) on the container around a site-wide search control.
* Exactly one `<main>` (or `role="main"`) appears on the page.

**Source:** <https://www.w3.org/WAI/ARIA/apg/practices/landmark-regions/>

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
