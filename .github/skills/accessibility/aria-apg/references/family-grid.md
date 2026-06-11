---
title: "ARIA APG family — Grid"
description: "The Grid family covers two-dimensional navigation widgets and their numeric input siblings."
---

# ARIA APG family — Grid

The Grid family covers two-dimensional navigation widgets and their numeric input siblings. APG distinguishes three grid variants by their content and selection model (layout, data with single-cell selection, data with multi-cell selection) and includes the spinbutton and slider patterns here because they share the grid family's cell-navigation primitives (focused cell with arrow-key movement and Page Up or Page Down for large steps).

Source: W3C WAI-ARIA Authoring Practices Guide, Grid, Spinbutton, and Slider patterns, <https://www.w3.org/WAI/ARIA/apg/patterns/grid/>.

## pattern-grid-layout

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

## pattern-grid-data-single-cell

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

## pattern-grid-data-multi-cell

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

## pattern-spinbutton

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

## pattern-slider-single-thumb

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

## pattern-slider-two-thumb

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

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
