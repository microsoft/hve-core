---
title: RPI Workflow Canvas Style Guide
description: Visual language, interaction grammar, and accessibility requirements for the hve-core RPI Workflow canvas
author: Microsoft
ms.date: 2026-10-27
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
* Never hide what will reach the agent. Everything the person adds waits, visibly, until they send it with Review and send; feedback shows its state from not sent to applied, and Review and send shows every item and the exact message first.
* Make every claim traceable. Stable IDs, evidence chips, and trace strips connect a question to the finding, decision, task, change, and review finding it became.
* Documents stay the source of truth. The canvas never changes them: the person suggests an edit beside the text, and the agent applies it to the file.
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
| `--rw-teal`      | Further research as a risk type                          | `#106e75` | `#1cb0ab` | `#0a4f54`           | `#56d4ce`          |

Each hue reaches at least 4.5:1 against `--rw-bg` and `--rw-bg-subtle` in its scheme (4.57:1 is the lowest, light attention on subtle), so it may color small text there. On `--rw-bg-selected`, light-scheme hues fall to 4.3:1 to 4.6:1, so selected rows set text in `--rw-fg` and use hues only for icons. Chips and badges place `--rw-fg` text on a 14 percent tint of their hue, which measures 12.9:1 or more.
A tone class (`tone-success` and the others) sets `--tone`; the badge and notice defaults sit in zero-specificity `:where()` rules, so a tone class always wins whatever the rule order.

### ID Family Hues

Each ID family in `ui/ids.mjs` names one of Primer's display hues (Primer Primitives 11.10.0). A chip uses the hue's text color on its muted background, which measures at least 4.9:1 in light and 6.1:1 in dark, with a 32 percent border of the hue. A linked chip keeps its family's color; its go-to icon, not blue text, says it navigates. In More contrast, chip text is `--rw-fg` and the hue moves to the border.

| Family | Hue    | Family | Hue    | Family | Hue    |
|--------|--------|--------|--------|--------|--------|
| Q      | blue   | P      | purple | DS     | brown  |
| F      | green  | T      | cyan   | AL     | pine   |
| D      | indigo | FR     | lime   | RV     | red    |
| C      | orange | NFR    | olive  | RD     | auburn |
| W      | teal   | PC     | coral  | FU     | pink   |
| L      | gray   | CH     | yellow | FB     | plum   |

### Syntax Colors

The source sheet colors code with Primer's syntax palette, scoped to `.source-view`. Light keyword red darkens to `#b42531` so it keeps 4.5:1 on the cited line's attention wash, and More contrast darkens every light token further. Comment and meta, keyword, string and code, constant (numbers, literals, keys, headings), entity (functions, attributes), variable (variables, list markers), and tag (tags, regular expressions) each keep 4.5:1 on the inset pane and on the cited line in every scheme.

### Status Vocabularies

Every status pairs an icon and a word with its hue. These are the only vocabularies; views do not invent new states.

| Vocabulary         | States (icon, hue)                                                                                                                                                                                                                        |
|--------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Phase status       | Done (check, success); Active (filled dot, accent); Upcoming (hollow circle, muted); Paused for you (pause, attention); Blocked (alert, danger); Skipped (dashed circle, muted)                                                           |
| Feedback lifecycle | Needs your input (hand, attention); Draft (pencil, muted); Not sent (inbox, accent); Sending (send, accent); Sent (send, accent); Interpreted (sparkle, agent); Applied (check, success); Corrected (undo, attention); Removed (x, muted) |
| Evidence state     | Evidence-backed (shield check, success); Partially supported (half circle, attention); Hypothesis (light bulb, muted); Weakened (trend down, danger); Unresolved (question, muted)                                                        |
| Severity           | Critical (filled alert, danger); High (alert, danger); Medium (alert, severe); Low (info, muted)                                                                                                                                          |
| Confidence         | High and very high (three bars, success); Medium and medium-high (two bars, attention); Low and medium-low (one bar, severe); Not recorded or other words (empty bars, muted); the label keeps the file's word                            |
| Priority           | High (double chevron up, danger); Medium (equals, attention); Low (chevron down, accent)                                                                                                                                                  |
| Risk type          | Risk (alert, severe); Open question (question, accent); Further research (magnifier, teal); Assumption (light bulb, attention); Dependency (branch, muted); Issue or blocker (x circle, danger); other words (info, muted)                |
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
| [=] Task title  Research - Plan - Implement - Review - Follow-up  Needs you 3  Send 2  Live |
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
* Session line: the line under the task title starts with the session button, a 20px bordered chip with the nodes icon, the session name, the loop count ("Offline trail maps · 2 loops"), and a chevron that turns when its menu is open. It keeps its natural width up to 30 characters and never shrinks below it while the line has room.
  For a real session, the follow state comes next: the active icon and "Following" in the accent hue, or the pause icon and "Paused" in the attention hue followed by a Resume following link button. Assistive technology hears "Following the running loop" or "Paused: following the running loop is paused".
* Source label: the session line continues with where the content comes from.
  A real session shows a muted badge with the file icon and the canvas handle in monospace; "RPI canvas" is kept for assistive technology and the tooltip. Then come the task ID in monospace, and the repository and branch.
  A child loop then adds "Child of" and its parent's title as a link button that shows the parent.
  The sample shows its "Sample session" badge instead.
  When space runs out, the repository and branch shorten first, then the task ID down to 9 characters, and the parent link keeps at least 14 characters. The line clips rather than run under the phase rail.
  Each shortened part keeps its full text in a tooltip, and the header height never changes.
* The steering panel docks at 1360px canvas width and wider; the navigator docks at 1024px and wider. Below those widths each opens as a modal drawer from its edge over a scrim, with the rest of the page inert.
* Document rows show their margin column (272px, `--rw-margin-w`) when the document column is at least 800px wide (a container query on the document, not the window), so a 1440px canvas with both panels docked keeps its margins. Narrower, the margin's annotations follow the row text in reading order.
* Only the navigator, the document, and the steering panel scroll; the page itself never scrolls. The sticky header and context bar reserve scroll padding so a focused element is never hidden beneath them.
* Below 1400px the phase rail moves to its own full-width header row. Below 720px the Needs you, Review and send, Live, and follow state labels become icon-only with their names kept for assistive technology; below 560px the source label hides, the session button narrows to 24 characters, and the rail shows icons plus the viewed phase's label. Content reflows at 320px without horizontal scrolling of text.
* Session menu: the session button opens a non-modal menu below the title, 460px wide and scrolling within 72 percent of the viewport height.
  It holds an `h2` ("Session: Offline trail maps") that takes focus, a meta line with the session folder and follow state, "Loops in this session" as a session tree, and, for a real session, "Other sessions" as full-width rows naming each session, its date, loop count, and running loop. `Escape`, a click outside, or moving focus out closes it, and `Escape` returns focus to the button.
* Status area: failures and follow moves appear as notes centered at the bottom of the document, sticky above its content, at most 640px wide with the floating shadow, and at most three at once. Each note is a notice in its tone (danger for failures, accent for moves) with its icon, its text, and a Dismiss icon button. A note never takes focus and stays until dismissed or, for a move, until the next move; it is announced politely.

## Phase Rail

* The rail is an ARIA tab list of the five phases in order. The selected tab chooses which phase the document shows; it has a 2px accent underline and a 600 weight label, matching the Session Log tab treatment.
* Each tab shows its phase status icon and label. Done segments of the connecting line use `--rw-success`; others use `--rw-border-muted`.
* The agent's active phase carries an "Agent" marker (sparkle icon and the word, in the agent hue). Viewing another phase never moves the marker, so a person can read Research while the agent implements.
* A tab with items needing the person shows an attention badge with the count.
* Each tab's accessible name states the phase, its status, the agent marker, and the count, for example "Implement, in progress, agent is here, 1 item needs you".
* Arrow keys move between tabs, `Home` and `End` jump, and number keys `1` to `5` select a phase from anywhere.

## Document Rows and Margins

Every document is a sequence of rows. A row is one section or item (a finding, task, change, or review finding) with two columns: the text column and the margin column. The margin holds that row's annotations: decision cards, agent notes, the person's comments, and research lanes. Annotations never drift away from their row; on narrow layouts they follow the text.

* Row header: ID chip (monospace, for example `D2` or `P02-T01`), title, status badges, then row actions. Row actions (Suggest an edit, Comment, and Research this or Ask the agent) are icon buttons with names and tooltips. They show while the row is hovered or holds focus, and always on devices without hover.
* Evidence chips (`C5`, `W2`) are buttons. Activating one expands an evidence detail directly below the chip row with the claim, source, confidence, and retrieval date; activating it again collapses it.
* Trace strip: a labeled list ("Trace") of linked IDs joined by chevrons, such as `Q2` to `F3` to `D2` to `P02-T03` to a change to `RV-003`. Each item moves to its row in its phase. The strip is text first, so it reads correctly to assistive technology.
* Trace sources: strips derive from the session's reference fields, so recorded work joins them. The fields are question findings, decision anchors, task, change, and discovery links, and review finding relations. A strip walks back to the earliest ancestor, then forward along the child with the longest path onward.
* Record rows: for a real session, each phase ends with a record row ("Plan record", "Changes record", "Review record") that lists the file sections no other row shows. The research record adds them after the evidence log. Each section is a collapsed disclosure whose summary is an `h4` with the file's heading, built only when opened and rendered as written.
* Section editing: rows that hold a document section offer Suggest an edit. It replaces the row text with a Write and Preview pair, a Markdown text area, Add suggestion (Update suggestion when one is pending), and Cancel, plus a line saying the suggestion waits in Review and send. The section never shows the person's text as its own.
* Suggestions: each suggestion that is not sent, sent, or read back sits in a callout below its section's source text.
  The callout has a 3px left edge and a 5 percent tint in the user hue, a pencil icon, "Your suggested edit", the lifecycle chip, and the `+N −N` counts. It shows the line changes in a diff well with spoken Added and Removed prefixes.
  While the suggestion is not sent it offers Edit suggestion and Remove; once read back, it offers Looks right and Not what I meant. When the section changed after the suggestion was made, an attention line says so.
* Edit conflicts: saving with a stale revision shows a conflict notice in place ("This section changed while you were editing") with Compare, Keep my suggestion, and Start from the new text. Focus moves to the notice.
* Unsaved drafts: Cancel, or `Escape` inside the editor, closes an unchanged editor at once. With changes, the Save row becomes an in-place question ("Discard your unsaved changes?") with Keep editing as the primary action and Discard changes. Starting another edit while a draft has changes keeps that draft, returns focus to it, and announces why.

## Decisions and Feedback

Decision cards are the heart of the canvas. Each card states what is being decided, who owns it, and where it stands.

* Needs your input: decision icon, ID and title, and a Needs your input chip; the question; a short context paragraph; options as radio cards, each with its consequence line and, when the agent recommends it, a Recommended tag with the reason, then "Your own answer" as the last radio card with a dashed border; evidence chips; an impact line ("Changes P02-T03");
  the text field, an optional note while an option is chosen and the required "Your answer" when Your own answer or no option exists; and an Answer button. A line beside the button says "Waits in Review and send".
* Answered: a "You" voice block (person icon, user hue label) quotes the chosen option and note, with the lifecycle chip and Edit answer while the answer is still queued.
* Interpreted: an "Agent understood" voice block (sparkle icon, agent hue label) states the interpretation and its effect, with Looks right and Not what I meant. Not what I meant opens a correction field prefilled with the original note, so nothing is retyped.
* Resolved: the card collapses to one line ("Resolved: Keep both photos · Changes P02-T03") with a How this was decided disclosure for its history.
* Card header: the decision icon, the ID, and the status chip share the first line, and the title takes the line below, so a long title never squeezes between them.
* Decisions rows: a real session's Research and Plan list the decisions their files record in a Decisions row, after the recommendation and before the requirements. The cards sit in a grid of columns at least 300px wide, labeled with the file's own IDs (`D1`, not `plan.D1`). An ID chip resolves to the viewed phase's decision first, so `D1` in the Plan view is the plan's D1. The row's count chip becomes "N needs you" in the attention hue while any decision waits on the person.
* Answers in your own words: a decision that lists no options asks for "Your answer" in a text area instead of radio cards. An agent decision with no alternatives opens Override as "What should the agent do instead?". In both, the submit button turns on once the text is not blank. The person's words then appear in the "You" or "Your override" voice, and in the resolved line when no option was chosen.
* Agent decided: an "Agent decided" voice block with the rationale and evidence, plus Override, which opens the options in place.
  The voice names the chosen option only when it differs from the title.
  While an override waits, the voice keeps the agent's original choice above the person's override.
  An override is feedback like any other, and removing it before it is sent restores the agent's choice.
  Settled decisions have no Override.
  In Review, the agent's decision on a finding offers Question this decision, which anchors a comment to that finding.
* Feedback items list their kind icon, target, an excerpt, the lifecycle chip, and the time; sent items also say how they left ("sent as a message"). Actions follow state: Go to whenever the item is about something in the canvas; Edit and Discard while not sent, as icon buttons beside the state chip; Looks right or Not what I meant once interpreted.
  Edit opens the words in place, with Save and Cancel, for comments, context, research requests, task requests, corrections, and the note on an answer or override; a suggested edit or checklist review opens where it was made. Answers and overrides are edited from their decision card (Edit answer, Edit override) while not sent. While a send is under way, its items show Sending and offer no actions.
* Review and send: a pill in the header, after Needs you, present in every phase and at every width. With nothing waiting it is neutral and its name is "Review and send, nothing waiting". Once items wait it takes the accent fill with a count, named "Review and send, 3 items waiting". Below 720px its label is visually hidden and the icon and count remain. It is the only way to open the dialog.
* Review and send dialog: a modal titled "Review and send", 640px wide, whose title takes focus when it opens.
  * An intro names the canvas by its handle and the chat line the message starts with, and says to check each item.
  * Items sit under a heading for each loop, the shown loop first, with its title, a Shown badge, its status, and its ID; a completed loop's heading says its items become follow-up work.
  * Each item is a row with its kind icon, its ID chip, its kind and what it is about, its full words or line counts, and Go to, Edit, and Discard as icon buttons with tooltips. Go to closes the dialog and goes to the item, in its loop. Edit replaces the words with a labeled text area, Save, and Cancel; a failed save keeps the words beside the reason.
  * Then come "Message to the agent (optional)" and a collapsed "Exact message the agent receives" holding the prompt, which refreshes while the person types and after an edit, without taking focus.
  * A sticky footer keeps Send N items, Discard all, and Close in view.
  * Discard and Discard all are second-press buttons: the first press turns the button into a question that names what goes ("Discard FB-004?", "Discard all 3 items from 2 loops?") with the trash icon in the danger tone, a 12 percent danger fill, and a heavier border in forced colors, and keeps focus. A press in the next half second, a repeated key, Escape, leaving the button, or four seconds disarm it or are ignored; the change is announced.
  * The dialog closes after a send, after Discard all, or when its last item is discarded, and says what happened.
  * With nothing waiting, the dialog explains how to add input instead.
  * Closing returns focus to the control that opened it.
* Send integrity: Send delivers only the listed items, and only while their text matches what was prepared. When the list or an item changed, the dialog shows the new list and asks for another check. A failure stays in the dialog as an alert, and the items remain unsent.
* Canvas handle: four base32 characters without I, L, O, or U, such as `3WF0`, in monospace. A real session's source badge reads "RPI canvas 3WF0", the words every chat message from the canvas starts with. The sample shows "Canvas 3WF0" after its badge.
* Signature moment: when an interpretation arrives, the Agent understood block reveals once, top down. It is the canvas's one signature animation; Motion lists the rest.

## Steering Panel

The panel is the person's control center. Its sections always appear in this order, so help and actions are found in the same place across phases:

1. Needs your input: every decision awaiting the person, across phases, each a link to its card that names its phase, then a "Check how the agent read" link for each read-back waiting on the person.
2. Decided by the agent: agent-owned decisions still open to override, each a link to its card. On Implement, Now follows: tasks done with a bar, the task the agent works on, other work in progress, decisions paused for you, blockers, and the latest activity. Decisions listed in a phase's Decisions row collapse to one link per phase, such as "10 recorded decisions" with the phase name.

A decision whose anchor has no row in a started phase, or that has no anchor, appears in its section as a full decision card instead of a link, so it can be answered or overridden in place.
3. Your feedback: the shown loop's items grouped as Not sent yet, With the agent, and Earlier, each with Go to, and the unsent ones with Edit and Discard. Other loops' items appear only in Review and send.
4. Add input: a composer whose kind is Comment, Context, or Research request; an optional anchor chip ("About F3", removable) set from the focused row; a text area; and Add comment, Add context, or Add research request. A line under it says that what you add waits until you send it with Review and send. A research request becomes a queued lane in the Research view.
5. Review checklist: an intro that says the questions are optional, that items needing work (with notes) and an all-good list go with the next send, and that other marks only track progress.
   A status line follows with progress ("3 of 6 reviewed, 1 needs work") and whether the review goes with the next send.
   Then comes each statement with two toggle buttons, Looks good (check, success hue when pressed) and Needs work (flag, attention hue when pressed). The buttons use `aria-pressed` and fixed labels in a group named by the statement, and pressing the selected one clears it. Needs work reveals "What needs work? (optional)".

## Phase Views

* Research: a summary band (bottom line, research status, readiness), What you may not know, a questions tracker, findings rows with evidence state and confidence, alternatives with dispositions, risks, research lanes, and a collapsed research record with the evidence log.
* Plan: a summary band with the critique verdict, a change map (Before and After, with a phase selector that highlights its nodes), phases as rows with progress, tasks as nested rows whose details expand in place, requirement coverage, planning decisions, and critique findings with dispositions. Moving a task uses Move up and Move down buttons, never dragging.
  * While a critique runs, the summary's critique card and the Critique row show Running (accent, active icon) in place of a verdict, each lens with its status badge (Queued, In progress, Done, Partial, Blocked), a progress bar of finished lenses, and the lens in progress with the findings so far. A critique left started by a session that stopped shows Stopped (attention, pause icon). While findings are open, both show "N of M findings addressed in the plan" with a bar.
  * Plan text the agent changed in the last ten minutes, after the canvas first read it, carries an Updated badge in the agent tone with a pencil and the time: the summary, What you may not know, and each task.
* Implement: the task board pinned under the context bar with a summary ("3 of 9 tasks done · 3 in progress") and a chevron that collapses it to that line; its body scrolls on its own up to `min(40vh, 340px)` and holds Up next, In progress, Paused for you, Done, and Blocked columns, where columns with cards take most of the width and empty ones stay narrow, and a detail region for the selected card.
  On panels 720px wide or less its body scrolls up to `min(25vh, 220px)`, leaving more of a narrow panel to the page; on panels 560px tall or less it stays in the page instead. The document's scroll padding equals the measured context bar and board, and rows add no scroll margin of their own, so a row you go to lands just below them. Going to a task scrolls only the board, never the page under it. Board cards move only through menu actions, never by dragging.
  * Phases and tasks: a segmented filter, In progress (in progress, paused, or blocked; the default), Remaining, Done, and All, each with its count, then each phase with a matching task under its ID, title, done count, and status, with Plan's task blocks; moves follow plan order. An empty filter says what that means and offers Show all.
  * Change map: the plan's After map with done parts in the success tone and in-progress parts in the accent tone, the canvas's in-progress tone (the agent tone is the agent's voice and shares the success value), each with a corner mark (a check or a dot), a Phase control whose tabs carry each phase's status icon and spoken status, starting on the phase in progress, and a legend.
    The chosen phase's parts take a 3-pixel outline in the foreground color over their progress fill, so the choice shows whatever a part's progress is; in forced colors they take Highlight. The legend reads Done, In progress, Bold outline: the chosen phase, and Dashed border: added by the plan. Plan's own map keeps its accent fill for the chosen phase.
  * Below them: changes grouped under a heading for each task (ID and title) in plan order, with files and validation and no repeated task chip; discoveries grouped under a heading for each kind (plan change, follow-up, implementation note, local judgment) with the kind's icon and word, omitting empty kinds; plan updates with before and after text; decisions that paused work; business alignment entries; blockers; and the validation record. Each group lists newest first.
* Review: a summary band (execution, outcome, counts by severity), findings rows with expected and observed behavior side by side, resolution condition, and route; decision cards in the margin; the decision history as a timeline; and validation evidence.
* Follow-up: ranked follow-ups with rationale, evidence, Select, and Skip, and "Loops in this session", the session tree. For a real session, each other loop offers Show, whose accessible name includes the loop's title, such as "Show Offline trail maps".
* Real sessions: the context bar adds Open in editor beside Copy for the phase's file, and "Updated" is when that file last changed. Changes render their behavior and validation text as Markdown, and changes recorded without a task group under "Not linked to a plan task".

Empty states teach: they say what will appear, when, and who produces it ("The plan appears here when Research is ready").

## Components and States

Every interactive control has default, hover, focus, active, disabled, and busy states drawn from the tokens.

* Buttons: neutral by default (`--rw-bg` fill, `--rw-border-control` outline). One primary button per region uses the accent fill. Icon-only buttons have an accessible name and tooltip; they are 32px in the header and panel heads and 28px elsewhere.
* Chips and badges: `--rw-t-meta`, fully rounded, 14 percent hue tint, `--rw-fg` text, and the status icon. Levels and kinds (confidence, priority, risk type, severity) use the strong badge: an 18 percent tint, a 1px border at 55 percent of the hue, and a 2px icon stroke.
* Choices: radio groups for exclusive choices (theme, composer kind, decision options), checkboxes for independent ones, and toggle buttons with `aria-pressed` for a clearable verdict (checklist items). Segmented controls are radio groups styled as segments.
* Menus: a button that opens a list of actions; `Escape` closes it and returns focus to the button.
* Canvas menu: right-click, Shift+F10, or the Menu key opens a `menu` of `menuitem` buttons at the pointer or under the focused element, in the top layer. Items are 28px with a 16px icon, the label, and the shortcut in meta text; separators group comments, the clicked ID, file, or link, and navigation.
  Focus moves to the first item, Up and Down wrap, Home and End jump, Enter and Space choose, and Escape or Tab close it and return focus. Shift with a right-click, and right-click in a text field, leave the host's menu.
* Tooltips: the canvas draws them in the top layer, 4px by 8px padding, meta text, `--rw-bg` with a border and `--rw-shadow-float`, at most 320px wide, below the element or above it when there is no room.
  They open 500ms after hover, at once on keyboard focus or when moving from one tooltip to the next within 300ms, stay while hovered, and hide 150ms after the pointer leaves, on Escape, a click, or scrolling. An element's `title` moves into its tooltip the first time, and stays as `aria-description` when it says more than the element's name. The shortcut follows the text, such as "Comment (c)".
* Part comments: row actions show while the row is hovered or holds focus, and always without hover. One 24px round button with the speech bubble follows the hovered paragraph, list item, table row, heading, quote, or code block, in the row's left gutter; hovering it washes the part in `--rw-wash`. The composer and margin notes show the part and a quote, clamped to four lines, behind a 3px border.
* Disclosures: native `details` and `summary` with a rotating chevron, or a button with `aria-expanded`.
* Session tree: nested ordered lists, parent first, each level indented 11px past a 1px guide line. Each loop is a card with its status badge (Completed, Running, or Stopped, with icon and word), its title, its task ID in monospace, and Show or a Shown badge at the end. The shown loop's card takes the accent border and selected fill. A loop continued from another session shows "Continues … from another session" with Show above its card.
* Send groups: when unsent items come from more than one loop, the Send dialog shows a section per loop headed by an `h3` with the loop's title, a Shown badge for the shown loop, and its status badge, then the task ID and, for a completed loop, a line saying its items go as follow-up work. Removing an item moves focus to the next item in its group, then the nearest group heading.
* Field errors: a failure about a field sits directly under it in the danger hue with the alert icon, the field gets `aria-invalid` and `aria-describedby`, and the person's text stays.
* Board cards and file rows open their details in place or in the file preview sheet; they are buttons, not links, unless they navigate.
* ID chips: monospace, in their family's colors (see ID Family Hues). Hovering a chip that acts sets its border to the full hue and underlines the ID; the tint stays, so the text keeps its contrast.
  The icon after the ID says what a click does: the box with an arrow goes to the item, and the page opens it in place. An ID inside a larger control, such as a navigator entry or a plan task toggle, carries that control's icon, and a plain ID label carries none. Websites show the globe and editor buttons the code file, so the box with an arrow never leaves the canvas.
* Previews: a card in the top layer, at most 440px wide and 60vh tall, with `--rw-shadow-float` and a 1px border that turns accent when locked.
  The head holds the ID chip and its kind in meta text, Go to, a 16px lock ring that fills over the lock delay, a pin once locked, and Close once locked.
  A preview opens 500ms after hover or 300ms after keyboard focus, hides 300ms after the pointer leaves, locks after 1s, and nests up to five deep. Unlocked previews are tooltips whose controls stay out of the tab order; locked ones are non-modal dialogs.
* Sources: a file entry puts the file name in monospace in a chip with the page icon, and the editor button, on one line, then the folder in muted monospace that breaks only after slashes, a dot, and the cited heading or symbol. An unavailable location shows the name struck through with the reason in italics.
  A website source reads as written, each link labeled by its title or by host and page, with one globe. The source sheet scrolls only its file pane, has a 4.5em line-number gutter, colors code by language, and marks the cited line with a 3px attention bar on an 18 percent attention wash.
* History: Back and Forward are 28px icon buttons before the phase title, transparent until hovered and 40 percent opacity when disabled. Their names say where they go.
* Header meta line: the canvas badge never shrinks. The session label shortens first, then the task details clip, and they hide below 6ch. Below 560px the line wraps, and the badge may shorten rather than run under the actions.
* Not connected screen: while the canvas shows no session, it replaces the workspace in its own `main`, and `#document` takes `hidden` so one `main` shows. A centered card of at most 640px holds the plug icon in a 44px circle tinted 14 percent attention, an `h2`, a lead paragraph, and three parts divided by muted rules.
  The request is a quote with a 3px accent rule on its leading edge and no box, so it does not read as a field; Ask the agent (primary) and Copy request follow it. Then a row offers Show the sample session, and a Still seeing this? disclosure holds the reason, three steps, the bug report and contributing links, and the details in a code well with Copy details.
  The header keeps the title, the canvas handle, a Not connected badge in the attention tone (shown at every width), and Appearance; the rail, the session controls, and the skip link hide. Ask the agent becomes Asked the agent with a check and stays `aria-disabled`, keeping focus, for 30 seconds. The canvas menu and tooltips mount in whichever `main` shows.

| State         | Treatment                                                                                                  |
|---------------|------------------------------------------------------------------------------------------------------------|
| Loading       | Static skeleton rows in `--rw-bg-subtle`; no shimmer                                                       |
| Empty         | Explains what appears here, when, and who produces it                                                      |
| Error         | Names the problem and the recovery, with Retry                                                             |
| Live          | Header control "Live" with a pulsing success dot on a success tint while the canvas follows the agent      |
| Not live      | Header control "Follow agent" with a hollow dot, transparent until hovered, while it does not follow       |
| Reconnect     | Header control "Reconnecting" in the attention hue; the page polls until the stream returns                |
| Hidden        | Nothing polls while the page is hidden; the stream reconnects when it shows again                          |
| Saving        | The save button shows busy text ("Saving") and is disabled until the server answers                        |
| Conflict      | In-place notice with Compare, Keep my suggestion, and Start from the new text                              |
| Sent          | The feedback items move to Sent; a polite announcement names the count and the chat line                   |
| Warnings      | Collapsed attention notice above the phase: "N problems reading this task's files"                         |
| Switching     | "Showing" and the task and phase are announced; focus moves to the title when you switch                   |
| Following     | A move to another loop adds an accent note in the status area                                              |
| Failed        | Danger note in the status area, or a field error under its field; focus stays put                          |
| Not connected | The Not connected screen in place of the workspace; it leaves by itself once the agent connects the canvas |

## Motion

* Transitions run 150ms (hover and color) to 200ms (disclosure chevrons) with `cubic-bezier(0.2, 0, 0, 1)` and convey state only.
* Drawers slide in from their edge, and dialogs (the shortcut list and the file preview) rise 8px and fade in, each over 200ms.
* One authored moment: the Agent understood block reveals with a clip-path wipe from the top and a fade, 240ms, once per interpretation.
* When the agent points the person to an item (`focus_item`), the row receives a 1.2s fade from a 12 percent accent wash to transparent, once.
* The Live dot pulses gently, to 55 percent opacity over 2.4s, while the canvas follows the agent; nothing else animates continuously.
* Previews fade in and rise 2px over 150ms, and the lock ring fills linearly over the lock delay while the pointer rests.
* Under `prefers-reduced-motion: reduce`, transitions, the reveal, the wash, the preview fade, and the Live pulse are removed; a static "New" badge marks the change until the next update. The lock ring keeps filling, because it reports progress.

## Keyboard

| Key                       | Action                                                       |
|---------------------------|--------------------------------------------------------------|
| `1` to `5`                | View Research, Plan, Implement, Review, or Follow-up         |
| `n`                       | Go to the first item that needs you, then the next           |
| `f`                       | Follow the agent, or stop following                          |
| `[` and `]`               | Previous and next row                                        |
| `e`                       | Edit the focused row's section                               |
| `c`                       | Comment on the focused row                                   |
| `/`                       | Open the navigator and filter it                             |
| `b`                       | Show or hide the navigator                                   |
| `s`                       | Show or hide the steering panel                              |
| `l`                       | Show the ID legend                                           |
| `?`                       | Show the shortcut list                                       |
| `Alt+Left`, `Alt+Right`   | Go back and forward through the places moved to              |
| `Down Arrow` on an ID     | Lock its preview and move focus into it                      |
| `Shift+F10` or `Menu`     | Open the canvas menu for the focused element                 |
| `Escape`                  | Close a menu, drawer, or dialog, or leave the section editor |
| Arrow keys, `Home`, `End` | Move within the phase rail, radio groups, and menus          |

* `e` and `c` act on the row that has focus. Without one they announce how to reach a row, and `e` on a row without a section says so.
* `Escape` closes the innermost layer: the newest preview, then the appearance menu, then a drawer, then the editor when focus is inside it, which asks first when the draft changed. Open dialogs handle their own `Escape`, and `Escape` during input-method composition is left to the input method.
* Single-key shortcuts are ignored while focus is in a text field. The shortcut list has a switch that turns letter, number, and symbol shortcuts off; their hints then leave tooltips and `aria-keyshortcuts`, while `Escape` and arrow keys keep working.

## Accessibility

* Conformance target: WCAG 2.2 AA in Light, Dark, and More contrast using the canvas palette alone, and usable in forced colors.
* Landmarks: the header is a banner, the navigator a navigation region, the document the main region, and the steering panel a complementary region. Headings descend in order: the task title is the only `h1`; the phase title, outline, and Steer are `h2`; document rows and steering sections are `h3`; cards, board columns, record section summaries, and Markdown headings inside rows are `h4` and below. Scrollable regions and tables have names that differ from their row's name.
* Focus: a 2px `--rw-accent` outline on every focusable element, never removed without a replacement. The offset is 2px by default, 0 on text fields, inset 2px on rail tabs and the scrolling document where an outer ring would be clipped, and 6px around document rows. Sticky regions reserve scroll padding so focus is never obscured.
* Focus survives updates: after a re-render or an action, focus returns to the same control, else to its item or row, else to its steering section heading, never to the page body.
* Targets are at least 24 by 24 CSS pixels; the default control size is 28px, and header icon buttons are 32px.
* A polite live region announces material changes at most once per update: a new item needs you, an interpretation arrived, the agent moved to another phase, a save conflicted, a send finished, or the stream reconnected. Initial load stays silent.
* Color is never the only cue: every status has an icon and a word, diff lines have plus and minus markers, and the trace strip uses words and chevrons.
* Nothing requires dragging: board moves, task moves, and panel sizes have buttons or menus.
* Corrections, edits, and overrides prefill what the person already entered, so nothing is retyped. Each task of a real session keeps its own drafts, open editor, and scroll position in the page, so moving to a parent or child and back loses nothing.
* Diagrams are figures with a caption and a text alternative that lists nodes and relationships, plus Show as text.
* Previews meet WCAG 1.4.13: they open on hover and on focus, stay while hovered, and close with `Escape` without moving the pointer. A locked preview follows the non-modal dialog pattern, and focus returns to its ID when it closes.
* Tabs follow the ARIA tabs pattern, and radio groups and menus follow their ARIA patterns. The shortcut list and the file preview are modal dialogs that return focus to their opener. Drawers are the navigation and complementary regions shown over a scrim: while one is open the rest of the page is inert, and closing it with `Escape` or its close button returns focus to its toggle.

## Content and Copy

* Use sentence case for labels, buttons, and headings, and no label above a heading.
* Controls name their action: "Answer", "Looks right", "Not what I meant", "Send 2 items", "Add suggestion", "Open change".
* Address the person as "you" and refer to the agent as "the agent".
* IDs appear exactly as the artifacts write them, in monospace: `Q2`, `C5`, `W1`, `D3`, `P02-T01`, `FR-003`, `PC-002`, `RV-001`, `RD-004`.
* Times show local `HH:MM` with the full ISO time in a `title`; relative times ("3 min ago") update with the data, not on a timer.
* Never invent text. A value the session never recorded is left out with its label: times, line counts, owners, clearing text, review execution and depth, critique verdict and setting, confidence, and the next action. A row whose section was never recorded is left out, and an unrecognized status shows its recorded word in a neutral chip.
* All session text is untrusted. It renders through DOM text APIs and a restricted Markdown subset: headings, paragraphs, lists and task lists, emphasis, inline and fenced code, tables, block quotes (nested up to six levels), rules, and links limited to `http` and `https`, which open in a new browsing context with `rel="noopener noreferrer"`.
* Every link the canvas renders, including evidence sources, passes the same check; any other address renders as text with the address in its tooltip. A relative link in an RPI file is the one exception: it opens as a source in the canvas.

## Icons

Icons are authored inline SVG symbols in one sprite, on a 16px grid with a 1.5px stroke, round caps and joins, and `currentColor`. They extend the Session Log sprite and keep its shapes for shared meanings (person, sparkle, check, alert, info, chevron, search, panel, keyboard).

Additions: phase icons (research magnifier, plan list, implement brackets, review eye, follow-up loop), decision signpost, hand, inbox, send, undo, pencil, sun, moon, contrast, steer sliders, trace nodes, file, code file, diff, go-to, globe, left and right arrows, pin, legend, anchor, checklist, light bulb, shield check, half circle, trend down, and plug.
Discard uses a trash can (a lid with a handle over a tapered can with two ribs), the one icon for removing something you added.
Level and state icons: signal bars (three filled bars of rising height, unfilled bars at 28 percent opacity), priority marks (double chevron up, equals, chevron down), and the Live dot (filled with a ring) and its hollow form.
Emoji and Unicode glyphs never stand in for icons. Decorative icons carry `aria-hidden="true"`.

Four icons keep one meaning wherever they mark a click: go-to (a box with an arrow) goes to the item in the canvas, file (a page with a folded corner) opens it in place, globe opens a website, and code file opens your editor. Static badges and headings do not use them.

## Browser Surfaces

* Text selection uses a 28 percent accent tint (`::selection`), and the caret uses `--rw-accent`.
* Scrollbars are thin, with `--rw-border` thumbs on transparent tracks.
* Links underline with a 2px offset; underline thickness grows on hover.
* Placeholders use `--rw-fg-muted`, which meets 4.5:1.
* Code and diff wells use `tab-size: 2`, preserve whitespace, and scroll long lines inside the well.

## Revision Log

| Date       | Change                                                                                                                                                                                          | Reason                                                                                                                                  |
|------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------|
| 2026-10-23 | Initial guide                                                                                                                                                                                   | Canvas build                                                                                                                            |
| 2026-10-23 | Margin column is 272px and appears at 800px document width                                                                                                                                      | At 1440px with both panels docked the document is 840px, so the 880px rule hid every margin                                             |
| 2026-10-23 | Header rail moves to its own row below 1200px; labels go icon-only below 720px and 560px                                                                                                        | Narrow editor panels; replaces the More menu with reflow that keeps every control visible                                               |
| 2026-10-23 | Delivery modes are a compact segmented control with the chosen mode's hint below, after the queued items                                                                                        | Three bordered radio cards pushed queued feedback below the fold; the panel now reads items, then mode                                  |
| 2026-10-23 | Headings: rows `h3`, cards `h4`, Markdown headings `h4` and `h5`                                                                                                                                | axe heading-order: rows were `h2` under the `h2` phase title and cards skipped to `h4`                                                  |
| 2026-10-23 | Navigating to a tall target aligns it to the top; shorter targets center                                                                                                                        | A centered tall decision card hid its header beneath the sticky context bar                                                             |
| 2026-10-23 | Readiness line uses a 14px radius instead of a full pill                                                                                                                                        | Two-line readiness text looked like a stadium shape                                                                                     |
| 2026-10-23 | Edit answer, Edit override, and corrections restore the earlier choice and text                                                                                                                 | Nothing is retyped; dismissing a correction now reopens what it corrected                                                               |
| 2026-10-23 | Decisions with no row in a started phase render as full cards in the steering panel                                                                                                             | Such decisions were links to nothing, so they could not be answered or overridden                                                       |
| 2026-10-23 | Deliver sends only the previewed text; items being delivered show Sending                                                                                                                       | A queue change after preview could send different text, and items could be delivered twice                                              |
| 2026-10-23 | Unsaved drafts ask before discarding; a second Edit section returns to the open draft                                                                                                           | `Escape` and a second edit silently discarded typed changes                                                                             |
| 2026-10-23 | Focus returns to the same control, item, or section heading after updates                                                                                                                       | Re-renders and actions dropped keyboard focus to the page body                                                                          |
| 2026-10-23 | Focus offsets and header icon button sizes recorded as built                                                                                                                                    | The guide stated one 2px offset and 28px icon buttons; the canvas varies them on purpose                                                |
| 2026-10-23 | Drawers are inert-backed regions over a scrim, not dialogs; dialogs and drawers animate                                                                                                         | The guide described drawers as dialogs and omitted their motion                                                                         |
| 2026-10-23 | Implement groups changes by task and discoveries by kind                                                                                                                                        | The lists were flat, so a task's work and a kind's discoveries were hard to scan                                                        |
| 2026-10-23 | Change cards inside a task group omit the task chip and keep the time on the title line                                                                                                         | The group heading already names the task; the repeated chip pushed the time onto a line of its own                                      |
| 2026-10-23 | Trace strips derive from reference fields and follow the longest path onward                                                                                                                    | Static strips missed work the agent recorded during the session                                                                         |
| 2026-10-23 | Links outside `http` and `https` render as text everywhere, with editor links built from absolute paths                                                                                         | Evidence links bypassed the scheme check, and editor links were malformed on Windows                                                    |
| 2026-10-23 | Real sessions get a source label, a parent link, Open in editor, warnings, and record rows                                                                                                      | The canvas now reads RPI files, so it says which task and files it shows and keeps sections no view shows                               |
| 2026-10-23 | Decisions rows hold a phase's recorded decisions; the steering panel links one row per phase                                                                                                    | A real session records many decisions, which buried the rest of the panel as separate cards or links                                    |
| 2026-10-23 | Answers and overrides can be written in the person's words when there are no options or alternatives                                                                                            | Decisions read from files often list no options, so they could not be answered or overridden                                            |
| 2026-10-23 | Decision titles take their own line; a pending override keeps the agent's original choice in view                                                                                               | Long titles squeezed into narrow columns, and the card showed the override as the agent's choice                                        |
| 2026-10-23 | Values never recorded are left out instead of showing "Not recorded"                                                                                                                            | Files omit times, line counts, and depths, and placeholders crowded the views                                                           |
| 2026-10-23 | Show this task switches tasks and keeps each task's drafts, editor, and scroll position                                                                                                         | A child loop and its parent are one session, and moving between them should not lose work                                               |
| 2026-10-26 | Send to agent sits in the header and opens a send dialog; the delivery modes are gone                                                                                                           | The person could not tell how input reached the agent: Queue was never read, and Attach shows nothing in VS Code                        |
| 2026-10-26 | Edits are suggestions shown beside the section's source text                                                                                                                                    | The canvas never writes the files, yet a saved edit replaced the text as if it had, then vanished on import                             |
| 2026-10-26 | Checklist items take Looks good or Needs work, and the review goes with the next send                                                                                                           | Checkboxes and Share review hid the purpose and could not tell "not reviewed" from "needs work"                                         |
| 2026-10-26 | The canvas handle appears in the source badge and starts every message                                                                                                                          | The agent could not tell which canvas a message came from                                                                               |
| 2026-10-26 | The phase rail takes its own row below 1400px; Markdown table regions name their section                                                                                                        | The header's new control pushed the meta line under the rail; tables with the same columns had duplicate names                          |
| 2026-10-26 | Session line, session menu, session tree, follow state, status notes, field errors, and Send groups                                                                                             | A canvas shows a whole session: its loops, where it is following, and every loop's unsent items; failures must be seen                  |
| 2026-10-26 | Decision cards take options from the file's decision block and always end with Your own answer; Override adds Something else                                                                    | People could not answer in their own words once a decision listed options, and file decisions had no options at all                     |
| 2026-10-26 | Icons say what a click does: go-to, page, globe, and code file; the canvas badge uses the message icon                                                                                          | The same ID navigated in one place and expanded in another, and the box with an arrow also meant leaving the canvas                     |
| 2026-10-26 | Previews, the legend, source chips and the source sheet, and Back and Forward                                                                                                                   | The person could not read an ID without losing their place, check a source at the cited spot, or retrace their steps                    |
| 2026-10-26 | The canvas badge has its own slot; the session label shortens first; the meta line wraps below 560px                                                                                            | At 768px and 1440px the badge was clipped                                                                                               |
| 2026-10-26 | A render failure replaces the document with its reason and Retry, and reaches `get_state`                                                                                                       | A stored sample from an earlier version crashed rendering and left only the loading skeleton                                            |
| 2026-10-26 | Badge and notice tone defaults move into `:where()` rules                                                                                                                                       | Their own `--tone` default overrode every tone class, so badges showed muted icons and Medium priority read as gray                     |
| 2026-10-26 | ID family hues, strong badges for confidence, priority, type, and severity, and syntax colors in the source sheet                                                                               | The person asked for color coding that works in light and dark, and highlighted code                                                    |
| 2026-10-26 | One Live control replaces the connection chip, the Following label, Resume following, and Go to the agent's phase                                                                               | The person asked to follow the agent's loop and phase from one control that shows its state                                             |
| 2026-10-26 | Canvas tooltips, part comments with a hover button and quotes, row actions shown on hover, and the canvas menu                                                                                  | VS Code's canvas shows no title tooltips, and its right-click menu highlighted elements and commented in the chat instead of the canvas |
| 2026-10-27 | A canvas with no session shows the Not connected screen; the sample opens only when asked for                                                                                                   | A reopen that lost its session showed the sample, which looked like the person's own work and hid that the canvas needed connecting     |
| 2026-10-27 | Plan shows a running critique's lens progress, the revision's progress, and Updated marks on changed text                                                                                       | The critique and its revision landed all at once, so a person had nothing to read while they ran                                        |
| 2026-10-27 | Review and send replaces Send to agent: every loop's items to go to, edit, or discard, with a second press to discard                                                                           | Your feedback counted items in other loops without naming them, and items could be removed but not changed                              |
| 2026-10-27 | Implement pins the task board, adds filtered Phases and tasks and a change map with progress, and moves Now to the steering panel                                                               | The board scrolled away, the plan's phases were only on Plan, and Now took the top of the page                                          |
| 2026-10-27 | Implement's change map draws in-progress parts in the accent tone and outlines the chosen phase; every Review and send row names its phase; the style guide states the board's narrow-panel cap | Done and in-progress parts looked alike, the legend promised a fill the map did not draw, and rows about a plain ID named no phase      |

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
