---
title: Session Log Canvas
description: Canvas extension that renders Copilot sessions, tool calls, and subagents as a live, navigable log
author: Microsoft
ms.date: 2026-10-23
ms.topic: reference
keywords:
  - canvas
  - session log
  - copilot sessions
  - subagents
---

## Overview

The Session Log canvas (`hve-core-session-log`) shows how Copilot used a session. It reads the event log that every Copilot SDK host writes and presents it as a readable timeline:

* The system prompt of any agent, expanding in place into its facts, sections (each opening to its text), skills, instruction files, and full text. Copilot records the prompt again when it rebuilds it (for example after a resume or a compaction), so each version appears in recorded order with what preceded it and which sections changed
* Each user prompt, including the injected context the model actually received
* Assistant responses, reasoning, and the tool calls they requested
* Tool calls with their arguments and latest output or errors shown inline in bounded, expandable boxes with JSON highlighting, navigable from an outline
* Hook runs per turn, with failures inline and each run's input, output, and error on request
* Subagents as their own logs, reachable from the call that started them, with breadcrumbs for nesting and an agent tree showing each agent's start and end times, tokens, and context use
* Context compactions as dashed bands in their own color, with tokens before and after, the request sent to the model when the session recorded it, and the summary that replaced the conversation
* Model, reasoning effort, context usage, and token totals
* Everything the model is given: tools, skills, agents, subagents, canvases, instructions, MCP servers, hooks, plugins, and extensions, each with its use count and the definition the model receives

The canvas opens on the current session, lets you switch to any recorded session, and refreshes while it is visible. Select the status chip in the header (Live or Up to date) to pause live updates, and select it again to catch up.

The canvas has three regions. The sidebar on the left has Sessions, an Outline (the agent tree and the prompts), and Details. The log fills the middle.

The sidebar's Details tab lists facts about the session and its main agent.

The inspector on the right covers the agent shown in the log, in two views:

* **Activity** shows the agent's model, totals, context meter, and instructions. It also lists the agent's system prompt versions (why each was rebuilt and what changed), its compactions (tokens before and after), and its Tool calls list, which includes compactions and sorts oldest or newest first. Selecting a version, compaction, prompt, or tool call scrolls the log to it.
* **Context** shows what the model is given, described in [Context](#context).

Agent instructions appear when the agent has its own: a subagent's agent definition, or the selected custom agent's instructions in the main prompt. Expand shows their full text, and In prompt shows the prompt they came from.

Each list scrolls inside its own bounded area, and section headings collapse their section. Sections take only the height their content needs, and long lists share the rest, so a panel scrolls only when it is too short for each list to keep a few rows.

Drag the divider beside the sidebar or the inspector to resize it, or select the width button at the right of the panel's tab bar to step through narrow, default, wide, and widest. A focused divider also takes the arrow keys, and a double-click or `Enter` restores the default width.

The toggles at each end of the header (or `b` and `i`) hide and show the sidebar and the inspector; the log, its prompt bar, and its scroll buttons widen into the space. In narrower canvases the panels open as drawers over the log instead. An open drawer keeps focus until `Escape`, its shortcut, or a click outside closes it, and a resize or zoom that hides the panel you were in moves focus to its toggle.

A bar above the log always shows the previous prompt; select it to scroll there, and it then shows the one before. Argument and output boxes scroll only after you click into them, so the mouse wheel keeps scrolling the log. Values longer than a page keep a Load more control under Telemetry and raw events. Buttons at the bottom right scroll to the first and the newest entry.

## Requirements

Canvases are an experimental Copilot feature. The Session Log renders wherever canvases are supported:

* GitHub Copilot app
* Copilot CLI with experimental extensions turned on (`--experimental` or `/experimental on`)
* VS Code with `chat.canvases.enabled` on, in a Copilot harness session

The canvas ships in the hve-core Copilot plugin. The hve-core VS Code extension does not carry canvases.

Sessions started in the hve-core repository also load the canvas from the project entry `.github/extensions/session-log/extension.mjs`, which imports this packaged extension. Copilot discovers project extensions only as direct children of `.github/extensions/`, and plugin membership excludes that unpackaged entry.

When the hve-core plugin is also installed, the host can list a second provider for `hve-core-session-log`. Both run the same module. When a host asks which one to open, pass the `extensionId` it reports, such as `project:session-log` for the project entry.

## Open the Canvas

Ask the agent to open the Session Log canvas, or choose it from the host's canvas list. To start on a specific session, pass its ID as input:

```json
{ "sessionId": "<session id>" }
```

Pass `"current"` (or nothing) to show the session that opened the canvas. Reopening the same canvas keeps the session you selected.

## Agent Actions

| Action                | Input                              | Result                                                                                                                           |
|-----------------------|------------------------------------|----------------------------------------------------------------------------------------------------------------------------------|
| `list_sessions`       | `limit` (1 to 100, default 20)     | Recent sessions with title, repository, branch, host, and activity                                                               |
| `select_session`      | `sessionId` (an ID or `"current"`) | Shows that session in the canvas                                                                                                 |
| `get_session_summary` | optional `sessionId`               | Model, agent, context usage, counts, tool totals, subagents, and event health (unknown event types, debug and unreadable counts) |
| `focus_entry`         | `toolCallId` or `agentId`          | Reveals a tool call or opens a subagent log in the canvas                                                                        |

Results contain metadata only: identifiers, short titles, counts, model names, and status. They never include prompt, response, argument, or result text. Titles and names come from recorded session data, so agents treat them as data rather than instructions.

## Keyboard

| Key                           | Action                                                                                                                     |
|-------------------------------|----------------------------------------------------------------------------------------------------------------------------|
| `j` and `k`                   | Next and previous entry                                                                                                    |
| `]` and `[`                   | Next and previous tool call                                                                                                |
| `o`                           | Open the subagent log for the focused entry                                                                                |
| `Escape`                      | Close a definition page or drawer, or return to the parent log                                                             |
| `/`                           | Filter sessions, tool calls, or context                                                                                    |
| `b`                           | Show or hide the sidebar                                                                                                   |
| `i`                           | Show or hide the inspector                                                                                                 |
| Arrow keys on a panel divider | Resize the panel (`Shift` for larger steps); `Home` and `End` go to the narrowest and widest; `Enter` restores the default |
| `Home`                        | Scroll to the first entry                                                                                                  |
| `End`                         | Jump to the newest entry and follow                                                                                        |
| `?`                           | Show all shortcuts                                                                                                         |

Letter and symbol shortcuts act only while focus is outside a text field. The shortcut list (`?` or the keyboard button in the header) can turn them off; `Escape`, `Home`, `End`, and the arrow keys keep working.

## Where Sessions Come From

Every Copilot SDK host (the GitHub Copilot app, the Copilot CLI, and VS Code's Copilot harness) writes one folder per session under `session-state` in the Copilot home folder:

| Platform     | Default location                                     |
|--------------|------------------------------------------------------|
| macOS, Linux | `~/.copilot/session-state/<session id>/`             |
| Windows      | `%USERPROFILE%\.copilot\session-state\<session id>\` |

Setting `COPILOT_HOME` moves the Copilot home folder, and the canvas follows it. When the joined session reports its own folder, the canvas uses that folder's parent instead. Only macOS was exercised during development; the Windows and Linux locations follow the GitHub Copilot CLI documentation.

Each session folder holds `events.jsonl`, the append-only event log the canvas renders, and `workspace.yaml`, which supplies the title, repository, branch, and host shown in the session list. Folders without recorded events are not listed. A session is marked active while a host process holds it.

## Context

The inspector's Context view lists everything the model is given at session start or through the system prompt, in ten sections. Each heading shows how many items it holds. Each row shows how often the item was used, with failures in red. One filter covers every section. Each section sorts by use, most or fewest first, or by name, and remembers its choice while the view refreshes.

| Section      | Lists                                                                                | Counts                                     |
|--------------|--------------------------------------------------------------------------------------|--------------------------------------------|
| Tools        | Every tool offered, marking MCP tools and tools loaded on demand through tool search | Calls and failures by the agent in view    |
| Skills       | Skills listed in the system prompt or loaded by the host                             | Loads                                      |
| Agents       | Custom agents loaded for the session, plus agents selected to run it                 | Times selected as the main agent, and runs |
| Subagents    | Agent types the `task` tool can launch, built-in and custom                          | Runs and failures                          |
| Canvases     | Canvases declared to the session                                                     | Opens, action calls, and capability checks |
| Instructions | Instruction files listed in the system prompt or found while the agent worked        | Reads with a file view                     |
| MCP servers  | Configured servers with their status                                                 | Calls to the server's tools                |
| Hooks        | Hook types that ran                                                                  | Runs, with failures by plugin              |
| Plugins      | Installed plugins and the skills and MCP servers they add                            | Loads of their skills                      |
| Extensions   | Loaded extensions and the canvases they provide                                      | Calls to their canvases                    |

### What the model is given

Select any row to open its definition page. Back or `Escape` returns to the list, or to the page you came from when one item links to another (an MCP server's tools, or a plugin's skills). JSON is indented and highlighted.

| Item        | Shown                                                                                                                                                                                |
|-------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Tool        | Source and loading, the description, the arguments with types and descriptions, the definition JSON, and the latest call's arguments and response (or error) with a link to the call |
| Agent       | Its `task` tool listing, the prompt it received (its latest run's opening or its main-agent instructions), its runs with log links, and the host's definition                        |
| Skill       | Its `<skill>` entry in the system prompt and, when loaded, the text injected into context with its trigger                                                                           |
| Canvas      | Its system prompt entry, open input, actions with their parameters and calls, the capabilities the model read, and its instances                                                     |
| Instruction | Its row in the system prompt's instruction table, file reads, how it was discovered, and the file content                                                                            |
| MCP server  | Status, source, address without credentials, error, the server instructions given to the model, and its tools                                                                        |
| Hook        | What the hook type does, the latest run with a link to it, failures by plugin, the latest failure, and the latest context it added for the model                                     |
| Plugin      | Version, marketplace, state, and the skills and MCP servers it adds                                                                                                                  |
| Extension   | Its ID, source, status, and the canvases it provides                                                                                                                                 |

Tools declare no result schema, so a tool's latest recorded response shows what it returns.

### Where each list comes from

For the session that opened the canvas, the host supplies live lists: offered tools with their definitions, declared canvases with their schemas and actions, custom agents, skills, instruction sources, MCP servers, plugins, and extensions. Use counts always come from the session log. Each section states its source.

Live lists are not saved in the session log. For other sessions, the canvas reconstructs what the log recorded:

* The canvas, skill, and instruction entries in the system prompt
* `list_canvas_capabilities` results the model received
* Canvas, MCP, and tool-search activity
* Agent selections and subagent runs
* The prompt each agent received
* Hook runs and the context hooks added

The log keeps only some tool names and no tool definitions, so those sections are marked partial. Copilot does not list configured hooks for a session, so hooks appear once they run, and a successful run does not name its plugin.

## Refresh and Resource Use

* The canvas indexes each session once and then reads only bytes appended since the last refresh. An unchanged refresh reads no file content. A log that is replaced, shortened, or changed without growing is indexed again from the start.
* The index keeps short summaries and file offsets, not message text. Full content is read on demand when you expand an entry, in pages for very long fields.
* At most three session indexes stay in memory. Hook events are counted per turn rather than listed, and model debug events are counted only. A rebuilt index starts a new epoch, so the page reloads instead of reusing content cached from the old one.
* The page polls about every 2 seconds for the open session and every 15 seconds for the session list, and only while it is visible and not paused. A burst of more than 200 new entries arrives in follow-up polls until the log catches up. Each poll also reports whether the session is still active, so Live clears when the host exits. It keeps at most 400 entries rendered and loads earlier entries on request.
* A selected session with no events yet loads on its own once it writes them; the page retries with backoff from 2 to 30 seconds.
* The Context view loads its lists only while it is shown, reloads them when the inventory changes or every 30 seconds, and otherwise refreshes counts at most every 5 seconds while the log grows.

## Security and Privacy

Session logs can contain prompts, file contents, command output, and secrets that tools printed. The canvas treats that content as untrusted data and keeps it local:

* The page is served from `127.0.0.1` on a random port while the canvas is open, and the server stops when the canvas closes.
* Every request must name the loopback host, which blocks DNS rebinding. Data requests from other websites are rejected through browser Fetch Metadata, and no cross-origin access is granted.
* A strict content security policy allows only the canvas's own scripts and styles, and all session text is inserted as text, never as HTML. Links open only for `http` and `https`.
* The canvas reads session folders and writes no files. Its diagnostics are ephemeral, so they are not added to any session log.
* Live inventories pass through field allowlists, so prompts, instruction content, launch arguments, and environment values are never returned in the lists.
* Definitions load one item at a time when you open it, and the extension caches each live list for 30 seconds. Text from the host (an agent's authored prompt, an instruction file, MCP server instructions, tool descriptions) is returned only on that request, with URL credentials and well-known token formats removed. Text recorded in the session log (a skill's injected text, a delivered agent prompt, a hook's added context, a tool call) appears as recorded, as it does in the log.
* MCP server addresses and plugin sources drop credentials and query strings. Agent MCP server settings are reduced to names, transports, commands, and URLs; arguments, environment variables, and headers are never returned.
* The extension calls only read-only session methods, such as `tools.getCurrentMetadata`, `canvas.list`, `mcp.list`, `plugins.list`, and `extensions.list`. It never reloads or reconfigures the session.

While the canvas is open, any local process that can reach the loopback port could request session content, much as a process running as you can already read the session files. Close the canvas on shared machines when you are not using it.

## Limitations

* The event format is internal to Copilot and can change. Unknown event types still appear in the log with their raw content.
* The canvas API is experimental, so host updates can change how canvases load or render.
* VS Code sessions that run outside the Copilot harness, remote sessions, and cloud agent sessions are not stored locally and do not appear.

## Development

The extension has no dependencies beyond Node.js built-ins and the host-provided `@github/copilot-sdk/extension` module. Run its tests, with every other extension's tests, from the repository root:

```bash
npm run test:extensions
```

PR validation discovers every directory under `.github/extensions/` that has an `extension.mjs` and test files, and runs its tests in the Node test lane whenever a file under `.github/extensions/` changes.

To load working-tree changes in a session started in this repository, ask the agent to reload extensions, or run `/clear`, then reopen the canvas.

[STYLE-GUIDE.md](STYLE-GUIDE.md) defines the visual language and log grammar. Update its revision log when a rule changes.

When a Copilot update changes what sessions record, run the repository's `/session-log-canvas-update` skill. It compares the installed session event schema with the schema the canvas was verified against, flags changes to the event types the canvas reads (`HANDLED_EVENT_TYPES` in `lib/indexer.mjs`), and guides the fixes and baseline refresh.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
