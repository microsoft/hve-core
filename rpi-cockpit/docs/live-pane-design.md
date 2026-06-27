<!-- markdownlint-disable MD013 -->
# Live pane via a file-backed cross-process bridge

## Purpose

The cockpit works end to end (a real MCP client drives the server, beats reach the WebSocket, the views render), but in Claude Code the live agent feed and the Preview pane are two separate processes that do not share state, so the pane shows the demo tour instead of the real session. This spec closes that gap with a file-backed bridge over a shared state directory, so the pane renders the live, agent-driven session and can steer it back.

## The two-process problem

A host like Claude Code launches the cockpit twice, as two OS processes with two in-memory bridges:

| Process | Launched by | Bridge | Role |
| --- | --- | --- | --- |
| MCP server (`dist/index.js`) | `.mcp.json` (stdio) | the real one the agent drives via 30 tools | producer of state |
| Pane server (`preview.mjs` today) | `.claude/launch.json` (a web server the pane views) | a separate bridge running the demo tour | consumer that renders |

The agent's beats land in the producer's bridge; the pane renders the consumer's bridge; they never meet. The existing `directives.jsonl` and `decisions.jsonl` sinks are one-directional audit records, not a shared live channel, and the default state dir is port-keyed (`os.tmpdir()/rpi-cockpit/<port>`), so the two processes do not even agree on a directory.

## The shared state directory

Both processes derive the SAME directory from the repository root, with no host-specific env interpolation needed: `liveStateDir(repoRoot) = os.tmpdir()/rpi-cockpit/live/<short hash of repoRoot>`. The producer (the MCP server) knows its repo root from its own path; the consumer (the same binary in `live` mode) computes it identically. `RPI_COCKPIT_STATE_DIR` still overrides it for tests and custom hosts.

## The two files

| File | Writer | Reader | Contents |
| --- | --- | --- | --- |
| `state.json` | producer | consumer | The full `SessionState` snapshot, rewritten on every change, written atomically (temp file then rename) so the consumer never reads a half-written file |
| `inbox.jsonl` | consumer | producer | One user-intent frame per line (steer, decide, answer, navigate, navigator, intervene, launch), appended as the user interacts with the live pane |

Ownership is strict and one-way per file: only the producer writes `state.json`, only the consumer writes `inbox.jsonl`. This avoids any read-write loop.

## Producer (the MCP server)

In its normal (non-`init`) run, `dist/index.js`:

1. Starts the UI server with snapshot writing on, so every bridge state change atomically rewrites `state.json` in the shared dir.
2. Tails `inbox.jsonl` from a byte offset (polling on a short interval), starting at the end of the file on startup so a producer restart does not replay a prior session's intents: for each new complete line, it validates the frame and applies it to its bridge exactly as the in-process WebSocket handler would (steer to enqueueDirective, decide to resolveDecision, answer to resolveQuestion, navigate, navigator open/close, intervene, launch). So a click in the live pane resolves the agent's blocking decision or queues a steer note across the process boundary.

The producer keeps serving its own keyed UI on its port too (unchanged), so a browser opened directly at its URL still works; the file bridge is additive.

## Consumer (the live pane)

A new `live` subcommand, `dist/index.js live`, run by `.claude/launch.json` on the host-assigned port:

1. Serves the cockpit UI in embed mode (trusted loopback, no token) so the pane loads with no key.
2. Watches `state.json` (a polling watch for cross-platform reliability) and, on each change, loads it as the rendered state and broadcasts it to connected pane clients. It holds no authoritative state of its own.
3. Routes every inbound WebSocket frame to `inbox.jsonl` instead of mutating a local bridge, so user actions travel to the producer.

`preview.mjs` stays as the standalone demo tour for `npm run preview`; the host pane now points at `live` instead.

## Server changes

`startServer` gains two options, both additive and off by default so existing callers and tests are unchanged:

* `writeStateSnapshot`: when true, atomically write `state.json` on every state event (producer only).
* `onInbound`: when provided, recognized inbound frames are handed to this callback instead of driving the bridge (the consumer routes them to `inbox.jsonl`).

The frame validation used by the WebSocket handler is factored into one place so the consumer's routing and the producer's inbox tailing validate identically.

## Scope

In scope:

* The shared `liveStateDir` helper, the atomic `state.json` snapshot, and the `inbox.jsonl` intent channel.
* `startServer` `writeStateSnapshot` and `onInbound` options, plus shared frame validation.
* The `live` consumer mode (`src/live.ts` + the `dist/index.js live` subcommand) and the producer's inbox tailing.
* Wiring `.claude/launch.json` to the `live` consumer.
* Tests for the snapshot round-trip (write state to a dir, read it back as a view-model), the inbox apply path (a frame line drives the bridge), atomic write, and the consumer routing frames to the inbox.

Deferred:

* Multiple concurrent live sessions in one repo (one shared dir per repo for now).
* Snapshot compaction or history; `state.json` is latest-only and `inbox.jsonl` is drained by offset.
* A heartbeat or staleness indicator when the producer is not running (the pane simply shows the last snapshot).
* Replacing the JSONL talk-back records; those stay as the durable audit trail.

## Non-goals

* No networked or remote bridge. This is loopback and local files only, same trust boundary as today.
* The consumer never becomes a second source of truth; it only mirrors `state.json` and forwards intent.
* No new agent capabilities; this is host integration so the existing cockpit renders a real session.
