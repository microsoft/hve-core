# RPI Cockpit — Live GUI Wiring + Steering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every element of the RPI Cockpit dashboard a pure function of live session state, and add a browser→agent steering channel (free-text notes + a next-phase approach select).

**Architecture:** The server already broadcasts the full `SessionState` on every beat. We resolve the orphaned-but-tested `toViewModel` (`src/render.ts`) by making it the single shaping seam the server broadcasts as `view`, so `client.js` becomes a thin, logic-free painter. Steering reuses the existing inbound-WebSocket seam: the browser sends a `steer` message, the `Bridge` queues a directive, and two new MCP tools (`offer_approaches`, `check_directives`) let the agent populate the select and pull directives at its checkpoints — the same pull pattern `present_options` already uses.

**Tech Stack:** TypeScript (ESM, NodeNext), Node ≥ 20, `@modelcontextprotocol/sdk`, `ws`, `zod`, Vitest (node environment). Browser client is dependency-free static HTML + JS in `public/`.

## Global Constraints

- ESM throughout: every relative import uses a `.js` extension, even from `.ts` sources.
- `strict` TypeScript must pass `npx tsc --noEmit` (only `src/**` is type-checked; `rootDir` is `src`).
- All runtime input validated with `zod`, mirroring `src/events.ts`.
- No new runtime dependencies. `public/` stays build-free (no bundler, no framework).
- Vitest runs in the `node` environment — keep display logic in `toViewModel` (Node-testable); do not add DOM tests.
- The WebSocket frame keeps its existing shape `{ type: "state", state }` and **adds** a `view` field. Existing consumers that read `msg.state` keep working.
- Tool count grows 7 → 9. `present_options` behavior is unchanged.
- Run all commands from `rpi-cockpit/`. Test: `npx vitest run`. Type-check: `npx tsc --noEmit`.
- Conventional-commit messages, one commit per task.

---

### Task 1: Directive + steer schemas and the `approaches.offer` beat

**Files:**
- Modify: `rpi-cockpit/src/events.ts`
- Test: `rpi-cockpit/tests/events.test.ts`

**Interfaces:**
- Consumes: existing `OptionItem`, `Beat` from `events.ts`.
- Produces:
  - `Directive` = `{ id: string; kind: "note"; text: string } | { id: string; kind: "approach"; value: string; label: string }`
  - `InboundDirective` = `Directive` without `id` (same two kinds).
  - `SteerMsg` = `{ type: "steer"; directive: InboundDirective }`
  - new `Beat` member `{ type: "approaches.offer"; label: string; options: OptionItem[] }`

- [ ] **Step 1: Write the failing tests**

Add to `rpi-cockpit/tests/events.test.ts`:

```ts
import { Beat, OptionItem, InboundDirective, SteerMsg } from "../src/events.js";

it("parses an approaches.offer beat", () => {
  const b = Beat.parse({ type: "approaches.offer", label: "Pick", options: [{ id: "a", title: "A" }] });
  expect(b).toMatchObject({ type: "approaches.offer", label: "Pick" });
});

it("parses an inbound note directive and rejects an empty one", () => {
  expect(InboundDirective.parse({ kind: "note", text: "focus on errors" }).kind).toBe("note");
  expect(() => InboundDirective.parse({ kind: "note", text: "" })).toThrow();
});

it("parses a steer message carrying an approach directive", () => {
  const m = SteerMsg.parse({ type: "steer", directive: { kind: "approach", value: "faster", label: "Move faster" } });
  expect(m.directive).toMatchObject({ kind: "approach", value: "faster" });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npx vitest run tests/events.test.ts`
Expected: FAIL — `InboundDirective`/`SteerMsg` are not exported; `approaches.offer` is not a valid `Beat`.

- [ ] **Step 3: Implement the schemas**

In `rpi-cockpit/src/events.ts`, add the `approaches.offer` member to the `Beat` union (insert before the closing `]` of `discriminatedUnion`):

```ts
  z.object({ type: z.literal("approaches.offer"), label: z.string(), options: z.array(OptionItem).min(1) }),
```

Then append at the end of the file:

```ts
export const InboundDirective = z.discriminatedUnion("kind", [
  z.object({ kind: z.literal("note"), text: z.string().min(1) }),
  z.object({ kind: z.literal("approach"), value: z.string().min(1), label: z.string() }),
]);
export type InboundDirective = z.infer<typeof InboundDirective>;

export const Directive = z.discriminatedUnion("kind", [
  z.object({ id: z.string(), kind: z.literal("note"), text: z.string().min(1) }),
  z.object({ id: z.string(), kind: z.literal("approach"), value: z.string().min(1), label: z.string() }),
]);
export type Directive = z.infer<typeof Directive>;

export const SteerMsg = z.object({ type: z.literal("steer"), directive: InboundDirective });
export type SteerMsg = z.infer<typeof SteerMsg>;
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `npx vitest run tests/events.test.ts`
Expected: PASS (all events tests).

- [ ] **Step 5: Commit**

```bash
git add rpi-cockpit/src/events.ts rpi-cockpit/tests/events.test.ts
git commit -m "feat(cockpit): directive/steer schemas and approaches.offer beat"
```

---

### Task 2: Session state — `steerMenu`, `directives`, and queue helpers

**Files:**
- Modify: `rpi-cockpit/src/state.ts`
- Test: `rpi-cockpit/tests/state.test.ts`

**Interfaces:**
- Consumes: `Directive`, `OptionItem` from `events.ts`.
- Produces:
  - `SessionState` gains `directives: Directive[]` and `steerMenu: SteerMenu | null`.
  - `interface SteerMenu { label: string; options: OptionItem[] }` (exported).
  - `enqueueDirective(s: SessionState, directive: Directive, now: number): SessionState`
  - `drainDirectives(s: SessionState, now: number): { state: SessionState; drained: Directive[] }`
  - `applyBeat` handles `approaches.offer` (sets `steerMenu`) and clears `steerMenu` on `phase.enter`.

- [ ] **Step 1: Write the failing tests**

Add to `rpi-cockpit/tests/state.test.ts`:

```ts
import { initialState, applyBeat, enqueueDirective, drainDirectives } from "../src/state.js";

it("offers a steer menu and clears it on the next phase", () => {
  let s = applyBeat(initialState(), { type: "approaches.offer", label: "Pick", options: [{ id: "a", title: "A" }] }, 1);
  expect(s.steerMenu).toMatchObject({ label: "Pick" });
  s = applyBeat(s, { type: "phase.enter", phase: "review" }, 2);
  expect(s.steerMenu).toBeNull();
});

it("queues a directive and logs it", () => {
  const s = enqueueDirective(initialState(), { id: "s1", kind: "note", text: "focus on errors" }, 7);
  expect(s.directives).toHaveLength(1);
  expect(s.log.at(-1)).toMatchObject({ kind: "directive.queued" });
});

it("drains directives, clearing the queue and logging each", () => {
  const queued = enqueueDirective(initialState(), { id: "s1", kind: "approach", value: "faster", label: "Move faster" }, 7);
  const { state, drained } = drainDirectives(queued, 8);
  expect(drained).toHaveLength(1);
  expect(state.directives).toHaveLength(0);
  expect(state.log.at(-1)).toMatchObject({ kind: "directive.consumed" });
});

it("drains to empty when there is nothing queued", () => {
  const { state, drained } = drainDirectives(initialState(), 8);
  expect(drained).toHaveLength(0);
  expect(state.log).toHaveLength(0);
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npx vitest run tests/state.test.ts`
Expected: FAIL — `enqueueDirective`/`drainDirectives` not exported; `approaches.offer` not handled.

- [ ] **Step 3: Implement state changes**

In `rpi-cockpit/src/state.ts`:

Update the import to include `Directive`:

```ts
import type { Beat, Phase, OptionItem, ValidationStatus, Directive } from "./events.js";
```

Add the `SteerMenu` interface and two fields to `SessionState`:

```ts
export interface SteerMenu { label: string; options: OptionItem[]; }
```

In `SessionState`, add after `pendingDecision`:

```ts
  directives: Directive[];
  steerMenu: SteerMenu | null;
```

In `initialState()`, add the two fields:

```ts
  return { task: "", host: "", phase: null, phasesDone: [], subagents: [], validations: {}, artifacts: [], pendingDecision: null, directives: [], steerMenu: null, log: [] };
```

In `applyBeat`, change the `phase.enter` case to clear the menu, and add an `approaches.offer` case:

```ts
    case "phase.enter": {
      const phasesDone = s.phase && s.phase !== beat.phase && !s.phasesDone.includes(s.phase)
        ? [...s.phasesDone, s.phase] : s.phasesDone;
      return { ...s, phase: beat.phase, phasesDone, steerMenu: null, log };
    }
    case "approaches.offer":
      return { ...s, steerMenu: { label: beat.label, options: beat.options }, log };
```

Add the `approaches.offer` case to `summarize`:

```ts
    case "approaches.offer": return beat.label;
```

Append the two queue helpers and a private summarizer at the end of the file:

```ts
export function enqueueDirective(s: SessionState, directive: Directive, now: number): SessionState {
  return {
    ...s,
    directives: [...s.directives, directive],
    log: [...s.log, { t: now, kind: "directive.queued", detail: summarizeDirective(directive) }],
  };
}

export function drainDirectives(s: SessionState, now: number): { state: SessionState; drained: Directive[] } {
  if (s.directives.length === 0) return { state: s, drained: [] };
  const log = [...s.log, ...s.directives.map((d) => ({ t: now, kind: "directive.consumed", detail: summarizeDirective(d) }))];
  return { state: { ...s, directives: [], log }, drained: s.directives };
}

function summarizeDirective(d: Directive): string {
  return d.kind === "note" ? `note: ${d.text}` : `approach: ${d.label}`;
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `npx vitest run tests/state.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add rpi-cockpit/src/state.ts rpi-cockpit/tests/state.test.ts
git commit -m "feat(cockpit): steerMenu + directive queue in session state"
```

---

### Task 3: Bridge — enqueue, drain, and offer methods

**Files:**
- Modify: `rpi-cockpit/src/bridge.ts`
- Test: `rpi-cockpit/tests/bridge.test.ts`

**Interfaces:**
- Consumes: `enqueueDirective`/`drainDirectives` from `state.ts`; `InboundDirective`, `Directive`, `OptionItem` from `events.ts`.
- Produces (on `Bridge`):
  - `enqueueDirective(directive: InboundDirective): void` — stamps a server id (`s${seq}`), updates state, emits `state`.
  - `drainDirectives(): Directive[]` — drains queued directives, emits `state` only when non-empty.
  - `offerApproaches(label: string, options: OptionItem[]): void` — emits an `approaches.offer` beat.

- [ ] **Step 1: Write the failing tests**

Add to `rpi-cockpit/tests/bridge.test.ts`:

```ts
it("stamps an id, queues a directive, and emits state", () => {
  const b = new Bridge();
  const seen = vi.fn();
  b.on("state", seen);
  b.enqueueDirective({ kind: "note", text: "focus on errors" });
  expect(b.state.directives).toHaveLength(1);
  expect(b.state.directives[0].id).toMatch(/^s\d+$/);
  expect(seen).toHaveBeenCalledOnce();
});

it("drains queued directives and clears them", () => {
  const b = new Bridge();
  b.enqueueDirective({ kind: "approach", value: "faster", label: "Move faster" });
  const drained = b.drainDirectives();
  expect(drained).toHaveLength(1);
  expect(b.state.directives).toHaveLength(0);
  expect(b.drainDirectives()).toHaveLength(0); // idempotent when empty
});

it("offerApproaches sets the steer menu", () => {
  const b = new Bridge();
  b.offerApproaches("Pick", [{ id: "a", title: "A" }]);
  expect(b.state.steerMenu).toMatchObject({ label: "Pick" });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npx vitest run tests/bridge.test.ts`
Expected: FAIL — the three methods don't exist.

- [ ] **Step 3: Implement the bridge methods**

In `rpi-cockpit/src/bridge.ts`, update imports:

```ts
import { initialState, applyBeat, enqueueDirective as reduceEnqueue, drainDirectives as reduceDrain, type SessionState } from "./state.js";
import type { Beat, OptionItem, InboundDirective, Directive } from "./events.js";
```

Add these methods to the `Bridge` class (after `emitBeat`):

```ts
  enqueueDirective(directive: InboundDirective): void {
    const stamped = { ...directive, id: `s${++this.seq}` } as Directive;
    this.state = reduceEnqueue(this.state, stamped, Date.now());
    this.emit("state", this.state);
  }

  drainDirectives(): Directive[] {
    const { state, drained } = reduceDrain(this.state, Date.now());
    if (drained.length > 0) {
      this.state = state;
      this.emit("state", this.state);
    }
    return drained;
  }

  offerApproaches(label: string, options: OptionItem[]): void {
    this.emitBeat({ type: "approaches.offer", label, options });
  }
```

(The existing `present_options` flow already increments `this.seq` with a `d` prefix; directives use an `s` prefix so ids never collide.)

- [ ] **Step 4: Run the tests to verify they pass**

Run: `npx vitest run tests/bridge.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add rpi-cockpit/src/bridge.ts rpi-cockpit/tests/bridge.test.ts
git commit -m "feat(cockpit): bridge enqueue/drain/offerApproaches"
```

---

### Task 4: MCP tools — `offer_approaches` and `check_directives`

**Files:**
- Modify: `rpi-cockpit/src/handlers.ts`, `rpi-cockpit/src/mcp.ts`
- Test: `rpi-cockpit/tests/handlers.test.ts`, `rpi-cockpit/tests/mcp.test.ts`

**Interfaces:**
- Consumes: `Bridge.offerApproaches`, `Bridge.drainDirectives`; `OptionItem` from `events.ts`.
- Produces:
  - `handlers.offer_approaches(b, { label, options }) => string`
  - `handlers.check_directives(b) => string` — returns `"no pending directives"` or newline-joined `note:`/`approach:` lines.
  - Two registered MCP tools, bringing the total to nine.

- [ ] **Step 1: Write the failing tests**

Add to `rpi-cockpit/tests/handlers.test.ts`:

```ts
it("offer_approaches populates the steer menu", () => {
  const b = new Bridge();
  const out = handlers.offer_approaches(b, { label: "Pick", options: [{ id: "a", title: "A" }] });
  expect(b.state.steerMenu).toMatchObject({ label: "Pick" });
  expect(out).toContain("1");
});

it("check_directives returns queued directives then drains", () => {
  const b = new Bridge();
  expect(handlers.check_directives(b)).toBe("no pending directives");
  b.enqueueDirective({ kind: "note", text: "focus on errors" });
  expect(handlers.check_directives(b)).toBe("note: focus on errors");
  expect(handlers.check_directives(b)).toBe("no pending directives");
});
```

Add to `rpi-cockpit/tests/mcp.test.ts`:

```ts
it("registers the steering tools and lists nine total", async () => {
  const bridge = new Bridge();
  const server = buildMcpServer(bridge);
  const [clientT, serverT] = InMemoryTransport.createLinkedPair();
  await server.connect(serverT);
  const client = new Client({ name: "test", version: "0" });
  await client.connect(clientT);

  const { tools } = await client.listTools();
  const names = tools.map((t) => t.name).sort();
  expect(names).toContain("offer_approaches");
  expect(names).toContain("check_directives");
  expect(tools).toHaveLength(9);

  await client.callTool({ name: "offer_approaches", arguments: { label: "Pick", options: [{ id: "a", title: "A" }] } });
  expect(bridge.state.steerMenu).toMatchObject({ label: "Pick" });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npx vitest run tests/handlers.test.ts tests/mcp.test.ts`
Expected: FAIL — handlers/tools not defined; tool count is 7.

- [ ] **Step 3: Implement the handlers**

In `rpi-cockpit/src/handlers.ts`, add `OptionItem` to the type import and append two handlers inside the `handlers` object (after `present_options`):

```ts
  offer_approaches: (b: Bridge, a: { label: string; options: OptionItem[] }) => {
    b.offerApproaches(a.label, a.options);
    return `offered ${a.options.length} approaches`;
  },
  check_directives: (b: Bridge) => {
    const drained = b.drainDirectives();
    if (drained.length === 0) return "no pending directives";
    return drained.map((d) => (d.kind === "note" ? `note: ${d.text}` : `approach: ${d.label}`)).join("\n");
  },
```

Ensure the import line reads:

```ts
import type { OptionItem, Phase, ValidationStatus } from "./events.js";
```

- [ ] **Step 4: Register the tools**

In `rpi-cockpit/src/mcp.ts`, add after the `present_options` registration (before `return server;`):

```ts
  server.registerTool(
    "offer_approaches",
    { description: "Offer the user a structured choice for the next phase (populates the cockpit's Steer select).", inputSchema: { label: z.string(), options: z.array(OptionItem).min(1) } },
    async (a) => text(handlers.offer_approaches(bridge, a)),
  );

  server.registerTool(
    "check_directives",
    { description: "Pull any user directives queued from the cockpit. Returns them as text; you MUST read and act on the result. Call at each phase_enter.", inputSchema: {} },
    async () => text(handlers.check_directives(bridge)),
  );
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `npx vitest run tests/handlers.test.ts tests/mcp.test.ts`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add rpi-cockpit/src/handlers.ts rpi-cockpit/src/mcp.ts rpi-cockpit/tests/handlers.test.ts rpi-cockpit/tests/mcp.test.ts
git commit -m "feat(cockpit): offer_approaches + check_directives MCP tools"
```

---

### Task 5: View model — header, lead, steer menu, directives

**Files:**
- Modify: `rpi-cockpit/src/render.ts`
- Test: `rpi-cockpit/tests/render.test.ts`

**Interfaces:**
- Consumes: `SessionState`, `SteerMenu` from `state.ts`; `Phase`, `OptionItem`, `Directive` from `events.ts`.
- Produces: an extended `ViewModel`:
  - `started: boolean`, `host: string`, `phase: Phase | null`, `phaseLabel: string | null`, `phaseNumber: number | null`, `lead: string`
  - `steerMenu: { label: string; source: "agent" | "preset"; options: { id: string; title: string; detail?: string }[] }`
  - `directives: Directive[]`
  - (existing) `task`, `steps`, `subagents`, `validations`, `decision`, `log`

- [ ] **Step 1: Write the failing tests**

Add to `rpi-cockpit/tests/render.test.ts`:

```ts
it("is not started and shows the waiting lead before a session begins", () => {
  const vm = toViewModel(initialState());
  expect(vm.started).toBe(false);
  expect(vm.phaseNumber).toBeNull();
  expect(vm.lead).toMatch(/Waiting for an RPI session/);
});

it("derives phase label, number, and lead from the active phase", () => {
  const s = applyBeat(initialState(), { type: "phase.enter", phase: "implement" }, 1);
  const vm = toViewModel(s);
  expect(vm.started).toBe(true);
  expect(vm.phaseLabel).toBe("Implement");
  expect(vm.phaseNumber).toBe(3);
  expect(vm.lead).toMatch(/Executing the plan/);
});

it("falls back to preset steer options when the agent has not offered a menu", () => {
  const vm = toViewModel(initialState());
  expect(vm.steerMenu.source).toBe("preset");
  expect(vm.steerMenu.options.map((o) => o.id)).toEqual(["default", "thorough", "faster", "ask-first"]);
});

it("uses the agent-declared menu when offered", () => {
  const s = applyBeat(initialState(), { type: "approaches.offer", label: "Implementor", options: [{ id: "x", title: "X" }] }, 1);
  const vm = toViewModel(s);
  expect(vm.steerMenu.source).toBe("agent");
  expect(vm.steerMenu.options).toEqual([{ id: "x", title: "X", detail: undefined }]);
});

it("exposes queued directives", () => {
  const s = enqueueDirective(initialState(), { id: "s1", kind: "note", text: "focus" }, 1);
  expect(toViewModel(s).directives).toHaveLength(1);
});
```

Update the import at the top of the test file to include `enqueueDirective`:

```ts
import { initialState, applyBeat, enqueueDirective } from "../src/state.js";
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npx vitest run tests/render.test.ts`
Expected: FAIL — new fields don't exist on the view model.

- [ ] **Step 3: Implement the extended view model**

Replace the contents of `rpi-cockpit/src/render.ts` with:

```ts
// rpi-cockpit/src/render.ts
import type { SessionState } from "./state.js";
import type { Phase, OptionItem, Directive } from "./events.js";

const ORDER: Phase[] = ["research", "plan", "implement", "review", "discover"];
const LABEL: Record<Phase, string> = { research: "Research", plan: "Plan", implement: "Implement", review: "Review", discover: "Discover" };
const LEAD: Record<Phase, string> = {
  research: "Gathering context and constraints before committing to a plan.",
  plan: "Turning research into an ordered, reviewable plan.",
  implement: "Executing the plan. Subagents and validation run here; the loop won't advance until checks pass.",
  review: "Verifying the work against the plan and the validation gate.",
  discover: "Surfacing follow-up work uncovered during the cycle.",
};
const EMPTY_LEAD = "Waiting for an RPI session… the cockpit is connected and lights up when the agent calls session_begin.";
const PRESETS: { id: string; title: string }[] = [
  { id: "default", title: "Default" },
  { id: "thorough", title: "Be more thorough" },
  { id: "faster", title: "Move faster" },
  { id: "ask-first", title: "Ask before big changes" },
];

export interface StepVM { phase: Phase; status: "done" | "active" | "pending"; }
export interface SteerMenuVM { label: string; source: "agent" | "preset"; options: { id: string; title: string; detail?: string }[]; }
export interface ViewModel {
  started: boolean;
  task: string;
  host: string;
  phase: Phase | null;
  phaseLabel: string | null;
  phaseNumber: number | null;
  lead: string;
  steps: StepVM[];
  subagents: { name: string; status: string; role?: string }[];
  validations: { check: string; status: string }[];
  decision: SessionState["pendingDecision"];
  steerMenu: SteerMenuVM;
  directives: Directive[];
  log: SessionState["log"];
}

export function toViewModel(s: SessionState): ViewModel {
  const steps: StepVM[] = ORDER.map((phase) => ({
    phase,
    status: s.phase === phase ? "active" : s.phasesDone.includes(phase) ? "done" : "pending",
  }));
  const idx = s.phase ? ORDER.indexOf(s.phase) : -1;
  const steerMenu: SteerMenuVM = s.steerMenu
    ? { label: s.steerMenu.label, source: "agent", options: s.steerMenu.options.map((o: OptionItem) => ({ id: o.id, title: o.title, detail: o.detail })) }
    : { label: "Next-phase approach", source: "preset", options: PRESETS.map((o) => ({ id: o.id, title: o.title })) };
  return {
    started: s.task !== "" || s.phase !== null,
    task: s.task,
    host: s.host,
    phase: s.phase,
    phaseLabel: s.phase ? LABEL[s.phase] : null,
    phaseNumber: s.phase ? idx + 1 : null,
    lead: s.phase ? LEAD[s.phase] : EMPTY_LEAD,
    steps,
    subagents: s.subagents.map((a) => ({ name: a.name, status: a.status, role: a.role })),
    validations: Object.entries(s.validations).map(([check, status]) => ({ check, status })),
    decision: s.pendingDecision,
    steerMenu,
    directives: s.directives,
    log: s.log,
  };
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `npx vitest run tests/render.test.ts`
Expected: PASS (including the pre-existing step/decision/validation tests).

- [ ] **Step 5: Commit**

```bash
git add rpi-cockpit/src/render.ts rpi-cockpit/tests/render.test.ts
git commit -m "feat(cockpit): extend toViewModel with header/lead/steer/directives"
```

---

### Task 6: Server — broadcast the view model and accept `steer` frames

**Files:**
- Modify: `rpi-cockpit/src/server.ts`
- Test: `rpi-cockpit/tests/server.test.ts`

**Interfaces:**
- Consumes: `toViewModel` from `render.ts`; `SteerMsg` from `events.ts`; `Bridge.enqueueDirective`.
- Produces: every WS frame becomes `{ type: "state", state, view }`; inbound `{ type: "steer", directive }` enqueues a directive.

- [ ] **Step 1: Write the failing tests**

Add to `rpi-cockpit/tests/server.test.ts`:

```ts
it("includes a view model in the pushed frame", async () => {
  const bridge = new Bridge();
  const srv = await startServer(bridge, 0);
  stop = srv.close;
  const ws = new WebSocket(`ws://127.0.0.1:${srv.port}`);
  const first = await new Promise<any>((res) => ws.on("message", (d) => res(JSON.parse(String(d)))));
  expect(first.view.started).toBe(false);
  expect(first.view.steerMenu.source).toBe("preset");
  ws.close();
});

it("enqueues a directive from an inbound steer frame", async () => {
  const bridge = new Bridge();
  const srv = await startServer(bridge, 0);
  stop = srv.close;
  const ws = new WebSocket(`ws://127.0.0.1:${srv.port}`);
  await new Promise((r) => ws.on("open", r));
  ws.send(JSON.stringify({ type: "steer", directive: { kind: "note", text: "focus on errors" } }));
  await new Promise((r) => setTimeout(r, 30));
  expect(bridge.state.directives).toHaveLength(1);
  expect(bridge.state.directives[0]).toMatchObject({ kind: "note", text: "focus on errors" });
  ws.close();
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `npx vitest run tests/server.test.ts`
Expected: FAIL — frames have no `view`; steer frames are ignored.

- [ ] **Step 3: Implement the server changes**

In `rpi-cockpit/src/server.ts`:

Add imports near the top:

```ts
import { toViewModel } from "./render.js";
import { SteerMsg } from "./events.js";
```

Change the `send` helper to include the view:

```ts
  const send = (ws: WebSocket, state: SessionState) => ws.send(JSON.stringify({ type: "state", state, view: toViewModel(state) }));
```

In the `ws.on("message", ...)` handler, add a `steer` branch after the existing `decide` branch:

```ts
      if (msg && typeof msg === "object" && (msg as { type?: string }).type === "steer") {
        const parsed = SteerMsg.safeParse(msg);
        if (parsed.success) bridge.enqueueDirective(parsed.data.directive);
        return;
      }
```

- [ ] **Step 4: Run the full suite to verify nothing regressed**

Run: `npx vitest run`
Expected: PASS — all tests, including the existing decision round-trip and `e2e` (which reads `msg.state.phase`, still present).

- [ ] **Step 5: Commit**

```bash
git add rpi-cockpit/src/server.ts rpi-cockpit/tests/server.test.ts
git commit -m "feat(cockpit): broadcast view model and accept steer frames"
```

---

### Task 7: Dashboard markup — bind points, steer panel, honesty cleanup

**Files:**
- Modify: `rpi-cockpit/public/index.html`

**Interfaces:**
- Consumes: nothing at build time; provides the element ids `client.js` (Task 8) writes to: `crumb-task`, `conn-pill`, `conn-label`, `host-pill`, `phase-title`, `phase-state`, `lead`, `steps`, `subagents`, `gate`, `decision`, `steer-label`, `steer-select`, `steer-note`, `steer-send`, `directives`, and the existing `.stream`.

This task has no unit test (static markup); it is verified in Task 10. Keep every existing CSS class name so the styling holds.

- [ ] **Step 1: Add styles for the real select and textarea**

In the `<style>` block, immediately after the `.select{...}` rule, add:

```css
  select.select{appearance:none;-webkit-appearance:none;cursor:pointer}
  textarea#steer-note{margin-top:7px;width:100%;min-height:48px;resize:vertical;border:1px solid var(--stroke-2);border-radius:var(--radius-sm);background:var(--layer);padding:8px 10px;font-family:inherit;font-size:12.5px;color:var(--text)}
  #directives{margin-top:10px}
  #directives .evt{border-bottom:1px dashed var(--stroke)}
  .pill[data-status="offline"]{background:var(--fail-bg);color:var(--fail)}
  .pill[data-status="connecting"]{background:var(--layer);color:var(--text-2)}
```

- [ ] **Step 2: Replace the topbar's static content with bind points and drop the dead Pause button**

Replace the existing `.topbar` block (the whole `<div class="topbar">…</div>`) with:

```html
  <div class="topbar">
    <div class="mark"><span class="glyph"><svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round"><path d="M4 12a8 8 0 1 0 2.3-5.6"/><path d="M4 4v3.5H7.5"/></svg></span>RPI Cockpit</div>
    <div class="crumb"><span id="crumb-task">—</span> · <b>RPI session</b></div>
    <div class="spacer"></div>
    <span class="pill" id="conn-pill" data-status="connecting"><span class="dot"></span><span id="conn-label">connecting…</span></span>
    <span class="host" id="host-pill" hidden>via MCP</span>
    <button class="iconbtn" id="theme-toggle" title="Toggle theme" aria-label="Toggle theme"></button>
  </div>
```

- [ ] **Step 3: Remove the fabricated chips and bind the center header + lead**

In the left rail, delete this line entirely:

```html
      <div class="chipline"><span class="chip">Difficulty: challenging</span><span class="chip muted">cycle 1</span></div>
```

In the `.center` section, replace the static header row and lead:

```html
      <div class="h-row"><h1 id="phase-title">RPI session</h1><span class="state" id="phase-state"></span></div>
      <div class="lead" id="lead"></div>
```

- [ ] **Step 4: Replace the decorative Steer block with a working panel**

In `.rail-right`, replace the existing `<div class="steer">…</div>` block with:

```html
      <div class="steer">
        <label id="steer-label">Next-phase approach</label>
        <select class="select" id="steer-select"></select>
        <label style="display:block;margin-top:11px">Note to the agent</label>
        <textarea id="steer-note" placeholder="e.g. focus on error paths"></textarea>
        <button class="btn primary" id="steer-send" style="margin-top:8px;width:100%">Queue directive</button>
        <div id="directives"></div>
      </div>
```

- [ ] **Step 5: Verify the page still loads as static markup**

Run: `node -e "const fs=require('fs');const h=fs.readFileSync('public/index.html','utf8');for(const id of ['crumb-task','conn-pill','phase-title','lead','steer-select','steer-note','steer-send','directives']){if(!h.includes('id=\"'+id+'\"'))throw new Error('missing '+id)}console.log('all bind points present')"`
Expected: `all bind points present`

- [ ] **Step 6: Commit**

```bash
git add rpi-cockpit/public/index.html
git commit -m "feat(cockpit): dashboard bind points + working steer panel, remove fabricated chrome"
```

---

### Task 8: Client — thin painter, connection status, reconnect, steering

**Files:**
- Modify (full rewrite): `rpi-cockpit/public/client.js`

**Interfaces:**
- Consumes: WS frames `{ type: "state", state, view }` from Task 6; the element ids from Task 7.
- Produces: live DOM updates; outbound `{ type: "decide", id, choiceId }` and `{ type: "steer", directive }` frames.

No unit test (browser DOM + WebSocket); verified in Task 10. All display logic already lives in the Node-tested `toViewModel`, so this file stays deliberately logic-free.

- [ ] **Step 1: Replace `rpi-cockpit/public/client.js` in full**

```js
// rpi-cockpit/public/client.js
// Thin painter: every value comes from the server's view model (src/render.ts).
const LABEL = { research: "Research", plan: "Plan", implement: "Implement", review: "Review", discover: "Discover" };

let ws = null;
let backoff = 500;

function connect() {
  setConn("connecting");
  ws = new WebSocket(`ws://${location.host}`);
  ws.onopen = () => { backoff = 500; };
  ws.onmessage = (e) => {
    let msg;
    try { msg = JSON.parse(e.data); } catch { return; }
    if (msg.type === "state" && msg.view) { setConn("live"); render(msg.view); }
  };
  ws.onclose = () => { setConn("offline"); setTimeout(connect, backoff); backoff = Math.min(backoff * 2, 8000); };
  ws.onerror = () => { try { ws.close(); } catch (_) {} };
}

function setConn(status) {
  const pill = document.getElementById("conn-pill");
  if (pill) pill.dataset.status = status;
  setText("conn-label", status === "live" ? "live" : status === "offline" ? "offline" : "connecting…");
}

function render(v) {
  setText("crumb-task", v.task || "—");
  setText("phase-title", v.phaseNumber ? `Phase ${v.phaseNumber} · ${v.phaseLabel}` : "RPI session");
  setText("phase-state", v.phase ? "● running" : "");
  setText("lead", v.lead);
  const host = document.getElementById("host-pill");
  if (host) { host.textContent = `via MCP · ${v.host}`; host.hidden = !v.host; }

  setHtml("steps", v.steps.map((st, i) =>
    `<div class="step ${st.status}"><div class="ring">${st.status === "done" ? "✓" : i + 1}</div>
      <div><div class="lbl">${i + 1} · ${LABEL[st.phase]}</div></div></div>`).join(""));

  setHtml("subagents", v.subagents.length
    ? v.subagents.map((a) =>
        `<div class="sub-card"><div class="av">${initials(a.name)}</div>
          <div style="flex:1"><div class="nm">${esc(a.name)}</div><div class="meta">${esc(a.role ?? "")}</div></div>
          <span class="tagidle">${esc(a.status)}</span></div>`).join("")
    : `<div class="sub-card"><div class="meta">No subagents yet.</div></div>`);

  setHtml("gate", v.validations.map(({ check, status }) => {
    const cls = status === "ok" ? "ok" : status === "running" ? "run" : status === "fail" ? "fail" : "wait";
    const mark = status === "ok" ? "✓" : status === "running" ? "●" : status === "fail" ? "✕" : "○";
    return `<span class="check ${cls}">${mark} ${esc(check)}</span>`;
  }).join("") || `<span class="check wait">○ no checks yet</span>`);

  const sel = document.getElementById("steer-select");
  if (sel) {
    setText("steer-label", v.steerMenu.label);
    const cur = sel.value;
    sel.innerHTML = v.steerMenu.options.map((o) => `<option value="${esc(o.id)}">${esc(o.title)}</option>`).join("");
    if (cur) sel.value = cur;
  }

  setHtml("directives", v.directives.map((d) =>
    `<div class="evt"><span><span class="k s2">queued</span> <span class="txt">${esc(d.kind === "note" ? d.text : d.label)} · applies at next checkpoint</span></span></div>`).join(""));

  setHtml("decision", v.decision ? decisionHtml(v.decision) : "");

  const stream = document.querySelector(".stream");
  if (stream) stream.innerHTML = v.log.slice(-12).map((l) =>
    `<div class="evt"><span class="ts">${new Date(l.t).toLocaleTimeString().slice(0, 5)}</span>
      <span><span class="k ${kindCls(l.kind)}">${esc(l.kind)}</span> <span class="txt">${esc(l.detail)}</span></span></div>`).join("");
}

function decisionHtml(d) {
  const opts = d.options.map((o) =>
    `<div class="opt ${o.recommended ? "rec" : ""}">${o.recommended ? '<span class="badge">RECOMMENDED</span>' : ""}
      <h4>${esc(o.title)}</h4><p>${esc(o.detail ?? "")}</p></div>`).join("");
  const btns = d.options.map((o) =>
    `<button class="btn ${o.recommended ? "primary" : ""}" data-id="${esc(d.id)}" data-choice="${esc(o.id)}">Choose ${esc(o.title)}</button>`).join("");
  return `<div class="decide"><div class="decide-head"><span class="t">${esc(d.prompt)}</span>
    <span class="s">present_options · awaiting your pick</span></div>
    <div class="decide-body"><div class="opts">${opts}</div><div class="btns">${btns}</div></div></div>`;
}

// Event delegation: decision buttons + the steer "Queue directive" button.
document.addEventListener("click", (e) => {
  const choice = e.target.closest("#decision [data-choice]");
  if (choice) { sendMsg({ type: "decide", id: choice.dataset.id, choiceId: choice.dataset.choice }); return; }
  if (e.target.closest("#steer-send")) {
    const note = document.getElementById("steer-note");
    const text = (note && note.value || "").trim();
    if (text) { sendMsg({ type: "steer", directive: { kind: "note", text } }); note.value = ""; return; }
    const sel = document.getElementById("steer-select");
    if (sel && sel.value) {
      const opt = sel.options[sel.selectedIndex];
      sendMsg({ type: "steer", directive: { kind: "approach", value: sel.value, label: opt ? opt.textContent : sel.value } });
    }
  }
});

function sendMsg(m) { if (ws && ws.readyState === 1) ws.send(JSON.stringify(m)); }
const setText = (id, t) => { const el = document.getElementById(id); if (el) el.textContent = t; };
const setHtml = (id, h) => { const el = document.getElementById(id); if (el) el.innerHTML = h; };
const initials = (n) => n.split(/\s+/).map((w) => w[0]).join("").slice(0, 2).toUpperCase();
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
const kindCls = (k) => k.indexOf("directive") === 0 ? "s2" : k === "validate" ? "ok" : "";

connect();
```

- [ ] **Step 2: Syntax-check the client**

Run: `node --check public/client.js`
Expected: no output (exit 0).

- [ ] **Step 3: Commit**

```bash
git add rpi-cockpit/public/client.js
git commit -m "feat(cockpit): state-driven client with reconnect + steering"
```

---

### Task 9: Narration contract — document the two new tools

**Files:**
- Modify: `rpi-cockpit/agents/cockpit-instructions.md`

**Interfaces:** `runInit` (`src/init.ts`) inlines this file verbatim into `CLAUDE.md`, `AGENTS.md`, and `.github/copilot-instructions.md`, so editing it is the single source of truth for the contract.

- [ ] **Step 1: Add the two beats to the contract**

In `rpi-cockpit/agents/cockpit-instructions.md`, add two bullets after the `present_options` bullet (before the closing summary line):

```md
- When you want the user to steer the next phase, call `offer_approaches(label, options[])` to populate the
  cockpit's Steer select with the real choices for the upcoming phase. Informational; does not block.
- At each `phase_enter` (and before a major decision), call `check_directives()`. It returns immediately with any
  directives the user queued in the cockpit (notes or an approach pick). You MUST read and incorporate them.
```

Then replace the final summary line with:

```md
These beats are informational except present_options, which blocks until the user decides and returns the chosen id.
check_directives does not block — it returns queued user directives (or "no pending directives") for you to act on.
```

- [ ] **Step 2: Verify init still inlines cleanly (idempotent dry check)**

Run: `npx vitest run tests/init.test.ts`
Expected: PASS — the narration block is read and written without duplication.

- [ ] **Step 3: Commit**

```bash
git add rpi-cockpit/agents/cockpit-instructions.md
git commit -m "docs(cockpit): document offer_approaches + check_directives in the narration contract"
```

---

### Task 10: Build, full suite, and manual verification

**Files:**
- Modify (optional, throwaway): `rpi-cockpit/demo.mjs` — add a steer beat so the live demo exercises the select.

- [ ] **Step 1: Type-check and run the whole suite**

Run: `npx tsc --noEmit && npx vitest run`
Expected: tsc clean; all tests pass.

- [ ] **Step 2: Build**

Run: `npm run build`
Expected: `dist/` regenerated, no errors.

- [ ] **Step 3: Add an `offer_approaches` beat to the demo (optional but recommended)**

In `rpi-cockpit/demo.mjs`, immediately before the `b.emitBeat({ type: "phase.enter", phase: "implement" });` line, add:

```js
  b.offerApproaches("Implementor for the implement phase", [
    { id: "default", title: "Phase Implementor (default)" },
    { id: "tdd", title: "TDD-first implementor" },
    { id: "surgical", title: "Surgical minimal-diff" },
  ]);
```

- [ ] **Step 4: Run the live demo and verify in the browser**

Run: `node demo.mjs`
Open: <http://127.0.0.1:4399>

Verify each:
- Before beats fire (first ~3s): breadcrumb shows `—`, header shows "RPI session", lead shows the "Waiting for an RPI session…" copy, connection pill shows **live** (green). No "Difficulty/cycle" chips, no Pause button.
- After `session.begin`: breadcrumb shows "Refactor auth module"; host pill shows "via MCP · demo".
- As phases advance: left-rail steps light active/done; center header shows "Phase N · <Label>" with "● running"; lead text changes per phase.
- During implement: the Steer select shows the three agent-declared implementor options.
- Type a note ("focus on error paths") and click **Queue directive** → it appears under the select as "queued · applies at next checkpoint" and in the activity stream as `directive.queued`.
- The two `present_options` decisions still render as cards and unblock the demo when clicked.

- [ ] **Step 5: Verify reconnect**

With the browser open, stop the demo (Ctrl-C) → connection pill flips to **offline**. Re-run `node demo.mjs` → pill returns to **live** and the UI re-syncs without a manual refresh.

- [ ] **Step 6: Commit any demo change**

```bash
git add rpi-cockpit/demo.mjs
git commit -m "chore(cockpit): exercise offer_approaches in the live demo"
```

---

## Self-Review

**Spec coverage:**
- "Dashboard never lies / every element state-driven" → Tasks 5 (view model), 7 (bind points), 8 (painter).
- "Honest empty + connection states, auto-reconnect" → Task 5 (`started`, empty lead), Task 8 (`setConn`, reconnect backoff).
- "Browser→agent steering: notes + approach select" → Tasks 1–4 (schemas, state, bridge, tools), 6 (inbound steer), 7–8 (UI).
- "Approach menu: agent-declared with preset fallback" → Task 5 (`steerMenu` resolution), verified in render tests.
- "Honesty cleanup (chips, tracking path, Pause button)" → Task 7.
- "Contract update + propagation via init" → Task 9.
- "Tests across state/bridge/handlers/mcp/server/render" → Tasks 1–6 each ship tests; Task 10 runs the full suite + manual UI/reconnect checks.

**Placeholder scan:** No TBD/TODO; every code step shows complete code; every test step shows real assertions.

**Type consistency:** `Directive`/`InboundDirective`/`SteerMsg` (Task 1) are consumed unchanged in Tasks 2–6. `SteerMenu` (state, Task 2) vs `SteerMenuVM` (view, Task 5) are distinct by design — the reducer stores `OptionItem[]`; the view flattens to `{id,title,detail?}` with a `source` tag. `toViewModel` field names (Task 5) match exactly what `client.js` reads (Task 8): `started`, `task`, `host`, `phase`, `phaseLabel`, `phaseNumber`, `lead`, `steps`, `subagents`, `validations`, `decision`, `steerMenu`, `directives`, `log`. Bridge method names `enqueueDirective`/`drainDirectives`/`offerApproaches` (Task 3) match handler call sites (Task 4). Log kinds `directive.queued`/`directive.consumed` (Task 2) match the client's `kindCls` prefix check (Task 8).
