---
title: RPI Workflow Canvas Style Guide
description: Visual language, interaction grammar, and accessibility requirements for the hve-core RPI Workflow canvas
author: Microsoft
ms.date: 2026-10-23
ms.topic: reference
keywords:
  - canvas
  - rpi
  - style guide
  - design system
  - accessibility
---

## Purpose and Principles

The RPI Workflow canvas is where a person steers an agent through Research, Plan, Implement, Review, and Follow-up. It is an operate-mode surface: people read, decide, correct, and monitor. Its documents are read in read mode, so prose gets a comfortable measure while controls stay compact. It is a sibling of the Session Log canvas and shares its tokens, icon grammar, and accessibility bar; this guide extends that system rather than forking it.

* Lead with what needs the person. Every view answers "what can I do here, and what is waiting on me" before anything else.
* Keep a decision next to the reasoning it depends on. Decisions, evidence, agent notes, and comments sit in a margin beside the text they concern.
* Show both voices. What the person said and what the agent understood appear side by side, so a misunderstanding is visible and correctable in one step.
* Never hide what will reach the agent. Feedback shows its state from draft to applied, and any delivery previews the exact text first.
* Make every claim traceable. Stable IDs, evidence chips, and trace strips connect a question to the finding, decision, task, change, and review finding it became.
* Documents stay the source of truth. The canvas edits one section at a time, checks revisions, and tells the agent about every edit.
* Stay quiet. One accent for interaction and the agent's active phase, no continuous motion, and no decoration that competes with content.

## Color and Appearance

The palette is restrained: neutral surfaces, one accent for interaction, selection, and the agent's active phase, and a small set of role and status hues that always travel with an icon and a word. Hue never carries meaning alone.

### Appearance Model

* Theme: System (default), Light, or Dark. More contrast: off, which still follows the operating system's `prefers-contrast: more`, or on.
* The extension stores the choice in its private data folder. The server writes `data-theme` and `data-contrast` on `<html>` for every page load, so the first paint is already correct. Browser storage is never used for appearance, because every canvas open binds a new loopback port and therefore a new origin.
* System honors host theme variables (`--background-color-default`, `--text-color-default`, and the rest of the Session Log list) when a host injects them, then falls back to the canvas palette. Light, Dark, and More contrast use the canvas palette only, so an explicit choice always wins over the host.
* Palette pairs are written once with `light-dark()`; the theme sets `color-scheme` to `light dark`, `light`, or `dark`. Browsers without `light-dark()` receive the light palette.
* Under `forced-colors: active`, the page uses system colors (`Canvas`, `CanvasText`, `LinkText`, `Highlight`, `ButtonText`) and keeps every border and outline so shapes survive.

### Surface and Text Tokens

| Token                 | Role                                                  | Light     | Dark      | More contrast light | More contrast dark |
|-----------------------|-------------------------------------------------------|-----------|-----------|---------------------|--------------------|
| `--rw-bg`             | Document and page surface                             | `#ffffff` | `#0d1117` | `#ffffff`           | `#010409`          |
| `--rw-bg-subtle`      | Header, navigator, steering panel, bands              | `#f6f8fa` | `#151b23` | `#f6f8fa`           | `#0d1117`          |
| `--rw-bg-inset`       | Code, diff, and payload wells                         | `#f6f8fa` | `#010409` | `#eff2f5`           | `#000000`          |
| `--rw-bg-hover`       | Row and control hover                                 | `#eff2f5` | `#1b222c` | `#e6eaef`           | `#1b222c`          |
| `--rw-bg-selected`    | Selected row; text on it uses `--rw-fg`               | `#ddf4ff` | `#12263f` | `#ddf4ff`           | `#1b2d47`          |
| `--rw-fg`             | Primary text                                          | `#1f2328` | `#e6edf3` | `#0e1116`           | `#f0f6fc`          |
| `--rw-fg-muted`       | Metadata and secondary text                           | `#59636e` | `#9198a1` | `#31373d`           | `#c9d1d9`          |
| `--rw-border`         | Dividers and card edges (decorative)                  | `#d1d9e0` | `#30363d` | `#6e7781`           | `#8b949e`          |
| `--rw-border-muted`   | Inner separators, rails                               | `#e3e8ec` | `#21262d` | `#8c959f`           | `#6e7681`          |
| `--rw-border-control` | Input, checkbox, radio, and button outlines           | `#818b98` | `#6e7681` | `#6e7781`           | `#8b949e`          |
| `--rw-accent`         | Links, primary action, selection, focus, active phase | `#0969da` | `#4493f8` | `#0349b4`           | `#71b7ff`          |
| `--rw-accent-fg`      | Text on accent fills                                  | `#ffffff` | `#0d1117` | `#ffffff`           | `#010409`          |

Measured contrast: `--rw-fg` reaches 13.9:1 or more on every surface in every scheme; `--rw-fg-muted` reaches 5.2:1 or more; `--rw-border-control` reaches 3.2:1 or more against `--rw-bg` and `--rw-bg-subtle`, which satisfies non-text contrast for control boundaries. `--rw-border` and `--rw-border-muted` are decorative and never the only edge of a control.

### Role and Status Tokens

| Token            | Use                                                      | Light     | Dark      | More contrast light | More contrast dark |
|------------------|----------------------------------------------------------|-----------|-----------|---------------------|--------------------|
| `--rw-user`      | The person's voice: answers, comments, edits, overrides  | `#8250df` | `#ab7df8` | `#622cbc`           | `#c8a8ff`          |
| `--rw-agent`     | The agent's voice: interpretations and agent decisions   | `#1a7f37` | `#3fb950` | `#055d20`           | `#56d364`          |
| `--rw-success`   | Done, applied, passed                                    | `#1a7f37` | `#3fb950` | `#055d20`           | `#56d364`          |
| `--rw-attention` | Needs your input, paused, partially supported, corrected | `#9a6700` | `#d29922` | `#744500`           | `#e3b341`          |
| `--rw-severe`    | Medium severity, plan changes                            | `#bc4c00` | `#ffa657` | `#873800`           | `#ffa657`          |
| `--rw-danger`    | Failed, blocked, High and Critical severity, weakened    | `#d1242f` | `#f85149` | `#a0111f`           | `#ff7b72`          |

Each hue reaches at least 4.5:1 against `--rw-bg` and `--rw-bg-subtle` in its scheme (4.57:1 is the lowest, light attention on subtle), so it may color small text there. On `--rw-bg-selected`, light-scheme hues fall to 4.3:1 to 4.6:1, so selected rows set text in `--rw-fg` and use hues only for icons. Chips and badges place `--rw-fg` text on a 14 percent tint of their hue, which measures 12.9:1 or more.

### Status Vocabularies

Every status pairs an icon and a word with its hue. These are the only vocabularies; views do not invent new states.

| Vocabulary         | States (icon, hue)                                                                                                                                                                                                                        |
|--------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Phase status       | Done (check, success); Active (filled dot, accent); Upcoming (hollow circle, muted); Paused for you (pause, attention); Blocked (alert, danger); Skipped (dashed circle, muted)                                                           |
| Feedback lifecycle | Needs your input (hand, attention); Draft (pencil, muted); Queued (inbox, accent); Sending (send, accent); Sent (send, accent); Interpreted (sparkle, agent); Applied (check, success); Corrected (undo, attention); Dismissed (x, muted) |
| Evidence state     | Evidence-backed (shield check, success); Partially supported (half circle, attention); Hypothesis (light bulb, muted); Weakened (trend down, danger); Unresolved (question, muted)                                                        |
| Severity           | Critical (filled alert, danger); High (alert, danger); Medium (alert, severe); Low (info, muted)                                                                                                                                          |
| Validation         | Passed (check, success); Failed (x circle, danger); Skipped (dash, muted); Unavailable (slashed circle, muted)                                                                                                                            |
| Voice              | You (person, user); Agent (sparkle, agent)                                                                                                                                                                                                |

## Typography

One family carries the interface; monospace is reserved for IDs, paths, code, and measurements.

* UI and prose: `-apple-system, BlinkMacSystemFont, "Segoe UI Variable Text", "Segoe UI", system-ui, Ubuntu, "Helvetica Neue", Arial, sans-serif`.
* Code, IDs, and paths: `ui-monospace, "SF Mono", "Cascadia Code", "Cascadia Mono", Menlo, Consolas, "Liberation Mono", monospace`.
* No web fonts and no remote resources; the CSP blocks fonts outright.

| Step           | Size and line height | Weight | Use                                          |
|----------------|----------------------|--------|----------------------------------------------|
| `--rw-t-title` | 20px / 28px          | 600    | View titles and the document title           |
| `--rw-t-h2`    | 17px / 26px          | 600    | Document section headings                    |
| `--rw-t-h3`    | 15px / 24px          | 600    | Row titles: findings, tasks, review findings |
| `--rw-t-read`  | 15px / 26px          | 400    | Document prose, 70ch measure                 |
| `--rw-t-ui`    | 13px / 20px          | 400    | Controls, navigation rows, panel text, cards |
| `--rw-t-meta`  | 12px / 18px          | 400    | Metadata, chips, timestamps                  |
| `--rw-t-code`  | 12.5px / 19px        | 400    | IDs, paths, code, diffs                      |

* Prose lines never exceed 70 characters (`max-width: 70ch`); tables, diffs, diagrams, and boards use the full width of their column.
* Counts, line numbers, and durations use `font-variant-numeric: tabular-nums`.
* Markdown inside documents steps down: Markdown `h1` and `h2` render at `--rw-t-h2`, deeper headings at `--rw-t-h3`, because the row title already carries the document hierarchy.
* Headings get more space above than below. A section title has 24px above and 8px below.

## Spacing, Shape, and Depth

* Base unit 4px. Use 4, 8, 12, 16, 24, 32, and 48.
* Controls are 28px tall with a 6px radius; compact controls inside chips and toolbars are 24px. Cards, wells, and menus use an 8px radius. Chips are fully rounded.
* Borders are 1px. Never use a colored side border thicker than 1px on rows, cards, or callouts; status is carried by an icon, a word, and at most a tinted background.
* Depth: flat surfaces separated by `--rw-bg-subtle` and 1px borders. Shadows appear only on floating layers (menus, drawers, the shortcut dialog, the file preview sheet): `0 8px 24px rgb(0 0 0 / 0.12), 0 1px 3px rgb(0 0 0 / 0.08)` in light, `0 8px 24px rgb(0 0 0 / 0.5)` in dark. Floating layers keep their 1px border as well, so the edge survives forced colors (which removes shadows) and dark themes (where shadows barely show).
* Do not nest cards. A decision card inside a margin sits on the page surface, not inside another card.

## Layout

```text
+------------------------------------------------------------------------------------------+
| [=] Task title     Research - Plan - Implement - Review - Follow-up   Needs you 3  Live [*] |
+--------------+-------------------------------------------------------------+-------------+
| Navigator    | Context bar: phase, artifact, updated, readiness, actions    | Steer       |
|  filter      |-------------------------------------------------------------|  Needs your |
|  outline     | Row text (70ch)                    | Margin: decisions,      |  input      |
|  items       |                                    | notes, comments         |  Decided    |
|              | Row text                           | Margin                  |  Feedback   |
|              | ...                                                          |  Add input  |
|              |                                                              |  Checklist  |
+--------------+-------------------------------------------------------------+-------------+
```

* Regions: header (48px), navigator (264px, `--rw-nav-w`), document (fluid), steering panel (336px, `--rw-steer-w`). The navigator and steering panel use `--rw-bg-subtle`.
* The steering panel docks at 1360px canvas width and wider; the navigator docks at 1024px and wider. Below those widths each opens as a modal drawer from its edge over a scrim, with the rest of the page inert.
* Document rows show their margin column (272px, `--rw-margin-w`) when the document column is at least 800px wide (a container query on the document, not the window), so a 1440px canvas with both panels docked keeps its margins. Narrower, the margin's annotations follow the row text in reading order.
* Only the navigator, the document, and the steering panel scroll; the page itself never scrolls. The sticky header and context bar reserve scroll padding so a focused element is never hidden beneath them.
* Below 1200px the phase rail moves to its own full-width header row. Below 720px the Needs you and Live labels become icon-only with their names kept for assistive technology; below 560px the repository line hides and the rail shows icons plus the viewed phase's label. Content reflows at 320px without horizontal scrolling of text.

## Phase Rail

* The rail is an ARIA tab list of the five phases in order. The selected tab chooses which phase the document shows; it has a 2px accent underline and a 600 weight label, matching the Session Log tab treatment.
* Each tab shows its phase status icon and label. Done segments of the connecting line use `--rw-success`; others use `--rw-border-muted`.
* The agent's active phase carries an "Agent" marker (sparkle icon and the word, in the agent hue). Viewing another phase never moves the marker, so a person can read Research while the agent implements.
* A tab with items needing the person shows an attention badge with the count.
* Each tab's accessible name states the phase, its status, the agent marker, and the count, for example "Implement, in progress, agent is here, 1 item needs you".
* Arrow keys move between tabs, `Home` and `End` jump, and number keys `1` to `5` select a phase from anywhere.

## Document Rows and Margins

Every document is a sequence of rows. A row is one section or item (a finding, task, change, or review finding) with two columns: the text column and the margin column. The margin holds that row's annotations: decision cards, agent notes, the person's comments, and research lanes. Annotations never drift away from their row; on narrow layouts they follow the text.

* Row header: ID chip (monospace, for example `D2` or `P02-T01`), title, status badges, then row actions. Row actions (Edit section, Comment, and Research this or Ask the agent) are always visible as icon buttons with names; they are not hover-only.
* Evidence chips (`C5`, `W2`) are buttons. Activating one expands an evidence detail directly below the chip row with the claim, source, confidence, and retrieval date; activating it again collapses it.
* Trace strip: a labeled list ("Trace") of linked IDs joined by chevrons, such as `Q2` to `F3` to `D2` to `P02-T03` to a change to `RV-003`. Each item moves to its row in its phase. The strip is text first, so it reads correctly to assistive technology.
* Trace sources: strips derive from the session's reference fields, so recorded work joins them. The fields are question findings, decision anchors, task, change, and discovery links, and review finding relations. A strip walks back to the earliest ancestor, then forward along the child with the longest path onward.
* Section editing: rows that hold a document section offer Edit section. It replaces the row text with a Write and Preview pair, a Markdown text area, Save, and Cancel, plus a line naming the base revision. A saved edit shows "Edited by you" and a Queued chip until the agent takes it, and the agent receives the saved Markdown.
* Edit conflicts: saving with a stale revision shows a conflict notice in place ("The agent changed this section while you were editing") with Compare, Keep my version, and Use the agent's version. Focus moves to the notice.
* Unsaved drafts: Cancel, or `Escape` inside the editor, closes an unchanged editor at once. With changes, the Save row becomes an in-place question ("Discard your unsaved changes?") with Keep editing as the primary action and Discard changes. Starting another edit while a draft has changes keeps that draft, returns focus to it, and announces why.

## Decisions and Feedback

Decision cards are the heart of the canvas. Each card states what is being decided, who owns it, and where it stands.

* Needs your input: decision icon, ID and title, and a Needs your input chip; the question; a short context paragraph; options as radio cards, each with its consequence line and, when the agent recommends it, a Recommended tag with the reason; evidence chips; an impact line ("Changes P02-T03"); an optional note; and an Answer button. A line beside the button says where the answer goes in the current delivery mode, such as "Queued; send it from Steer".
* Answered: a "You" voice block (person icon, user hue label) quotes the chosen option and note, with the lifecycle chip and Edit answer while the answer is still queued.
* Interpreted: an "Agent understood" voice block (sparkle icon, agent hue label) states the interpretation and its effect, with Looks right and Not what I meant. Not what I meant opens a correction field prefilled with the original note, so nothing is retyped.
* Resolved: the card collapses to one line ("Resolved: Keep both photos · Changes P02-T03") with a How this was decided disclosure for its history.
* Agent decided: an "Agent decided" voice block with the rationale and evidence, plus Override, which opens the options in place. An override is feedback like any other, and dismissing it while queued restores the agent's choice. Settled decisions have no Override. In Review, the agent's decision on a finding offers Question this decision, which anchors a comment to that finding.
* Feedback items list their kind icon, target, an excerpt, the lifecycle chip, and the time. Actions follow state: Dismiss while a draft or queued; Looks right or Not what I meant once interpreted. Answers and overrides are edited from their decision card (Edit answer, Edit override) while queued, and Deliver acts on the whole queue from the delivery controls. While a delivery is under way, its items show Sending and offer no actions.
* Delivery modes: Queue for the agent (default: the agent collects feedback at its next checkpoint), Attach to my next message (adds a pill to the chat composer; you decide when to send), and Send now (starts an agent turn when it is idle, otherwise waits behind the current one). Attach and Send now always show the exact text first and say "Nothing is sent until you choose Deliver."
* Delivery integrity: Deliver sends only the previewed text. If the queue changed since the preview, it shows the new text, announces the change, and waits for another Deliver.
* Signature moment: when an interpretation arrives, the Agent understood block reveals once, top down. It is the canvas's one signature animation; Motion lists the rest.

## Steering Panel

The panel is the person's control center. Its sections always appear in this order, so help and actions are found in the same place across phases:

1. Needs your input: every decision awaiting the person, across phases, each a link to its card that names its phase, then a "Check how the agent read" link for each read-back waiting on the person.
2. Decided by the agent: agent-owned decisions still open to override, each a link to its card.

A decision whose anchor has no row in a started phase, or that has no anchor, appears in its section as a full decision card instead of a link, so it can be answered or overridden in place.
3. Your feedback: items grouped by lifecycle state, the delivery mode selector, the exact-text preview, and Deliver.
4. Add input: a composer whose kind is Comment, Context, or Research request; an optional anchor chip ("About F3", removable) set from the focused row; a text area; and Add to feedback. A research request becomes a queued lane in the Research view.
5. Review checklist: the viewed phase's checklist, progress ("3 of 6 reviewed"), and Share review with the agent.

## Phase Views

* Research: a summary band (bottom line, research status, readiness), What you may not know, a questions tracker, findings rows with evidence state and confidence, alternatives with dispositions, risks, research lanes, and a collapsed research record with the evidence log.
* Plan: a summary band with the critique verdict, a change map (Before and After, with a phase selector that highlights its nodes), phases as rows with progress, tasks as nested rows whose details expand in place, requirement coverage, planning decisions, and critique findings with dispositions. Moving a task uses Move up and Move down buttons, never dragging.
* Implement: a Now banner (current task, the agent's latest activity, progress), a board with Up next, In progress, Paused for you, Done, and Blocked columns, and a detail region for the selected card. Board cards move only through menu actions, never by dragging.
  * Below the board: changes grouped under a heading for each task (ID and title) in plan order, with files and validation and no repeated task chip; discoveries grouped under a heading for each kind (plan change, follow-up, implementation note, local judgment) with the kind's icon and word, omitting empty kinds; plan updates with before and after text; decisions that paused work; business alignment entries; blockers; and the validation record. Each group lists newest first.
* Review: a summary band (execution, outcome, counts by severity), findings rows with expected and observed behavior side by side, resolution condition, and route; decision cards in the margin; the decision history as a timeline; and validation evidence.
* Follow-up: ranked follow-ups with rationale, evidence, Select, and Skip, and the loop lineage from parent to child tasks.

Empty states teach: they say what will appear, when, and who produces it ("The plan appears here when Research is ready").

## Components and States

Every interactive control has default, hover, focus, active, disabled, and busy states drawn from the tokens.

* Buttons: neutral by default (`--rw-bg` fill, `--rw-border-control` outline). One primary button per region uses the accent fill. Icon-only buttons have an accessible name and tooltip; they are 32px in the header and panel heads and 28px elsewhere.
* Chips and badges: `--rw-t-meta`, fully rounded, 14 percent hue tint, `--rw-fg` text, and the status icon.
* Choices: radio groups for exclusive choices (theme, delivery mode, decision options) and checkboxes for independent ones (checklists). Segmented controls are radio groups styled as segments.
* Menus: a button that opens a list of actions; `Escape` closes it and returns focus to the button.
* Disclosures: native `details` and `summary` with a rotating chevron, or a button with `aria-expanded`.
* Board cards and file rows open their details in place or in the file preview sheet; they are buttons, not links, unless they navigate.

| State     | Treatment                                                                                |
|-----------|------------------------------------------------------------------------------------------|
| Loading   | Static skeleton rows in `--rw-bg-subtle`; no shimmer                                     |
| Empty     | Explains what appears here, when, and who produces it                                    |
| Error     | Names the problem and the recovery, with Retry                                           |
| Live      | Header chip "Live" with a filled dot while the event stream is connected                 |
| Reconnect | Header chip "Reconnecting" in the attention hue; the page polls until the stream returns |
| Paused    | Header chip "Paused" while the page is hidden; nothing polls                             |
| Saving    | The save button shows busy text ("Saving") and is disabled until the server answers      |
| Conflict  | In-place notice with Compare, Keep my version, and Use the agent's version               |
| Delivered | The feedback item moves to Sent; a polite announcement names the count and mode          |

## Motion

* Transitions run 150ms (hover and color) to 200ms (disclosure chevrons) with `cubic-bezier(0.2, 0, 0, 1)` and convey state only.
* Drawers slide in from their edge, and dialogs (the shortcut list and the file preview) rise 8px and fade in, each over 200ms.
* One authored moment: the Agent understood block reveals with a clip-path wipe from the top and a fade, 240ms, once per interpretation.
* When the agent points the person to an item (`focus_item`), the row receives a 1.2s fade from a 12 percent accent wash to transparent, once.
* Nothing animates continuously. The live dot is static.
* Under `prefers-reduced-motion: reduce`, transitions, the reveal, and the wash are removed; a static "New" badge marks the change until the next update.

## Keyboard

| Key                       | Action                                                       |
|---------------------------|--------------------------------------------------------------|
| `1` to `5`                | View Research, Plan, Implement, Review, or Follow-up         |
| `n`                       | Move to the next item that needs you                         |
| `[` and `]`               | Previous and next row                                        |
| `e`                       | Edit the focused row's section                               |
| `c`                       | Comment on the focused row                                   |
| `/`                       | Open the navigator and filter it                             |
| `b`                       | Show or hide the navigator                                   |
| `s`                       | Show or hide the steering panel                              |
| `?`                       | Show the shortcut list                                       |
| `Escape`                  | Close a menu, drawer, or dialog, or leave the section editor |
| Arrow keys, `Home`, `End` | Move within the phase rail, radio groups, and menus          |

* `e` and `c` act on the row that has focus. Without one they announce how to reach a row, and `e` on a row without a section says so.
* `Escape` closes the innermost layer: the appearance menu, then a drawer, then the editor when focus is inside it, which asks first when the draft changed. Open dialogs handle their own `Escape`, and `Escape` during input-method composition is left to the input method.
* Single-key shortcuts are ignored while focus is in a text field. The shortcut list has a switch that turns letter, number, and symbol shortcuts off; their hints then leave tooltips and `aria-keyshortcuts`, while `Escape` and arrow keys keep working.

## Accessibility

* Conformance target: WCAG 2.2 AA in Light, Dark, and More contrast using the canvas palette alone, and usable in forced colors.
* Landmarks: the header is a banner, the navigator a navigation region, the document the main region, and the steering panel a complementary region. Headings descend in order: the task title is the only `h1`; the phase title, outline, and Steer are `h2`; document rows and steering sections are `h3`; cards, board columns, and Markdown headings inside rows are `h4` and below. Scrollable regions and tables have names that differ from their row's name.
* Focus: a 2px `--rw-accent` outline on every focusable element, never removed without a replacement. The offset is 2px by default, 0 on text fields, inset 2px on rail tabs and the scrolling document where an outer ring would be clipped, and 6px around document rows. Sticky regions reserve scroll padding so focus is never obscured.
* Focus survives updates: after a re-render or an action, focus returns to the same control, else to its item or row, else to its steering section heading, never to the page body.
* Targets are at least 24 by 24 CSS pixels; the default control size is 28px, and header icon buttons are 32px.
* A polite live region announces material changes at most once per update: a new item needs you, an interpretation arrived, the agent moved to another phase, a save conflicted, a delivery finished, or the stream reconnected. Initial load stays silent.
* Color is never the only cue: every status has an icon and a word, diff lines have plus and minus markers, and the trace strip uses words and chevrons.
* Nothing requires dragging: board moves, task moves, and panel sizes have buttons or menus.
* Corrections, edits, and overrides prefill what the person already entered, so nothing is retyped.
* Diagrams are figures with a caption and a text alternative that lists nodes and relationships, plus Show as text.
* Tabs follow the ARIA tabs pattern, and radio groups and menus follow their ARIA patterns. The shortcut list and the file preview are modal dialogs that return focus to their opener. Drawers are the navigation and complementary regions shown over a scrim: while one is open the rest of the page is inert, and closing it with `Escape` or its close button returns focus to its toggle.

## Content and Copy

* Use sentence case for labels, buttons, and headings, and no label above a heading.
* Controls name their action: "Answer", "Looks right", "Not what I meant", "Deliver 2 items", "Open change".
* Address the person as "you" and refer to the agent as "the agent".
* IDs appear exactly as the artifacts write them, in monospace: `Q2`, `C5`, `W1`, `D3`, `P02-T01`, `FR-003`, `PC-002`, `RV-001`, `RD-004`.
* Times show local `HH:MM` with the full ISO time in a `title`; relative times ("3 min ago") update with the data, not on a timer.
* Never invent text. A missing value renders as "Not recorded".
* All session text is untrusted. It renders through DOM text APIs and a restricted Markdown subset: headings, paragraphs, lists and task lists, emphasis, inline and fenced code, tables, block quotes (nested up to six levels), rules, and links limited to `http` and `https`, which open in a new browsing context with `rel="noopener noreferrer"`.
* Every link the canvas renders, including evidence sources, passes the same check; any other address renders as text with the address in its tooltip. Open in editor is the one exception: a `vscode://file/` link built from an absolute POSIX or Windows path, shown only when the path is absolute.

## Icons

Icons are authored inline SVG symbols in one sprite, on a 16px grid with a 1.5px stroke, round caps and joins, and `currentColor`. They extend the Session Log sprite and keep its shapes for shared meanings (person, sparkle, check, alert, info, chevron, search, panel, keyboard).

Additions: phase icons (research magnifier, plan list, implement brackets, review eye, follow-up loop), decision signpost, hand, inbox, send, undo, pencil, sun, moon, contrast, steer sliders, trace nodes, file, diff, external link, anchor, checklist, light bulb, shield check, half circle, and trend down. Emoji and Unicode glyphs never stand in for icons. Decorative icons carry `aria-hidden="true"`.

## Browser Surfaces

* Text selection uses a 28 percent accent tint (`::selection`), and the caret uses `--rw-accent`.
* Scrollbars are thin, with `--rw-border` thumbs on transparent tracks.
* Links underline with a 2px offset; underline thickness grows on hover.
* Placeholders use `--rw-fg-muted`, which meets 4.5:1.
* Code and diff wells use `tab-size: 2`, preserve whitespace, and scroll long lines inside the well.

## Revision Log

| Date       | Change                                                                                                   | Reason                                                                                                 |
|------------|----------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------|
| 2026-10-23 | Initial guide                                                                                            | Canvas build                                                                                           |
| 2026-10-23 | Margin column is 272px and appears at 800px document width                                               | At 1440px with both panels docked the document is 840px, so the 880px rule hid every margin            |
| 2026-10-23 | Header rail moves to its own row below 1200px; labels go icon-only below 720px and 560px                 | Narrow editor panels; replaces the More menu with reflow that keeps every control visible              |
| 2026-10-23 | Delivery modes are a compact segmented control with the chosen mode's hint below, after the queued items | Three bordered radio cards pushed queued feedback below the fold; the panel now reads items, then mode |
| 2026-10-23 | Headings: rows `h3`, cards `h4`, Markdown headings `h4` and `h5`                                         | axe heading-order: rows were `h2` under the `h2` phase title and cards skipped to `h4`                 |
| 2026-10-23 | Navigating to a tall target aligns it to the top; shorter targets center                                 | A centered tall decision card hid its header beneath the sticky context bar                            |
| 2026-10-23 | Readiness line uses a 14px radius instead of a full pill                                                 | Two-line readiness text looked like a stadium shape                                                    |
| 2026-10-23 | Edit answer, Edit override, and corrections restore the earlier choice and text                          | Nothing is retyped; dismissing a correction now reopens what it corrected                              |
| 2026-10-23 | Decisions with no row in a started phase render as full cards in the steering panel                      | Such decisions were links to nothing, so they could not be answered or overridden                      |
| 2026-10-23 | Deliver sends only the previewed text; items being delivered show Sending                                | A queue change after preview could send different text, and items could be delivered twice             |
| 2026-10-23 | Unsaved drafts ask before discarding; a second Edit section returns to the open draft                    | `Escape` and a second edit silently discarded typed changes                                            |
| 2026-10-23 | Focus returns to the same control, item, or section heading after updates                                | Re-renders and actions dropped keyboard focus to the page body                                         |
| 2026-10-23 | Focus offsets and header icon button sizes recorded as built                                             | The guide stated one 2px offset and 28px icon buttons; the canvas varies them on purpose               |
| 2026-10-23 | Drawers are inert-backed regions over a scrim, not dialogs; dialogs and drawers animate                  | The guide described drawers as dialogs and omitted their motion                                        |
| 2026-10-23 | Implement groups changes by task and discoveries by kind                                                 | The lists were flat, so a task's work and a kind's discoveries were hard to scan                       |
| 2026-10-23 | Change cards inside a task group omit the task chip and keep the time on the title line                  | The group heading already names the task; the repeated chip pushed the time onto a line of its own     |
| 2026-10-23 | Trace strips derive from reference fields and follow the longest path onward                             | Static strips missed work the agent recorded during the session                                        |
| 2026-10-23 | Links outside `http` and `https` render as text everywhere, with editor links built from absolute paths  | Evidence links bypassed the scheme check, and editor links were malformed on Windows                   |

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
