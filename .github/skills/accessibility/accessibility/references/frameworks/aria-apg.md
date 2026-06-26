---
title: ARIA Authoring Practices Guide framework reference
description: WAI-ARIA Authoring Practices Guide widget patterns used as an accessibility assessment knowledge base by the Accessibility Planner and Skill Assessor subagent
---

# ARIA Authoring Practices Guide framework reference

This skill packages the W3C WAI-ARIA Authoring Practices Guide (APG) as an accessibility assessment knowledge base. APG documents the keyboard interaction, ARIA roles, states, and properties for the common interactive widget patterns that web authors implement. The skill groups 44 design patterns into seven families (Disclosure, Combobox, Grid, Menu, Tabs, Treegrid, and Dialog) and points the Accessibility Skill Assessor subagent at the per-family reference files in `references/` when a finding involves a specific pattern.

APG is non-normative implementation guidance that operationalises the normative WAI-ARIA specification, so APG patterns sit alongside the [`wcag-22`](wcag-22.md) skill: APG describes how to build the widget, WCAG 2.2 describes which behaviours the finished widget must satisfy. Assessor subagents typically cite both — the APG pattern for the widget contract and the relevant WCAG 2.2 success criterion for the user-facing requirement.

Source: W3C WAI-ARIA Authoring Practices Guide, <https://www.w3.org/WAI/ARIA/apg/>. APG content is published under the W3C Document License. Per the repository licensing posture in `.github/instructions/accessibility/accessibility-license-posture.instructions.md`, pattern summaries in this skill are paraphrased in the authors' own words and every reference file links to the canonical W3C pattern URL for verification.

## Pattern roll-up

| Pattern                            | Family     | Primary roles                                                                                   | Required keyboard                                                                          | Required ARIA                                                                                            | Reference                                                                                          |
|------------------------------------|------------|-------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------|
| Accordion                          | Disclosure | `button`, `region`                                                                              | Enter, Space, Down/Up arrows (optional), Home, End                                         | `aria-expanded`, `aria-controls`                                                                         | [family-disclosure.md#pattern-accordion](#pattern-accordion)                                       |
| Disclosure (Show/Hide)             | Disclosure | `button`                                                                                        | Enter, Space                                                                               | `aria-expanded`, `aria-controls` (optional)                                                              | [family-disclosure.md#pattern-disclosure-show-hide](#pattern-disclosure-show-hide)                 |
| Carousel (Auto-Rotating)           | Disclosure | `region`, `button`                                                                              | Left/Right arrows, Space or Enter (pause)                                                  | `aria-live`, `aria-controls`                                                                             | [family-disclosure.md#pattern-carousel-auto-rotating](#pattern-carousel-auto-rotating)             |
| Carousel (Tabbed)                  | Disclosure | `tablist`, `tab`, `tabpanel`                                                                    | Left/Right arrows, Enter, Space                                                            | `aria-selected`                                                                                          | [family-disclosure.md#pattern-carousel-tabbed](#pattern-carousel-tabbed)                           |
| Disclosure Navigation              | Disclosure | `button`, `navigation`                                                                          | Enter, Space, Escape (optional), Tab                                                       | `aria-expanded`                                                                                          | [family-disclosure.md#pattern-disclosure-navigation](#pattern-disclosure-navigation)               |
| Disclosure Navigation Hybrid       | Disclosure | `button`, `link`                                                                                | Enter, Space, Tab, arrow keys (optional)                                                   | `aria-expanded`, `aria-haspopup` (optional)                                                              | [family-disclosure.md#pattern-disclosure-navigation-hybrid](#pattern-disclosure-navigation-hybrid) |
| Combobox (Autocomplete Both)       | Combobox   | `combobox`, `listbox`, `option`                                                                 | Down/Up arrows, Escape, Enter, Alt+Down or Alt+Up                                          | `aria-expanded`, `aria-controls`, `aria-autocomplete="both"`, `aria-activedescendant`                    | [family-combobox.md#pattern-combobox-autocomplete-both](#pattern-combobox-autocomplete-both)       |
| Combobox (List)                    | Combobox   | `combobox`, `listbox`, `option`                                                                 | Down/Up arrows, Escape, Enter, Backspace                                                   | `aria-expanded`, `aria-controls`, `aria-autocomplete="list"`, `aria-activedescendant`                    | [family-combobox.md#pattern-combobox-list](#pattern-combobox-list)                                 |
| Combobox (None)                    | Combobox   | `combobox`, `listbox`, `option`                                                                 | Down arrow, Enter, Escape                                                                  | `aria-expanded`, `aria-controls`, `aria-autocomplete="none"`, `aria-activedescendant`                    | [family-combobox.md#pattern-combobox-none](#pattern-combobox-none)                                 |
| Combobox (Select-Only)             | Combobox   | `combobox`, `listbox`, `option`                                                                 | Down/Up arrows, Escape, Enter, Space, printable characters                                 | `aria-expanded`, `aria-controls`, `aria-activedescendant`                                                | [family-combobox.md#pattern-combobox-select-only](#pattern-combobox-select-only)                   |
| Combobox (Grid Popup)              | Combobox   | `combobox`, `grid`, `gridcell`                                                                  | Arrow keys, Home, End, Enter, Escape                                                       | `aria-haspopup="grid"`, `aria-expanded`, `aria-controls`, `aria-activedescendant`                        | [family-combobox.md#pattern-combobox-grid-popup](#pattern-combobox-grid-popup)                     |
| Listbox                            | Combobox   | `listbox`, `option`                                                                             | Down/Up arrows, Space, Shift+Space, Home, End, Ctrl+A                                      | `aria-selected`, `aria-multiselectable`, `aria-disabled`                                                 | [family-combobox.md#pattern-listbox](#pattern-listbox)                                             |
| Grid (Layout)                      | Grid       | `grid`, `row`, `gridcell`                                                                       | Arrow keys, Home, End, Ctrl+Home, Ctrl+End, Enter or Space                                 | `aria-selected`                                                                                          | [family-grid.md#pattern-grid-layout](#pattern-grid-layout)                                         |
| Grid (Data, Single-Cell Selection) | Grid       | `grid`, `row`, `gridcell`, `columnheader`                                                       | Arrow keys, Home, End, Ctrl+Home, Ctrl+End, Enter or Space                                 | `aria-selected`, `aria-readonly`                                                                         | [family-grid.md#pattern-grid-data-single-cell](#pattern-grid-data-single-cell)                     |
| Grid (Data, Multi-Cell Selection)  | Grid       | `grid`, `row`, `gridcell`                                                                       | Arrow keys, Ctrl+Space, Shift+arrow keys, Ctrl+A                                           | `aria-multiselectable`, `aria-selected`                                                                  | [family-grid.md#pattern-grid-data-multi-cell](#pattern-grid-data-multi-cell)                       |
| Spinbutton                         | Grid       | `spinbutton`                                                                                    | Up/Down arrows, Page Up, Page Down, Home, End                                              | `aria-valuenow`, `aria-valuemin`, `aria-valuemax`, `aria-valuetext`, `aria-disabled`                     | [family-grid.md#pattern-spinbutton](#pattern-spinbutton)                                           |
| Slider (Single-Thumb)              | Grid       | `slider`                                                                                        | Left/Right or Up/Down arrows, Home, End, Page Up, Page Down                                | `aria-valuenow`, `aria-valuemin`, `aria-valuemax`, `aria-valuetext`, `aria-orientation`, `aria-disabled` | [family-grid.md#pattern-slider-single-thumb](#pattern-slider-single-thumb)                         |
| Slider (Two-Thumb)                 | Grid       | `slider`                                                                                        | Arrow keys, Tab between thumbs, Home, End                                                  | `aria-valuenow`, `aria-valuemin`, `aria-valuemax`, `aria-valuetext`, `aria-label`, `aria-orientation`    | [family-grid.md#pattern-slider-two-thumb](#pattern-slider-two-thumb)                               |
| Menu Button                        | Menu       | `button`, `menu`, `menuitem`                                                                    | Enter, Space, Down/Up arrows, Escape, Tab, printable characters                            | `aria-haspopup="menu"`, `aria-expanded`, `aria-controls`                                                 | [family-menu.md#pattern-menu-button](#pattern-menu-button)                                         |
| Menubar (Editor)                   | Menu       | `menubar`, `menuitem`                                                                           | Tab, arrow keys, Down (open menu), Right (next menu), Enter, Space, Escape                 | `aria-haspopup="menu"`, `aria-expanded`, `aria-orientation`                                              | [family-menu.md#pattern-menubar-editor](#pattern-menubar-editor)                                   |
| Menubar (Navigation)               | Menu       | `menubar`, `menuitem`, `link`                                                                   | Tab, Left/Right arrows, Down (submenu), Up, Escape, Enter, Space                           | `aria-haspopup`, `aria-orientation`                                                                      | [family-menu.md#pattern-menubar-navigation](#pattern-menubar-navigation)                           |
| Actions Menu Button                | Menu       | `button`, `menu`, `menuitem`                                                                    | Enter, Space, Down arrow, arrow keys, Escape, printable characters                         | `aria-haspopup="menu"`, `aria-expanded`                                                                  | [family-menu.md#pattern-actions-menu-button](#pattern-actions-menu-button)                         |
| Menubar with Multiple Selection    | Menu       | `menubar`, `menuitemcheckbox`, `menuitemradio`                                                  | Arrow keys, Space, Enter, Shift+arrow (optional), Ctrl+A (optional)                        | `aria-checked`, `aria-multiselectable`                                                                   | [family-menu.md#pattern-menubar-multi-select](#pattern-menubar-multi-select)                       |
| Tabs (Manual Activation)           | Tabs       | `tablist`, `tab`, `tabpanel`                                                                    | Tab, Left/Right or Up/Down arrows, Home, End, Enter, Space, Delete (optional)              | `aria-selected`, `aria-controls`, `aria-labelledby`, `aria-orientation`                                  | [family-tabs.md#pattern-tabs-manual-activation](#pattern-tabs-manual-activation)                   |
| Tabs (Automatic Activation)        | Tabs       | `tablist`, `tab`, `tabpanel`                                                                    | Tab, Left/Right or Up/Down arrows, Home, End, Delete (optional)                            | `aria-selected`, `aria-controls`, `aria-labelledby`, `aria-orientation`                                  | [family-tabs.md#pattern-tabs-automatic-activation](#pattern-tabs-automatic-activation)             |
| Tree View                          | Treegrid   | `tree`, `treeitem`                                                                              | Arrow keys, Home, End, asterisk (optional), printable characters                           | `aria-expanded`, `aria-level`, `aria-posinset`, `aria-setsize`, `aria-selected`                          | [family-treegrid.md#pattern-tree-view](#pattern-tree-view)                                         |
| Treegrid (Email Client)            | Treegrid   | `treegrid`, `row`, `gridcell`                                                                   | Right/Left arrows (expand/collapse), Down/Up arrows, Home, End, Ctrl+Home, Ctrl+End, Space | `aria-expanded`, `aria-level`, `aria-selected`, `aria-controls`                                          | [family-treegrid.md#pattern-treegrid-email-client](#pattern-treegrid-email-client)                 |
| Link                               | Treegrid   | `link` (native `<a>` or role)                                                                   | Enter, Space (optional with role), Tab                                                     | `aria-current`, `aria-disabled`, `aria-label`, `aria-expanded` (optional)                                | [family-treegrid.md#pattern-link](#pattern-link)                                                   |
| Alert                              | Dialog     | `alert`                                                                                         | None (announced on insertion); Tab through embedded controls                               | `aria-live="assertive"`, `aria-atomic="true"`                                                            | [family-dialog.md#pattern-alert](#pattern-alert)                                                   |
| Alert Dialog (Modal)               | Dialog     | `alertdialog`                                                                                   | Tab, Shift+Tab, Escape, Enter on default button                                            | `aria-modal="true"`, `aria-labelledby`, `aria-describedby`                                               | [family-dialog.md#pattern-alert-dialog-modal](#pattern-alert-dialog-modal)                         |
| Dialog (Modal)                     | Dialog     | `dialog`                                                                                        | Tab, Shift+Tab, Escape, Enter on submit                                                    | `aria-modal="true"`, `aria-labelledby`, `aria-describedby`                                               | [family-dialog.md#pattern-dialog-modal](#pattern-dialog-modal)                                     |
| Feed                               | Dialog     | `feed`, `article`                                                                               | Page Up, Page Down, Home, End (optional), Tab                                              | `aria-label`, `aria-live="polite"`, `aria-relevant`, `aria-busy`                                         | [family-dialog.md#pattern-feed](#pattern-feed)                                                     |
| Breadcrumb                         | Dialog     | `navigation`, `link`                                                                            | Tab, Enter                                                                                 | `aria-label`, `aria-current="page"`                                                                      | [family-dialog.md#pattern-breadcrumb](#pattern-breadcrumb)                                         |
| Notification (Live Region)         | Dialog     | `alert`, `status`, `log`                                                                        | None (announced); Tab through embedded controls                                            | `aria-live`, `aria-atomic`, `aria-relevant`                                                              | [family-dialog.md#pattern-notification-live-region](#pattern-notification-live-region)             |
| Switch                             | Dialog     | `switch`                                                                                        | Space, Enter (optional), Tab                                                               | `aria-checked`, `aria-label`, `aria-disabled`                                                            | [family-dialog.md#pattern-switch](#pattern-switch)                                                 |
| Radio Group                        | Dialog     | `radiogroup`, `radio`                                                                           | Tab, Space, arrow keys                                                                     | `aria-checked`, `aria-label`                                                                             | [family-dialog.md#pattern-radio-group](#pattern-radio-group)                                       |
| Radio Group (Roving Tabindex)      | Dialog     | `radiogroup`, `radio`                                                                           | Tab, arrow keys, Space (optional)                                                          | `aria-checked`, managed `tabindex`                                                                       | [family-dialog.md#pattern-radio-group-roving-tabindex](#pattern-radio-group-roving-tabindex)       |
| Checkbox (Dual State)              | Dialog     | `checkbox`                                                                                      | Space, Tab                                                                                 | `aria-checked` (true or false), `aria-label`, `aria-disabled`                                            | [family-dialog.md#pattern-checkbox-dual-state](#pattern-checkbox-dual-state)                       |
| Checkbox (Mixed State)             | Dialog     | `checkbox`                                                                                      | Space, Tab                                                                                 | `aria-checked="mixed"` (plus true and false), `aria-label`, `aria-disabled`                              | [family-dialog.md#pattern-checkbox-mixed-state](#pattern-checkbox-mixed-state)                     |
| Button                             | Dialog     | `button`                                                                                        | Enter, Space, Tab, Shift+F10 (optional)                                                    | `aria-pressed`, `aria-haspopup`, `aria-expanded`, `aria-disabled`, `aria-label`                          | [family-dialog.md#pattern-button](#pattern-button)                                                 |
| Meter                              | Dialog     | `meter`                                                                                         | None (read-only display)                                                                   | `aria-valuenow`, `aria-valuemin`, `aria-valuemax`, `aria-valuetext`, `aria-label`                        | [family-dialog.md#pattern-meter](#pattern-meter)                                                   |
| Tooltip                            | Dialog     | `tooltip`                                                                                       | Tab triggers display, Escape (optional)                                                    | `aria-describedby` on trigger, `aria-expanded` (optional)                                                | [family-dialog.md#pattern-tooltip](#pattern-tooltip)                                               |
| Window Splitter                    | Dialog     | `separator`                                                                                     | Tab, arrow keys, Home, End, Enter (optional)                                               | `aria-valuenow`, `aria-valuemin`, `aria-valuemax`, `aria-orientation`, `aria-label`, `aria-controls`     | [family-dialog.md#pattern-window-splitter](#pattern-window-splitter)                               |
| Landmarks                          | Dialog     | `navigation`, `main`, `complementary`, `contentinfo`, `search`, `region`, `form`, `application` | None (structural; screen-reader landmark navigation)                                       | `aria-label`, `aria-labelledby`, `aria-current`                                                          | [family-dialog.md#pattern-landmarks](#pattern-landmarks)                                           |

Total: 44 patterns across 7 families (Disclosure: 6; Combobox: 6; Grid: 6; Menu: 5; Tabs: 2; Treegrid: 3; Dialog: 16).

## Assessment heuristics

Per-pattern keyboard interaction lists, ARIA role and state requirements, and pattern-specific notes live inside the per-family reference files in `references/`. The Accessibility Skill Assessor subagent consumes the appropriate `family-<name>.md#pattern-<slug>` section when evaluating a finding against a specific APG pattern.

Cross-skill use is the common case: an APG finding usually cites both the pattern reference here and the relevant WCAG 2.2 success criterion in [`wcag-22`](wcag-22.md). For example, a custom combobox with broken keyboard support is cited against `family-combobox.md#pattern-combobox-list` (for the missing keyboard contract) and `../wcag-22/references/guideline-2-1.md#sc-2-1-1` (for the WCAG 2.1.1 Keyboard requirement).

## Skill layout

* `SKILL.md` — this file (skill entrypoint and 44-row roll-up table).
* `references/` — one markdown file per APG pattern family. Each file contains a paraphrased description of every pattern in the family, its keyboard interaction contract, its ARIA roles, states, and properties, and a canonical W3C source URL.

## ARIA APG family — Combobox

The Combobox family covers single-line input controls that combine a text field with a popup of candidate values. APG distinguishes four combobox variants by their autocomplete behaviour (both, list, none, select-only) and a fifth variant whose popup is a grid rather than a listbox. The standalone `listbox` pattern lives in this family too because the combobox popup is almost always a listbox and authors reuse the same keyboard contract for both.

Source: W3C WAI-ARIA Authoring Practices Guide, Combobox and Listbox patterns, <https://www.w3.org/WAI/ARIA/apg/patterns/combobox/> and <https://www.w3.org/WAI/ARIA/apg/patterns/listbox/>.

### pattern-combobox-autocomplete-both

**Combobox (Autocomplete Both)** is the combobox variant where typing both filters the visible options in the listbox and automatically inserts the text completion of the closest matching option into the input. The user sees the typed characters as confirmed text and the completion as selected text that can be accepted, edited, or rejected.

**Required keyboard**

* Typing in the input filters the listbox and inserts the closest completion as selected text.
* Down arrow opens the listbox if closed and moves focus into the listbox (or to the next option); Up arrow does the same in reverse.
* Alt+Down opens the listbox without moving focus into it; Alt+Up closes the listbox.
* Enter accepts the highlighted option (or the typed value if no option is highlighted) and closes the listbox.
* Escape closes the listbox without changing the input; pressing Escape a second time clears the input.
* Backspace and Delete edit the input as expected and rerun the filter.

**Required ARIA**

* `role="combobox"` on the text input (or on a `div` wrapping a native `<input>`) with `aria-expanded`, `aria-controls` pointing at the listbox's `id`, and `aria-autocomplete="both"`.
* `aria-activedescendant` on the combobox points at the `id` of the currently highlighted option.
* `role="listbox"` on the popup container with `aria-label` or `aria-labelledby` naming the listbox.
* `role="option"` on each option, with `aria-selected="true"` on the currently highlighted option.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/combobox/examples/combobox-autocomplete-both/>

### pattern-combobox-list

**Combobox (List)** is the combobox variant where typing filters the listbox but does not automatically insert a completion. The user must explicitly choose an option from the listbox; the input retains exactly what was typed until a selection is committed.

**Required keyboard**

* Typing in the input filters the listbox; the input retains the typed text.
* Down arrow opens the listbox and moves focus to the first option (or to the next option when already open); Up arrow does the same in reverse.
* Enter commits the highlighted option to the input and closes the listbox.
* Escape closes the listbox without changing the input; pressing Escape a second time clears the input.
* Backspace edits the input and rerun the filter.

**Required ARIA**

* `role="combobox"` on the text input with `aria-expanded`, `aria-controls`, and `aria-autocomplete="list"`.
* `aria-activedescendant` on the combobox points at the `id` of the currently highlighted option.
* `role="listbox"` on the popup container with an accessible name.
* `role="option"` on each option, with `aria-selected="true"` on the highlighted option.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/combobox/examples/combobox-autocomplete-list/>

### pattern-combobox-none

**Combobox (None)** is the combobox variant whose listbox does not filter as the user types; the listbox shows the full set of options at all times. The input still accepts free-form text; the listbox simply offers convenient suggestions.

**Required keyboard**

* Typing in the input does not filter the listbox.
* Down arrow opens the listbox and moves focus to the first option (or to the next option when already open).
* Enter commits the highlighted option (or the typed value) and closes the listbox.
* Escape closes the listbox without changing the input.

**Required ARIA**

* `role="combobox"` on the text input with `aria-expanded`, `aria-controls`, and `aria-autocomplete="none"`.
* `aria-activedescendant` on the combobox points at the `id` of the currently highlighted option.
* `role="listbox"` on the popup container with an accessible name.
* `role="option"` on each option, with `aria-selected="true"` on the highlighted option.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/combobox/examples/combobox-autocomplete-none/>

### pattern-combobox-select-only

**Combobox (Select-Only)** is the combobox variant that behaves like a native `<select>` element: the user picks one option from a fixed listbox but cannot type free-form text. The "input" is therefore not a text input but a focusable container whose visible label reflects the chosen option.

**Required keyboard**

* Down arrow opens the listbox and moves focus to the next option (or to the first option when closed); Up arrow does the same in reverse.
* Enter or Space on the combobox opens or closes the listbox; Enter commits the highlighted option when the listbox is open.
* Escape closes the listbox without changing the selection.
* Home and End jump focus to the first or last option.
* Printable characters jump focus to the next option whose label starts with the typed string.

**Required ARIA**

* The combobox uses `role="combobox"` (typically on a `button` or focusable `div`) with `aria-expanded`, `aria-controls`, and a `tabindex="0"`. There is no `aria-autocomplete` value because no typing occurs.
* `aria-activedescendant` on the combobox points at the highlighted option.
* `role="listbox"` on the popup container with an accessible name.
* `role="option"` on each option, with `aria-selected="true"` on the chosen option.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/combobox/examples/combobox-select-only/>

### pattern-combobox-grid-popup

**Combobox (Grid Popup)** is the combobox variant whose popup is a grid rather than a listbox. The grid suits cases where each candidate value has multiple columns of information (for example, a date picker showing day, weekday, and additional metadata, or an autocomplete that surfaces multiple attributes per row).

**Required keyboard**

* Typing in the input filters the grid (when filtering is enabled).
* Down arrow opens the grid and moves focus to the first row (or first cell) when closed; Up arrow does the same in reverse.
* Within the open grid: Left and Right arrows move focus between cells in a row; Down and Up arrows move focus between rows; Home and End jump to the first or last cell in the current row.
* Enter commits the currently highlighted row to the input and closes the grid.
* Escape closes the grid without changing the input.

**Required ARIA**

* `role="combobox"` on the text input with `aria-expanded`, `aria-controls` pointing at the grid's `id`, and `aria-haspopup="grid"`.
* `aria-activedescendant` on the combobox points at the currently highlighted cell (or row).
* `role="grid"` on the popup container with an accessible name.
* `role="row"` on each row, `role="gridcell"` on cells, and `role="columnheader"` on the grid's column headers.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/combobox/examples/grid-combo/>

### pattern-listbox

**Listbox** is a standalone widget that presents a list of choices for selection. APG supports two selection models: single-select (where one option is selected at a time) and multi-select (where any subset of options may be selected). The listbox is rarely used in isolation in modern UIs but remains the canonical popup for combobox patterns.

**Required keyboard**

* Tab moves focus into and out of the listbox; the listbox itself is one tab stop.
* Down and Up arrows move focus between options (changing selection in a single-select listbox); Home and End jump to the first or last option.
* Space toggles selection in a multi-select listbox; in a single-select listbox, Space selects the focused option.
* Shift+Space (multi-select only) extends selection from the previous anchor to the focused option.
* Shift+Down or Shift+Up (multi-select only) extends selection by one option.
* Ctrl+A (multi-select, optional) selects all options.
* Printable characters jump focus to the next option whose label starts with the typed string.

**Required ARIA**

* The container uses `role="listbox"` with `aria-orientation` set when the orientation is not the default vertical.
* `aria-multiselectable="true"` when the listbox supports multi-selection.
* `role="option"` on each option, with `aria-selected="true"` on selected options and `aria-selected="false"` on unselected options in a multi-select listbox.
* `aria-disabled="true"` on options that cannot currently be selected.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/listbox/>

## ARIA APG family — Dialog

The Dialog family is the catch-all bucket per the ARIA APG source rollup. The "true" dialog widgets (alert, alertdialog, dialog) form the core, but the rollup also groups here a wide range of patterns that did not fall into another family: live regions (alert, status, log via the notification live-region pattern), interactive form controls (switch, radio variants, checkbox variants, button), display widgets (meter, tooltip), structural primitives (window splitter, breadcrumb, feed), and landmark guidance. Sections in this file are independent; the family grouping reflects APG's rollup ordering, not a shared behavioural contract.

Source: W3C WAI-ARIA Authoring Practices Guide, Dialog and supporting patterns, <https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/>.

### pattern-alert

**Alert** is the live-region pattern for an unsolicited, important message that requires the user's attention but does not interrupt the user's task. The alert appears in the page, is announced by assistive technology immediately, and does not move focus.

**Required keyboard**

* No keyboard interaction inside the alert itself; the alert does not take focus.
* Focus may move to a dismiss control inside the alert (such as a close button), but the alert region itself is non-interactive.

**Required ARIA**

* The alert container uses `role="alert"` (which implicitly sets `aria-live="assertive"` and `aria-atomic="true"`).
* The alert text appears inside the container at the moment the alert should be announced; assistive technology announces the text on insertion.
* `aria-atomic="false"` may be set when the alert region updates progressively and only the changed portion should be announced.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/alert/>

### pattern-alert-dialog-modal

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

### pattern-dialog-modal

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

### pattern-feed

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

### pattern-breadcrumb

**Breadcrumb** is a navigation pattern that shows the user's location within the site's hierarchy as a sequence of links from the root to the current page. The current page is included as a non-link item to provide context for the user's current position.

**Required keyboard**

* Tab moves focus to each link in the breadcrumb trail in document order.
* Enter activates the focused link (standard `<a>` behaviour).

**Required ARIA**

* The container uses `nav` (or `role="navigation"`) with `aria-label="Breadcrumb"`.
* The breadcrumb items are arranged in an ordered list (`<ol>`).
* Each item except the last is a native `<a>` link; the last item represents the current page and uses `aria-current="page"`.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/breadcrumb/>

### pattern-notification-live-region

**Notification (Live Region)** covers the family of polite, non-interruptive live regions: `status`, `log`, `timer`, and the generic `aria-live="polite"` region. These regions announce updates to assistive technology without moving focus and without interrupting current speech, in contrast to `role="alert"` which interrupts.

**Required keyboard**

* No keyboard interaction with the live region itself; the region does not take focus.

**Required ARIA**

* The region uses one of `role="status"` (general advisory information), `role="log"` (a sequence of additions such as a chat transcript), `role="timer"` (an elapsed or remaining time indicator), or a bare container with `aria-live="polite"` and `aria-atomic` set appropriately.
* `aria-live="polite"` is implicit for `role="status"` and `role="log"`; the value can be overridden when the announcement urgency differs.
* `aria-atomic="true"` requests that the entire region be reannounced on every change; `aria-atomic="false"` (the default for log) announces only the additions.
* `aria-relevant` (optional) tunes which mutations trigger announcement (`additions`, `removals`, `text`, `all`).

**Source:** <https://www.w3.org/WAI/ARIA/apg/practices/live-regions/>

### pattern-switch

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

### pattern-radio-group

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

### pattern-radio-group-roving-tabindex

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

### pattern-checkbox-dual-state

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

### pattern-checkbox-mixed-state

**Checkbox (Mixed-State)** is the tri-state checkbox: in addition to checked and unchecked, the control can be in a mixed (indeterminate) state. The mixed state suits parent checkboxes that summarise a set of child checkboxes; the parent is mixed when some but not all children are checked.

**Required keyboard**

* Tab moves focus to and away from the checkbox.
* Space cycles the checkbox among checked, mixed, and unchecked (or among checked and unchecked when the mixed state is set programmatically rather than via direct user activation).

**Required ARIA**

* The control uses `role="checkbox"`.
* `aria-checked="mixed"` represents the indeterminate state; `aria-checked="true"` and `aria-checked="false"` represent the other two states.
* When the checkbox summarises a set of children, JavaScript updates the parent's `aria-checked` value as the children's states change.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/checkbox/examples/checkbox-mixed/>

### pattern-button

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

### pattern-meter

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

### pattern-tooltip

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

### pattern-window-splitter

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

### pattern-landmarks

**Landmarks** is the structural-navigation pattern: the page is divided into well-named regions that screen readers expose as a landmark map, so that users can jump directly to (for example) the main content, the primary navigation, or the search region. APG advises authors to use the native HTML sectioning elements (`main`, `nav`, `aside`, `header`, `footer`, `section`, `form`) wherever possible because they expose the corresponding landmark roles implicitly.

**Required keyboard**

* No keyboard interaction with the landmarks themselves; landmarks are navigated via the screen reader's landmark-navigation gestures (typically D in NVDA or VoiceOver, or the screen reader's landmark list).

**Required ARIA**

* Prefer the native sectioning elements: `<main>` (`role="main"`), `<nav>` (`role="navigation"`), `<aside>` (`role="complementary"`), `<header>` and `<footer>` (which expose `role="banner"` and `role="contentinfo"` when they are direct children of `<body>`), `<section>` with an accessible name (`role="region"`), and `<form>` with an accessible name (`role="form"`).
* Apply `aria-label` or `aria-labelledby` to differentiate landmarks of the same role (for example, two `<nav>` elements labelled "Main" and "Footer").
* Use the search landmark (`role="search"`) on the container around a site-wide search control.
* Exactly one `<main>` (or `role="main"`) appears on the page.

**Source:** <https://www.w3.org/WAI/ARIA/apg/practices/landmark-regions/>

## ARIA APG family — Disclosure

The Disclosure family covers widgets whose primary behaviour is showing or hiding a region of related content. APG groups the simple show/hide disclosure together with composite patterns built on the same expand-and-collapse mechanic: accordions (a vertical stack of disclosures), carousels (a rotating disclosure of one panel at a time), and disclosure navigation menus (a navigation menu whose submenus appear via the disclosure pattern rather than the menu pattern). The hybrid disclosure-navigation variant combines a link as the top-level item with a separate disclosure button for the submenu.

Source: W3C WAI-ARIA Authoring Practices Guide, Disclosure and related patterns, <https://www.w3.org/WAI/ARIA/apg/patterns/disclosure/>.

### pattern-accordion

**Accordion** is a vertical stack of disclosure controls. Each header is a button that expands or collapses an associated region; accordions may permit only one panel open at a time (single-expand) or any combination of panels open at the same time (multi-expand).

**Required keyboard**

* Tab moves focus to the next header in the accordion, then out of the accordion.
* Enter or Space on a header toggles the expanded state of its panel.
* Down arrow (optional) moves focus to the next accordion header (wrapping to the first); Up arrow (optional) moves focus to the previous header (wrapping to the last).
* Home (optional) moves focus to the first header; End (optional) moves focus to the last header.

**Required ARIA**

* Each header uses a `button` (or `role="button"`) with `aria-expanded="true"` or `aria-expanded="false"` and `aria-controls` pointing at the `id` of its panel.
* Each panel uses `role="region"` (or a semantically equivalent landmark) with `aria-labelledby` pointing at its header's `id`.
* The hidden panel is fully removed from the accessibility tree (via `hidden` or `display: none`) when collapsed.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/accordion/>

### pattern-disclosure-show-hide

**Disclosure (Show/Hide)** is the minimal pattern: a single button that toggles the visibility of one region of content. The pattern is the building block for more complex disclosures (accordions, navigation menus, expandable filters).

**Required keyboard**

* Tab moves focus to and away from the disclosure button.
* Enter or Space toggles the expanded state of the controlled region.

**Required ARIA**

* The trigger uses a `button` (or `role="button"`) with `aria-expanded="true"` or `aria-expanded="false"`.
* `aria-controls` on the button (optional but recommended) points at the `id` of the controlled region.
* The region is fully removed from the accessibility tree when collapsed.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/disclosure/>

### pattern-carousel-auto-rotating

**Carousel (Auto-Rotating)** is a carousel that advances through its slides automatically on a timer. APG requires an obvious way for users to pause and resume rotation so that the auto-advance does not interfere with reading or interacting with slide content. The pattern emphasises pause-on-hover and pause-on-focus behaviour in addition to the explicit pause button.

**Required keyboard**

* Tab moves focus to the carousel controls (pause button, previous, next, and slide picker).
* Space or Enter on the pause button toggles auto-rotation; while paused, the carousel does not advance.
* Left and Right arrows on the previous and next buttons advance to the previous or next slide.
* Focus entering any descendant of the carousel pauses auto-rotation; focus leaving the carousel resumes it (when previously rotating).

**Required ARIA**

* The container uses `role="region"` (or `role="group"`) with `aria-roledescription="carousel"` and an `aria-label` or `aria-labelledby` naming the carousel.
* Each slide container uses `aria-roledescription="slide"` and an `aria-label` or `aria-labelledby` identifying the slide.
* The live region wrapping the slide track uses `aria-live="off"` while auto-rotating and `aria-live="polite"` while paused, so that announcement does not collide with the auto-advance.
* The pause button uses `aria-label` describing the current action ("Stop slide rotation" or "Start slide rotation").
* `aria-controls` on the previous, next, and slide-picker controls points at the slide track.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/carousel/examples/carousel-1-prev-next/>

### pattern-carousel-tabbed

**Carousel (Tabbed)** is a carousel whose slide picker takes the form of a tablist: each tab represents one slide, and activating a tab displays its slide as the carousel's current panel. The pattern reuses the Tabs keyboard contract for slide navigation; the previous and next buttons are optional.

**Required keyboard**

* Tab moves focus into the tablist (and from there into the rotation controls, when present).
* Left and Right arrows move focus between tabs in the tablist; activation may be manual or automatic per `pattern-tabs-manual-activation` and `pattern-tabs-automatic-activation`.
* Enter or Space activates the focused tab and displays the matching slide (when activation is manual).
* Home and End move focus to the first or last tab.

**Required ARIA**

* The container uses `role="region"` (or `role="group"`) with `aria-roledescription="carousel"` and an accessible name.
* The slide picker uses `role="tablist"`, with each picker control using `role="tab"` and `aria-controls` pointing at its slide.
* Each slide uses `role="tabpanel"` with `aria-labelledby` pointing at its owning tab.
* The active tab uses `aria-selected="true"`; other tabs use `aria-selected="false"`.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/carousel/examples/carousel-2-tablist/>

### pattern-disclosure-navigation

**Disclosure Navigation** is a navigation menu whose submenus open via the disclosure pattern rather than the menu pattern. Top-level items are buttons that expand vertical lists of links; the keyboard contract differs from `pattern-menubar-navigation` because submenus do not use roving tabindex and arrow keys do not move focus between top-level items.

**Required keyboard**

* Tab moves focus through each top-level disclosure button and (when open) through the links in the open submenu.
* Enter or Space on a top-level button toggles the expansion of its submenu.
* Escape (optional) closes the open submenu and returns focus to its trigger button.
* Tab away from the last visible link closes any open submenu.

**Required ARIA**

* The outer container uses a `nav` element (or `role="navigation"`) with an accessible name.
* Each top-level item uses a `button` (or `role="button"`) with `aria-expanded` and `aria-controls` pointing at its submenu container.
* Submenu items are native `<a>` links inside a `<ul>` or equivalent list container.
* Closed submenus are hidden via `hidden` or `display: none` so that they are removed from the accessibility tree.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/disclosure/examples/disclosure-navigation/>

### pattern-disclosure-navigation-hybrid

**Disclosure Navigation Hybrid** is the disclosure-navigation pattern in which the top-level item is itself a link to a destination, and a separate disclosure button sits next to it to expand the submenu. The hybrid pattern suits sites where the top-level navigation item must be directly clickable as a landing page, but the user must also be able to expand the submenu without leaving the current page.

**Required keyboard**

* Tab moves focus to the top-level link, then to its adjacent disclosure button, then to the submenu links when the submenu is open, then on to the next top-level link.
* Enter or Space on the top-level link follows the link (standard `<a>` behaviour).
* Enter or Space on the disclosure button toggles the submenu.
* Arrow keys (optional) on the disclosure button or in the submenu may move focus between submenu items.
* Escape (optional) closes the open submenu and returns focus to the disclosure button.

**Required ARIA**

* The outer container uses `nav` (or `role="navigation"`) with an accessible name.
* The top-level link is a native `<a>` element.
* The adjacent disclosure button uses `aria-expanded` and `aria-controls` pointing at its submenu container, plus an `aria-label` (such as "Show submenu for Products") because the visible label is typically an icon.
* `aria-haspopup="true"` (optional) on the disclosure button signals that activation reveals a popup region.
* Submenu items are native `<a>` links inside a list container.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/disclosure/examples/disclosure-navigation-hybrid/>

## ARIA APG family — Grid

The Grid family covers two-dimensional navigation widgets and their numeric input siblings. APG distinguishes three grid variants by their content and selection model (layout, data with single-cell selection, data with multi-cell selection) and includes the spinbutton and slider patterns here because they share the grid family's cell-navigation primitives (focused cell with arrow-key movement and Page Up or Page Down for large steps).

Source: W3C WAI-ARIA Authoring Practices Guide, Grid, Spinbutton, and Slider patterns, <https://www.w3.org/WAI/ARIA/apg/patterns/grid/>.

### pattern-grid-layout

**Grid (Layout)** is the variant where the grid is used to lay out a collection of widgets in a two-dimensional structure (for example, a toolbar matrix or a collection of buttons). The cells contain interactive widgets rather than tabular data; selection is typically a single focused cell rather than a selected range.

**Required keyboard**

* Tab moves focus into and out of the grid; the grid itself is one tab stop.
* Within the grid: Left and Right arrows move focus between cells in a row; Down and Up arrows move focus between rows.
* Home moves focus to the first cell in the current row; End moves focus to the last cell in the current row.
* Ctrl+Home moves focus to the first cell in the grid; Ctrl+End moves focus to the last cell.
* Enter or Space (optional) activates the widget inside the focused cell.

**Required ARIA**

* The container uses `role="grid"`.
* Rows use `role="row"`; cells use `role="gridcell"`.
* `aria-selected` reflects per-cell selection state when selection is supported.
* Only the focused cell carries `tabindex="0"`; other cells use `tabindex="-1"`.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/grid/examples/layout-grids/>

### pattern-grid-data-single-cell

**Grid (Data, Single-Cell Selection)** is the variant where the grid presents tabular data and the user can select exactly one cell at a time. Headers, sortable columns, and read-only behaviour are common features of the data-grid variants.

**Required keyboard**

* Tab moves focus into and out of the grid.
* Left and Right arrows move focus between cells in a row; Down and Up arrows move focus between rows.
* Home and End move focus to the first or last cell in the current row.
* Ctrl+Home and Ctrl+End move focus to the first or last cell in the grid.
* Enter or Space selects the focused cell (or invokes the cell's edit mode in editable grids).
* F2 (optional) enters edit mode on an editable cell.

**Required ARIA**

* The container uses `role="grid"` with `aria-rowcount` and `aria-colcount` when the data set is virtualised.
* Rows use `role="row"` with `aria-rowindex` when virtualised.
* Cells use `role="gridcell"` with `aria-colindex` when virtualised; header cells use `role="columnheader"` or `role="rowheader"`.
* `aria-selected="true"` on the currently selected cell.
* `aria-readonly="true"` on the grid (or on individual cells) when content cannot be edited.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/grid/examples/data-grids/>

### pattern-grid-data-multi-cell

**Grid (Data, Multi-Cell Selection)** is the variant where the user can select a range of cells, an entire row, or an entire column. The keyboard contract extends `pattern-grid-data-single-cell` with modifier-augmented arrow keys for range selection and an explicit "select all" gesture.

**Required keyboard**

* Arrow keys, Home, End, Ctrl+Home, and Ctrl+End behave as in `pattern-grid-data-single-cell` to move focus.
* Shift+arrow keys extend the current selection by one cell in the arrow's direction.
* Shift+Home and Shift+End extend selection to the start or end of the current row.
* Ctrl+Space selects (or deselects) the entire current column; Shift+Space selects (or deselects) the entire current row.
* Ctrl+A selects all cells in the grid.
* Enter or Space on the focused cell toggles selection of that cell.

**Required ARIA**

* The container uses `role="grid"` with `aria-multiselectable="true"`.
* Rows use `role="row"`; cells use `role="gridcell"`, with `aria-selected="true"` or `aria-selected="false"` on every cell in the selection-capable region.
* Header cells use `role="columnheader"` or `role="rowheader"` as appropriate.
* `aria-rowcount`, `aria-colcount`, `aria-rowindex`, and `aria-colindex` describe virtualised grids.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/grid/examples/data-grids/>

### pattern-spinbutton

**Spinbutton** is a numeric input augmented with increment and decrement controls. Users may type a value directly into the input or step through the value range with arrow-key, page-key, and Home or End shortcuts. The spinbutton is the recommended role for numeric inputs whose value range is bounded and known.

**Required keyboard**

* Up arrow increments the value by one step; Down arrow decrements by one step.
* Page Up increments by a larger step (typically ten times the base step); Page Down decrements by the same larger step.
* Home sets the value to `aria-valuemin`; End sets the value to `aria-valuemax`.
* Typing inside the input edits the value directly (per native text-input behaviour).

**Required ARIA**

* The input uses `role="spinbutton"` (or the native `<input type="number">` element, which exposes the role implicitly).
* `aria-valuenow` reflects the current value.
* `aria-valuemin` and `aria-valuemax` bound the value range.
* `aria-valuetext` provides a human-readable representation when the numeric value alone is insufficient (for example, "10 minutes" rather than "10").
* `aria-disabled="true"` indicates that the spinbutton cannot accept input.
* `aria-required="true"` indicates that the spinbutton must hold a value before form submission.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/spinbutton/>

### pattern-slider-single-thumb

**Slider (Single-Thumb)** is a value-picker widget with a single thumb that slides along a track between minimum and maximum bounds. The pattern suits any continuous-range numeric input where a visual track conveys the value better than a typed number (volume, brightness, threshold).

**Required keyboard**

* Right or Up arrow increments the value by one step; Left or Down arrow decrements by one step.
* Page Up increments by a larger step (typically one tenth of the range); Page Down decrements by the same larger step.
* Home sets the value to `aria-valuemin`; End sets the value to `aria-valuemax`.

**Required ARIA**

* The thumb uses `role="slider"` with `tabindex="0"`.
* `aria-valuenow` reflects the current value.
* `aria-valuemin` and `aria-valuemax` bound the value range.
* `aria-valuetext` provides a human-readable representation when needed.
* `aria-orientation="horizontal"` (the default) or `aria-orientation="vertical"` describes the slider axis.
* `aria-label` or `aria-labelledby` supplies the accessible name.
* `aria-disabled="true"` indicates that the slider cannot be adjusted.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/slider/>

### pattern-slider-two-thumb

**Slider (Two-Thumb)** is a range-picker widget with two thumbs on the same track. Each thumb represents one end of a value range (for example, a price filter with minimum and maximum). The two thumbs operate independently but cannot cross each other.

**Required keyboard**

* Tab moves focus to the lower thumb, then to the upper thumb, then out of the slider.
* On the focused thumb: Right or Up arrow increments by one step; Left or Down arrow decrements by one step.
* Page Up and Page Down change the value by a larger step.
* Home sets the focused thumb to its minimum bound (the slider's `aria-valuemin` for the lower thumb, or the current lower-thumb value for the upper thumb); End sets it to its maximum bound (the current upper-thumb value for the lower thumb, or the slider's `aria-valuemax` for the upper thumb).

**Required ARIA**

* Each thumb uses `role="slider"` with its own `aria-valuenow`, `aria-valuemin`, `aria-valuemax`, and `aria-valuetext`.
* Each thumb has an `aria-label` distinguishing it (for example, "Minimum price" and "Maximum price").
* `aria-orientation` describes the slider axis.
* The lower thumb's `aria-valuemax` updates to the upper thumb's current value (and vice versa) so that the bounds prevent the thumbs from crossing.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/slider-multithumb/>

## ARIA APG family — Menu

The Menu family covers application menus, menu buttons, menubars, and menubars that support multi-selection of menu items. Menu widgets behave like desktop application menus rather than navigation menus: users move focus with arrow keys, open submenus along the perpendicular axis, and dismiss menus with Escape. Navigation menus that look like menubars but use links instead of menuitems are documented as `pattern-menubar-navigation` to make the distinction explicit.

Source: W3C WAI-ARIA Authoring Practices Guide, Menu and Menubar patterns, <https://www.w3.org/WAI/ARIA/apg/patterns/menu-button/> and <https://www.w3.org/WAI/ARIA/apg/patterns/menubar/>.

### pattern-menu-button

**Menu Button** is a button that opens a popup menu of actions, options, or commands. The button acts as the menu's trigger and its accessible reference; the menu itself follows the standard `role="menu"` keyboard contract once it opens.

**Required keyboard**

* When focus is on the button: Enter, Space, or Down arrow opens the menu and moves focus to the first menu item; Up arrow opens the menu and moves focus to the last menu item.
* When focus is in the menu: Down and Up arrows move focus between menu items (wrapping at the ends); Home and End jump to the first and last items.
* Escape closes the menu and returns focus to the button.
* Tab closes the menu and moves focus to the next focusable element after the button.
* Enter or Space on a focused menu item activates the item and closes the menu.
* Printable characters jump focus to the next menu item whose visible label starts with the typed character.

**Required ARIA**

* The button uses `aria-haspopup="menu"` and `aria-expanded="true"` or `aria-expanded="false"`; when the menu is open, `aria-controls` on the button points at the menu's `id`.
* The popup uses `role="menu"`, with each item using `role="menuitem"` (or `role="menuitemcheckbox"` or `role="menuitemradio"` when stateful).
* Submenu triggers use `aria-haspopup="menu"` and `aria-expanded`.
* The first menu item receives focus when the menu opens; subsequent navigation uses managed focus.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/menu-button/>

### pattern-menubar-editor

**Menubar (Editor)** is the editor-style menubar found in desktop applications such as word processors. Top-level menu items live in a horizontal menubar, and each top-level item opens a vertical dropdown menu that may contain submenus. The pattern emphasises rapid keyboard navigation between menus.

**Required keyboard**

* Tab moves focus into and out of the menubar; the menubar itself is one tab stop.
* Within the menubar: Left and Right arrows move focus between top-level items (wrapping at the ends); Down arrow or Enter opens the focused menu and moves focus to its first item; Up arrow opens the menu and moves focus to its last item.
* Within an open menu: Down and Up arrows move focus between items; Right arrow opens a submenu or moves to the next top-level menu; Left arrow closes the current submenu (or moves to the previous top-level menu when at the root).
* Enter or Space activates the focused menuitem and closes the menu chain.
* Escape closes the current menu and returns focus to its trigger (or to the menubar item for top-level menus).
* Printable characters jump focus to the next item whose label starts with the typed character.

**Required ARIA**

* The container uses `role="menubar"` with `aria-orientation="horizontal"`.
* Top-level items use `role="menuitem"` with `aria-haspopup="menu"` and `aria-expanded`.
* Submenus use `role="menu"` with `aria-orientation="vertical"`.
* Submenu items use `role="menuitem"`, `role="menuitemcheckbox"`, or `role="menuitemradio"` as appropriate.
* Only one element in the menubar carries `tabindex="0"` at any time; the rest use `tabindex="-1"`.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/menubar/examples/menubar-editor/>

### pattern-menubar-navigation

**Menubar (Navigation)** is the navigation-style variant of a menubar, used as a site-wide or section-level navigation bar. The visible behaviour resembles `pattern-menubar-editor`, but the leaf items are links that navigate to URLs rather than menuitems that fire JavaScript actions. APG keeps the pattern separate because the activation contract differs: leaf items are activated by following a link rather than by invoking an application command.

**Required keyboard**

* Tab moves focus into and out of the navigation menubar.
* Left and Right arrows move focus between top-level items; Down arrow opens the submenu under the focused top-level item.
* Within an open submenu: Down and Up arrows move focus between submenu items (which are typically links); Right arrow opens a nested submenu; Left arrow closes the current submenu and returns focus to its trigger.
* Enter or Space on a leaf link follows the link (the same as activating an `<a>` element directly).
* Escape closes the current submenu.

**Required ARIA**

* The container uses `role="menubar"` with `aria-orientation="horizontal"` and an accessible name (`aria-label` such as "Main").
* Top-level items that open a submenu use `role="menuitem"` with `aria-haspopup="menu"` and `aria-expanded`.
* Leaf items use native `<a>` elements; the surrounding `role="menu"` and `role="none"` wrappers expose the structure to assistive technology without breaking link semantics.
* Submenus use `role="menu"` with `aria-orientation="vertical"`.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/menubar/examples/menubar-navigation/>

### pattern-actions-menu-button

**Actions Menu Button** is a specialised menu button whose menu items represent contextual actions on a target object (for example, the row-level actions menu in a data grid or the per-item kebab menu in a list view). The keyboard contract is identical to `pattern-menu-button`; APG documents the pattern separately to highlight authoring guidance about labelling, contextual scope, and menu placement.

**Required keyboard**

* Enter, Space, or Down arrow on the button opens the menu and moves focus to the first action.
* Up arrow on the button opens the menu and moves focus to the last action.
* Within the menu: Down and Up arrows move focus between actions; Home and End jump to the first or last action.
* Escape closes the menu and returns focus to the button.
* Tab closes the menu and moves focus to the next focusable element.
* Enter or Space activates the focused action and closes the menu.
* Printable characters jump focus to the next action whose label starts with the typed character.

**Required ARIA**

* The button uses `aria-haspopup="menu"`, `aria-expanded`, and `aria-controls`. The button label identifies both the context and the kind of menu (for example, "Actions for Smith order #4421").
* The popup uses `role="menu"` with `aria-label` describing the target of the actions.
* Each action uses `role="menuitem"`, or `role="menuitemcheckbox"` or `role="menuitemradio"` when the action toggles state.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/menu-button/examples/menu-button-actions-active-descendant/>

### pattern-menubar-multi-select

**Menubar with Multiple Selection** is a menubar variant where items support multi-selection through `role="menuitemcheckbox"` or `role="menuitemradio"`. Users toggle selection state on each item without dismissing the menu, which suits filter menus, column-picker menus, and tag-assignment menus.

**Required keyboard**

* Tab moves focus into and out of the menubar.
* Left and Right arrows move focus between top-level menus; Down arrow opens a menu and moves focus to its first item.
* Within an open menu: Down and Up arrows move focus between items; Home and End jump to the first or last item.
* Space toggles the selection state of the focused `menuitemcheckbox` or `menuitemradio` without closing the menu.
* Enter activates the focused item; on a checkbox or radio item the behaviour is the same as Space but typically also closes the menu in the default APG implementation.
* Shift+arrow keys (optional) extend selection across a contiguous range of items.
* Ctrl+A (optional) selects all items in the current menu when multi-selection is permitted.
* Escape closes the menu and returns focus to its menubar trigger.

**Required ARIA**

* The container uses `role="menubar"` with `aria-orientation="horizontal"`.
* Submenus use `role="menu"` with `aria-orientation="vertical"`.
* Multi-select items use `role="menuitemcheckbox"` with `aria-checked="true"` or `aria-checked="false"`.
* Single-select-within-group items use `role="menuitemradio"` with `aria-checked` and a `role="group"` wrapper that scopes the radio set.
* `aria-multiselectable="true"` may appear on the parent menu when grouped multi-selection is supported across items.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/menubar/examples/menubar-editor/>

## ARIA APG family — Tabs

The Tabs family covers tabbed-content interfaces, where a row of tabs controls which of several tab panels is visible. APG separates the family into two activation modes (manual and automatic) because the keyboard contract differs even though the markup is identical. The third historical APG entry, Tabbed Carousel, lives in `family-disclosure.md` alongside the other carousel variants because the source rollup groups all three carousel patterns there.

Source: W3C WAI-ARIA Authoring Practices Guide, Tabs family, <https://www.w3.org/WAI/ARIA/apg/patterns/tabs/>.

### pattern-tabs-manual-activation

**Tabs (Manual Activation)** is the variant where moving keyboard focus along the tablist does not change which panel is visible. The user moves focus with the arrow keys and then presses Enter or Space to activate the focused tab and reveal its panel. This is the recommended activation mode when revealing a panel is expensive (large data fetch, layout reflow, or destructive side effects).

**Required keyboard**

* Tab moves focus to the active tab when entering the tablist, and out of the tablist on the next Tab press.
* Left and Right arrows (for horizontal tablists) or Up and Down arrows (for vertical tablists) move focus between tabs without activating them.
* Home moves focus to the first tab; End moves focus to the last tab.
* Enter or Space activates the focused tab, showing its associated panel.
* Delete (optional) removes a closable tab.

**Required ARIA**

* `role="tablist"` on the container, with `aria-orientation="horizontal"` or `aria-orientation="vertical"` as appropriate.
* `role="tab"` on each tab, with `aria-selected="true"` on the active tab and `aria-selected="false"` on the rest.
* `aria-controls` on each tab pointing at its panel's `id`.
* `role="tabpanel"` on each panel, with `aria-labelledby` pointing at its owning tab's `id`.
* Only the active tab is in the page tab sequence (`tabindex="0"`); inactive tabs are removed with `tabindex="-1"`.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/tabs/examples/tabs-manual/>

### pattern-tabs-automatic-activation

**Tabs (Automatic Activation)** is the variant where moving keyboard focus along the tablist immediately changes which panel is visible. Pressing Left or Right (or Up or Down for a vertical tablist) both moves focus and activates the newly focused tab. This is the recommended activation mode when revealing a panel is cheap and the user benefits from a fast scan across panels.

**Required keyboard**

* Tab moves focus to the active tab when entering the tablist, and out of the tablist on the next Tab press.
* Left and Right arrows (horizontal) or Up and Down arrows (vertical) move focus and activate the newly focused tab in a single step.
* Home moves focus to and activates the first tab; End moves focus to and activates the last tab.
* Delete (optional) removes a closable tab.

**Required ARIA**

* `role="tablist"` on the container, with `aria-orientation` set appropriately.
* `role="tab"` on each tab, with `aria-selected="true"` on the currently focused and active tab.
* `aria-controls` on each tab pointing at its panel's `id`.
* `role="tabpanel"` on each panel, with `aria-labelledby` pointing at its owning tab's `id`.
* Only the active tab is in the page tab sequence (`tabindex="0"`); inactive tabs use `tabindex="-1"`.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/tabs/examples/tabs-automatic/>

## ARIA APG family — Treegrid

The Treegrid family covers hierarchical navigation widgets: simple disclosure trees, treegrids that overlay a hierarchy on a tabular layout, and the link pattern that often participates in tree navigation. APG groups the link pattern here because navigation trees commonly delegate row activation to nested links and because the link contract is small enough that it does not warrant a family of its own.

Source: W3C WAI-ARIA Authoring Practices Guide, Treegrid and related patterns, <https://www.w3.org/WAI/ARIA/apg/patterns/treegrid/> and <https://www.w3.org/WAI/ARIA/apg/patterns/treeview/>.

### pattern-tree-view

**Tree View** presents a hierarchical list of items where each item can have a parent and any number of children. Users navigate the tree with the arrow keys, expand and collapse parent nodes with the Right and Left arrows, and select an item with Enter or Space depending on the tree's selection model.

**Required keyboard**

* Up and Down arrows move focus to the previous and next visible node in document order, descending into children of expanded nodes.
* Right arrow on a collapsed parent expands it; on an expanded parent it moves focus to the first child; on a leaf it does nothing.
* Left arrow on an expanded parent collapses it; on a collapsed or leaf node it moves focus to the parent.
* Home moves focus to the first node; End moves focus to the last visible node.
* Asterisk (optional) expands all sibling nodes at the same level as the focused node.
* Printable characters jump focus to the next node whose visible label starts with the typed string.

**Required ARIA**

* `role="tree"` on the outer container.
* `role="treeitem"` on each node.
* `aria-expanded="true"` or `aria-expanded="false"` on parent nodes; the attribute is omitted on leaf nodes.
* `aria-level` indicates depth (1 for the root level, 2 for the first level of children, and so on).
* `aria-posinset` and `aria-setsize` indicate position within the parent's child list.
* `aria-selected` indicates selection state when the tree supports selection.
* Only one node has `tabindex="0"` (the focused or last-focused node); all other nodes use `tabindex="-1"`.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/treeview/>

### pattern-treegrid-email-client

**Treegrid (Email Client)** is APG's reference implementation of the treegrid pattern, modelled on an email-thread reader. The widget combines tabular row and cell navigation with the hierarchical expand and collapse behaviour of a tree, so users can drill into nested message threads while still inspecting per-column data such as sender, subject, and date.

**Required keyboard**

* Right arrow on a collapsed row expands it; on an expanded row it moves focus to the first cell or to the first child row depending on the column.
* Left arrow on an expanded row collapses it; on a collapsed row or a non-parent row it moves focus to the parent row.
* Down and Up arrows move focus between rows (or cells, when focus is in a cell).
* Home and End move focus to the first or last cell in the current row; Ctrl+Home and Ctrl+End move focus to the first or last cell in the grid.
* Space toggles selection on the focused row when the treegrid supports row selection.

**Required ARIA**

* `role="treegrid"` on the outer container.
* `role="row"` on each row, with `aria-level`, `aria-posinset`, and `aria-setsize` reflecting hierarchical position.
* `aria-expanded="true"` or `aria-expanded="false"` on parent rows.
* `role="gridcell"` or `role="columnheader"` on cells; `role="rowheader"` on the row's primary cell when applicable.
* `aria-selected` reflects per-row selection state.
* `aria-controls` on the row may point at the panel that displays the row's expanded content when applicable.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/treegrid/examples/treegrid-1/>

### pattern-link

**Link** is the navigational primitive. APG advises authors to use the native HTML `<a href="...">` element whenever possible because it brings the keyboard contract, the focusable behaviour, and the screen-reader semantics for free. The `role="link"` attribute exists only for cases where the native element cannot be used (for instance, when scripting must intercept activation).

**Required keyboard**

* Tab moves focus to and away from the link.
* Enter activates the link (follows the destination).
* Space activates the link only when the element uses `role="link"`; the native `<a>` element does not respond to Space and that behaviour is intentional.

**Required ARIA**

* Prefer the native `<a href="...">` element. Use `role="link"` only when the host element is not an anchor.
* `aria-current="page"` (or `"step"`, `"location"`, `"date"`, `"time"`, or `"true"`) indicates the current item within a navigation set.
* `aria-disabled="true"` indicates a link whose action is currently unavailable; the link must remain focusable so that users can discover the disabled state.
* `aria-label` supplies an accessible name when the visible link text is insufficient (icon-only or short labels).
* `aria-expanded` is set on a link that controls disclosure of a related region, although that combination usually indicates the element should be a button instead.

**Source:** <https://www.w3.org/WAI/ARIA/apg/patterns/link/>

