---
title: Session Log Canvas
description: Canvas extension that renders Copilot sessions, tool calls, and subagents as a live, navigable log
author: Microsoft
ms.date: 2026-10-22
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
* Model, reasoning effort, context usage, token totals, skills, instruction files, and other recorded details

The canvas opens on the current session, lets you switch to any recorded session, and refreshes while it is visible.

The Outline panel holds the agent tree, a card for the shown agent with its facts, context meter, and System prompt versions, the prompts, and a Tools list that scrolls on its own, includes compactions, and sorts oldest or newest first.

A bar above the log always shows the previous prompt; select it to scroll there, and it then shows the one before. Argument and output boxes scroll only after you click into them, so the mouse wheel keeps scrolling the log. Buttons at the bottom right scroll to the first and the newest entry.

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

| Key         | Action                                      |
|-------------|---------------------------------------------|
| `j` and `k` | Next and previous entry                     |
| `]` and `[` | Next and previous tool call                 |
| `o`         | Open the subagent log for the focused entry |
| `Escape`    | Return to the parent agent log              |
| `/`         | Focus the filter in the active panel        |
| `Home`      | Scroll to the first entry                   |
| `End`       | Jump to the newest entry and follow         |
| `?`         | Show all shortcuts                          |

## Where Sessions Come From

Every Copilot SDK host (the GitHub Copilot app, the Copilot CLI, and VS Code's Copilot harness) writes one folder per session under `session-state` in the Copilot home folder:

| Platform     | Default location                                     |
|--------------|------------------------------------------------------|
| macOS, Linux | `~/.copilot/session-state/<session id>/`             |
| Windows      | `%USERPROFILE%\.copilot\session-state\<session id>\` |

Setting `COPILOT_HOME` moves the Copilot home folder, and the canvas follows it. When the joined session reports its own folder, the canvas uses that folder's parent instead. Only macOS was exercised during development; the Windows and Linux locations follow the GitHub Copilot CLI documentation.

Each session folder holds `events.jsonl`, the append-only event log the canvas renders, and `workspace.yaml`, which supplies the title, repository, branch, and host shown in the session list. Folders without recorded events are not listed. A session is marked active while a host process holds it.

## Inventories

For the current session, the Details panel asks the host for live lists of agents, skills, instruction sources, MCP servers, plugins, extensions, and the current model. Each list is labeled with its source.

Live lists are not saved in the session log. For other sessions, and whenever a live list is unavailable, the canvas reconstructs what the log recorded: skill names and instruction files from the system prompt, the selected custom agent, tools that were offered or called, and the subagent types that ran. The full agent catalog is not recorded, so it appears as "Not recorded in session".

## Refresh and Resource Use

* The canvas indexes each session once and then reads only bytes appended since the last refresh. An unchanged refresh reads no file content.
* The index keeps short summaries and file offsets, not message text. Full content is read on demand when you expand an entry, in pages for very long fields.
* At most three session indexes stay in memory. Hook events are counted per turn rather than listed, and model debug events are counted only.
* The page polls about every 2 seconds for the open session and every 15 seconds for the session list, and only while it is visible. It keeps at most 400 entries rendered and loads earlier entries on request.

## Security and Privacy

Session logs can contain prompts, file contents, command output, and secrets that tools printed. The canvas treats that content as untrusted data and keeps it local:

* The page is served from `127.0.0.1` on a random port while the canvas is open, and the server stops when the canvas closes.
* Every request must name the loopback host, which blocks DNS rebinding. Data requests from other websites are rejected through browser Fetch Metadata, and no cross-origin access is granted.
* A strict content security policy allows only the canvas's own scripts and styles, and all session text is inserted as text, never as HTML. Links open only for `http` and `https`.
* The canvas reads session folders and writes no files. Its diagnostics are ephemeral, so they are not added to any session log.
* Live inventories pass through field allowlists, so prompts, instruction content, launch arguments, and environment values are never returned.

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
