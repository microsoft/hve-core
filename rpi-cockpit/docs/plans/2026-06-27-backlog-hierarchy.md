<!-- markdownlint-disable -->
# Backlog Hierarchy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a backlog item declare a `parent`, and render the resulting Epic→Feature→Story→Task hierarchy on the kanban board by nesting a child under its parent when both share a column and showing a "↳ under {parent}" reference when they do not.

**Architecture:** An optional `parent` threads through the `item.add` beat, `BacklogItem` state, and the `add_item` tool. The view-model `toViewModel` does the hierarchy math per column (a pure `orderColumnItems` helper computes a depth-first ordered list with `depth` and `parentRef`). The client renders the ordered list flatly with a left indent and an optional reference line. State columns stay authoritative.

**Tech Stack:** TypeScript (ESM, strict), zod, unbundled browser client (`public/client.js` + `public/index.html`), Vitest + happy-dom. Design spec: `docs/backlog-hierarchy-design.md`.

## Global Constraints

* TypeScript strict; no new `any`.
* ESM `.js` import specifiers in all `src/` imports.
* No new MCP tools (the count stays 30); `add_item` only gains an optional field.
* `item.move` is unchanged: moving a card changes its column, never its parentage.
* Every interpolation in `public/client.js` goes through the existing `esc()` helper.
* `depth` = number of consecutive ancestors present in the SAME column (a column root is `depth 0`). `parentRef` is set only when an item's immediate parent is NOT in its column, resolved to the parent's title (falling back to the raw parent id if the parent is not on the board).
* Run `npx tsc --noEmit && npx vitest run` until green before each commit; `node --check public/client.js` must pass.
* House markdown for docs: asterisk bullets, no em-dashes, lint clean from the REPO ROOT.

---

### Task 1: Thread `parent` through the beat, state, and tool

**Files:**
* Modify: `src/events.ts` (the `item.add` beat schema)
* Modify: `src/state.ts` (`BacklogItem` type + the `item.add` reducer)
* Modify: `src/mcp.ts` (the `add_item` tool inputSchema)
* Modify: `src/handlers.ts` (`add_item` handler)
* Test: `tests/state.test.ts`

**Interfaces:**
* Produces: `BacklogItem` gains `parent?: string`; the `item.add` beat gains `parent?: string`; `add_item` accepts `{ ..., parent?: string }`.

* [ ] **Step 1: Write the failing test**

Add to `tests/state.test.ts`:

```ts
it("item.add stores an optional parent", () => {
  let s = applyBeat(initialState(), { type: "backlog.start", target: "S", columns: ["Todo"] }, 1);
  s = applyBeat(s, { type: "item.add", id: "F1", title: "Feature", column: "Todo", parent: "E1" }, 2);
  s = applyBeat(s, { type: "item.add", id: "X1", title: "No parent", column: "Todo" }, 3);
  expect(s.boardItems.find((i) => i.id === "F1")?.parent).toBe("E1");
  expect(s.boardItems.find((i) => i.id === "X1")?.parent).toBeUndefined();
});
```

* [ ] **Step 2: Run to verify it fails**

Run: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/state.test.ts`
Expected: FAIL (`parent` not stored).

* [ ] **Step 3: Implement**

In `src/events.ts`, the `item.add` beat currently is:

```ts
  z.object({ type: z.literal("item.add"), id: z.string(), title: z.string(), column: z.string(), kind: z.string().optional(), tier: z.string().optional() }),
```

Add `parent`:

```ts
  z.object({ type: z.literal("item.add"), id: z.string(), title: z.string(), column: z.string(), kind: z.string().optional(), tier: z.string().optional(), parent: z.string().optional() }),
```

In `src/state.ts`, change `BacklogItem` (line 6):

```ts
export interface BacklogItem { id: string; title: string; column: string; kind?: string; tier?: string; parent?: string; }
```

In the `item.add` reducer (around line 95), add `parent: beat.parent` to the new item:

```ts
    case "item.add": {
      const others = s.boardItems.filter((i) => i.id !== beat.id);
      return { ...s, boardItems: [...others, { id: beat.id, title: beat.title, column: beat.column, kind: beat.kind, tier: beat.tier, parent: beat.parent }], log };
    }
```

In `src/mcp.ts`, the `add_item` tool inputSchema currently is:

```ts
    { description: "Add or update a work item on the backlog board, placing it in the given column.", inputSchema: { id: z.string(), title: z.string(), column: z.string(), kind: z.string().optional(), tier: z.string().optional() } },
```

Add `parent`:

```ts
    { description: "Add or update a work item on the backlog board, placing it in the given column. Pass parent (a parent item's id) to nest it under that item in the hierarchy.", inputSchema: { id: z.string(), title: z.string(), column: z.string(), kind: z.string().optional(), tier: z.string().optional(), parent: z.string().optional() } },
```

In `src/handlers.ts`, change `add_item` (lines 47-49):

```ts
  add_item: (b: Bridge, a: { id: string; title: string; column: string; kind?: string; tier?: string; parent?: string }) => {
    b.emitBeat({ type: "item.add", id: a.id, title: a.title, column: a.column, kind: a.kind, tier: a.tier, parent: a.parent });
    return `item added: ${a.id}`;
  },
```

* [ ] **Step 4: Run to verify it passes, then tsc**

Run: `npx vitest run tests/state.test.ts && npx tsc --noEmit`
Expected: PASS; tsc clean (this task is additive, the whole project still compiles).

* [ ] **Step 5: Commit**

```bash
git add rpi-cockpit/src/events.ts rpi-cockpit/src/state.ts rpi-cockpit/src/mcp.ts rpi-cockpit/src/handlers.ts rpi-cockpit/tests/state.test.ts
git commit -m "feat(cockpit): backlog items accept an optional parent"
```

---

### Task 2: View-model hierarchy projection (depth + parentRef + ordering)

**Files:**
* Modify: `src/render.ts` (the `ViewModel` board item type + the board projection; add the `orderColumnItems` helper)
* Test: `tests/render.test.ts`

**Interfaces:**
* Consumes: `BacklogItem.parent` from Task 1.
* Produces: each view-model board item becomes `{ id: string; title: string; kind?: string; tier?: string; depth: number; parentRef?: string }`. New helper `orderColumnItems(columnItems: BacklogItem[], byId: Map<string, BacklogItem>, inColumn: Set<string>)` returning that ordered array.

* [ ] **Step 1: Write the failing tests**

Add to `tests/render.test.ts`:

```ts
describe("backlog hierarchy projection", () => {
  function build(items: { id: string; title: string; column: string; parent?: string }[]) {
    let s = applyBeat(initialState(), { type: "backlog.start", target: "S", columns: ["Plan", "Done"] }, 1);
    items.forEach((it, n) => { s = applyBeat(s, { type: "item.add", ...it }, n + 2); });
    return toViewModel(s);
  }
  const plan = (vm: any) => vm.board.columns.find((c: any) => c.name === "Plan").items;
  const done = (vm: any) => vm.board.columns.find((c: any) => c.name === "Done").items;

  it("nests a same-column chain with increasing depth, parent-first", () => {
    const vm = build([
      { id: "E", title: "Epic", column: "Plan" },
      { id: "F", title: "Feature", column: "Plan", parent: "E" },
      { id: "S", title: "Story", column: "Plan", parent: "F" },
    ]);
    expect(plan(vm).map((i: any) => [i.id, i.depth])).toEqual([["E", 0], ["F", 1], ["S", 2]]);
    expect(plan(vm).every((i: any) => i.parentRef === undefined)).toBe(true);
  });

  it("shows a parentRef when the parent is in a different column", () => {
    const vm = build([
      { id: "E", title: "Epic", column: "Plan" },
      { id: "S", title: "Story", column: "Done", parent: "E" },
    ]);
    expect(done(vm)).toEqual([{ id: "S", title: "Story", kind: undefined, tier: undefined, depth: 0, parentRef: "Epic" }]);
  });

  it("falls back to the raw parent id when the parent is not on the board", () => {
    const vm = build([{ id: "S", title: "Orphan", column: "Plan", parent: "ghost" }]);
    expect(plan(vm)[0]).toMatchObject({ id: "S", depth: 0, parentRef: "ghost" });
  });

  it("keeps parentless items in insertion order at depth 0", () => {
    const vm = build([
      { id: "A", title: "A", column: "Plan" },
      { id: "B", title: "B", column: "Plan" },
    ]);
    expect(plan(vm).map((i: any) => [i.id, i.depth])).toEqual([["A", 0], ["B", 0]]);
  });
});
```

* [ ] **Step 2: Run to verify they fail**

Run: `npx vitest run tests/render.test.ts`
Expected: FAIL (`depth`/`parentRef` undefined; `orderColumnItems` not defined).

* [ ] **Step 3: Implement in `src/render.ts`**

Change the `ViewModel` board type (line 35) so each item carries `depth` and `parentRef`:

```ts
  board: { target: string | null; action: string | null; count: number; columns: { name: string; items: { id: string; title: string; kind?: string; tier?: string; depth: number; parentRef?: string }[] }[] };
```

Add the pure helper near the top of `render.ts` (after the imports). It imports nothing new beyond the existing `BacklogItem` type (already in scope via `./state.js`; if `toViewModel` does not already import `BacklogItem`, add it to the existing `import { ... } from "./state.js";`):

```ts
function orderColumnItems(
  columnItems: BacklogItem[],
  byId: Map<string, BacklogItem>,
  inColumn: Set<string>,
): { id: string; title: string; kind?: string; tier?: string; depth: number; parentRef?: string }[] {
  const childrenOf = new Map<string, BacklogItem[]>();
  const roots: BacklogItem[] = [];
  for (const i of columnItems) {
    const sameColParent = i.parent && inColumn.has(i.parent) ? i.parent : null;
    if (sameColParent) {
      const arr = childrenOf.get(sameColParent) ?? [];
      arr.push(i);
      childrenOf.set(sameColParent, arr);
    } else {
      roots.push(i);
    }
  }
  const out: { id: string; title: string; kind?: string; tier?: string; depth: number; parentRef?: string }[] = [];
  const seen = new Set<string>();
  const visit = (i: BacklogItem, depth: number): void => {
    if (seen.has(i.id)) return;
    seen.add(i.id);
    const crossColumn = i.parent !== undefined && !inColumn.has(i.parent);
    out.push({
      id: i.id, title: i.title, kind: i.kind, tier: i.tier, depth,
      parentRef: crossColumn ? (byId.get(i.parent as string)?.title ?? (i.parent as string)) : undefined,
    });
    for (const c of childrenOf.get(i.id) ?? []) visit(c, depth + 1);
  };
  for (const r of roots) visit(r, 0);
  for (const i of columnItems) if (!seen.has(i.id)) visit(i, 0); // defensive: cycles/orphans never silently drop
  return out;
}
```

Replace the `board` projection (lines 77-87) so each column runs the helper:

```ts
  const byId = new Map(s.boardItems.map((i) => [i.id, i]));
  const board = {
    target: s.boardTarget,
    action: s.boardAction,
    count: s.boardItems.length,
    columns: s.boardColumns.map((name) => {
      const columnItems = s.boardItems.filter((i) => i.column === name);
      const inColumn = new Set(columnItems.map((i) => i.id));
      return { name, items: orderColumnItems(columnItems, byId, inColumn) };
    }),
  };
```

* [ ] **Step 4: Run the new tests, then the whole suite + tsc**

Run: `npx vitest run tests/render.test.ts && npx tsc --noEmit && npx vitest run`
Expected: the new tests PASS; tsc clean; whole suite green. If a pre-existing test exact-matches a board item object (a `toEqual` without `depth`), update it to include `depth: 0` (and `parentRef: undefined` where applicable) — that is the intended shape change.

* [ ] **Step 5: Commit**

```bash
git add rpi-cockpit/src/render.ts rpi-cockpit/tests/render.test.ts
git commit -m "feat(cockpit): view-model projects backlog hierarchy (depth + parentRef)"
```

---

### Task 3: Client renders the indent and reference line

**Files:**
* Modify: `public/client.js` (`renderBoard`)
* Modify: `public/index.html` (the `.bcard-parent` CSS)
* Test: `tests/backlog-client.test.ts`

**Interfaces:**
* Consumes: the view-model board item `{ ..., depth, parentRef? }` from Task 2.
* Produces: a `.bcard` with `style="margin-left:{depth*16}px"` when `depth > 0`, and a `.bcard-parent` line `↳ under {parentRef}` when `parentRef` is set.

* [ ] **Step 1: Write the failing tests**

Add to `tests/backlog-client.test.ts` (reuse the existing `boot()` harness; build a hierarchy vm):

```ts
function hierarchyVm() {
  let s = applyBeat(initialState(), { type: "backlog.start", target: "S", columns: ["Plan", "Done"] }, 1);
  s = applyBeat(s, { type: "item.add", id: "E", title: "Epic", column: "Plan" }, 2);
  s = applyBeat(s, { type: "item.add", id: "F", title: "Feature", column: "Plan", parent: "E" }, 3);
  s = applyBeat(s, { type: "item.add", id: "S", title: "Story", column: "Done", parent: "E" }, 4);
  return toViewModel(s);
}

it("indents a same-column child and shows a reference for a cross-column child", () => {
  (win as any).render(hierarchyVm());
  const planCards = win.document.querySelectorAll('#board .board-col[aria-label="Plan"] .bcard');
  const feature = Array.from(planCards).find((c: any) => c.querySelector(".bcard-id")!.textContent === "F") as any;
  expect(feature.getAttribute("style")).toContain("margin-left:16px");
  expect(feature.querySelector(".bcard-parent")).toBeNull(); // same-column: nesting, no ref
  const doneCard = win.document.querySelector('#board .board-col[aria-label="Done"] .bcard') as any;
  expect(doneCard.querySelector(".bcard-parent")!.textContent).toContain("Epic");
  const epic = Array.from(planCards).find((c: any) => c.querySelector(".bcard-id")!.textContent === "E") as any;
  expect(epic.getAttribute("style")).toBeNull(); // root: no indent
});
```

* [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run tests/backlog-client.test.ts`
Expected: FAIL (no margin-left, no `.bcard-parent`).

* [ ] **Step 3: Implement `renderBoard` in `public/client.js`**

Replace the card template inside `renderBoard` (the `c.items.map((it) => ...)` block) with:

```js
       ${c.items.map((it) =>
         `<div class="bcard"${it.depth ? ` style="margin-left:${it.depth * 16}px"` : ""}>
            <div class="bcard-id">${esc(it.id)}</div>
            ${it.parentRef ? `<div class="bcard-parent">↳ under ${esc(it.parentRef)}</div>` : ""}
            <div class="bcard-title">${esc(it.title)}</div>
            ${(it.kind || it.tier) ? `<div class="bcard-chips">${it.kind ? `<span class="chip-kind">${esc(it.kind)}</span>` : ""}${it.tier ? `<span class="chip-tier">${esc(it.tier)}</span>` : ""}</div>` : ""}
          </div>`).join("") || `<div class="col-empty"></div>`}
```

* [ ] **Step 4: Add CSS in `public/index.html`**

Next to the existing `.bcard` rules, add:

```css
  .bcard-parent { font-size: 11px; opacity: .55; margin-bottom: 2px; }
```

* [ ] **Step 5: Run the focused test, then the whole suite + tsc + node check**

Run: `npx vitest run tests/backlog-client.test.ts && npx tsc --noEmit && node --check public/client.js && npx vitest run`
Expected: ALL green.

* [ ] **Step 6: Commit**

```bash
git add rpi-cockpit/public/client.js rpi-cockpit/public/index.html rpi-cockpit/tests/backlog-client.test.ts
git commit -m "feat(cockpit): kanban nests child cards and shows cross-column parentage"
```

---

### Task 4: Agent contract for backlog parentage

**Files:**
* Modify: `rpi-cockpit/agents/cockpit-instructions.md` (the backlog section)

**Interfaces:**
* Consumes: nothing in code; the narration contract every agent reads.

* [ ] **Step 1: Edit the contract**

In `rpi-cockpit/agents/cockpit-instructions.md`, in the backlog-orchestration section, the `add_item` bullet currently reads (around the "Backlog orchestration" heading):

```markdown
* `add_item(id, title, column, kind?, tier?)` to add or update a work item, `move_item(id, column)` as it progresses, and `set_backlog_action(text)` to show the action you are taking (null clears it).
```

Change it to mention `parent` and add a planner note:

```markdown
* `add_item(id, title, column, kind?, tier?, parent?)` to add or update a work item, `move_item(id, column)` as it progresses, and `set_backlog_action(text)` to show the action you are taking (null clears it). Pass `parent` (a parent item's id) to nest the item: the board indents a child under its parent when both are in the same column and shows "↳ under {parent}" when they are not. A PRD-to-WIT planner proposing an Epic→Feature→Story→Task tree should pass `parent` and add the items to one planning column so the whole tree nests.
```

* [ ] **Step 2: Lint from the repo root**

Run: `cd "/Volumes/Main External/Development/hve-core" && npx markdownlint-cli2 "rpi-cockpit/agents/cockpit-instructions.md"`
Expected: `Summary: 0 error(s)`.

* [ ] **Step 3: Commit**

```bash
git add rpi-cockpit/agents/cockpit-instructions.md
git commit -m "docs(cockpit): add_item gains parent; PRD-to-WIT planners nest the WIT tree"
```

---

## Final verification (after Task 4)

* [ ] `cd rpi-cockpit && npx tsc --noEmit && npx vitest run` fully green; `node --check public/client.js` OK.
* [ ] `npm run build`, then verify live: drive a producer that adds an Epic→Feature→Story in one column (nests with increasing indent) and a Story in a different column from its Epic (shows "↳ under {epic}"); screenshot.
* [ ] Push to `fork` (PR #1).

## Self-Review

**Spec coverage:** optional `parent` through beat/state/tool/contract (Tasks 1, 4) — covered. The `depth`/`parentRef`/ordering projection (Task 2) — covered, matching the spec's worked example (E/F/S one column → depths 0/1/2; move S to Done → S depth 0 + parentRef). Indent + reference-line rendering (Task 3) — covered. Deferred items (swimlanes, tree view, reparent, collapse, tier-inference) correctly absent.

**Placeholder scan:** every code step shows complete code; the one conditional ("if a pre-existing test exact-matches a board item") names the concrete fix (add `depth`). No TBD/TODO.

**Type consistency:** the board item shape `{ id, title, kind?, tier?, depth, parentRef? }` is identical across the `ViewModel` type, `orderColumnItems`'s return type, and the client/test usage. `parent?: string` is identical across `BacklogItem`, the `item.add` beat, and `add_item`. `orderColumnItems(columnItems, byId, inColumn)` signature matches its call site.
