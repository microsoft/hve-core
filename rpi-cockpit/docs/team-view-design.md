<!-- markdownlint-disable MD013 -->
# Live team-orchestration view design

## Purpose

This is the first starred item from the roadmap's parking lot, promoted because it is too good to wait on now that the UX foundation is solid. It is the live team-orchestration view: an orchestrator and its subagents shown as a board you watch and intervene in, with the ability to pause, swap, or spawn an agent mid-run. Where the RPI loop shows one agent's phases, the team view shows a whole team at once, so a multi-agent run stops being an opaque wall of log lines and becomes a legible, steerable board.

This spec covers the team view: a new `team` domain, the beats that build and update the roster, the view-model and board it renders, and, most importantly, the intervention model that lets the user pause, swap, or spawn while staying true to the cockpit's charter. It follows the loop-view shape already set by the findings, interview, and backlog views, and the talk-back shape already set by the steer panel and the decision card. It builds on the archetype work in [docs/representation-map.md](representation-map.md) and the launch-boundary principle in [docs/navigator-design.md](navigator-design.md).

## What it represents

A team run has one orchestrator (the lead) and a roster of subagents, each doing a piece of the work, each in some state at any moment. The view makes that legible as a board grouped by agent status, with the orchestrator in the header.

| Concept | On the board |
| --- | --- |
| Orchestrator | The header: the lead's name and the overall task it is running |
| Subagents | Cards in status columns, each with a name, a role, and its current action |
| Status | The columns: running, blocked, queued, done, failed |
| Intervention | Per-agent pause and swap controls, and a spawn control in the header |

## The intervention model (the charter boundary)

The headline feature is intervention, and it must respect the rule that has held since the Navigator: the cockpit captures intent and the agent performs the action. The cockpit cannot and does not pause, swap, or spawn an agent itself. It has no handle on the running agents; it is a UI. So an intervention is an intent the user expresses, sent over the same talk-back channel the steer panel already uses, which the orchestrator drains through `check_directives` and acts on. The cockpit then reflects whatever the orchestrator does through the normal `agent.update` beats.

| Control | What the cockpit does | What the orchestrator does |
| --- | --- | --- |
| Pause an agent | Emits a pause intent for that agent id | Reads it via `check_directives`, pauses that subagent, narrates the new status |
| Swap an agent | Emits a swap intent for that agent id | Decides a replacement, swaps it, narrates the roster change |
| Spawn an agent | Emits a spawn intent | Decides what to spawn, starts it, narrates the new agent |

This keeps the team view honest: the controls are real and immediate as expressions of intent, and the board updates as the orchestrator acts, but the cockpit never reaches into the run. The interventions ride the existing directive queue, so they also work on hosts that read the directive file rather than the live MCP connection, exactly like steer notes.

## Protocol additions

Four beats build and update the roster, mirroring how the backlog board uses `backlog.start` plus item beats. The team agents are distinct from the RPI `subagent.start`/`subagent.stop` beats, which stay for the single-agent loop.

| Beat | Fields | Effect |
| --- | --- | --- |
| `team.start` | `task`, `orchestrator` | Switches the domain to `team`, sets the orchestrator and task, resets the roster |
| `agent.add` | `id`, `name`, `role?`, `status` | Adds a team agent, or replaces the one with the same id |
| `agent.update` | `id`, `status?`, `action?` | Updates an agent's status and/or current action; a no-op if the id is unknown |
| `agent.remove` | `id` | Removes an agent from the roster |

Agent status is one of `queued`, `running`, `blocked`, `done`, `failed`. As with the other views, `team.start` is self-sufficient: it sets `view: "loop"` and `domain: "team"` so a cold team run lands on the board.

The MCP surface adds `team_start`, `add_agent`, `update_agent`, and `remove_agent`, each a thin wrapper over its beat. The intervention path adds one inbound frame, `{ type: "intervene", action: "pause" | "swap" | "spawn", agentId? }`, handled by a `bridge.intervene` that enqueues a directive (a note the orchestrator reads), reusing the existing directive queue and `check_directives` drain. No new outbound beat is needed for intervention; the orchestrator narrates the result with `agent.update`.

## State and view-model

Session state gains `team` in the domain union, an `orchestrator: string | null`, and a `teamAgents` array of `{ id, name, role?, status, action? }`. The reducers follow the existing idioms: `agent.add` replaces by id (like `item.add`), `agent.update` maps over the roster (like `subagent.stop`), `agent.remove` filters. The view-model projects the orchestrator, the task, and the roster grouped into status columns in a fixed order (running, blocked, queued, done, failed), with empty columns dropped so the board shows only the states in play.

## Rendering

The client adds a `#team-view` section inside the loop container, routed when `domain` is `team`, hiding the other views (the same routing the findings, interview, and backlog views use). A `renderTeam` function paints the header (orchestrator, task, and a Spawn button) and the status columns of agent cards. Each card shows the agent name, role, a status badge, and its current action, plus Pause and Swap controls. The controls are keyboard-accessible buttons, and clicking one sends the matching `intervene` frame. The board reuses the kanban column and card styling so it reads as part of the same product.

## Scope

In scope:

* The four roster beats and their MCP tools.
* The `team` domain, the orchestrator and roster state, and the status-grouped view-model.
* The `intervene` inbound frame, `bridge.intervene`, and the Pause / Swap / Spawn controls, all expressing intent over the existing directive queue.
* The `#team-view` board: orchestrator header, status columns, agent cards with status, action, and controls.
* Tests for the reducers, the view-model grouping, the MCP tools, the intervene-to-directive path, and the client rendering, routing, and control frames.

Deferred:

* A dependency or hand-off graph between agents (who spawned whom, who is waiting on whom). The roster is flat by status for now.
* Per-agent live output or a drill-in to a single agent's transcript.
* Swap and spawn target pickers in the cockpit (which agent type to swap in). The intent is generic for now and the orchestrator decides specifics.
* Direct cockpit control of agents. Out of scope by charter, permanently.

## Non-goals

* The cockpit does not pause, swap, or spawn agents. It expresses the user's intent and reflects what the orchestrator does. This is the same launch boundary the Navigator holds.
* The team view is not a scheduler or a process manager. It is a legibility and steering surface over an orchestration the agent runs.
* No new agent capabilities. The orchestration ships in HVE Core; the cockpit renders and steers it.
