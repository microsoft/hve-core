---
title: "ARIA APG family — Combobox"
description: "The Combobox family covers single-line input controls that combine a text field with a popup of candidate values."
---

# ARIA APG family — Combobox

The Combobox family covers single-line input controls that combine a text field with a popup of candidate values. APG distinguishes four combobox variants by their autocomplete behaviour (both, list, none, select-only) and a fifth variant whose popup is a grid rather than a listbox. The standalone `listbox` pattern lives in this family too because the combobox popup is almost always a listbox and authors reuse the same keyboard contract for both.

Source: W3C WAI-ARIA Authoring Practices Guide, Combobox and Listbox patterns, <https://www.w3.org/WAI/ARIA/apg/patterns/combobox/> and <https://www.w3.org/WAI/ARIA/apg/patterns/listbox/>.

## pattern-combobox-autocomplete-both

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

## pattern-combobox-list

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

## pattern-combobox-none

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

## pattern-combobox-select-only

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

## pattern-combobox-grid-popup

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

## pattern-listbox

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

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
