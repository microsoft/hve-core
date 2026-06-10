---
title: "ARIA APG family — Treegrid"
description: "The Treegrid family covers hierarchical navigation widgets: simple disclosure trees, treegrids that overlay a hierarchy on a tabular layout, and the link pattern that often participates in tree nav..."
---

# ARIA APG family — Treegrid

The Treegrid family covers hierarchical navigation widgets: simple disclosure trees, treegrids that overlay a hierarchy on a tabular layout, and the link pattern that often participates in tree navigation. APG groups the link pattern here because navigation trees commonly delegate row activation to nested links and because the link contract is small enough that it does not warrant a family of its own.

Source: W3C WAI-ARIA Authoring Practices Guide, Treegrid and related patterns, <https://www.w3.org/WAI/ARIA/apg/patterns/treegrid/> and <https://www.w3.org/WAI/ARIA/apg/patterns/treeview/>.

## pattern-tree-view

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

## pattern-treegrid-email-client

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

## pattern-link

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

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
