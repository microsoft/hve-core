---
title: Diagram Type Reference
description: Detailed guidance for each diagram type including rendering approach, layout patterns, and content-specific conventions
---

## Architecture / System Diagrams

Two approaches depending on what matters more:

Text-heavy overviews (card content matters more than connections): CSS Grid with explicit row/column placement. Sections as rounded cards with colored borders and monospace labels. Vertical flow arrows between sections. Nested grids for subsystems. The reference template at `../templates/architecture.html` demonstrates this pattern. Use when cards need descriptions, code references, tool lists, or other rich content that Mermaid nodes can't hold.

Topology-focused diagrams (connections matter more than card content): use Mermaid. A `graph TD` (or `graph LR` for simple linear flows) with custom `themeVariables` produces proper diagrams with automatic edge routing. Use when the point is showing how components connect rather than describing what each component does in detail.

## Flowcharts / Pipelines

Use Mermaid. Automatic node positioning and edge routing produces proper diagrams with connecting lines, decision diamonds, and parallel branches, dramatically better than CSS flexbox with arrow characters. Prefer `graph TD` (top-down); use `graph LR` only for simple 3-4 node linear flows. Color-code node types with Mermaid's `classDef` or rely on `themeVariables` for automatic styling.

## Sequence Diagrams

Use Mermaid. Lifelines, messages, activation boxes, notes, and loops all need automatic layout. Use Mermaid's `sequenceDiagram` syntax. Style actors and messages via CSS overrides on `.actor`, `.messageText`, `.activation` classes.

## Data Flow Diagrams

Use Mermaid. Data flow diagrams emphasize connections over boxes, exactly what Mermaid excels at. Use `graph TD` (or `graph LR` for simple linear flows) with edge labels for data descriptions. Thicker, colored edges for primary flows. Source/sink nodes styled differently from transform nodes via Mermaid's `classDef`.

## Schema / ER Diagrams

Use Mermaid. Relationship lines between entities need automatic routing. Use Mermaid's `erDiagram` syntax with entity attributes. Style via `themeVariables` and CSS overrides on `.er.entityBox` and `.er.relationshipLine`.

## State Machines / Decision Trees

Use Mermaid. Use `stateDiagram-v2` for states with labeled transitions. Supports nested states, forks, joins, and notes. Decision trees can use `graph TD` with diamond decision nodes.

The `stateDiagram-v2` label caveat: transition labels have a strict parser. Colons, parentheses, `<br/>`, HTML entities, and most special characters cause silent parse failures ("Syntax error in text").
If your labels need any of these (e.g., `cancel()`, `curate: true`, multi-line labels), use `flowchart TD` instead with rounded nodes and quoted edge labels (`|"label text"|`). Flowcharts handle all special characters and support `<br/>` for line breaks. Reserve `stateDiagram-v2` for simple single-word or plain-text labels.

## Mind Maps / Hierarchical Breakdowns

Use Mermaid. Use `mindmap` syntax for hierarchical branching from a root node. Mermaid handles the radial layout automatically. Style with `themeVariables` to control node colors at each depth level.

## Data Tables / Comparisons / Audits

Use a real `<table>` element, not CSS Grid pretending to be a table. Tables get accessibility, copy-paste behavior, and column alignment for free. The reference template at `../templates/data-table.html` demonstrates all patterns below.

Use proactively. Any time you'd render an ASCII box-drawing table in the terminal, generate an HTML table instead. This includes: requirement audits (request vs plan), feature comparisons, status reports, configuration matrices, test result summaries, dependency lists, permission tables, API endpoint inventories, any structured rows and columns.

Layout patterns:

* Sticky `<thead>` so headers stay visible when scrolling long tables
* Alternating row backgrounds via `tr:nth-child(even)` (subtle, 2-3% lightness shift)
* First column optionally sticky for wide tables with horizontal scroll
* Responsive wrapper with `overflow-x: auto` for tables wider than the viewport
* Column width hints via `<colgroup>` or `th` widths; let text-heavy columns breathe
* Row hover highlight for scanability

Status indicators (use styled `<span>` elements, never emoji):

* Match/pass/yes: colored dot or checkmark with green background
* Gap/fail/no: colored dot or cross with red background
* Partial/warning: amber indicator
* Neutral/info: dim text or muted badge

Cell content:

* Wrap long text naturally; don't truncate or force single-line
* Use `<code>` for technical references within cells
* Secondary detail text in `<small>` with dimmed color
* Keep numeric columns right-aligned with `tabular-nums`

## Timeline / Roadmap Views

Vertical or horizontal timeline with a central line (CSS pseudo-element). Phase markers as circles on the line. Content cards branching left/right (alternating) or all to one side. Date labels on the line. Color progression from past (muted) to future (vivid).

## Dashboard / Metrics Overview

Card grid layout. Hero numbers large and prominent. Sparklines via inline SVG `<polyline>`. Progress bars via CSS `linear-gradient` on a div. For real charts (bar, line, pie), use Chart.js via CDN (see `../libraries.md`). KPI cards with trend indicators (up/down arrows, percentage deltas).

## Implementation Plans

For visualizing implementation plans, extension designs, or feature specifications. The goal is understanding the approach, not reading the full source code.

Don't dump full files. Displaying entire source files inline overwhelms the page and defeats the purpose of a visual explanation. Instead:

* Show file structure with descriptions: list functions/exports with one-line explanations
* Show key snippets only: the 5-10 lines that illustrate the core logic
* Use collapsible sections for full code if truly needed

Code blocks require explicit formatting. Without `white-space: pre-wrap`, code runs together into an unreadable wall. See the "Code Blocks" section in `css-patterns.md` for the correct pattern.

Structure for implementation plans:

1. Overview/purpose (what problem does this solve?)
2. Flow diagram (Mermaid or CSS cards)
3. File structure with descriptions (not full code)
4. Key implementation details (snippets)
5. API/interface summary
6. Usage examples

## Documentation (READMEs, Library Docs, API References)

When visualizing documentation, extract structure into visual elements:

| Content | Visual Treatment |
|---------|------------------|
| Features | Card grid (2-3 columns) |
| Install/setup steps | Numbered cards or vertical flow |
| API endpoints/commands | Table with sticky header |
| Config options | Table |
| Architecture | Mermaid diagram or CSS card layout |
| Comparisons | Side-by-side panels or table |
| Warnings/notes | Callout boxes |

Don't just format the prose; transform it. A feature list becomes a card grid. Install steps become a numbered flow. An API reference becomes a table.

## Prose Accent Elements

Use these sparingly within visual pages to highlight key points or provide breathing room. See "Prose Page Elements" in `css-patterns.md` for CSS patterns.

* Lead paragraph: larger intro text to set context before diving into cards/grids
* Pull quote: highlight a key insight; one per page maximum
* Callout box: warnings, tips, important notes
* Section divider: visual break between major sections

A visual page explaining an essay might use a lead paragraph for the thesis, then cards for key arguments. A README visualization might use callout boxes for warnings but otherwise stay card/table-focused.
