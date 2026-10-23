---
title: Session Log Canvas Style Guide
description: Visual language, log grammar, interaction rules, and accessibility requirements for the hve-core Session Log canvas
author: Microsoft
ms.date: 2026-10-23
ms.topic: reference
keywords:
  - canvas
  - session log
  - style guide
  - design system
---

## Purpose and Principles

The Session Log canvas turns a Copilot session's event stream into a log that a person can read top to bottom and still trust as evidence. It is an operate-mode tool: people use it to answer questions such as "which instructions were loaded", "what did that tool return", and "what did the subagent actually do". Fast scanning and consistency outrank expression.

* Show the conversation the way Copilot experienced it: system prompt, user prompt, assistant turns, tool calls, and subagents, in recorded order.
* Keep the reading path quiet. Bulky material (system prompt, reasoning, hooks) starts collapsed behind a one-line summary that already answers the common question. Tool arguments and output show inline in bounded boxes because they are the substance of a tool call.
* Make every number traceable. Counts, tokens, and durations come from recorded events, and the UI never estimates a value it cannot read.
* Treat all session text as untrusted data. It is displayed, never interpreted.
* Spend CPU only when something changed. No perpetual animation, no polling while hidden, no rendering of off-screen pages.

## Color

The palette is restrained: neutral surfaces, one accent for interaction and selection, and a small set of role hues that appear only on role markers and labels. Role hue never carries meaning alone; every role also has an icon and a text label.

Tokens resolve host variables first and fall back to the canvas palette. Hosts that inject GitHub-style tokens (`--background-color-default`, `--text-color-default`, and similar) get a native look; all other hosts get the fallbacks, which must meet WCAG 2.2 AA on their own. The page declares `color-scheme: light dark` and switches fallbacks with `prefers-color-scheme`.

### Surface and Text Tokens

| Token               | Role                                     | Light fallback | Dark fallback |
|---------------------|------------------------------------------|----------------|---------------|
| `--sl-bg`           | Page and log surface                     | `#ffffff`      | `#0d1117`     |
| `--sl-bg-subtle`    | Sidebar, header, second neutral layer    | `#f6f8fa`      | `#151b23`     |
| `--sl-bg-inset`     | Code and payload wells                   | `#f6f8fa`      | `#010409`     |
| `--sl-bg-hover`     | Row hover                                | `#eff2f5`      | `#1b222c`     |
| `--sl-bg-selected`  | Selected row                             | `#ddf4ff`      | `#12263f`     |
| `--sl-fg`           | Primary text                             | `#1f2328`      | `#e6edf3`     |
| `--sl-fg-muted`     | Metadata and secondary text              | `#59636e`      | `#9198a1`     |
| `--sl-border`       | Dividers, card and control borders       | `#d1d9e0`      | `#30363d`     |
| `--sl-border-muted` | Timeline rail and inner separators       | `#e3e8ec`      | `#21262d`     |
| `--sl-accent`       | Links, primary actions, selection, focus | `#0969da`      | `#4493f8`     |
| `--sl-accent-fg`    | Text on accent fills                     | `#ffffff`      | `#0d1117`     |
| `--sl-focus`        | Focus ring                               | `#0969da`      | `#4493f8`     |

### Role and Status Tokens

| Token          | Use                                    | Light     | Dark      | Icon         |
|----------------|----------------------------------------|-----------|-----------|--------------|
| `--sl-system`  | System prompt, session events, notices | `#59636e` | `#9198a1` | gear         |
| `--sl-user`    | User prompts, injected context         | `#8250df` | `#ab7df8` | person       |
| `--sl-assist`  | Assistant messages and reasoning       | `#1a7f37` | `#3fb950` | sparkle      |
| `--sl-tool`    | Tool calls and results                 | `#bc4c00` | `#ffa657` | wrench       |
| `--sl-agent`   | Subagents, agent tree, breadcrumbs     | `#bf3989` | `#db61a2` | branch nodes |
| `--sl-compact` | Compaction dividers, rows, meter ticks | `#127874` | `#3cbcb0` | arrows in    |
| `--sl-success` | Successful completion                  | `#1a7f37` | `#3fb950` | check        |
| `--sl-warning` | Warnings, retrying, partial data       | `#9a6700` | `#d29922` | triangle     |
| `--sl-danger`  | Errors, failed tools, aborts           | `#d1242f` | `#f85149` | circled x    |

Each role and status hue reaches at least 4.5:1 against `--sl-bg` and `--sl-bg-subtle` in its scheme, so it can color small text. `--sl-compact` also reaches 4.5:1 on its own 8 percent band tint (4.75:1 light, 7.24:1 dark). Badge tints use the hue at 12 percent opacity behind text in `--sl-fg`, never hue-on-tint text.

## Typography

One family carries the interface; monospace is reserved for code, payloads, identifiers, and measurements.

* UI and prose: `-apple-system, BlinkMacSystemFont, "Segoe UI Variable Text", "Segoe UI", system-ui, Ubuntu, "Helvetica Neue", Arial, sans-serif`.
* Code and data: `ui-monospace, "SF Mono", "Cascadia Code", "Cascadia Mono", Menlo, Consolas, "Liberation Mono", monospace`.
* No web fonts and no remote resources.

| Step          | Size and line height | Weight | Use                                       |
|---------------|----------------------|--------|-------------------------------------------|
| `--sl-t-xl`   | 20px / 28px          | 600    | Session title in the header               |
| `--sl-t-lg`   | 16px / 24px          | 600    | Sidebar section titles                    |
| `--sl-t-md`   | 14px / 22px          | 400    | Message prose, entry labels (600)         |
| `--sl-t-sm`   | 12px / 18px          | 400    | Metadata, badges, timestamps, table cells |
| `--sl-t-code` | 12.5px / 19px        | 400    | Monospace payloads, tool names, IDs       |

* Compact controls (buttons, tabs, navigation rows, session titles, and data tables) use 13px / 20px so sidebar rows fit the 280px column. The agent card title uses 14px / 20px at weight 600.
* Message prose wraps at 76 characters (`max-width: 76ch`). Tool payload wells wrap long lines so arguments and results stay readable in narrow panels; fenced code in messages keeps its lines and scrolls horizontally.
* Numbers in metadata, tables, and meters use `font-variant-numeric: tabular-nums`.
* Headings inside rendered Markdown step down: Markdown `h1` renders at `--sl-t-lg`, `h2` and below at `--sl-t-md` with weight 600.

## Spacing, Shape, and Depth

* Base unit 4px. Use 4, 8, 12, 16, 24, and 32.
* Entries in one turn sit 8px apart; turns sit 16px apart; interactions (a user prompt and everything it caused) sit 24px apart, and the timeline rail breaks across that gap so each prompt visibly starts a new section.
* Controls are 28px tall (24px compact) with a 6px radius. Cards and payload wells use an 8px radius.
* Borders are 1px. Do not use thick colored side borders on entries or callouts.
* Shadows appear only on floating layers, and floating layers use elevation instead of a hairline border: drawers and the shortcut dialog use `--sl-shadow` (`0 8px 24px rgb(0 0 0 / 0.12), 0 1px 3px rgb(0 0 0 / 0.08)` in light, `0 8px 24px rgb(0 0 0 / 0.5)` in dark) on `--sl-bg-subtle`; the floating scroll buttons use the smaller `--sl-shadow-float`.

## Layout

```text
+------------------------------------------------------------------------------+
| [=] Session title, repo/branch, host   live status, refresh, actions   [=]   |
+---------------+--------------------------------------+-----------------------+
| Sidebar tabs  | Previous-prompt bar                  | Agent title bar       |
|  Sessions     | Breadcrumb: Session / subagent / ... | [Activity] [Context]  |
|  Outline      | Log feed (paged, recorded order)     | Activity: overview,   |
|   Agents      |   interaction divider                |   Agent instructions, |
|   Prompts     |   entry, entry, compaction band ...  |   System prompt,      |
|  Details      |                                      |   Compactions,        |
|               |                                      |   Tool calls          |
|               |                                      | Context: filter and   |
|               |                                      |   ten sections, or a  |
|               |                                      |   definition page     |
+---------------+--------------------------------------+-----------------------+
```

* Three regions: the sidebar (280px, `--sl-sidebar-w`), the log, and the inspector (304px, `--sl-inspector-w`). Both side panels use `--sl-bg-subtle`, and their top bars (the sidebar tabs and the inspector's agent title bar) share one 41px height (`--sl-panel-bar`).
* A divider on each docked panel's inner edge resizes it: the sidebar from 248px (the narrowest that fits its tabs and width button) and the inspector from 260px, up to 760px, always leaving the log at least 400px. Widths last while the page is open, and shrinking the window clamps them.
* A width button at the right of each panel's tab bar is the pointer alternative to dragging: each press steps to the next named width (sidebar 248, 280, 380, and 520px; inspector 260, 304, 440, and 600px, each capped by the room left for the log) and wraps from the widest to the narrowest. Its name and tooltip give the current and next width.
* Header (`--sl-bg-subtle`, one 40px row): the sidebar toggle at the left edge, the session title at 16px with the repository, branch, and host line beside it (both truncated), the live status chip (also the pause control), refresh time, icon buttons for Use current session, Follow latest, and Keyboard shortcuts, and the inspector toggle at the right edge.
* Each panel toggle fills its side of the icon while the panel is shown and names its action ("Hide sidebar (b)"); the key drops from the name while single-key shortcuts are off.
* Side panels dock when there is room: the sidebar at 900px and wider, the inspector at 1180px and wider.
  * A docked panel collapses to a 0-width track, and the log, the previous-prompt bar, and the scroll buttons take the space. The track animates over 200ms while the panel content keeps its width and is clipped.
  * Below those widths a panel opens as a drawer from its edge over a scrim. An open drawer is modal: the header, the log, and the other panel are inert, so focus stays in the drawer. The scrim, Escape, or the panel's shortcut closes it, and choosing a row in a drawer closes it.
  * Hidden panels are inert. Closing a panel that held focus returns focus to its toggle, and so does a resize or zoom that crosses a threshold and hides it.
* Sidebar tabs:
  * Sessions: a filter field and the session list, newest first. Rows show repository, branch, host, and the working folder (last two segments, full path on hover), with the current session marked Current.
  * Outline: Agents (the agent tree; each node shows start and end time or "running", input and output tokens, and latest context percent) and Prompts (the agent's user prompts, oldest first, opening scrolled to the newest).
  * Details: session facts (including Copilot version and premium requests), main agent model facts, and a "Show what the model is given" button that opens Context.
* Inspector, for the agent shown in the log:
  * Title bar: agent icon, name, role ("main agent") or type badge, and status or Active.
  * View tabs: Activity and Context in a 34px bar under the title bar, with the sidebar's underline treatment. The inspector remembers the chosen view while the page is open.
  * Overview: a subagent's description (clamped to three lines), the model line, a stat grid (turns, tool calls, subagents, requests, tokens, duration, models used) whose labels wrap within a shared grid row so values stay aligned, and the context meter.
  * Agent instructions, when the agent has its own: a subagent's agent definition (the opening of its prompt) or the selected custom agent's `<agent_instructions>` block in the main prompt. In prompt reveals the system prompt version they came from. A bounded box (titled with the agent's name) previews the start as Markdown, and Expand shows the full text; the box head carries the size.
  * System prompt: Show latest, then versions newest first, the latest marked Latest. Each row has the version and time, why it was rebuilt, and the size, size change, and section changes; selecting it reveals and opens that version.
  * Compactions: newest first, each with status and time in `--sl-compact` (failed in `--sl-danger`), tokens before and after with the reduction, then messages removed, trigger, duration, and checkpoint. Selecting one reveals its band. With none, the list explains when Copilot compacts.
  * Tool calls: the filter, status segments, previous and next tool buttons, the count, and the call list. A sort button names and toggles the order; oldest first keeps the newest row in view. Compactions also appear in order in the list with a dashed `--sl-compact` outline.
  * Context (its own view): a filter over every section, a status line that says where the lists come from (or the match count), and ten sections in a fixed order: Tools, Skills, Agents, Subagents, Canvases, Instructions, MCP servers, Hooks, Plugins, Extensions. Tools starts expanded.
  * While filtering, Context sections with matches open and headings read "3 of 225" without changing the saved collapse state.
* Section headings are toggles with a chevron and a muted count; a collapsed section gives its height to the sections that stay open. A heading stays on one line; in a narrow panel the actions beside it (sort chips, Show latest, In prompt) move to the next line.
* Lists sit in bounded scroll wells (`--sl-bg`, 1px `--sl-border-muted`, 8px radius) that shrink before their panel scrolls. In the Outline, Agents takes up to 45% and Prompts fills the rest. Wells re-render only when their data changes and keep keyboard focus and scroll position.
* Inspector sections are never taller than their content, in both views. Short lists (up to four items, or a Tool calls list with up to four rows) keep their full height. Longer sections start from a floor set on the section and share the free height, Tool calls taking a double share:
  * System prompt and Compactions: the heading and one item, growing to a 188px well (no limit while Tool calls is collapsed).
  * Agent instructions: the heading, the box head, and about two lines, growing to a 120px preview. Expanded instructions keep their full height.
  * Tool calls: the heading, controls, count, and about three rows.
  * Context lists of five or more items: the heading, note, and about two and a half rows, so a cut-off row shows there is more.
  * Wells keep only a small backstop, so a heading or note that wraps takes height from its list rather than overlapping the next section. A panel scrolls only when the floors do not fit.
* Main column: breadcrumb and the log feed, which take the full width of the column. Running prose (paragraphs, lists, quotes, headings) in log entries keeps a 90ch measure; code, payload boxes, tables, and cards use the full width. Only the log column and side panels scroll; the document is clipped and never scrolls.
* A previous-prompt bar sits above the log. It always shows the latest prompt that starts above the top of the visible log (time and first line); selecting it scrolls that prompt to the top, and the bar then shows the prompt before it. Scrolling updates it. At the first prompt it reads "No earlier prompt in this log" and is disabled.
* Floating Scroll to top and Scroll to latest buttons sit at the bottom right of the log; the latest button carries a count of newer unloaded entries.
* Below 900px the refresh time is hidden. Below 640px the repository line is hidden so the title keeps the row, and the log uses 10px side padding with a 22px marker column. No title, code line, or table may widen the page past the panel; wide content wraps or scrolls inside its own box. The context meter text wraps rather than dropping values.

## Log Grammar

Every entry shares one anatomy:

```text
[rail marker]  Label  ·  meta (time, duration, tokens, model)   [status]
               one-line summary or prose body
               > disclosure: details, payloads, raw event
```

* The rail is a 1px `--sl-border-muted` line. Markers are 20px circles with a 12px role icon in the role hue on a 12 percent tint.
* The label names the kind in plain words ("User", "Assistant", "Tool", "Subagent", "System prompt"), followed by the specific name where one exists (`bash`, `RPI Researcher`).
* Meta text uses `--sl-t-sm` in `--sl-fg-muted`, separated by spaced middle dots.
* Status appears as an icon plus a word (Succeeded, Failed, Running, Aborted). In navigation lists the icon carries the status visually and the word is visually hidden text in the row's accessible name.

| Kind              | Source events                                                                        | Collapsed view                                                                                                                           | Expanded view                                                               |
|-------------------|--------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------|
| Agent card        | `session.start`, `subagent.started`, `subagent.configured`, model and usage events   | In the Outline panel: name, model and effort, facts, context meter, System prompt control                                                | Version list; each version reveals and opens its entry                      |
| System prompt     | `system.message`                                                                     | "System prompt" or "System prompt rebuilt", version N of M, size and change, sections, static share                                      | Facts, then drill rows for that version: sections, skills, files, full text |
| User prompt       | `user.message`                                                                       | Full prompt text as Markdown and attachment chips                                                                                        | Injected context (`transformedContent`) when it differs, source, delivery   |
| Turn divider      | `assistant.turn_start`, `assistant.turn_end`, `session.usage_record`, hooks          | "Turn N", duration, tokens, context percent, hook count, and each failed hook with its error                                             | Hook runs (type, tool, status, time); each opens input, output, and error   |
| Assistant message | `assistant.message`                                                                  | Content as Markdown and the tool request count                                                                                           | Reasoning text, model, request IDs                                          |
| Tool call         | `tool.execution_start`, `tool.execution_complete`, `external_tool.*`                 | Name, intent, status, duration, Arguments box (top), Error and Output boxes (latest), collapse                                           | Boxes grow with a scroll bar and full text; telemetry and raw events        |
| Subagent          | `task` call joined with `subagent.started`, `subagent.completed`, `subagent.failed`  | Card: display name, agent type, status, description (clamped to three lines), model, duration, tool calls, tokens, and Open subagent log | Description, execution mode, error                                          |
| Skill             | `skill.invoked`, `skill.invoked_ref`                                                 | "Skill loaded", name, source or plugin, trigger                                                                                          | Description and path                                                        |
| Model change      | `session.model_change`                                                               | "Model changed", new model and effort                                                                                                    | Source and tier                                                             |
| Compaction        | `session.compaction_start`, `session.compaction_complete`, `model.messages_snapshot` | Dashed band: "Context compacted", tokens before and after, share removed, messages removed, facts                                        | Drill rows: compaction request and summary response; raw events             |
| Notification      | `system.notification`                                                                | Kind in words ("Agent idle", "Shell completed") with an agent link when present                                                          | Full notification text                                                      |
| Permission        | `permission.requested`, `permission.completed`                                       | Requested permission and outcome                                                                                                         | Request detail                                                              |
| Info and problems | `session.info`, `session.warning`, `session.error`, `abort`                          | Message with a status icon                                                                                                               | Detail fields                                                               |
| Unknown           | Any other type                                                                       | Event type and time                                                                                                                      | Raw event (formatted JSON)                                                  |

* Hook events never become entries; they run about twice per tool call. Start and end events pair into runs attached to their turn (prompt and session-start hooks attach to the turn they precede). Failed runs show inline with their error message; every run opens its input, output, and error (message, source, stack).
* Input and output boxes: about 168px tall when collapsed. Arguments and inputs show their start with a fade at the bottom; output, errors, and hook outputs show their latest text with a fade at the top. Box heads stay on one line: the title truncates first, so the size and Expand keep their place.
* Selecting a box or its Expand button grows it to `min(70vh, 720px)` and loads the full text when the preview was cut; output starts at the end.
* An expanded box scrolls only while focused (clicked into) and shows "Click inside to scroll" when it has more to show; otherwise the wheel scrolls the log. Code wells in the feed follow the same rule. Nothing traps the wheel: boxes without overflow, and boxes at their end, pass it to the log.
* Short content shows without a fade or Expand button and does not expand on click. A box that shrinks with its panel (the instructions preview) gains the fade and Expand as soon as its text is cut off. A chevron in the tool header hides or shows the boxes, and choices survive live refreshes. Live updates carry previews, so tools that finish after first render keep their boxes.
* System prompt text highlights XML-style tags in `--sl-tok-num`. JSON in boxes and raw events is syntax highlighted: keys `--sl-tok-key`, strings `--sl-tok-str`, numbers `--sl-tok-num`, `true`, `false`, and `null` `--sl-tok-lit`, punctuation `--sl-fg-muted`. Every token color meets 4.5:1 on `--sl-bg-inset` in both schemes.
* The log is in recorded order. Copilot records the system prompt again whenever it rebuilds it, for example after a resume, a compaction, a model change, or a notification, so a session can hold several versions at different points. Version 1 explains what the prompt is; each later version says what preceded it and which sections were added, removed, or resized, and that it applies to requests from there on.
* Compaction is a band in `--sl-compact`: 1px dashed rules above and below, a 6 percent tint, and the label in the hue. Facts list model, trigger, tokens used, the system, conversation, and tool split before and after, and the checkpoint. The request (the instruction sent with the conversation, the last user message of the call's recorded snapshot) and the summary response open as tag-highlighted boxes; when the session did not record the request, a note says so.
* When a compaction ran in the background across other entries, a start marker (dashed top rule only) sits where it began and the result band sits where it finished, each linking to the other.
* `model.*` debug events and binary assets appear only as counts in the Details tab. A compaction's request snapshot is located by byte range during indexing and read only when its drill row opens.
* Tool requests inside an assistant message link to their tool entries.
* A subagent log reuses the same grammar. Its breadcrumb shows each ancestor, and Escape or an ancestor crumb returns to that log at the spawning tool call.

## Navigation

* The log is an ARIA feed (`role="feed"`) of `article` entries with `aria-posinset` and `aria-setsize`; each article is labeled by its header.
* Deep links use the hash `#agent=<agentId>&entry=<seq>`. Loading a link selects the agent, loads the page containing the entry, scrolls it into view, and moves focus to it.
* The tool index filters by name and by status (all, failed, running); compaction rows match "compaction" and follow the status filter. Selecting a tool reveals and expands its entry; selecting a compaction reveals its band. Previous and next tool buttons step from the last focused entry, matching `[` and `]`.
* Inspector rows for system prompt versions and compactions reveal their entries the same way.
* A Context row opens its definition page in place. Back (or Escape) returns to the list with the row focused and the list where it was. Links between items (an MCP server's tools, a plugin's skills, an extension's canvases) stack pages, and Back names the page it returns to. Actions on a page ("Show latest call", "Show in log", "Open log") reveal the log and close a drawer.
* Follow latest keeps the feed pinned to the newest entry while on. Scrolling up turns it off; the toggle and the End shortcut turn it back on.
* Pages hold up to 200 entries. Earlier pages load on demand with a "Load earlier entries" button at the top of the feed.

### Keyboard

| Key                             | Action                                                                                                                      |
|---------------------------------|-----------------------------------------------------------------------------------------------------------------------------|
| `j` and `k`                     | Next and previous entry                                                                                                     |
| `]` and `[`                     | Next and previous tool call                                                                                                 |
| `Enter` or `Space` on a summary | Expand or collapse                                                                                                          |
| `o` on a subagent card          | Open the subagent log                                                                                                       |
| `Escape`                        | Close a definition page or a drawer, else return to the parent log                                                          |
| `/`                             | Filter sessions (Sessions tab), tool calls (Activity), or Context                                                           |
| `b`                             | Show or hide the sidebar                                                                                                    |
| Arrow keys on a panel divider   | Resize the panel by 16px (64px with `Shift`); `Home` and `End` go to the narrowest and widest; `Enter` restores the default |
| `i`                             | Show or hide the inspector                                                                                                  |
| `Home`                          | Scroll to the first entry                                                                                                   |
| `End`                           | Jump to the newest entry and resume following                                                                               |
| `?`                             | Show the shortcut list                                                                                                      |

Single-key shortcuts are ignored while focus is in a text field. The shortcut list has a switch that turns letter and symbol shortcuts off; their key hints then leave tooltips and `aria-keyshortcuts`, and `Escape`, `Home`, `End`, and component arrow keys keep working.

## Components and States

Every interactive control has default, hover, focus, active, disabled, and busy states drawn from the tokens.

* Focus: a 2px `--sl-focus` outline with a 2px offset on every focusable element, including entries, summaries, tabs, and list rows. Never remove an outline without a replacement.
* Selection: list rows use a `--sl-bg-selected` fill plus a 600 weight label. The active sidebar tab uses a 2px `--sl-accent` underline so it reads as a tab rather than a row. The accent is not used for decoration.
* Buttons: neutral by default (`--sl-bg` with a border); accent fill only for the single primary action in a view.
* Disclosures use native `details` and `summary` with a chevron icon that rotates 90 degrees.
* Badges: `--sl-t-sm`, fully rounded, tinted background, text in `--sl-fg`.
* Context meter: a 6px bar of `--sl-border-muted` with the latest usage in `--sl-accent`, a peak tick in `--sl-fg-muted`, and compaction ticks in `--sl-compact` at the pre-compaction token count. The peak includes pre-compaction counts. Text beside it states latest, limit, percent, and peak; the bar is decorative (`aria-hidden`) because the text carries the values.
* Navigation lists (prompts, tools) show plain-text summaries with Markdown markers removed; the log itself renders the Markdown.
* Clamped descriptions: three lines, then a 12px Show more link that appears only while text is cut off; Show less collapses it again. The choice and the last measurement survive live refreshes, so a focused link keeps focus.
* Panel dividers: a 9px `col-resize` hit area over the panel's inner edge with a 3px line, `--sl-accent` at 70% on hover and while dragging and `--sl-focus` when focused (the line replaces the focus outline). Each is a focusable `separator` whose value is the panel width; a double-click restores the default. Dividers hide while their panel is collapsed or opens as a drawer, and dragging turns off the panel transition and text selection.
* Sort chips: fully rounded, 24px tall, `--sl-t-sm`, in the section heading row with no visible "Sort" label (the group is labeled for assistive technology). The pressed chip (`aria-pressed="true"`) has an accent-tinted fill and border and a 600 weight. Each chip names the order it applies ("Most calls", "Fewest runs", "A–Z", "Z–A"); selecting the pressed chip reverses it.
* Context rows: a full-width button. The first line holds the name (600; tools and hooks in `--sl-mono`) and, right-aligned in tabular numerals, the use count ("7 calls", "Loaded 2×", "Not called" in `--sl-fg-muted`) with failures in `--sl-danger`. The second line holds badges (MCP server, On demand, Built-in, Current, status) and the description, clipped to one line with an ellipsis; the full text is in the title.
* Definition page: Back (named for where it returns) and the kind on one line, the name at 15px 600, then the count line with badges, then facts, `--sl-t-sm` 600 sub-headings, parameter and run lists with a 2px `--sl-border-muted` left rule, related-item links, and bounded boxes. Box headers wrap instead of squeezing the title. When the definition is not this session's, an info note says so before anything else.
* Definition text: descriptions and server instructions render as prose; prompts, skill text, and file content keep their exact text with tags highlighted; JSON is indented, then highlighted.

| State                   | Treatment                                                                                                                                               |
|-------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------|
| Loading                 | Static skeleton rows in `--sl-bg-subtle`; no shimmer                                                                                                    |
| Empty list              | Explains where sessions are read from (the resolved folder) and how `COPILOT_HOME` changes it                                                           |
| Empty session           | "No recorded events yet" with the session ID; the page retries with backoff and loads the log once events appear                                        |
| Live                    | "Live" with a filled dot when the session is active and polling succeeds                                                                                |
| Idle                    | "Up to date" when the session is not active and polling succeeds                                                                                        |
| Paused                  | "Paused" with a pause icon and the chip pressed while the reader pauses live updates, or "Paused" while the page is hidden; polling stops               |
| Retrying                | "Retrying" in `--sl-warning` after one or two failed refreshes; Live never shows then                                                                   |
| Stale                   | "Stale" in `--sl-warning` after three failed refreshes                                                                                                  |
| Error                   | Names the problem and the recovery, with a Retry button                                                                                                 |
| Partial text            | "Showing 128 KB of 346 KB" with Load more                                                                                                               |
| Reconstructed inventory | Each Context section's note names its source ("Live, with loads from the log", "From the system prompt and recorded calls", or partial with the reason) |
| Not recorded            | "Not recorded in session" in `--sl-fg-muted`                                                                                                            |

## Motion

* Transitions run 150 to 200ms with `cubic-bezier(0.2, 0, 0, 1)` and convey state only: disclosure open, tab change, and new-entry arrival.
* New entries receive a 1.2s fade from a 12 percent accent wash to transparent, once.
* Nothing animates continuously. The live dot is static.
* Under `prefers-reduced-motion: reduce`, transitions and the new-entry wash are removed; new entries keep a static "New" badge until the next refresh.

## Content and Copy

* Use sentence case for labels, buttons, and headings.
* Controls name their action: "Open subagent log", "Show full text", "Load earlier entries", "Use current session".
* Times show local `HH:MM:SS` in entries and relative dates ("Today 14:02", "Oct 19") in the session list, with the full ISO time in a `title` attribute.
* Tokens render as `950`, `12.4k`, `968k`, `1.4M`. Durations render as `850 ms`, `12.4 s`, `3 m 05 s`. Sizes render as `12 KB` and `3.4 MB`.
* Never invent text. A missing value renders as "Not recorded".
* Session text renders through DOM text APIs and a restricted Markdown subset: headings, paragraphs, lists, emphasis and strikethrough, inline code, fenced code, tables, block quotes nested up to six levels, horizontal rules, and links limited to `http` and `https`. Links open in a new browsing context with `rel="noopener noreferrer"`. Block patterns match in linear time, and an entry that fails to render shows as plain text.

## Browser Surfaces

* Text selection uses an accent tint (`::selection`).
* Scrollbars are thin and use `--sl-border` thumbs on transparent tracks (`scrollbar-color`, `scrollbar-width: thin`).
* Code wells use `tab-size: 2` and preserve whitespace. Fenced code scrolls long lines horizontally; tool payload wells wrap them.
* Focus outlines, caret color, and link underline offset come from tokens.

## Icons

Icons are authored inline SVG symbols in one sprite: 16px grid, 1.5px stroke, round caps and joins, `currentColor`. Emoji and Unicode glyphs never stand in for icons. Decorative icons carry `aria-hidden="true"`; icon-only buttons carry an accessible name.

## Accessibility

* Text and focus indicators meet WCAG 2.2 AA in both schemes using fallback tokens alone.
* Every control is reachable and operable by keyboard in a logical order: header, sidebar tabs and panel, breadcrumb, then the feed.
* A polite live region announces refresh results ("Updated 14:02:31, 3 new entries") at most once per refresh and only when something changed. It also announces once when refresh becomes stale, when it recovers, and when the shown session starts or stops being live; initial load stays silent.
* Filtering Sessions or Tool calls announces the result ("3 of 40 sessions", "No tool calls match.") through the same live region without moving focus.
* The status chip pauses and resumes live updates (WCAG 2.2.2), the shortcut list turns single-key shortcuts off (WCAG 2.1.4), and each panel's width button replaces dragging for pointer users (WCAG 2.5.7).
* Refreshed navigation lists (Sessions, Agents, Prompts, and Tool calls) keep focus on the same row, matched by its key, and fall back to the row at the same position.
* Tabs follow the ARIA tabs pattern with arrow-key movement; the feed follows the ARIA feed pattern.
* Target sizes are at least 24 by 24 CSS pixels.

## Resource Rules

* Poll only while `document.visibilityState` is `visible` and the reader has not paused updates: selection and entries about every 2 seconds and the session list about every 15 seconds. Back off to 10 seconds after an error. A poll that delivers one page of a larger burst keeps its previous version and polls again after 50ms until the rest arrives.
* Keep at most two pages of entries rendered at once; drop pages far from the viewport and reload them on demand.
* Fetch payloads only when a disclosure opens, and cache them per entry until the session changes or its index is rebuilt (cache keys include the index epoch).
* Load a definition only when its page opens. Keep at most 40 in the page, render a cached one at once, and reload it in the background when the inventory changed or, while the page is open, when the log grew (at most every 5 seconds).
* Load Context lists only while the Context view shows: reload them when the inventory version changes or after 30 seconds, and otherwise refresh counts alone (`part=counts`) at most every 5 seconds while the log grows. Re-render a section only when its rows change.

## Revision Log

| Date       | Change                                                                                                                                                                                                                                                     | Reason                                                                                                                                                                       |
|------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 2026-10-21 | Initial guide                                                                                                                                                                                                                                              | Canvas build                                                                                                                                                                 |
| 2026-10-21 | Header actions wrap below 900px instead of 560px                                                                                                                                                                                                           | At 640px the title collapsed to one character and the actions overflowed the viewport                                                                                        |
| 2026-10-21 | Interaction spacing is 24px with a rail break instead of a 32px labeled divider                                                                                                                                                                            | The user entry already labels the interaction; the rail break reads as the divider                                                                                           |
| 2026-10-21 | Peak context includes pre-compaction tokens; compaction ticks sit at the pre-compaction count                                                                                                                                                              | The peak otherwise understated the largest context the session reached                                                                                                       |
| 2026-10-21 | Navigation lists strip Markdown markers from summaries                                                                                                                                                                                                     | Raw `#` and `**` markers made prompt summaries hard to scan                                                                                                                  |
| 2026-10-21 | System prompt detail shows a section table above Show full text                                                                                                                                                                                            | The section sizes answer "what was in the prompt" without loading the full text                                                                                              |
| 2026-10-21 | Compact controls use 13px / 20px; the active tab uses an accent underline                                                                                                                                                                                  | Sidebar rows fit 280px, and a filled tab read as a selected list row                                                                                                         |
| 2026-10-21 | Tool payload wells wrap; fenced code scrolls; breadcrumb separator is `/`                                                                                                                                                                                  | Payloads were unreadable in narrow panels; `/` matches path-like agent nesting                                                                                               |
| 2026-10-21 | Markdown subset documents tables, quotes, rules, and strikethrough with linear block patterns                                                                                                                                                              | The renderer supported them unlisted; a review found super-linear block patterns                                                                                             |
| 2026-10-21 | Narrow layouts keep the context meter text and hide only the refresh time                                                                                                                                                                                  | The meter rule requires latest, limit, percent, and peak at every width                                                                                                      |
| 2026-10-21 | Retrying state, transition announcements, and text status in navigation lists                                                                                                                                                                              | Screen-reader users could not perceive refresh failures or tool and subagent status                                                                                          |
| 2026-10-21 | Previous and Next tool buttons, working folder in session rows, per-name tool counts                                                                                                                                                                       | Pointer users needed tool stepping; FR details were missing from the list and Details                                                                                        |
| 2026-10-21 | Document clipped; only the log column and panels scroll                                                                                                                                                                                                    | Hidden text escaped non-positioned scroll areas and let the page scroll                                                                                                      |
| 2026-10-21 | One-row 40px header with icon actions                                                                                                                                                                                                                      | More room for the log                                                                                                                                                        |
| 2026-10-21 | Inline bounded argument and output boxes with expand, collapse, and JSON highlighting                                                                                                                                                                      | Collapsed disclosures hid the substance of tool calls                                                                                                                        |
| 2026-10-21 | Hook runs per turn with inline failures and per-run input, output, and error                                                                                                                                                                               | Counts alone did not explain what a hook did or why it failed                                                                                                                |
| 2026-10-21 | Pinned section prompt, Scroll to top and latest buttons, Home shortcut                                                                                                                                                                                     | Long logs needed fast orientation and navigation                                                                                                                             |
| 2026-10-21 | Agent tree timing, tokens, and context; System prompt dialog for any agent                                                                                                                                                                                 | Agent cost and timing and the full prompt were several clicks away                                                                                                           |
| 2026-10-21 | Page and log column use 0-minimum grid tracks; tighter padding below 640px                                                                                                                                                                                 | A long session title or code line widened the page past narrow panels                                                                                                        |
| 2026-10-21 | Previews also ride on live updates                                                                                                                                                                                                                         | Tools that finished after first render, such as long browser runs, lost their boxes                                                                                          |
| 2026-10-21 | Boxes and code wells scroll only when focused and never contain the wheel                                                                                                                                                                                  | Expanded boxes trapped the wheel even with nothing to scroll                                                                                                                 |
| 2026-10-21 | Previous-prompt bar above the log replaces the disappearing pinned prompt                                                                                                                                                                                  | Readers wanted one-click steps back through prompts at all times                                                                                                             |
| 2026-10-21 | System prompt expands inline with facts and drill rows; dialog removed                                                                                                                                                                                     | A wall of text in a dialog was hard to reason about                                                                                                                          |
| 2026-10-21 | System prompt versions with reason and section changes; each entry loads its own version                                                                                                                                                                   | The newest version sat mid-log unexplained, and older entries showed the newest                                                                                              |
| 2026-10-21 | `--sl-compact` role; compaction band, start marker, request and summary drill rows                                                                                                                                                                         | Compaction was easy to miss and its request was never shown                                                                                                                  |
| 2026-10-21 | Agent card moves to the Outline panel; Tools region scrolls on its own with a sort button                                                                                                                                                                  | More room for the log; a long tool list pushed the rest of the panel away                                                                                                    |
| 2026-10-21 | Version rows wrap their details under the version and time; card tracks have a 0 minimum                                                                                                                                                                   | Unwrapped reason text widened the card past the sidebar                                                                                                                      |
| 2026-10-22 | Details sort chips; tools, agents, skills, and instructions expand to what the model receives                                                                                                                                                              | Long lists needed ordering, and readers wanted the definitions behind each item                                                                                              |
| 2026-10-22 | Short boxes that overflow once wrapped regain Expand                                                                                                                                                                                                       | Wrapped lines in the sidebar were clipped with no way to see them                                                                                                            |
| 2026-10-22 | Inspector on the right with the agent overview, prompt versions, compactions, and Tools                                                                                                                                                                    | The Outline was crowded, and compactions and versions needed their own place                                                                                                 |
| 2026-10-22 | Collapsible docked panels, drawers below 900px and 1180px, `b` and `i`, a full-width log                                                                                                                                                                   | Readers wanted to reclaim width for the log; narrow canvases need panels on demand                                                                                           |
| 2026-10-22 | Bounded scroll wells and collapsible section headings in both panels                                                                                                                                                                                       | Long Agents and Prompts lists forced the whole panel to scroll                                                                                                               |
| 2026-10-22 | Impeccable pass: elevation-only overlays, inset segmented control, 16px title, aligned stats                                                                                                                                                               | Detector and review found border-plus-shadow overlays, flush controls, and wrapped stats                                                                                     |
| 2026-10-22 | Inspector Activity and Context views; Tools list renamed Tool calls; ten Context sections with counts and definition pages; Details keeps session facts                                                                                                    | Readers wanted everything the model is given (tools, skills, agents, subagents, canvases, and more) with use counts and the exact definitions, in one place                  |
| 2026-10-22 | Agent instructions in Activity; subagent descriptions clamp to three lines with Show more in the inspector and on log cards; inspector sections size to their content and share free height from section floors; drag or arrow keys resize the side panels | Readers saw only part of an agent's instructions, sections stretched past their few items, and fixed panel widths hid the log or the panels                                  |
| 2026-10-23 | Width buttons, a pausing status chip, a single-key shortcut switch, modal drawers, focus kept across list refreshes and breakpoints, and announced filter results; the sidebar's minimum width rises to 248px                                              | PR review found gaps against WCAG 2.5.7, 2.2.2, 2.1.4, and 4.1.3 and focus loss in drawers, refreshes, and breakpoints; the width button needs room at the narrowest sidebar |

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
