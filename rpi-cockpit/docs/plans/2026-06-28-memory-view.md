<!-- markdownlint-disable -->
# Memory View Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a new `memory` loop view for the Memory agent: category-grouped memory entries (tagged recalled/added/updated) as the centerpiece, with a secondary handoff strip, driven by three new MCP tools.

**Architecture:** A new `memory` domain peer to dataprofile/gallery/promptlab. Three new beats (`memory.open`, `memory.add`, `handoff.add`) and three state fields (`memoryTitle`, `memoryEntries`, `memoryHandoffs`) feed a `memory` view-model projection with derived tag counts; three new MCP tools emit the beats; a new `#memory-view` renders a header count strip + category-grouped expandable entries + a handoff strip, with domain routing exactly like the existing views.

**Tech Stack:** TypeScript (ESM, strict), zod, Node `ws`, unbundled browser client (`public/client.js` + `public/index.html`), Vitest + happy-dom. Design spec: `docs/memory-view-design.md`.

## Global Constraints

* `MemoryEntry = { id: string; title?: string; content: string; category: string; tag: MemoryTag }`; `MemoryTag = "recalled" | "added" | "updated"`.
* `MemoryHandoff = { id: string; from: string; summary: string; action: HandoffAction }`; `HandoffAction = "stored" | "merged" | "recalled"`.
* State fields: `memoryTitle: string | null`, `memoryEntries: MemoryEntry[]`, `memoryHandoffs: MemoryHandoff[]`.
* The MCP tool count goes from 38 to 41 (three new tools; none removed). Update the assertion in `tests/mcp.test.ts`.
* `memory.add` / `handoff.add` upsert by `id` IN PLACE (preserve order on update; append a new id). `memory.add` defaults `tag` to `"recalled"`; `handoff.add` defaults `action` to `"stored"`.
* `memory.open` sets the title and CLEARS both arrays; `title` defaults to null.
* The view-model `counts` is derived by counting entry tags: `{ recalled, added, updated, total }`.
* `tag` is a zod enum `["recalled","added","updated"]`; `action` is a zod enum `["stored","merged","recalled"]`; out-of-enum values are rejected at the tool boundary.
* TypeScript strict; no new `any`; ESM `.js` import specifiers; keep the `summarize(beat)` switch exhaustive.
* Every interpolation in `public/client.js` goes through the existing `esc()` helper. Long content is shown via expand; the prompt-style expand uses the proven id-keyed Set pattern (see Task 3) NOT `classList.toggle` (which is unreliable under the happy-dom test harness).
* Keep the global `[hidden]{display:none!important}` rule and all iframe `sandbox` attributes untouched.
* Run `npx tsc --noEmit && npx vitest run` until green before each commit; `node --check public/client.js` must pass.
* House markdown for docs: asterisk bullets, no em-dashes, lint clean from the REPO ROOT.

---

### Task 1: Beats, state, and view-model

**Files:**
* Modify: `src/events.ts` (add the three beats to the `Beat` union)
* Modify: `src/state.ts` (domain union; the four types; the three fields; `initialState`; the three reducer arms; the three `summarize` arms)
* Modify: `src/render.ts` (domain union; `ViewModel.memory`; the `toViewModel` projection with derived counts)
* Test: `tests/state.test.ts`, `tests/render.test.ts`

**Interfaces:**
* Produces:
  * Beats `{ type: "memory.open"; title?: string }`, `{ type: "memory.add"; id: string; content: string; category: string; tag?: MemoryTag; title?: string }`, `{ type: "handoff.add"; id: string; from: string; summary: string; action?: HandoffAction }`.
  * `SessionState.memoryTitle`/`memoryEntries`/`memoryHandoffs`, `MemoryEntry`, `MemoryTag`, `MemoryHandoff`, `HandoffAction`.
  * `ViewModel.memory: { title: string | null; counts: { recalled: number; added: number; updated: number; total: number }; entries: { id: string; title: string | null; content: string; category: string; tag: string }[]; handoffs: { id: string; from: string; summary: string; action: string }[] }`.

* [ ] **Step 1: Write the failing tests**

Add to `tests/state.test.ts`:

```ts
describe("memory", () => {
  it("memory.open sets title and clears both arrays", () => {
    let s = applyBeat(initialState(), { type: "memory.add", id: "x", content: "old", category: "project" }, 1);
    s = applyBeat(s, { type: "handoff.add", id: "h", from: "RPI", summary: "old" }, 2);
    s = applyBeat(s, { type: "memory.open", title: "hve-core" }, 3);
    expect(s.domain).toBe("memory");
    expect(s.view).toBe("loop");
    expect(s.memoryTitle).toBe("hve-core");
    expect(s.memoryEntries).toEqual([]);
    expect(s.memoryHandoffs).toEqual([]);
  });
  it("memory.open defaults title to null", () => {
    const s = applyBeat(initialState(), { type: "memory.open" }, 1);
    expect(s.memoryTitle).toBeNull();
  });
  it("memory.add appends, defaults tag to recalled, and a same-id add updates in place", () => {
    let s = applyBeat(initialState(), { type: "memory.open", title: "t" }, 1);
    s = applyBeat(s, { type: "memory.add", id: "e1", content: "likes terse output", category: "user" }, 2);
    s = applyBeat(s, { type: "memory.add", id: "e2", content: "ship to fork", category: "project", tag: "added" }, 3);
    s = applyBeat(s, { type: "memory.add", id: "e1", content: "likes terse output", category: "user", tag: "updated", title: "output style" }, 4);
    expect(s.memoryEntries.map((e) => e.id)).toEqual(["e1", "e2"]);
    expect(s.memoryEntries[0]).toEqual({ id: "e1", title: "output style", content: "likes terse output", category: "user", tag: "updated" });
    expect(s.memoryEntries[1].tag).toBe("added");
  });
  it("handoff.add appends, upserts by id, and defaults action to stored", () => {
    let s = applyBeat(initialState(), { type: "memory.open" }, 1);
    s = applyBeat(s, { type: "handoff.add", id: "h1", from: "GitHub Backlog Manager", summary: "sprint state" }, 2);
    s = applyBeat(s, { type: "handoff.add", id: "h1", from: "GitHub Backlog Manager", summary: "sprint state", action: "merged" }, 3);
    expect(s.memoryHandoffs).toEqual([{ id: "h1", from: "GitHub Backlog Manager", summary: "sprint state", action: "merged" }]);
  });
});
```

Add to `tests/render.test.ts`:

```ts
it("projects the memory view with derived tag counts", () => {
  let s = applyBeat(initialState(), { type: "memory.open", title: "hve-core" }, 1);
  s = applyBeat(s, { type: "memory.add", id: "a", content: "c1", category: "user", tag: "recalled" }, 2);
  s = applyBeat(s, { type: "memory.add", id: "b", content: "c2", category: "project", tag: "added" }, 3);
  s = applyBeat(s, { type: "memory.add", id: "c", content: "c3", category: "project" }, 4);
  s = applyBeat(s, { type: "handoff.add", id: "h", from: "RPI", summary: "did x", action: "stored" }, 5);
  const vm = toViewModel(s);
  expect(vm.domain).toBe("memory");
  expect(vm.memory.title).toBe("hve-core");
  expect(vm.memory.counts).toEqual({ recalled: 2, added: 1, updated: 0, total: 3 });
  expect(vm.memory.entries[1]).toEqual({ id: "b", title: null, content: "c2", category: "project", tag: "added" });
  expect(vm.memory.handoffs[0]).toEqual({ id: "h", from: "RPI", summary: "did x", action: "stored" });
  expect(toViewModel(initialState()).memory.title).toBeNull();
});
```

* [ ] **Step 2: Run to verify they fail**

Run: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/state.test.ts tests/render.test.ts`
Expected: FAIL (beats/fields/projection not defined).

* [ ] **Step 3: Implement `src/events.ts`**

Add to the `Beat` union (after the `case.add` member from the promptlab feature):

```ts
  z.object({ type: z.literal("memory.open"), title: z.string().optional() }),
  z.object({ type: z.literal("memory.add"), id: z.string(), content: z.string(), category: z.string(), tag: z.enum(["recalled", "added", "updated"]).optional(), title: z.string().optional() }),
  z.object({ type: z.literal("handoff.add"), id: z.string(), from: z.string(), summary: z.string(), action: z.enum(["stored", "merged", "recalled"]).optional() }),
```

* [ ] **Step 4: Implement `src/state.ts`**

Add the types near the other interfaces (e.g. after `PromptCase`):

```ts
export type MemoryTag = "recalled" | "added" | "updated";
export interface MemoryEntry { id: string; title?: string; content: string; category: string; tag: MemoryTag; }
export type HandoffAction = "stored" | "merged" | "recalled";
export interface MemoryHandoff { id: string; from: string; summary: string; action: HandoffAction; }
```

In the `domain` union add `"memory"`:

```ts
  domain: "rpi" | "review" | "interview" | "backlog" | "team" | "codemap" | "dataprofile" | "gallery" | "promptlab" | "memory" | null;
```

Add three fields to `SessionState` (near `promptCases`):

```ts
  memoryTitle: string | null;
  memoryEntries: MemoryEntry[];
  memoryHandoffs: MemoryHandoff[];
```

In `initialState()`, add `memoryTitle: null, memoryEntries: [], memoryHandoffs: []` to the returned object.

Add the reducer arms (after the `case.add` arm):

```ts
    case "memory.open":
      return { ...s, view: "loop", domain: "memory", memoryTitle: beat.title ?? null, memoryEntries: [], memoryHandoffs: [], log };
    case "memory.add": {
      const e = { id: beat.id, title: beat.title, content: beat.content, category: beat.category, tag: beat.tag ?? "recalled" };
      const exists = s.memoryEntries.some((x) => x.id === beat.id);
      return { ...s, memoryEntries: exists ? s.memoryEntries.map((x) => (x.id === beat.id ? e : x)) : [...s.memoryEntries, e], log };
    }
    case "handoff.add": {
      const h = { id: beat.id, from: beat.from, summary: beat.summary, action: beat.action ?? "stored" };
      const exists = s.memoryHandoffs.some((x) => x.id === beat.id);
      return { ...s, memoryHandoffs: exists ? s.memoryHandoffs.map((x) => (x.id === beat.id ? h : x)) : [...s.memoryHandoffs, h], log };
    }
```

In the `summarize(beat)` switch, add three arms (keep it exhaustive):

```ts
    case "memory.open": return beat.title ?? "memory";
    case "memory.add": return beat.id;
    case "handoff.add": return beat.from;
```

* [ ] **Step 5: Implement `src/render.ts`**

In the `ViewModel` `domain` union add `"memory"`. Add the `memory` field to the `ViewModel` interface (near `promptlab`):

```ts
  memory: { title: string | null; counts: { recalled: number; added: number; updated: number; total: number }; entries: { id: string; title: string | null; content: string; category: string; tag: string }[]; handoffs: { id: string; from: string; summary: string; action: string }[] };
```

In `toViewModel`, add to the returned object (near `promptlab`):

```ts
    memory: {
      title: s.memoryTitle,
      counts: s.memoryEntries.reduce(
        (a, e) => { a[e.tag]++; a.total++; return a; },
        { recalled: 0, added: 0, updated: 0, total: 0 },
      ),
      entries: s.memoryEntries.map((e) => ({ id: e.id, title: e.title ?? null, content: e.content, category: e.category, tag: e.tag })),
      handoffs: s.memoryHandoffs.map((h) => ({ id: h.id, from: h.from, summary: h.summary, action: h.action })),
    },
```

* [ ] **Step 6: Run the tests, then tsc + whole suite**

Run: `npx vitest run tests/state.test.ts tests/render.test.ts && npx tsc --noEmit && npx vitest run`
Expected: the new tests PASS; tsc clean; whole suite green.

* [ ] **Step 7: Commit**

```bash
git add rpi-cockpit/src/events.ts rpi-cockpit/src/state.ts rpi-cockpit/src/render.ts rpi-cockpit/tests/state.test.ts rpi-cockpit/tests/render.test.ts
git commit -m "feat(cockpit): memory domain state, beats, and view-model"
```

---

### Task 2: MCP tools and handlers

**Files:**
* Modify: `src/handlers.ts` (add `memory_open`, `add_memory`, `add_handoff`)
* Modify: `src/mcp.ts` (register the three tools)
* Test: `tests/mcp.test.ts` (round trip + tool count + rejections)

**Interfaces:**
* Consumes: the `memory.open` / `memory.add` / `handoff.add` beats from Task 1.
* Produces: tools `memory_open({ title? })`, `add_memory({ id, content, category, tag?, title? })`, `add_handoff({ id, from, summary, action? })`.

* [ ] **Step 1: Write the failing test**

Add to `tests/mcp.test.ts` a round-trip test (build the client inline, matching the existing tests' style):

```ts
it("memory tools drive the memory view and reject bad enums", async () => {
  const bridge = new Bridge();
  const server = buildMcpServer(bridge);
  const [clientT, serverT] = InMemoryTransport.createLinkedPair();
  await server.connect(serverT);
  const client = new Client({ name: "test", version: "0" });
  await client.connect(clientT);

  await client.callTool({ name: "memory_open", arguments: { title: "hve-core" } });
  await client.callTool({ name: "add_memory", arguments: { id: "e1", content: "likes terse output", category: "user", tag: "recalled" } });
  await client.callTool({ name: "add_handoff", arguments: { id: "h1", from: "GitHub Backlog Manager", summary: "sprint state", action: "stored" } });
  expect(bridge.state.domain).toBe("memory");
  expect(bridge.state.memoryTitle).toBe("hve-core");
  expect(bridge.state.memoryEntries[0]).toMatchObject({ id: "e1", category: "user", tag: "recalled" });
  expect(bridge.state.memoryHandoffs[0]).toMatchObject({ id: "h1", from: "GitHub Backlog Manager", action: "stored" });

  const badTag = await client.callTool({ name: "add_memory", arguments: { id: "e2", content: "x", category: "user", tag: "bogus" } });
  expect(badTag.isError).toBe(true);
  const badAction = await client.callTool({ name: "add_handoff", arguments: { id: "h2", from: "x", summary: "y", action: "bogus" } });
  expect(badAction.isError).toBe(true);
});
```

In the tool-count test, change `expect(tools).toHaveLength(38)` to `41` and add `expect(names).toContain(...)` for `memory_open`, `add_memory`, `add_handoff`.

* [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run tests/mcp.test.ts`
Expected: FAIL (tools not registered; count is 38).

* [ ] **Step 3: Implement `src/handlers.ts`**

Add the type imports (these types live in `state.ts`):

```ts
import type { MemoryTag, HandoffAction } from "./state.js";
```

Add (next to the promptlab handlers):

```ts
  memory_open: (b: Bridge, a: { title?: string }) => {
    b.emitBeat({ type: "memory.open", title: a.title });
    return `memory view opened${a.title ? `: ${a.title}` : ""}`;
  },
  add_memory: (b: Bridge, a: { id: string; content: string; category: string; tag?: MemoryTag; title?: string }) => {
    b.emitBeat({ type: "memory.add", id: a.id, content: a.content, category: a.category, tag: a.tag, title: a.title });
    return `memory ${a.id}: ${a.tag ?? "recalled"}`;
  },
  add_handoff: (b: Bridge, a: { id: string; from: string; summary: string; action?: HandoffAction }) => {
    b.emitBeat({ type: "handoff.add", id: a.id, from: a.from, summary: a.summary, action: a.action });
    return `handoff ${a.id} from ${a.from}: ${a.action ?? "stored"}`;
  },
```

* [ ] **Step 4: Implement `src/mcp.ts`**

Register the three tools (after the promptlab tools):

```ts
  server.registerTool(
    "memory_open",
    { description: "Open the Memory view and switch the cockpit to it. Optionally name the collection (e.g. a project memory name). Clears the entries and handoffs for a fresh session view.", inputSchema: { title: z.string().optional() } },
    async (a) => text(handlers.memory_open(bridge, a)),
  );

  server.registerTool(
    "add_memory",
    { description: "Add or update one MEMORY ENTRY (a recalled or written fact, not a kanban item / dataset column / prompt case). Give an id, its content, and a category to group by (a memory type like user/feedback/project/reference, or a source); optionally a short title and a tag: recalled (loaded into context), added (written this session), or updated.", inputSchema: { id: z.string(), content: z.string(), category: z.string(), tag: z.enum(["recalled", "added", "updated"]).optional(), title: z.string().optional() } },
    async (a) => text(handlers.add_memory(bridge, a)),
  );

  server.registerTool(
    "add_handoff",
    { description: "Add or update one memory HANDOFF: another agent handing state to Memory. Give an id, `from` (the handing-off agent's name), a summary of what was handed, and an action: stored, merged, or recalled.", inputSchema: { id: z.string(), from: z.string(), summary: z.string(), action: z.enum(["stored", "merged", "recalled"]).optional() } },
    async (a) => text(handlers.add_handoff(bridge, a)),
  );
```

* [ ] **Step 5: Run the test, then tsc + whole suite**

Run: `npx vitest run tests/mcp.test.ts && npx tsc --noEmit && npx vitest run`
Expected: PASS; tsc clean; whole suite green (tool-count assertion now 41).

* [ ] **Step 6: Commit**

```bash
git add rpi-cockpit/src/handlers.ts rpi-cockpit/src/mcp.ts rpi-cockpit/tests/mcp.test.ts
git commit -m "feat(cockpit): memory_open, add_memory, add_handoff MCP tools"
```

---

### Task 3: The memory client view and routing

**Files:**
* Modify: `public/index.html` (the `#memory-view` markup + CSS)
* Modify: `public/client.js` (`renderMemory`; the routing branch; hide `#memory-view` in every other domain branch; the entry expand delegation)
* Test: `tests/memory-client.test.ts` (new)

**Interfaces:**
* Consumes: `ViewModel.memory` from Task 1.
* Produces: a `#memory-view` shown when `v.domain === "memory"`; a `#me-entries` with one `.me-group` per category and one `.me-entry` per entry; a `.me-tag.me-t-{tag}` pill per entry; a `#me-handoffs` with one `.mh-card` per handoff; clicking a `.me-head` toggles `.open` on its `.me-entry`.

* [ ] **Step 1: Write the failing test**

Create `tests/memory-client.test.ts` (mirror `tests/promptlab-client.test.ts`'s `boot()` harness):

```ts
import { describe, it, expect, beforeEach } from "vitest";
import { Window } from "happy-dom";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { initialState, applyBeat } from "../src/state.js";
import { toViewModel } from "../src/render.js";

const PUBLIC = path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "public");
function boot() {
  const html = readFileSync(path.join(PUBLIC, "index.html"), "utf8");
  const js = readFileSync(path.join(PUBLIC, "client.js"), "utf8");
  const win = new Window({ url: "http://127.0.0.1:4399/" });
  win.document.write(html);
  (win as any).WebSocket = class { readyState = 1; send() {} close() {} };
  win.eval(js.replace(/^import .*$/gm, ""));
  return win;
}
function memVm() {
  let s = applyBeat(initialState(), { type: "memory.open", title: "hve-core" }, 1);
  s = applyBeat(s, { type: "memory.add", id: "e1", title: "output style", content: "Prefers terse output, no preamble.", category: "user", tag: "recalled" }, 2);
  s = applyBeat(s, { type: "memory.add", id: "e2", content: "Ship to the fork, never origin.", category: "project", tag: "added" }, 3);
  s = applyBeat(s, { type: "handoff.add", id: "h1", from: "GitHub Backlog Manager", summary: "Sprint 24 state", action: "stored" }, 4);
  return toViewModel(s);
}

describe("memory client", () => {
  let win: ReturnType<typeof boot>;
  beforeEach(() => { win = boot(); });

  it("shows the memory view and hides the others on the memory domain", () => {
    (win as any).render(memVm());
    expect((win.document.getElementById("memory-view") as any).hidden).toBe(false);
    expect((win.document.getElementById("rpi-view") as any).hidden).toBe(true);
    expect((win.document.getElementById("promptlab-view") as any).hidden).toBe(true);
  });

  it("renders entries grouped by category with tag pills, a handoff card, and the counts", () => {
    (win as any).render(memVm());
    expect(win.document.querySelectorAll("#me-entries .me-group").length).toBe(2);
    expect(win.document.querySelectorAll("#me-entries .me-entry").length).toBe(2);
    expect(win.document.querySelector("#me-entries .me-t-recalled")).not.toBeNull();
    expect(win.document.querySelector("#me-entries .me-t-added")).not.toBeNull();
    expect(win.document.querySelectorAll("#me-handoffs .mh-card").length).toBe(1);
    expect((win.document.getElementById("me-title") as any).textContent).toContain("hve-core");
  });

  it("expands an entry on click to reveal the full content", () => {
    (win as any).render(memVm());
    const head = win.document.querySelector("#me-entries .me-entry .me-head") as any;
    head.dispatchEvent(new win.Event("click", { bubbles: true }));
    expect((win.document.querySelector("#me-entries .me-entry") as any).className).toContain("open");
  });
});
```

* [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run tests/memory-client.test.ts`
Expected: FAIL (no `#memory-view`).

* [ ] **Step 3: Markup + CSS in `public/index.html`**

Add the view as a sibling of `#promptlab-view` (after it, inside `#loop`):

```html
    <section id="memory-view" hidden>
      <div class="rev-head">
        <span class="board-target" id="me-title">Memory</span>
        <span class="pl-summary" id="me-counts"></span>
      </div>
      <div class="me-body">
        <div id="me-entries" class="me-entries"></div>
        <aside class="me-handoff-panel"><div class="sec">Handoffs</div><div id="me-handoffs"></div></aside>
      </div>
    </section>
```

Add the CSS (next to the `.pl-*` / `.pc-*` rules):

```css
  #memory-view { flex: 1 1 0; min-height: 0; display: flex; flex-direction: column; overflow: hidden; }
  .me-c-recalled { color: var(--accent-cyan, #9CDCFE); } .me-c-added { color: var(--ok, #73C991); } .me-c-updated { color: #E0954B; }
  .me-body { flex: 1; min-height: 0; display: flex; gap: 16px; overflow: hidden; padding: 12px 18px; }
  .me-entries { flex: 1 1 0; min-width: 0; overflow: auto; display: flex; flex-direction: column; gap: 10px; }
  .me-group { display: flex; flex-direction: column; gap: 6px; }
  .me-group-head { font-size: 11px; text-transform: uppercase; letter-spacing: .06em; color: var(--text-3, #6E6E6E); font-weight: 600; padding-bottom: 3px; border-bottom: 1px solid var(--stroke, #3C3C3C); }
  .me-handoff-panel { flex: 0 0 300px; min-width: 0; overflow: auto; border-left: 1px solid var(--stroke, #3C3C3C); padding-left: 14px; }
  .me-entry { border: 1px solid var(--stroke, #3C3C3C); border-radius: 7px; background: var(--layer, #252526); overflow: hidden; }
  .me-head { display: flex; align-items: center; gap: 12px; padding: 9px 12px; cursor: pointer; }
  .me-name { font-weight: 600; font-size: 12.5px; flex: 0 0 32%; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .me-preview { flex: 1 1 0; min-width: 0; color: var(--text-3, #6E6E6E); font-size: 11.5px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .me-tag { flex: none; font-size: 10.5px; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; padding: 2px 9px; border-radius: 10px; }
  .me-t-recalled { background: var(--brand-2, #094771); color: var(--accent-cyan, #9CDCFE); }
  .me-t-added { background: var(--ok-bg, #16301F); color: var(--ok, #73C991); }
  .me-t-updated { background: #2a1d11; color: #E0954B; }
  .me-entry-body { display: none; border-top: 1px solid var(--stroke, #3C3C3C); padding: 10px 12px; white-space: pre-wrap; word-break: break-word; font-size: 12px; color: var(--text, #CCCCCC); }
  .me-entry.open .me-entry-body { display: block; }
  .mh-card { border: 1px solid var(--stroke, #3C3C3C); border-radius: 7px; background: var(--layer, #252526); padding: 9px 11px; margin-top: 8px; }
  .mh-from { font-weight: 600; font-size: 12px; }
  .mh-summary { color: var(--text-2, #9D9D9D); font-size: 11.5px; margin: 3px 0 6px; }
  .mh-action { font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: .04em; padding: 1px 8px; border-radius: 9px; background: var(--layer-alt, #2D2D2D); color: var(--text-2, #9D9D9D); }
  .mh-a-recalled { color: var(--accent-cyan, #9CDCFE); } .mh-a-merged { color: #E0954B; } .mh-a-stored { color: var(--ok, #73C991); }
  @media (max-width: 860px) { .me-body { flex-direction: column; } .me-handoff-panel { flex: none; border-left: none; border-top: 1px solid var(--stroke, #3C3C3C); padding-left: 0; padding-top: 12px; } }
```

* [ ] **Step 4: Implement `public/client.js`**

Add module-level expand state near the promptlab `plOpen` declaration:

```js
// Memory: which entry rows are expanded, keyed by the entry's data-me id (the same
// id-keyed Set + per-render reconcile + document re-scan pattern the promptlab case
// rows use, because happy-dom's eval harness does not reflect parentElement mutations).
const meOpen = new Set();
```

In `render(v)`, after `const promptlabView = document.getElementById("promptlab-view");` add:

```js
  const memoryView = document.getElementById("memory-view");
```

In EACH existing domain branch (`codemap`, `team`, `backlog`, `dataprofile`, `gallery`, `promptlab`, `interview`) and the review/default tail, add alongside the other hide lines:

```js
      if (memoryView) memoryView.hidden = true;
```

Add the new `memory` branch (place it next to the `promptlab` branch):

```js
    if (v.domain === "memory") {
      rpiView.hidden = true; findingsView.hidden = true;
      if (interviewView) interviewView.hidden = true;
      if (backlogView) backlogView.hidden = true;
      if (teamView) teamView.hidden = true;
      if (codemapView) codemapView.hidden = true;
      if (dataprofileView) dataprofileView.hidden = true;
      if (galleryView) galleryView.hidden = true;
      if (promptlabView) promptlabView.hidden = true;
      if (memoryView) memoryView.hidden = false;
      renderMemory(v);
      return;
    }
```

Add `renderMemory` (next to `renderPromptlab`):

```js
function renderMemory(v) {
  const m = v.memory || { title: null, counts: { recalled: 0, added: 0, updated: 0, total: 0 }, entries: [], handoffs: [] };
  setText("me-title", m.title || "Memory");
  const ct = m.counts;
  const chip = (n, cls, label) => n > 0 ? `<span class="pl-chip ${cls}">${n} ${label}</span>` : "";
  setHtml("me-counts", ct.total
    ? chip(ct.recalled, "me-c-recalled", "recalled") + chip(ct.added, "me-c-added", "added") + chip(ct.updated, "me-c-updated", "updated")
    : "");
  // Reconcile expand state: drop ids no longer present so nothing carries across sessions.
  const ids = new Set((m.entries || []).map((e) => e.id));
  for (const id of meOpen) if (!ids.has(id)) meOpen.delete(id);
  // Group entries by category in first-seen order.
  const order = [];
  const byCat = new Map();
  (m.entries || []).forEach((e) => {
    if (!byCat.has(e.category)) { byCat.set(e.category, []); order.push(e.category); }
    byCat.get(e.category).push(e);
  });
  setHtml("me-entries", order.map((cat) => {
    const rows = byCat.get(cat).map((e) => {
      const name = e.title ? esc(e.title) : esc(e.content.replace(/\s+/g, " ").slice(0, 60));
      const preview = esc(e.content.replace(/\s+/g, " ").slice(0, 120));
      return `<div class="me-entry${meOpen.has(e.id) ? " open" : ""}" data-me="${esc(e.id)}"><div class="me-head"><span class="me-name">${name}</span><span class="me-preview">${preview}</span><span class="me-tag me-t-${esc(e.tag)}">${esc(e.tag)}</span></div><div class="me-entry-body">${esc(e.content)}</div></div>`;
    }).join("");
    return `<div class="me-group"><div class="me-group-head">${esc(cat)}</div>${rows}</div>`;
  }).join("") || `<div class="meta" style="padding:8px">No memory yet.</div>`);
  setHtml("me-handoffs", (m.handoffs || []).map((h) =>
    `<div class="mh-card"><div class="mh-from">${esc(h.from)}</div><div class="mh-summary">${esc(h.summary)}</div><span class="mh-action mh-a-${esc(h.action)}">${esc(h.action)}</span></div>`).join("")
    || `<div class="meta">No handoffs.</div>`);
}
```

In the existing delegated click handler (`document.addEventListener("click", (e) => { ... }`), add (near the `.pc-head` handler):

```js
  const meHead = e.target.closest(".me-head");
  if (meHead && meHead.parentElement) {
    const k = meHead.parentElement.getAttribute("data-me");
    if (k != null) {
      if (meOpen.has(k)) meOpen.delete(k); else meOpen.add(k);
      const cls = meOpen.has(k) ? "me-entry open" : "me-entry";
      document.querySelectorAll(".me-entry").forEach((el) => { if (el.getAttribute("data-me") === k) el.className = cls; });
    }
    return;
  }
```

* [ ] **Step 5: Run the test, then tsc + node check + whole suite**

Run: `npx vitest run tests/memory-client.test.ts && npx tsc --noEmit && node --check public/client.js && npx vitest run`
Expected: ALL green.

* [ ] **Step 6: Commit**

```bash
git add rpi-cockpit/public/index.html rpi-cockpit/public/client.js rpi-cockpit/tests/memory-client.test.ts
git commit -m "feat(cockpit): memory view (category-grouped entries + handoff strip) and routing"
```

---

### Task 4: Agent contract for the memory view

**Files:**
* Modify: `rpi-cockpit/agents/cockpit-instructions.md`

**Interfaces:**
* Consumes: nothing in code; the narration contract every agent reads.

* [ ] **Step 1: Edit the contract**

Add a new section (after the prompt-engineering section or near the meta-utility mappings):

```markdown
## Memory (the memory store)

* `memory_open(title?)` opens the Memory view and switches the cockpit to it; optionally name the collection. The Memory agent calls this when it activates.
* `add_memory(id, content, category, tag?, title?)` adds or updates one memory entry: a recalled or written fact, grouped by `category` (a memory type like user/feedback/project/reference, or a source). Tag it `recalled` (loaded into context), `added` (written this session), or `updated`; give an optional short `title`.
* `add_handoff(id, from, summary, action?)` records another agent handing state to Memory: `from` is the agent's name, `summary` is what was handed, `action` is stored/merged/recalled.
* The context badges (`set_context`) remain the active-standards strip and are orthogonal to this store.
```

* [ ] **Step 2: Lint from the repo root**

Run: `cd "/Volumes/Main External/Development/hve-core" && npx markdownlint-cli2 "rpi-cockpit/agents/cockpit-instructions.md"`
Expected: `Summary: 0 error(s)`. (Split a bullet if a line-length rule trips; keep asterisk bullets, no em-dashes.)

* [ ] **Step 3: Commit**

```bash
git add rpi-cockpit/agents/cockpit-instructions.md
git commit -m "docs(cockpit): memory narration contract"
```

---

## Final verification (after Task 4)

* [ ] `cd rpi-cockpit && npx tsc --noEmit && npx vitest run` fully green; `node --check public/client.js` OK.
* [ ] `npm run build`, then verify live in a RESTARTED consumer pane (a render.ts/state change requires a consumer restart, not just a browser reload): drive a producer that calls `memory_open` + several `add_memory` (mixed categories + tags) + a couple `add_handoff`; confirm the entries render grouped by category with tag pills, the count chips reflect the tags, the handoff strip shows the cards with action pills, and clicking an entry expands its full content.
* [ ] Push to `fork` and open a PR.

## Self-Review

**Spec coverage:** the `memory` domain + state (Task 1) covered; the three beats + tools with tag/action validation (Tasks 1, 2) covered; the derived-counts view-model projection (Task 1) covered; the `#memory-view` (header counts + category-grouped entries + handoff strip) + routing + expand interaction (Task 3) covered; the agent contract (Task 4) covered. Deferred items (edit/delete, cross-session diff, semantic search) correctly absent.

**Placeholder scan:** every code step shows complete code. The expand handler uses the proven id-keyed Set + document-scan pattern (not classList.toggle) so it works under the happy-dom harness. No TBD/TODO.

**Type consistency:** `MemoryEntry`/`MemoryTag`/`MemoryHandoff`/`HandoffAction` are identical across the beat zod enums (events.ts), the state interfaces (state.ts), the tool inputSchemas (mcp.ts), and the handler arg types (handlers.ts). The view-model widens `tag`/`action` to `string` and null-coalesces `title`, used consistently by the client (Task 3) and asserted in the render test (Task 1) and client test (Task 3). The derived `counts` keys (`recalled`/`added`/`updated`/`total`) match the `MemoryTag` values plus `total`. The names `memory_open`/`add_memory`/`add_handoff`/`memory.open`/`memory.add`/`handoff.add`/`renderMemory`/`#memory-view`/`me-entries`/`me-entry`/`me-t-{tag}`/`me-handoffs`/`mh-a-{action}` are consistent across all tasks.
