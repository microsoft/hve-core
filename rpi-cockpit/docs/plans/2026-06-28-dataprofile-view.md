<!-- markdownlint-disable -->
# Dataset Profile View Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a new `dataprofile` loop view that renders a dataset profile (data dictionary) as a structured table for the DS Gen Data Spec agent, driven by two new MCP tools.

**Architecture:** A new `dataprofile` domain peer to review/backlog/interview. Two new beats (`profile.start`, `column.add`) and state fields (`profileDataset`, `profileColumns`) feed a `dataProfile` view-model projection; two new MCP tools (`dataset_profile`, `add_column`) emit the beats; a new `#dataprofile-view` renders a header + column table with domain routing exactly like the existing views.

**Tech Stack:** TypeScript (ESM, strict), zod, Node `ws`, unbundled browser client (`public/client.js` + `public/index.html`), Vitest + happy-dom. Design spec: `docs/dataprofile-view-design.md`.

## Global Constraints

* `ProfileColumn = { name: string; dtype: string; nullPct?: number; distinct?: number; stat?: string; quality?: "ok" | "warn" | "risk" }`.
* `profileDataset: { name: string; rows?: number; cols?: number; source?: string } | null`.
* The MCP tool count goes from 30 to 32 (two new tools; no tools removed).
* `quality` is a zod enum `["ok","warn","risk"]` at the tool boundary; an out-of-enum value is rejected.
* `column.add` upserts by `name` IN PLACE (preserves column order on update; appends a new name).
* TypeScript strict; no new `any`; ESM `.js` import specifiers in all `src/` imports.
* Every interpolation in `public/client.js` goes through the existing `esc()` helper.
* Keep the global `[hidden]{display:none!important}` rule and all iframe `sandbox` attributes untouched.
* Run `npx tsc --noEmit && npx vitest run` until green before each commit; `node --check public/client.js` must pass.
* House markdown for docs: asterisk bullets, no em-dashes, lint clean from the REPO ROOT.

---

### Task 1: Beats, state, and view-model

**Files:**
* Modify: `src/events.ts` (add the two beats to the `Beat` union)
* Modify: `src/state.ts` (domain union; `ProfileColumn` type; `profileDataset`/`profileColumns` fields; `initialState`; the two reducer arms; the two `summarize` arms)
* Modify: `src/render.ts` (domain union; `ViewModel.dataProfile`; the `toViewModel` projection)
* Test: `tests/state.test.ts`, `tests/render.test.ts`

**Interfaces:**
* Produces:
  * Beats `{ type: "profile.start"; name: string; rows?: number; columns?: number; source?: string }` and `{ type: "column.add"; name: string; dtype: string; nullPct?: number; distinct?: number; stat?: string; quality?: "ok"|"warn"|"risk" }`.
  * `SessionState.profileDataset`, `SessionState.profileColumns`, `ProfileColumn`.
  * `ViewModel.dataProfile: { dataset: { name: string; rows?: number; cols?: number; source?: string } | null; columns: { name: string; dtype: string; nullPct?: number; distinct?: number; stat?: string; quality?: string }[] }`.

* [ ] **Step 1: Write the failing tests**

Add to `tests/state.test.ts`:

```ts
describe("data profile", () => {
  it("profile.start sets the dataset and clears columns", () => {
    let s = applyBeat(initialState(), { type: "profile.start", name: "sales.csv", rows: 38201, columns: 12, source: "warehouse" }, 1);
    expect(s.domain).toBe("dataprofile");
    expect(s.view).toBe("loop");
    expect(s.profileDataset).toEqual({ name: "sales.csv", rows: 38201, cols: 12, source: "warehouse" });
    expect(s.profileColumns).toEqual([]);
  });
  it("column.add appends, and a same-name add updates in place (order preserved)", () => {
    let s = applyBeat(initialState(), { type: "profile.start", name: "d", rows: 1, columns: 2 }, 1);
    s = applyBeat(s, { type: "column.add", name: "revenue", dtype: "float", nullPct: 0, distinct: 900, stat: "0-4820", quality: "ok" }, 2);
    s = applyBeat(s, { type: "column.add", name: "region", dtype: "category", distinct: 5, stat: "top: US 42%", quality: "warn" }, 3);
    s = applyBeat(s, { type: "column.add", name: "revenue", dtype: "float", nullPct: 3, distinct: 901 }, 4);
    expect(s.profileColumns.map((c) => c.name)).toEqual(["revenue", "region"]);
    expect(s.profileColumns[0]).toEqual({ name: "revenue", dtype: "float", nullPct: 3, distinct: 901, stat: undefined, quality: undefined });
  });
});
```

Add to `tests/render.test.ts`:

```ts
it("projects the data profile dataset and columns", () => {
  let s = applyBeat(initialState(), { type: "profile.start", name: "sales.csv", rows: 100, columns: 3, source: "warehouse" }, 1);
  s = applyBeat(s, { type: "column.add", name: "id", dtype: "int", nullPct: 0, distinct: 100, quality: "ok" }, 2);
  const vm = toViewModel(s);
  expect(vm.domain).toBe("dataprofile");
  expect(vm.dataProfile.dataset).toEqual({ name: "sales.csv", rows: 100, cols: 3, source: "warehouse" });
  expect(vm.dataProfile.columns).toEqual([{ name: "id", dtype: "int", nullPct: 0, distinct: 100, stat: undefined, quality: "ok" }]);
  expect(toViewModel(initialState()).dataProfile.dataset).toBeNull();
});
```

* [ ] **Step 2: Run to verify they fail**

Run: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/state.test.ts tests/render.test.ts`
Expected: FAIL (beats/fields/projection not defined).

* [ ] **Step 3: Implement `src/events.ts`**

Add to the `Beat` union (after the `backlog.action` member at line 55):

```ts
  z.object({ type: z.literal("profile.start"), name: z.string(), rows: z.number().int().optional(), columns: z.number().int().optional(), source: z.string().optional() }),
  z.object({ type: z.literal("column.add"), name: z.string(), dtype: z.string(), nullPct: z.number().optional(), distinct: z.number().int().optional(), stat: z.string().optional(), quality: z.enum(["ok", "warn", "risk"]).optional() }),
```

* [ ] **Step 4: Implement `src/state.ts`**

Add the `ProfileColumn` interface near the other interfaces (e.g. after `BacklogItem`):

```ts
export interface ProfileColumn { name: string; dtype: string; nullPct?: number; distinct?: number; stat?: string; quality?: "ok" | "warn" | "risk"; }
```

In the `domain` union (line 18) add `"dataprofile"`:

```ts
  domain: "rpi" | "review" | "interview" | "backlog" | "team" | "codemap" | "dataprofile" | null;
```

Add two fields to `SessionState` (near `boardItems`):

```ts
  profileDataset: { name: string; rows?: number; cols?: number; source?: string } | null;
  profileColumns: ProfileColumn[];
```

In `initialState()`, add `profileDataset: null, profileColumns: []` to the returned object.

Add the reducer arms (after the `backlog.action` arm):

```ts
    case "profile.start":
      return { ...s, view: "loop", domain: "dataprofile", profileDataset: { name: beat.name, rows: beat.rows, cols: beat.columns, source: beat.source }, profileColumns: [], log };
    case "column.add": {
      const col = { name: beat.name, dtype: beat.dtype, nullPct: beat.nullPct, distinct: beat.distinct, stat: beat.stat, quality: beat.quality };
      const exists = s.profileColumns.some((c) => c.name === beat.name);
      return { ...s, profileColumns: exists ? s.profileColumns.map((c) => (c.name === beat.name ? col : c)) : [...s.profileColumns, col], log };
    }
```

In the `summarize(beat)` function's switch, add two arms (so it stays exhaustive):

```ts
    case "profile.start": return beat.name;
    case "column.add": return beat.name;
```

* [ ] **Step 5: Implement `src/render.ts`**

In the `ViewModel` `domain` union (line 66) add `"dataprofile"` (same as state). Add the `dataProfile` field to the `ViewModel` interface (near `board`):

```ts
  dataProfile: { dataset: { name: string; rows?: number; cols?: number; source?: string } | null; columns: { name: string; dtype: string; nullPct?: number; distinct?: number; stat?: string; quality?: string }[] };
```

In `toViewModel`, add to the returned object (near `board`):

```ts
    dataProfile: { dataset: s.profileDataset, columns: s.profileColumns },
```

* [ ] **Step 6: Run the tests, then tsc + whole suite**

Run: `npx vitest run tests/state.test.ts tests/render.test.ts && npx tsc --noEmit && npx vitest run`
Expected: the new tests PASS; tsc clean; whole suite green. (If a test exact-matches the full `ViewModel`, add `dataProfile`; none is expected.)

* [ ] **Step 7: Commit**

```bash
git add rpi-cockpit/src/events.ts rpi-cockpit/src/state.ts rpi-cockpit/src/render.ts rpi-cockpit/tests/state.test.ts rpi-cockpit/tests/render.test.ts
git commit -m "feat(cockpit): dataprofile domain state, beats, and view-model"
```

---

### Task 2: MCP tools and handlers

**Files:**
* Modify: `src/handlers.ts` (add `dataset_profile` and `add_column` handlers)
* Modify: `src/mcp.ts` (register the two tools)
* Test: `tests/mcp.test.ts` (round trip + tool count), `tests/handlers.test.ts` if it covers handlers directly (follow the suite's pattern)

**Interfaces:**
* Consumes: the `profile.start` / `column.add` beats from Task 1.
* Produces: tools `dataset_profile({ name, rows?, columns?, source? })` and `add_column({ name, dtype, nullPct?, distinct?, stat?, quality? })`.

* [ ] **Step 1: Write the failing test**

Add to `tests/mcp.test.ts` (mirror the existing backlog round-trip test that drives a tool over the in-memory transport and reads `bridge.state`; reuse its harness/imports):

```ts
it("dataset_profile + add_column drive the data profile state", async () => {
  const { bridge, callTool } = await makeServer(); // use the suite's existing helper
  await callTool("dataset_profile", { name: "sales.csv", rows: 100, columns: 2, source: "dw" });
  await callTool("add_column", { name: "id", dtype: "int", nullPct: 0, distinct: 100, quality: "ok" });
  expect(bridge.state.domain).toBe("dataprofile");
  expect(bridge.state.profileDataset).toMatchObject({ name: "sales.csv", cols: 2 });
  expect(bridge.state.profileColumns[0]).toMatchObject({ name: "id", dtype: "int", quality: "ok" });
});
```

If the suite has a tool-count assertion, bump it from 30 to 32. (Search `tests/mcp.test.ts` for `toHaveLength(30)` / `30` / `tools.length`.)

(If `tests/mcp.test.ts` uses a different harness shape, match it exactly; the assertion on `bridge.state.profileDataset`/`profileColumns` is the point. The zod enum on `quality` is enforced by the tool layer, so passing `quality: "bogus"` would reject; you may add that negative case if the suite exercises rejections.)

* [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run tests/mcp.test.ts`
Expected: FAIL (tools not registered).

* [ ] **Step 3: Implement `src/handlers.ts`**

Add (next to `add_item` / `set_backlog_action`):

```ts
  dataset_profile: (b: Bridge, a: { name: string; rows?: number; columns?: number; source?: string }) => {
    b.emitBeat({ type: "profile.start", name: a.name, rows: a.rows, columns: a.columns, source: a.source });
    return `profile started: ${a.name}`;
  },
  add_column: (b: Bridge, a: { name: string; dtype: string; nullPct?: number; distinct?: number; stat?: string; quality?: "ok" | "warn" | "risk" }) => {
    b.emitBeat({ type: "column.add", name: a.name, dtype: a.dtype, nullPct: a.nullPct, distinct: a.distinct, stat: a.stat, quality: a.quality });
    return `column added: ${a.name}`;
  },
```

* [ ] **Step 4: Implement `src/mcp.ts`**

Register the two tools (in the backlog tool region, after `set_backlog_action`):

```ts
  server.registerTool(
    "dataset_profile",
    { description: "Begin a dataset profile; switches the cockpit to the data-profile table view. Name the dataset; optionally give its row count, total column count, and source.", inputSchema: { name: z.string(), rows: z.number().int().optional(), columns: z.number().int().optional(), source: z.string().optional() } },
    async (a) => text(handlers.dataset_profile(bridge, a)),
  );

  server.registerTool(
    "add_column",
    { description: "Add or update one column's profile in the dataset profile view (a dataset field, not a kanban column). Give its name and dtype; optionally null percentage (0-100), distinct count, a representative stat string (e.g. \"0-4820\" or \"mean 126.2\"), and a quality flag (ok/warn/risk).", inputSchema: { name: z.string(), dtype: z.string(), nullPct: z.number().optional(), distinct: z.number().int().optional(), stat: z.string().optional(), quality: z.enum(["ok", "warn", "risk"]).optional() } },
    async (a) => text(handlers.add_column(bridge, a)),
  );
```

* [ ] **Step 5: Run the test, then tsc + whole suite**

Run: `npx vitest run tests/mcp.test.ts && npx tsc --noEmit && npx vitest run`
Expected: PASS; tsc clean; whole suite green (the tool-count assertion now expects 32).

* [ ] **Step 6: Commit**

```bash
git add rpi-cockpit/src/handlers.ts rpi-cockpit/src/mcp.ts rpi-cockpit/tests/mcp.test.ts
git commit -m "feat(cockpit): dataset_profile and add_column MCP tools"
```

---

### Task 3: The dataprofile client view and routing

**Files:**
* Modify: `public/index.html` (the `#dataprofile-view` markup + CSS)
* Modify: `public/client.js` (`renderDataProfile`; the routing branch; hide `#dataprofile-view` in every other domain branch)
* Test: `tests/dataprofile-client.test.ts` (new)

**Interfaces:**
* Consumes: `ViewModel.dataProfile` from Task 1.
* Produces: a `#dataprofile-view` shown when `v.domain === "dataprofile"`; a `#dp-table` with one `<tr>` per column; a `.dp-q.dp-q-{quality}` dot per column with a quality.

* [ ] **Step 1: Write the failing test**

Create `tests/dataprofile-client.test.ts` (mirror `tests/backlog-client.test.ts`'s `boot()` harness):

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
function profileVm() {
  let s = applyBeat(initialState(), { type: "profile.start", name: "sales.csv", rows: 100, columns: 2, source: "dw" }, 1);
  s = applyBeat(s, { type: "column.add", name: "id", dtype: "int", nullPct: 0, distinct: 100, quality: "ok" }, 2);
  s = applyBeat(s, { type: "column.add", name: "region", dtype: "category", distinct: 5, stat: "top: US 42%", quality: "warn" }, 3);
  return toViewModel(s);
}

describe("dataprofile client", () => {
  let win: ReturnType<typeof boot>;
  beforeEach(() => { win = boot(); });

  it("shows the dataprofile view and hides the others on the dataprofile domain", () => {
    (win as any).render(profileVm());
    expect((win.document.getElementById("dataprofile-view") as any).hidden).toBe(false);
    expect((win.document.getElementById("rpi-view") as any).hidden).toBe(true);
    expect((win.document.getElementById("backlog-view") as any).hidden).toBe(true);
  });

  it("renders one row per column with a quality dot of the right class", () => {
    (win as any).render(profileVm());
    const rows = win.document.querySelectorAll("#dp-table tbody tr");
    expect(rows.length).toBe(2);
    expect(win.document.querySelector("#dp-table .dp-q-ok")).not.toBeNull();
    expect(win.document.querySelector("#dp-table .dp-q-warn")).not.toBeNull();
    expect((win.document.getElementById("dp-name") as any).textContent).toBe("sales.csv");
  });
});
```

* [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run tests/dataprofile-client.test.ts`
Expected: FAIL (no `#dataprofile-view`).

* [ ] **Step 3: Markup + CSS in `public/index.html`**

Add the view as a sibling of `#backlog-view` (after it):

```html
    <section id="dataprofile-view" hidden>
      <div class="rev-head">
        <span class="board-target" id="dp-name">Dataset</span>
        <span class="board-count" id="dp-meta"></span>
      </div>
      <table id="dp-table" class="dp-table"></table>
    </section>
```

Add the CSS (next to the `.board-*` rules):

```css
  .dp-table { width: 100%; border-collapse: collapse; font-size: 12.5px; }
  .dp-table th { text-align: left; font-size: 11px; text-transform: uppercase; letter-spacing: .04em; color: var(--text-3, #6E6E6E); font-weight: 600; padding: 6px 10px; border-bottom: 1px solid var(--stroke, #3C3C3C); }
  .dp-table td { padding: 7px 10px; border-bottom: 1px solid var(--stroke, #3C3C3C); }
  .dp-col { font-weight: 600; }
  .dp-type { color: var(--accent-cyan, #9CDCFE); }
  .dp-stat { color: var(--text-2, #9D9D9D); }
  .dp-q { display: inline-block; width: 9px; height: 9px; border-radius: 50%; }
  .dp-q-ok { background: var(--ok, #73C991); }
  .dp-q-warn { background: #E0954B; }
  .dp-q-risk { background: var(--fail, #f2b8b5); }
```

* [ ] **Step 4: Implement `public/client.js`**

In `render(v)`, after `const codemapView = document.getElementById("codemap-view");` add:

```js
  const dataprofileView = document.getElementById("dataprofile-view");
```

In EACH existing domain branch (the `codemap`, `team`, `backlog`, and `interview` `if` blocks) add this line alongside the other hide lines:

```js
      if (dataprofileView) dataprofileView.hidden = true;
```

In the review/default tail (where `rpiView.hidden = review; findingsView.hidden = !review;` and the others are hidden), also add `if (dataprofileView) dataprofileView.hidden = true;`.

Add the new `dataprofile` branch (place it next to the `backlog` branch, before the `interview` branch):

```js
    if (v.domain === "dataprofile") {
      rpiView.hidden = true; findingsView.hidden = true;
      if (interviewView) interviewView.hidden = true;
      if (backlogView) backlogView.hidden = true;
      if (teamView) teamView.hidden = true;
      if (codemapView) codemapView.hidden = true;
      if (dataprofileView) dataprofileView.hidden = false;
      renderDataProfile(v);
      return;
    }
```

Add the `renderDataProfile` function (next to `renderBoard`):

```js
function renderDataProfile(v) {
  const dp = v.dataProfile || { dataset: null, columns: [] };
  const ds = dp.dataset;
  setText("dp-name", ds ? ds.name : "Dataset");
  const meta = ds ? [ds.rows != null ? `${ds.rows} rows` : null, ds.cols != null ? `${ds.cols} cols` : null, ds.source].filter(Boolean).join(" · ") : "";
  setText("dp-meta", meta);
  const head = `<thead><tr><th>Column</th><th>Type</th><th>Null %</th><th>Distinct</th><th>Stat</th><th></th></tr></thead>`;
  const body = (dp.columns || []).map((c) =>
    `<tr><td class="dp-col">${esc(c.name)}</td><td class="dp-type">${esc(c.dtype)}</td>
       <td>${c.nullPct != null ? esc(String(c.nullPct)) + "%" : ""}</td>
       <td>${c.distinct != null ? esc(String(c.distinct)) : ""}</td>
       <td class="dp-stat">${c.stat ? esc(c.stat) : ""}</td>
       <td>${c.quality ? `<span class="dp-q dp-q-${esc(c.quality)}" title="${esc(c.quality)}"></span>` : ""}</td></tr>`).join("")
    || `<tr><td colspan="6" class="meta">No columns profiled yet.</td></tr>`;
  setHtml("dp-table", head + `<tbody>${body}</tbody>`);
}
```

* [ ] **Step 5: Run the test, then tsc + node check + whole suite**

Run: `npx vitest run tests/dataprofile-client.test.ts && npx tsc --noEmit && node --check public/client.js && npx vitest run`
Expected: ALL green.

* [ ] **Step 6: Commit**

```bash
git add rpi-cockpit/public/index.html rpi-cockpit/public/client.js rpi-cockpit/tests/dataprofile-client.test.ts
git commit -m "feat(cockpit): dataprofile table view and domain routing"
```

---

### Task 4: Agent contract for data-science

**Files:**
* Modify: `rpi-cockpit/agents/cockpit-instructions.md`

**Interfaces:**
* Consumes: nothing in code; the narration contract every agent reads.

* [ ] **Step 1: Edit the contract**

Add a new section after the backlog-orchestration section:

```markdown
## Data science (dataset profiling, notebooks, dashboards)

* `dataset_profile(name, rows?, columns?, source?)` opens the data-profile table view; then call `add_column(name, dtype, nullPct?, distinct?, stat?, quality?)` once per field, with `quality` one of ok/warn/risk for a data-quality flag. Use this for a data dictionary or profile (the Data Spec agent).
* For a generated notebook or data spec document, render the preview with `show_screen(html, title)`.
* For a Streamlit (or other) dashboard you are running, call `set_app_frame(url)` with its loopback URL to embed the live app beside the cockpit; when testing it, pair `set_app_frame` with `review_start` + `add_finding` so the running app and its issues show together.
* For interview-driven dataset curation (the evaluation dataset creator), use the guided question flow (`ask_question`).
```

* [ ] **Step 2: Lint from the repo root**

Run: `cd "/Volumes/Main External/Development/hve-core" && npx markdownlint-cli2 "rpi-cockpit/agents/cockpit-instructions.md"`
Expected: `Summary: 0 error(s)`. (Split a bullet if a line-length rule trips; keep asterisk bullets, no em-dashes.)

* [ ] **Step 3: Commit**

```bash
git add rpi-cockpit/agents/cockpit-instructions.md
git commit -m "docs(cockpit): data-science narration contract (profile, dashboards, notebooks)"
```

---

## Final verification (after Task 4)

* [ ] `cd rpi-cockpit && npx tsc --noEmit && npx vitest run` fully green; `node --check public/client.js` OK.
* [ ] `npm run build`, then verify live: drive a producer that calls `dataset_profile` + several `add_column` (varied dtypes + quality flags); confirm the table renders with the header line and quality dots in the RESTARTED consumer pane (a render.ts change requires a consumer restart, not just a browser reload).
* [ ] Push to `fork` (PR #1).

## Self-Review

**Spec coverage:** the `dataprofile` domain + state (Task 1) — covered. The two beats + tools (Tasks 1, 2) — covered. The view-model projection (Task 1) — covered. The `#dataprofile-view` table + routing (Task 3) — covered. The agent contract incl. the category mapping (Task 4) — covered. Deferred items (sorting, sparklines, notebook renderer, quality inference) correctly absent.

**Placeholder scan:** every code step shows complete code; the one soft reference (the `tests/mcp.test.ts` harness "use the suite's existing helper") is intentional, matching that suite's invocation style, with a concrete assertion. No TBD/TODO.

**Type consistency:** `ProfileColumn` fields are identical across state (Task 1), the view-model widening to `quality?: string` (Task 1), the tool inputSchema (Task 2), and the client/test usage (Task 3). The beat field `columns` maps to state `cols` in exactly one place (the `profile.start` reducer arm); the tool param `columns` flows through the handler to the beat unchanged. `dataset_profile`/`add_column`/`profile.start`/`column.add`/`renderDataProfile`/`#dataprofile-view`/`dp-table` names are consistent across all tasks.
