<!-- markdownlint-disable MD013 -->
# Flow canvas (gh-aw pipeline) design

## Purpose

The GitHub Agentic Workflows agent (#58) is the last Meta-Utility with no cockpit surface. gh-aw runs a pipeline of event-driven workflows that hand off to each other through labels and GitHub events: issue-triage applies `agent-ready`, which triggers issue-implement, which opens a PR, which triggers pr-review, and so on (see `docs/architecture/agentic-workflows.md`, which already hand-draws this as a mermaid state diagram plus per-workflow flowcharts). A single workflow is not itself a control-flow graph; it is a trigger, activation guards, one agent prompt, and a whitelist of safe-outputs. The genuine graph is the orchestration across workflows.

This design adds a `flow` loop view: a node canvas with the look and feel of LangFlow / n8n (node cards with ports, Bezier edges, a minimap, pan and zoom), rendering that pipeline live. It is a NARRATION surface, not an authoring tool: the gh-aw agent narrates the graph and the live run (which workflow is firing, which handoff edge lit up, where a run failed); the user steers via the existing directive queue (for example "trigger on PRs too"), and the agent performs the edit and recompiles. The cockpit never authors or runs workflows itself.

The user picked: narration (not authoring); both levels with drill-in; Bezier edges plus full ports plus a minimap but cockpit-clean (no n8n cruft); the live run as the centerpiece (structure matters too, but watching the pipeline fire is the point); and both levels in this phase.

This is distinct from the existing decision-flow primitive (which uses `decisions` / `flow-slot` / `renderDecisionFlow`); this surface is a new `flow` domain with its own identifiers.

## A new `flow` domain

`flow` becomes a new loop-view domain, peer to `rpi`, `review`, `interview`, `backlog`, `team`, `codemap`, `dataprofile`, `gallery`, `promptlab`, and `memory`. Opening it switches the cockpit to the flow canvas, exactly as the others switch to theirs.

## Two levels, one node set

The canvas shows one of two levels at a time, drilled between client-side:

* Orchestration (the centerpiece): whole workflows as nodes, label/event handoffs as edges. This is the emergent agentic pipeline.
* Anatomy (drill-in): one workflow's internals as a small left-to-right flow: trigger, activation guards, the agent, the safe-outputs (and MCP servers).

Both levels live in one node/edge set, tagged by `scope`: orchestration nodes carry `scope: "orchestration"`; an anatomy node carries `scope: <workflow id>` (the id of the orchestration workflow node it belongs to). Clicking a workflow node drills into its anatomy instantly (client-side); a back control returns to orchestration. The agent can also drive the drill via `flow_focus` (for example, to pull the pane to a failing workflow during a debug narration).

## State

Five new `SessionState` fields:

* `flowTitle: string | null` (the pipeline heading, for example the repo name; null when no canvas is active).
* `flowNodes: FlowNode[]`, where `FlowNode = { id: string; scope: string; kind: FlowNodeKind; label: string; sub?: string; status: FlowStatus }`, `FlowNodeKind = "workflow" | "trigger" | "guard" | "agent" | "output" | "mcp"`, and `FlowStatus = "idle" | "running" | "passed" | "failed" | "skipped" | "stale"`.
* `flowEdges: FlowEdge[]`, where `FlowEdge = { id: string; from: string; to: string; scope: string; label?: string; kind: FlowEdgeKind; status: FlowEdgeStatus }`, `FlowEdgeKind = "label" | "event" | "output" | "step"`, and `FlowEdgeStatus = "idle" | "active"`.
* `flowFocus: string | null` (the agent-narrated drill target: a workflow id, or null for orchestration).

`scope` is a free string (`"orchestration"` or a workflow node id); `from`/`to` are node ids. Both collections upsert by `id` in place (preserve order on update; append a new id), the rule the other surfaces use. The agent narrates topology (nodes and edges) and run status; it does NOT supply positions, the client computes layout. Live-run animation is just re-upserting a node or edge with a new `status`.

## Beats and tools

Four new beats and four new MCP tools. The MCP tool count goes from 41 to 45.

| Tool | Beat | Effect |
| --- | --- | --- |
| `flow_open(title?)` | `flow.open` | Switch the view to `flow`, set `flowTitle` (default null), reset `flowFocus` to null, and clear `flowNodes` and `flowEdges` (a fresh canvas). |
| `add_flow_node(id, kind, label, scope?, sub?, status?)` | `flownode.add` | Append a `FlowNode`, or update the existing one with the same `id` in place. `scope` defaults to `"orchestration"`, `status` to `"idle"`. |
| `add_flow_edge(id, from, to, scope?, label?, kind?, status?)` | `flowedge.add` | Append a `FlowEdge`, or update the existing one with the same `id` in place. `scope` defaults to `"orchestration"`, `kind` to `"label"`, `status` to `"idle"`. |
| `flow_focus(workflow?)` | `flow.focus` | Set `flowFocus` to the given workflow id, or null (omitted) to return to the orchestration level. |

`kind` and `status` are zod enums at the tool boundary (node kind and node status; edge kind and edge status are separate enums), so an out-of-enum value is rejected rather than rendered. The tool descriptions disambiguate a flow node from a kanban item / memory entry / prompt case, and explain the orchestration-vs-anatomy `scope`.

## View-model

`toViewModel` projects:

```text
flow: {
  title: string | null;
  focus: string | null;
  nodes: { id; scope; kind; label; sub: string | null; status }[];
  edges: { id; from; to; scope; label: string | null; kind; status }[];
}
```

A direct pass-through of the five state fields, with `sub` and `label` null-coalesced. Layout (node positions, the camera, edge routing) is computed in the client, not the projection, so `toViewModel` stays pure data.

## The view

A new `#flow-view`, a sibling of the other loop views, shown when `v.domain === "flow"` and hidden otherwise (the same mutually-exclusive routing). It fills `#loop` and renders an n8n-style node canvas.

### Active level and layout

The active level is the client focus override if set, else `v.flow.focus`, else orchestration. When the agent sends a new `flow.focus`, the client override is cleared so server narration wins; a local click sets the override so user interaction wins until the next narration (the seed-plus-override pattern the gallery size toggle uses).

The active node set is the nodes whose `scope` matches the active level (`"orchestration"`, or the focused workflow id); the active edges are those with the same scope.

`computeFlowLayout(nodes, edges)` is a pure function (unit-testable) that assigns each active node an `{ x, y }`:

* Build adjacency from the active edges. Assign layers by longest-path from the roots (in-degree 0), computed by a DFS that ignores back edges (an edge to a node already on the DFS stack), so a feedback edge such as pr-review's `needs-revision` returning to implement does not break layering (the back edge still renders, curving back).
* Order nodes within a layer by first-seen (insertion) order. Position: `x = layer * COL_W`, `y = orderInLayer * ROW_H`, centered per column. Anatomy (a mostly linear chain with the agent fanning out to several outputs) lays out as columns naturally.

### Canvas, nodes, edges

* World: a `#gw-world` div with a CSS camera `transform: translate(camX, camY) scale(camZ)`. Pan by dragging the canvas background; zoom by wheel around the cursor. On a new node set, fit the graph bounding box into the viewport (initial camera).
* Nodes: absolutely-positioned `.gw-node.gw-k-{kind}.gw-s-{status}` cards at their computed `{ x, y }`. A typed header (a kind glyph plus the `label`), a body (`sub`), an input port `.gw-port.gw-in` (left) and an output port `.gw-port.gw-out` (right). Status drives the look: running pulses an accent border, passed green, failed red, skipped muted, stale amber, idle neutral.
* Edges: one `<svg>` layer inside `#gw-world` (so edges track the camera) drawing a cubic Bezier `<path>` per active edge from the source out-port to the target in-port, with an arrowhead marker and the `label` at the midpoint. `.gw-edge.gw-e-{kind}`; `.gw-active` animates the stroke (dash-offset) for an edge that is currently firing.

### Live run, drill-in, minimap, inspector, legend

* Live run (the centerpiece): the agent narrates a run by stepping statuses, setting the active workflow node `running`, the firing edge `active`, then `passed` or `failed`, and so on. The client only renders the status classes; the CSS animates. On a failure the agent may `flow_focus` the failing workflow so the pane drills into its anatomy.
* Drill-in: clicking a `workflow`-kind node sets the client focus override to that node id and re-lays-out to its anatomy. A `back to pipeline` control clears the override. Instant and client-side.
* Selection and inspector: clicking any node selects it (client state) and a right-side inspector panel shows its details (label, kind, status, sub). Clicking the canvas background clears the selection.
* Minimap: a fixed bottom-right panel showing all active nodes as scaled dots plus a viewport rectangle reflecting the camera; clicking recenters the camera there.
* Legend: a compact left-side key of the node kinds (the cleaned-up palette, read-only since this is narration not authoring).

Every interpolated field (title, label, sub, edge label) goes through the existing `esc()` helper. Status and kind reach the DOM only as enum-locked class suffixes. The keyboard and pointer wiring follows the existing delegated-handler pattern; pan/zoom/drag reuse the approach the codemap camera established.

## Agent contract

`agents/cockpit-instructions.md` gains a gh-aw section: the agent calls `flow_open(title?)` when it begins working a gh-aw pipeline; `add_flow_node` per workflow (kind `workflow`, scope `orchestration`) and per anatomy element (kind trigger/guard/agent/output/mcp, scope the workflow id) and `add_flow_edge` for each handoff (kind label/event/output) and anatomy step (kind step); it narrates a run by re-calling `add_flow_node` / `add_flow_edge` with a new `status` (node running/passed/failed, edge active) and `flow_focus(workflow)` to drill the pane to a workflow during a debug. A note records that the user steers a workflow's trigger/outputs through the directive queue (`check_directives`), and the agent edits the `.md` and recompiles; the cockpit never authors or runs workflows.

## Testing

* state: `flow.open` sets the title and clears nodes/edges and resets focus; `flownode.add` appends, defaults scope/status, and a same-id add updates in place (order preserved); `flowedge.add` appends, defaults scope/kind/status, and upserts by id; `flow.focus` sets and clears (null) the focus.
* view-model: `toViewModel` exposes `flow.title`/`focus` and the `nodes`/`edges` arrays with every field, null-coalescing `sub`/`label`; null title, empty arrays, null focus when no canvas started.
* tools: a round trip drives `flow_open` + `add_flow_node` + `add_flow_edge` + `flow_focus` over the in-memory transport and asserts `bridge.state.flowNodes` / `flowEdges` / `flowFocus`; the tool-count assertion goes 41 to 45; `add_flow_node` rejects a `kind` or `status` outside its enum and `add_flow_edge` rejects a `kind` or `status` outside its enum.
* layout: `computeFlowLayout` is unit-tested as a pure function: a linear chain lays out in increasing layers; a fan-out (one source to several targets) places the targets in one later layer; a back edge (target is an ancestor) does not change the forward layering and the function does not loop forever.
* client: the `flow` domain shows `#flow-view` and hides the others; orchestration nodes render with `gw-k-workflow` and `gw-s-{status}` classes; an SVG path renders per active edge; clicking a workflow node drills into its anatomy (the anatomy-scoped nodes render, the orchestration nodes do not) and the back control returns; clicking a node selects it and the inspector shows its label; an `active` edge carries the `gw-active` class; fields are escaped. The client test follows the existing happy-dom render-harness pattern.
* `tsc --noEmit`, the full vitest suite, `node --check public/client.js`, and markdown lint (repo root) must be green.

## Scope

In scope: the `flow` domain, the five state fields and their four beats, the four MCP tools with kind/status validation, the view-model projection, the `#flow-view` node canvas (camera pan/zoom, n8n-style node cards with ports, Bezier edges with arrowheads and labels, live-run status animation, instant client-side drill-in between orchestration and anatomy plus agent-driven `flow_focus`, the minimap, the inspector, and the legend), the pure `computeFlowLayout`, the agent contract, and the tests above.

Deferred / non-goals:

* Authoring: dragging nodes to build a workflow, editing config in the inspector, wiring edges by hand, or round-tripping the canvas back to the `.md` frontmatter and prose. This surface narrates and the user steers; it does not author (the option-A authoring tool is a separate, much larger build).
* Compiling, running, or validating workflows from the pane: the cockpit shows what the agent narrates; the agent runs `gh aw compile` / `logs` / `audit` itself.
* A full crossing-minimization layout: the layered longest-path layout with first-seen within-layer order is enough at this scale (about 5 to 15 nodes); barycenter crossing reduction is a later refinement.
* Manual node repositioning persisted to state, named multi-ports per node, or sub-flow nesting beyond the two levels.
* The compiled `.lock.yml` preview: if wanted later it can reuse `show_screen`, not this surface.
