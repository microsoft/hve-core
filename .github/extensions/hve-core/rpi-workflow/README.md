---
title: RPI Workflow Canvas
description: Canvas extension for following and steering RPI sessions through research, planning, implementation, review, and follow-up
author: Microsoft
ms.date: 2026-10-26
ms.topic: reference
keywords:
  - canvas
  - rpi
  - research plan implement review
  - decisions
  - feedback
---

<!-- cspell:ignore pypirc netrc -->

## Overview

The RPI Workflow canvas (`hve-core-rpi-workflow`) is a shared surface for an RPI session. You read, decide, edit, and steer here, and the agent reports its work, asks for decisions, and reads back how it understood you. The canvas adapts to the phase you view:

* Research: a summary with readiness, what you may not know, a questions tracker, findings with evidence state and confidence, alternatives, risks, research lanes, and the evidence log
* Plan: a summary with the critique verdict, a Before and After change map, phases and tasks that expand in place, requirement coverage, and critique findings
* Implement: a Now banner with the agent's current task and latest activity, a task board, changes grouped by task with files and validation, discoveries grouped by kind with their plan updates, business alignment, and blockers
* Review: an assessment with severity counts, findings with expected and observed behavior side by side, the agent's decisions with Question this decision, and the decision history
* Follow-up: ranked follow-ups with Select and Skip, and the loops in this session as a tree, parent first

Every document is a sequence of rows. A row's margin holds its annotations: decision cards, research lanes, your comments, and the agent's notes. On narrow canvases the annotations follow the row text.
IDs such as `C22` or `P01-T02` link wherever they appear. Hover over one to preview the whole item, and its icon says whether a click goes to the item or opens it in place.
Evidence chips (`C5`, `W2`) open their claim and source in place, and each trace strip links a question through its finding, decision, task, change, and review finding. Strips follow the session's own references, so a change or discovery the agent records joins its task's strip.
See [IDs, Previews, and History](#ids-previews-and-history) and [Sources](#sources).

The canvas shows a real RPI session from the workspace's `.copilot-tracking/` folder, or a fictional sample session, "Offline drafts with background sync", that lets you try every phase and interaction.
A real session comes from its RPI files: the state file, research, plan, critique, changes record, and review log.
The canvas follows those files while it is open and never changes them. What you add, suggested edits included, waits in the canvas until you send it to the agent, and the agent changes the files. See [Send to the Agent](#send-to-the-agent) and [Real RPI Sessions](#real-rpi-sessions).

### Regions

* The header holds the task title, the phase rail, Needs you, Send to agent, the live status, appearance, the ID legend, keyboard shortcuts, and the panel toggles. The rail marks the phase the agent works in, and you can read any other phase meanwhile. Under the title, the session button names the session and counts its loops; it opens the session menu, which lists the session's loops as a tree and, for a real session, the workspace's other sessions.
  Next comes the canvas badge with the handle that starts this canvas's messages; it never shrinks. For a real session, the line continues with whether the canvas follows the running loop (Following, or Paused with Resume following), the task ID, the repository and branch, and, for a child loop, a link to its parent task. In a narrow header the session name shortens first, then the task details give way.
* The navigator on the left outlines the viewed phase and filters it.
* The document fills the middle. Its context bar starts with Back and Forward, then names the phase, its status, the artifact path with Copy and, when the canvas runs in VS Code, Open in VS Code, when the file last changed, and the agent's next action. Sections of a real artifact that no other row shows appear, collapsed, in the phase's record row.
* The steering panel on the right always lists, in order: Needs your input, Decided by the agent, Your feedback, Add input, and the phase review checklist. A decision with no row to sit beside, such as one about a phase that has not started, appears there as a full card. Agent decisions listed in a Decisions row appear as one link per phase.

Below 1400px the phase rail takes its own row under the title. Below 1360px the steering panel opens as a drawer, and below 1024px the navigator does too. Content reflows down to 320px.

### Decisions and Feedback

Decision cards state what is being decided, who owns it, and where it stands.
A real session's Research and Plan show the decisions their files record in a Decisions row, labeled with each file's own IDs, so `D1` in the Plan view is the plan's D1.
In a real session, a decision that needs you shows the question and options from its detail block in the research or plan file, with the recommended option marked.
Answer a decision by choosing an option, adding an optional note, and selecting Answer, or choose Your own answer, the last choice, and write it.
When a decision lists no options, write your answer instead.
The agent then reads back how it understood you in an Agent understood block.
Select Looks right, or select Not what I meant to write a correction that starts with your earlier note.
Edit answer takes back an answer you have not sent and reopens the card with your choice and note filled in.

While a decision the agent made is open, its card offers Override. Override lists the alternatives and Something else, or, when the decision lists none, asks what the agent should do instead, in your words. Removing an override you have not sent restores the agent's choice. A settled decision shows the option it resolved to and how it was decided. In Review, the agent's decision on each finding offers Question this decision, which starts a comment about that finding.

Answers, overrides, comments, context, research requests, suggested edits, corrections, and checklist reviews become feedback items:

* An item is Not sent until you send it with Send to agent, or until the agent collects it with `take_feedback` when you ask it to. Then it is Sent.
* The agent reads it back (Interpreted). The item ends Applied when you confirm the read-back or the agent marks it applied, or Corrected when you write a correction, which waits to be sent like any other item.
* You can remove an item you have not sent.

### Send to the Agent

Everything you add waits in the canvas until you send it. Send to agent, in the header next to Needs you, is there in every phase and at every width. It counts the items waiting in every loop of the session and turns blue once there are any. Your feedback in the steering panel lists the shown loop's items under Not sent yet, says how many wait in other loops, and offers Review and send.

Either opens a short review:

* every waiting item, with Show to go to it and Remove to take it out; when items wait in more than one loop, they appear in a group per loop, and a completed loop's group says its items go to the agent as follow-up work;
* an optional message to the agent;
* the exact message the agent receives, behind a disclosure;
* Send, which delivers the listed items as one message in the chat that opened the canvas.

The chat shows your message, then a line such as "RPI canvas 3WF0 sent 3 items: 1 suggested edit, 1 review checklist, and 1 comment." The agent receives the full message:

* the canvas handle and instance ID;
* how to handle the items: change the task's files, or use canvas actions on the sample, then read back each item;
* the task's files;
* each item with what it targets and, for a suggested edit, its line changes.

A message with items from several loops groups them under a heading per task with that task's files, numbers them through, and asks the agent to name the task with each read-back, because feedback IDs such as `FB-001` repeat across tasks.

When the agent is busy, the message waits for its turn. If the items change while the review is open, Send shows the new list and asks you to check it again. During a send, its items show Sending, and neither the agent nor a second send can take them. If the host cannot take the message, the review says so, and the items stay unsent.

Each open canvas has a short handle, such as `3WF0`, that stays the same for its instance ID and is unique among the canvases the extension has open. A real session's badge reads RPI canvas 3WF0, matching the chat line, so you can tell which canvas sent a message. The agent learns the handle and instance ID when it opens the canvas and from `get_state`.

### Suggested Edits

The canvas never changes a document. Rows that hold a document section offer Suggest an edit, which opens a Markdown editor with a preview. Add suggestion saves your version as a suggestion. The section keeps showing its source text, and a callout beside it shows your line changes and whether the suggestion is sent.

Before you send a suggestion, Edit suggestion reopens it and Remove withdraws it; editing it back to the current text also withdraws it. Once you send it, the agent applies it to the file, or to the sample through `update_section`. The section shows the change once it lands.

If the section changes while you edit, the editor offers Compare, Keep my suggestion, and Start from the new text. A suggestion made before the section changed says so. Cancel or `Escape` closes the editor and asks first when you have unsaved changes. Selecting Suggest an edit elsewhere while a draft has unsaved changes returns you to that draft.

### Review Checklist

The steering panel's checklist holds a few optional statements for reviewing the viewed phase, such as "Each finding's evidence is convincing." Mark each one Looks good or Needs work as you read. Pressing the selected verdict clears it, and Needs work takes an optional note.

Your marks track your progress and stay private. Items that need work, with their notes, go to the agent with your next send, and so does a list where every item looks good. The status line under the checklist says when your review goes with the next send.

### IDs, Previews, and History

The legend, from its header button or `l`, lists every ID family by phase with an example and a plain description, so `C22` reads as code evidence and `RD-012` as a review decision. The canvas builds the legend from the same table it uses to link IDs.

An ID's icon says what a click does:

* The box with an arrow goes to the item, and Back returns you.
* The page opens the item in place, as evidence chips and plan tasks do. An opened item's own ID goes to the item.
* The globe opens a website in your browser.
* The code file opens a file in VS Code at the cited line.

Hover over an ID, or move focus to it, to preview the whole item: its kind, title, status, text, and related IDs. The preview stays while you move the pointer onto it.
To lock it, keep the pointer on the ID or the preview until the ring fills, about a second, or middle-click the ID. From the keyboard, Down Arrow locks the preview and moves focus into it.
A locked preview is a small dialog with a close button, and the IDs in it open previews of their own, up to five deep. Escape closes the newest preview and returns focus to its ID. Clicking outside closes every preview, and clicking an ID goes to it.

Back and Forward, beside the phase title, retrace the places you moved to: IDs you followed, phases you switched to, and loops you showed, across the whole session. Alt+Left and Alt+Right do the same. A new move after going back clears Forward. Going back to another loop shows it as Show does, which pauses following when that loop is not running.

### Sources

In a real session, code evidence shows each cited location as a source chip with the path and the heading or symbol. The chip opens the file in a read-only sheet scrolled to the cited place. The canvas finds that place by heading, link fragment, definition, or first mention, and the sheet says which. Copy path copies `path:line`. When the canvas runs in VS Code, Open in VS Code opens the file at that line, in the window that has the workspace.

Relative links in research, plans, changes records, and reviews, such as a task's References, open the same way. A code span after the link's colon, as in `` [path](path): `symbol` ``, sets the place. The file sheet for a change offers Show the file and Open in VS Code.

A cited path that is not a file in the workspace appears in the problems list, and the RPI Agent fixes it. The research template asks for each code location as a workspace-relative path followed by its heading or symbol in backticks, with several locations separated by semicolons.

## Requirements

Canvases are an experimental Copilot feature. The canvas renders wherever canvases are supported:

* GitHub Copilot app
* Copilot CLI with experimental extensions turned on (`--experimental` or `/experimental on`)
* VS Code with `chat.canvases.enabled` on, in a Copilot harness session

The canvas ships in the hve-core Copilot plugin. The hve-core VS Code extension does not carry canvases.

Sessions started in the hve-core repository also load the canvas from the project entry `.github/extensions/rpi-workflow/extension.mjs`, which imports this packaged extension. When the hve-core plugin is also installed, the host can list two providers for `hve-core-rpi-workflow`. Both run the same module; pass the `extensionId` the host reports, such as `project:rpi-workflow`, when it asks which one to open.

## Open the Canvas

Ask the agent to open the RPI Workflow canvas, or choose it from the host's canvas list. The RPI Agent opens it by itself when the host offers it, on the state file of the task it is working on:

```json
{ "state": ".copilot-tracking/rpi-sessions/2026-10-23/rpi-workflow-canvas/rpi-workflow-canvas-state.json" }
```

To show the workspace's most recent session instead, pass `task`:

```json
{ "task": "current" }
```

`current` is the most recently changed task whose session is running, or the most recently changed task when none runs. A task ID, such as `{ "task": "offline-drafts" }`, opens that task. Without `state` or `task`, the canvas shows the sample session. To start at a stage of the sample, pass it as input:

```json
{ "stage": "research" }
```

Stages are `research`, `plan`, `implement` (the default), `review`, and `followup`; `state` and `task` cannot be combined with each other or with `stage`. Reopening the canvas keeps the session as you left it. Opening at a different stage replaces the sample only when you have not changed it; otherwise the canvas keeps your changes and says so.

## Real RPI Sessions

The canvas looks for `.copilot-tracking/` in the session's working directory, then in the directory the host started in. It reads:

* the state files in session folders, `.copilot-tracking/rpi-sessions/<date>/<session>/<task>-state.json`, to find the task, its mode and phase, its session, and the other loops in it;
* the artifacts a state file names in `artifact_paths`: research, plan, plan critique, changes record, and review log;
* the branch and repository from the workspace's `.git` folder, for the header.

Every file must be a Markdown or JSON file inside `.copilot-tracking/`, reached without symbolic links, and at most 2 MB. A state file, whether given as input or named by another state file's link, must also sit in a session folder. The canvas refuses anything else and never writes these files.

One session folder holds every task one conversation worked on. Each state file names its session (`session_name`), its parent's state file (`parent_task.state_path`), and its children's (`child_tasks`), and the canvas builds the session's tree from those links.
A task whose parent sits in another session shows that parent as context. A link the canvas cannot follow, a child its parent does not list, and a state file left directly under a date folder each appear in the problems list above the phase; the canvas skips state files that are not in a session folder.

While a page is open, the canvas checks the task's files and the session's state files about every 1.5 seconds. It imports a change once the file has stopped changing between two checks, so a half-written file is skipped. Edits by the agent appear within a few seconds. When a file cannot be read, the canvas keeps the last good version and lists the problem above each phase.

The canvas reports what it cannot read instead of dropping it: decision rows not numbered `D1`, `D2`, and so on, decision blocks with no row or no options, citations the evidence log does not list, code evidence that cites a path missing from the workspace, tables without their expected columns, and a research title that is still the slug.
These appear in the problems list and in `get_state`, and the RPI Agent fixes the ones in the files it is writing; older artifacts stay as they are.

What you add stays in the canvas across these updates: feedback, suggested edits, checklist verdicts and notes, research lanes, activity, and decisions created in the canvas. A section always shows the file's text, and a suggestion for it stays beside it until it is applied or removed. An answer or override on a decision stays until the agent changes that decision. Text typed into a section by an earlier version of the canvas gives way to the file's text.

The files remain the record, and only the agent changes them. Answers, overrides, comments, suggested edits, and checklist reviews reach the agent when you send them. The agent updates the files and reads each item back. The canvas refuses agent actions that would change file-owned content, such as `update_task` or `update_section`, with `source_managed` and names the file to change instead.

The canvas follows the running loop. When the task it shows is no longer running and exactly one of its child loops is, it moves to that loop in the same panel and says so in a note at the bottom of the document. With several running children, it stays and lets you choose.
Showing a loop that is not running, from the session menu, Follow-up, or a child's link to its parent, pauses following; Resume following, beside the session button, returns to the session's running loop. The session menu also lists the workspace's other sessions, newest first, and shows a session's running loop, or its most recently changed one.

Each task keeps its own drafts, open editor, and scroll position in the page, so switching back returns you to where you were. When an action fails, the failure stays visible in the note area at the bottom of the document until you dismiss it, and a comment that fails keeps your text with the reason beside it.
When the page cannot render a task, it says why with Retry instead of staying blank, and `get_state` reports the reason to the agent.

## Agent Actions

| Group                     | Action                  | Purpose                                                                                                                                                                                                                                                                                                                                                                       |
|---------------------------|-------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| State                     | `get_state`             | Summarizes the canvas handle and instance ID, the editor that opens files when there is one, the phase, decisions that need the user, agent decisions, feedback in every loop of the session (`otherTasks`), the session tree, whether it follows the running loop, progress, appearance, and page status, including why the page could not render (`clientInfo.renderError`) |
| State                     | `load_scenario`         | Loads the sample at a stage; refuses to overwrite user changes unless `replace` is true, then backs them up                                                                                                                                                                                                                                                                   |
| State                     | `show_task`             | Shows an RPI task from the workspace (`state`, `current`, or a task ID), or the sample (`sample` with an optional stage); a task that is not running pauses following                                                                                                                                                                                                         |
| Session                   | `update_session`        | Sets the agent's phase, task and session status, mode, next action, or a phase status                                                                                                                                                                                                                                                                                         |
| Decisions and feedback    | `upsert_decision`       | Asks the user for a decision (owner `user`) or records an agent decision the user can override (owner `agent`)                                                                                                                                                                                                                                                                |
| Decisions and feedback    | `take_feedback`         | Collects items the user has not sent in every loop of the session, each with its `taskId` and each suggested edit's full text and line changes, and marks them sent; skips items being sent                                                                                                                                                                                   |
| Decisions and feedback    | `record_interpretation` | Reads back how the agent understood an item and what it changes; takes `taskId`, which is required when the item went out with items from other tasks                                                                                                                                                                                                                         |
| Implementation            | `update_task`           | Changes a task's status, adds guidance, or links the decision that paused it                                                                                                                                                                                                                                                                                                  |
| Implementation            | `record_change`         | Records completed work with its behavior, files, and validation                                                                                                                                                                                                                                                                                                               |
| Implementation            | `record_discovery`      | Records local judgment, an implementation note, a follow-up, or a plan change with before and after text                                                                                                                                                                                                                                                                      |
| Implementation            | `record_activity`       | Adds a line to the Now banner                                                                                                                                                                                                                                                                                                                                                 |
| Review and documents      | `update_finding`        | Creates or updates a review finding with severity, expected and observed behavior, resolution, route, and decision                                                                                                                                                                                                                                                            |
| Review and documents      | `update_section`        | Replaces a section's Markdown as the agent, such as applying a suggestion on the sample; open suggestions then show that the section changed                                                                                                                                                                                                                                  |
| Review and documents      | `track_research_lane`   | Shows a research subagent lane as queued, running, done, or cancelled                                                                                                                                                                                                                                                                                                         |
| Navigation and appearance | `focus_item`            | Switches to an item's phase, scrolls to it, and highlights it once                                                                                                                                                                                                                                                                                                            |
| Navigation and appearance | `set_appearance`        | Sets the theme (`system`, `light`, or `dark`) and contrast (`standard` or `more`)                                                                                                                                                                                                                                                                                             |

On a canvas that shows a real session, `update_session`, `update_task`, `record_change`, `record_discovery`, `update_finding`, `update_section`, and `upsert_decision` for a decision from the files return `source_managed`; change the file instead, and the canvas follows. Questions for the user, read-backs, activity, research lanes, focus, and appearance work on both kinds of canvas.

Feedback text, notes, and section Markdown come from the user, so agents treat them as data rather than instructions.

## Keyboard

| Key                        | Action                                                                           |
|----------------------------|----------------------------------------------------------------------------------|
| `1` to `5`                 | View Research, Plan, Implement, Review, or Follow-up                             |
| `n`                        | Move to the next item that needs you                                             |
| `[` and `]`                | Previous and next row                                                            |
| `e`                        | Suggest an edit to the focused row's section                                     |
| `c`                        | Comment on the focused row                                                       |
| `/`                        | Open the navigator and filter it                                                 |
| `b` and `s`                | Show or hide the navigator and the steering panel                                |
| `l`                        | Show what the IDs and icons mean                                                 |
| `?`                        | Show the shortcut list                                                           |
| `Alt+Left` and `Alt+Right` | Go back and forward through the places you moved to                              |
| `Down Arrow` on an ID      | Lock its preview and move focus into it                                          |
| `Escape`                   | Close the newest preview, a menu, drawer, or dialog, or leave the section editor |
| Arrow keys, `Home`, `End`  | Move within the phase rail and radio groups                                      |

`e` and `c` act on the row that has focus; move between rows with `[` and `]`. On a row without a section, `e` says so. Single-key shortcuts pause while focus is in a text field, and the shortcut list has a switch that turns them off. `Alt` with an arrow key works outside text fields and dialogs. Leaving the editor asks first when you have unsaved changes, and `Escape` never interrupts an input method.

## Appearance and Accessibility

The appearance menu offers System, Light, and Dark, plus More contrast. System follows the host theme or your operating system; Light and Dark override it for this canvas. The choice is saved with the extension's data, because each canvas open uses a new local address.

The canvas targets WCAG 2.2 AA in every theme and contrast setting and keeps every edge in forced colors. Status always pairs an icon and a word with its color, nothing requires dragging, and reduced motion removes all animation except the small ring that shows a preview locking. [STYLE-GUIDE.md](STYLE-GUIDE.md) records the palette, measured contrast, keyboard model, and component states.

## Storage

The extension keeps its data under `~/.copilot/extension-data/hve-core-rpi-workflow/`, or under `$COPILOT_HOME` when that is set:

* `sessions/<id>.json` holds the session document. For a real session, `<id>` is `rpi-` and the task ID, and the document is a copy of the task's files plus what you added in the canvas. Writes are atomic, and a lock file serializes writers across processes. A write lands only when no other process wrote since it read the session; otherwise it is applied again to the newer session. A document saved by an earlier canvas version is brought up to date as it is read.
* `sessions/<id>.previous.json` holds the session that the last replace discarded your changes from (`load_scenario` with `replace: true`), or an unreadable file it replaced. It stays until the next such replace.
* `preferences.json` holds the theme and contrast choice.

## Security and Privacy

* The page is served from `127.0.0.1` on a random port while the canvas is open, and the server stops when the canvas closes.
* Every request must name the loopback host, which blocks DNS rebinding. API requests whose Fetch Metadata shows another origin are rejected, and no cross-origin access is granted.
* Every API call must carry the canvas's key, a random value in the page address the host opens. Without it, nothing can read or change the canvas session, show or open files, or send to the agent through the canvas. `get_state` reports the address without the key.
* A strict content security policy allows only the canvas's own scripts and styles. All session text is inserted as text through a restricted Markdown subset, never as HTML. Links open only for `http` and `https`; a relative link in an RPI file opens as a source in the canvas, and any other address shows as text.
* The canvas reads workspace files only to show sources, and only read-only. A file must be a workspace-relative path, with no drive or stream colon, to a regular file inside the workspace, reached without symbolic links, outside `.git`, `.ssh`, `.aws`, `.azure`, and `.gnupg` folders, at most 1 MB, and text.
  It must not look like it holds secrets: `.env*`, `*.pem`, `*.key`, `*.p12`, `*.pfx`, `*.jks`, `*.keystore`, `id_rsa*`, `id_ed25519*`, `.npmrc`, `.pypirc`, `.netrc`, and `.git-credentials` are refused. The sheet shows at most 5,000 lines.
* Open in VS Code runs VS Code's own command-line tool, found from the extension's own process, with `--goto` and the file's path and line. It runs without a shell, one open at a time, and only for files the read rules allow. Where no VS Code is found, the button does not appear. It never opens a `.code-workspace` file, which VS Code would open as a workspace with its settings and tasks; the canvas shows such a file instead.
* Request bodies are limited to 16 KB, and 64 KB for a suggested edit.
* Nothing reaches the agent until you select Send in the Send to agent review. The canvas then sends one message, with the host's send method, into the session that opened it.

The key keeps other local processes, such as other accounts or containers, from using the canvas. A process running as you can still read the extension's data folder and your workspace directly, as it always could. Close the canvas on shared machines when you are not using it.

## Limitations

* The canvas reads RPI files but never writes them. Changes to a real session reach the files only through the agent.
* Artifacts that stray far from the RPI templates still render, but sections the canvas does not recognize appear only in the record rows.
* Following moves only to the one running child of a loop that has finished. A subagent that runs its own RPI loop in the session looks like any other child, so the canvas can follow into it; use the session menu or Resume following to go back.
* Send to agent needs a host that accepts messages from extensions. When it does not, the review says so, and the items stay unsent until the agent collects them with `take_feedback`. The canvas does not attach items to your next message, because VS Code does not show extension attachments.
* Open in VS Code is verified with VS Code Insiders on macOS. Other hosts show the source in the canvas and Copy path.
* VS Code may handle Alt+Left and Alt+Right before the canvas sees them; the Back and Forward buttons always work.
* Previews follow the WAI-ARIA tooltip and dialog patterns, but nested previews have not been tested with screen readers.
* The canvas API is experimental, so host updates can change how canvases load or render.

## Development

The extension has no dependencies beyond Node.js built-ins and the host-provided `@github/copilot-sdk/extension` module. Run its tests, with every other extension's tests, from the repository root:

```bash
npm run test:extensions
```

The UI renders from files read on each request, so a page reload shows UI changes. Changes under `lib/` or `extension.mjs` need an extension reload; ask the agent to reload extensions, then reopen the canvas.

[STYLE-GUIDE.md](STYLE-GUIDE.md) defines the visual language and interaction grammar. Update its revision log when a rule changes.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
