# RPI Cockpit — live wiring + steering design spec

**Status:** draft for review · **Date:** 2026-06-24 · **Increment:** v2 (wire the GUI to live state; add browser → agent steering)

## Summary

The RPI Cockpit's backend is clean — `mcp.ts → handlers.ts → bridge.ts → state.ts` reducer → `server.ts` (HTTP + WebSocket) broadcasting the full `SessionState` on every beat. The polished dashboard (`public/index.html`) is, however, a **half-static mockup**: the header, breadcrumb, phase title, "running" badge, host pill, and lead paragraph are hardcoded demo content, while only five regions (`#steps`, `#subagents`, `#gate`, `#decision`, `.stream`) actually update from live state. When a real session runs, half the screen contradicts the other half.

This increment makes the dashboard an honest, complete view of the live session, and adds the first real **Steer** capability: the browser can queue directives that the agent pulls at its next checkpoint.

This builds on [`2026-06-24-rpi-cockpit-design.md`](./2026-06-24-rpi-cockpit-design.md), which named three verbs (Show / Steer / Decide). v1 delivered Show + Decide (`present_options`). This increment completes **Show** (every element is state-driven) and delivers the first slice of **Steer**.

## Goals

1. **The dashboard never lies.** Every visible element is a pure function of `SessionState`. No hardcoded session content survives.
2. **Honest empty + connection states.** Before `session_begin`, show a clear waiting state. The "live" pill reflects the real WebSocket connection, and the client auto-reconnects.
3. **Browser → agent steering.** The user can (a) inject a free-text **note** and (b) choose a **next-phase approach**, which the agent picks up at its next checkpoint.

## Non-goals (this increment)

- No pause/resume, no re-run/redo (explicitly deferred).
- No orchestration changes — the harness remains the brain; the cockpit stays a membrane.
- No new runtime dependencies; `public/` stays build-free static HTML + JS.
- No multi-user / remote.

## Core constraint that shapes the design

The cockpit MCP server is **passive**: the agent calls *into* it; it cannot push to the agent. So steering is **pull-based**, mirroring the proven `present_options` pattern:

> Browser queues a directive → the server holds it → the agent pulls it at its next natural checkpoint (a `phase_enter`) and acts on it.

## Architecture

Data flow for narration is unchanged:

```
agent → MCP tool → handler → bridge.emitBeat → state reducer → bridge "state" event
      → server broadcasts FULL SessionState over WS → client render(state)
```

The server already broadcasts the **entire** `SessionState` on every beat. "Wiring the GUI" is therefore mostly client-side: make `render(state)` repaint every element instead of five. The remaining work is the steering channel, which reuses the existing inbound WS seam (today only `{type:"decide"}`).

### Steering protocol (new)

```
Browser → WS {type:"steer", directive} → server → bridge.enqueueDirective
        → state.directives gets a PENDING entry → broadcast (user instantly sees "queued")

Agent   → MCP check_directives() → bridge.drainDirectives → returns queued directives as text,
          removes them from state, logs each as consumed → broadcast. Agent reads the text and acts.

Agent   → MCP offer_approaches(label, options[]) → sets state.steerMenu → broadcast
        → the Steer select shows those phase-specific options
```

Two new MCP tools (7 → 9):

- **`offer_approaches(label: string, options: OptionItem[])`** — informational beat. Populates the Steer select with phase-specific choices. Optional for the agent; when it hasn't been called, the select falls back to fixed presets.
- **`check_directives()`** — returns any queued user directives and drains them. The agent **must act on the return value**, exactly like `present_options`. The narration contract instructs the agent to call this at each `phase_enter`.

## Data model changes

`SessionState` gains two fields (additive; existing fields unchanged):

```ts
directives: Directive[]          // pending, unconsumed user directives
steerMenu: SteerMenu | null      // null ⇒ client shows fixed presets

type Directive =
  | { id: string; kind: "note"; text: string }
  | { id: string; kind: "approach"; value: string; label: string };

type SteerMenu = { label: string; options: { id: string; title: string; detail?: string }[] };
```

`steerMenu` persists until the agent replaces it with a newer `offer_approaches` call or a `phase.enter` resets it (a menu offered for one phase does not linger into the next). Inbound steer directives from the browser are **id-less**; the bridge stamps the id when it enqueues (`enqueueDirective(state, directive, id)`), so ids stay server-authoritative and never collide with decision ids.

- **`events.ts`** — add `Directive` and `SteerMsg` (inbound WS) zod schemas; add an `approaches.offer` member to the `Beat` discriminated union.
- **`state.ts`** — `initialState()` seeds `directives: []`, `steerMenu: null`. `applyBeat` handles `approaches.offer` (sets `steerMenu`) and clears `steerMenu` on `phase.enter`. Add two pure helpers so **all** transitions live in one tested place:
  - `enqueueDirective(state, directive, id) → SessionState`
  - `drainDirectives(state, now) → { state: SessionState; drained: Directive[] }` (removes pending directives, appends one `log` entry per consumed directive).
- **`bridge.ts`** — `enqueueDirective(d)`, `drainDirectives()`, `offerApproaches(label, options)`. Directive ids reuse the existing `seq` counter (e.g. `s${++this.seq}`).
- **`handlers.ts` / `mcp.ts`** — register `offer_approaches` and `check_directives`.
- **`server.ts`** — handle inbound `{type:"steer", directive}` (zod-validated via `SteerMsg`) alongside the existing `{type:"decide"}`; on receipt, `bridge.enqueueDirective(...)`.

## Frontend changes

`index.html` gains stable element IDs; `client.js` becomes a single pure `render(state)` plus a connection manager.

**Bindings (every element state-driven):**

| Element | Source |
|---|---|
| `#crumb-task` | `state.task` (fallback "—") |
| host pill | `via MCP · ${state.host}` (hidden when empty) |
| connection pill | WebSocket status: connecting / live / offline (color-coded) |
| `#phase-title` | `Phase {n} · {Label}` from `state.phase` (n = index in RPI order + 1) |
| phase badge | running / idle |
| `#lead` | honest per-phase copy (see below) |
| `#steps`, `#subagents`, `#gate`, `#decision`, `.stream` | as today, with empty-state fallbacks |
| Steer select | `state.steerMenu.options` when present, else fixed presets |
| directives list | `state.directives` (pending), each shown as "queued · applies at next checkpoint" |

**Honest per-phase lead copy** (static text keyed by phase — descriptive, not fabricated session data):

- research — "Gathering context and constraints before committing to a plan."
- plan — "Turning research into an ordered, reviewable plan."
- implement — "Executing the plan. Subagents and validation run here; the loop won't advance until checks pass."
- review — "Verifying the work against the plan and the validation gate."
- discover — "Surfacing follow-up work uncovered during the cycle."

**Empty/initial state** — when `state.task === ""` && `state.phase === null`: "Waiting for an RPI session… the cockpit is connected and lights up when the agent calls `session_begin`." The phase panels show neutral placeholders rather than fake "Phase 3 · Implement".

**Connection + reconnect** — wrap socket creation in `connect()`; `onclose` schedules a backoff retry and sets the pill to "offline". Because the server sends the full state on every new connection, the UI re-syncs automatically on reconnect — no client-side replay needed.

**Steer panel** — the select (from `steerMenu` or presets) plus a free-text note box and a send button. Sending posts `ws.send({type:"steer", directive})`. Fixed presets: `default`, `be more thorough`, `move faster`, `ask before big changes`. The pending-directives list flips entries to consumed when the agent drains them.

## Honesty cleanup (removals)

Delete chrome with no data source — these are exactly the "unclean" bits:

- "Difficulty: challenging" / "cycle 1" chips (no backing data).
- The hardcoded `.copilot-tracking/plans/` path in the lead (replaced by per-phase copy).
- The decorative **Pause button** in the topbar (pause/resume is out of scope; a dead button is the kind of thing we're removing). The theme toggle stays.

## Narration contract changes

`agents/cockpit-instructions.md` documents the two new tools:

- `offer_approaches(label, options[])` — call at a phase boundary to give the user a structured choice for the next phase (optional).
- `check_directives()` — call at each `phase_enter` (and before major decisions). It returns immediately with any queued user directives; you **must** read and incorporate them.

Re-running `init --host <…>` regenerates the inlined per-host blocks (`CLAUDE.md`, `AGENTS.md`, `.github/copilot-instructions.md`), so the contract update propagates idempotently.

## Error handling

- **Malformed inbound WS messages** — already ignored on JSON parse failure; the new `steer` branch additionally validates with `SteerMsg` and drops anything non-conforming (no throw).
- **Steer before a session exists** — directives queue regardless; they're delivered whenever the agent next calls `check_directives`. Harmless if never drained.
- **UI server unavailable** — unchanged: narration/steering state still lives in the bridge; only the browser face is degraded. (The agent can't receive steering without the UI to enqueue it, which is acceptable.)
- **Reconnect storms** — backoff caps the retry interval; each reconnect gets a full state snapshot.

## Testing

- **`state.test.ts`** — `approaches.offer` sets `steerMenu`; `enqueueDirective` appends pending; `drainDirectives` clears pending and logs each consumed directive.
- **`bridge.test.ts`** — `enqueueDirective` / `drainDirectives` / `offerApproaches` mutate state and emit `state`.
- **`handlers.test.ts`** — `offer_approaches` and `check_directives` behavior, including drain-and-return text.
- **`mcp.test.ts`** — nine tools registered.
- **`server.test.ts` / `e2e.test.ts`** — inbound `{type:"steer"}` enqueues; a full round trip where the agent drains directives.
- **`render.test.ts`** (happy-dom) — header/host/phase/lead bind from state; empty state renders; select shows declared menu vs presets; connection pill reflects status; pending directives render.

## Rollout

Additive and backward-compatible: existing beats and the seven original tools are unchanged. A host that never calls the new tools behaves exactly as today, but now shows an honest, fully state-driven dashboard. After merge, run `init` once per host to refresh the contract.
