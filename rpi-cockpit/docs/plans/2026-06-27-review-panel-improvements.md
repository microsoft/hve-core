<!-- markdownlint-disable -->
# Review-panel Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the cockpit's findings panel a live "reviewers" pipeline strip (so orchestrator reviewers show progress during long scans), turn each finding's `file:line` into a copy-to-clipboard button, and clarify the agent contract so narrative reviewers use `show_screen` instead of the findings list.

**Architecture:** Pure presentation changes plus one doc. `renderFindings(v)` in `public/client.js` renders the already-projected `v.subagents` as a compact strip and emits the location as a `<button>`; the document click listener gains a copy branch. No MCP tool, state, beat, reducer, or view-model change. The agent contract gains two lines.

**Tech Stack:** Unbundled browser client (`public/client.js` + `public/index.html`), Vitest + happy-dom, markdownlint.

## Global Constraints

* No new MCP tools (count stays 30); no state/beat/reducer/view-model change. `v.subagents` (`{ name: string; status: string; role?: string }[]`) is already projected for every domain.
* Every interpolation of view-model data in `public/client.js` goes through the existing `esc()` helper.
* Keep the global `[hidden]{display:none!important}` rule and all iframe `sandbox` attributes untouched.
* The pipeline strip reuses the existing `.sub-card` markup (`av` / `nm` / `meta` / `tagidle` classes and the `initials(name)` helper), exactly as the RPI subagents render at `client.js:204-206`.
* Run `npx tsc --noEmit && npx vitest run` until fully green before each commit. `node --check public/client.js` must pass.
* House markdown for docs: asterisk bullets, no em-dashes, lint clean from the REPO ROOT (`/Volumes/Main External/Development/hve-core`).

---

### Task 1: Findings-view pipeline strip and copy-location button

**Files:**
* Modify: `public/index.html` (add `#rev-pipeline` container in `#findings-view`; restyle `.finding-loc` as a button; add `#rev-pipeline` CSS)
* Modify: `public/client.js` (`renderFindings`: render the strip + emit the location button; add the `copyLoc` helper and the click branch)
* Test: `tests/findings-client.test.ts`

**Interfaces:**
* Consumes: `v.subagents` (already on the view-model), the existing `esc`, `setText`, `setHtml`, `initials` helpers, and the `.sub-card`/`av`/`nm`/`meta`/`tagidle` CSS classes.
* Produces: a `#rev-pipeline` element holding one `.sub-card` per `v.subagents` entry (hidden when empty); each finding with a file renders a `<button class="finding-loc" data-loc="path:line">`; clicking it copies `path:line` and flips its label to `copied`.

* [ ] **Step 1: Write the failing tests**

Add to `tests/findings-client.test.ts` a vm builder with a pipeline, then the three tests:

```ts
function reviewVmWithPipeline() {
  let s = applyBeat(initialState(), { type: "review.start", target: "Security audit" }, 1);
  s = applyBeat(s, { type: "subagent.start", name: "Codebase Profiler", role: "profiler" }, 2);
  s = applyBeat(s, { type: "subagent.start", name: "Skill Assessor", role: "auth skill" }, 3);
  s = applyBeat(s, { type: "finding.add", severity: "high", title: "Missing authz", file: "api.ts", line: 12, detail: "x" }, 4);
  return toViewModel(s);
}

it("renders the live-reviewers pipeline strip from subagents, hidden when none", () => {
  (win as any).render(reviewVmWithPipeline());
  const pipe = win.document.getElementById("rev-pipeline") as any;
  expect(pipe.hidden).toBe(false);
  expect(pipe.querySelectorAll(".sub-card").length).toBe(2);
  (win as any).render(reviewVm()); // reviewVm() has no subagents
  expect((win.document.getElementById("rev-pipeline") as any).hidden).toBe(true);
});

it("emits the finding location as a button carrying path:line, and copying flips its label", () => {
  (win as any).render(reviewVmWithPipeline());
  const loc = win.document.querySelector("#findings .finding-loc") as any;
  expect(loc.tagName).toBe("BUTTON");
  expect(loc.getAttribute("data-loc")).toBe("api.ts:12");
  loc.click();
  expect(loc.textContent).toBe("copied");
});

it("omits the location button for a finding with no file", () => {
  (win as any).render(reviewVm()); // the "nit" low finding has no file
  const groups = [...win.document.querySelectorAll("#findings .sev-group")];
  const lowGroup = groups.find((g) => g.textContent!.includes("nit"))!;
  expect(lowGroup.querySelector(".finding-loc")).toBeNull();
});
```

* [ ] **Step 2: Run to verify they fail**

Run: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/findings-client.test.ts`
Expected: FAIL (no `#rev-pipeline`; `.finding-loc` is a `<span>`, not a `<button>`).

* [ ] **Step 3: Markup + CSS in `public/index.html`**

In `#findings-view`, insert a `#rev-pipeline` container between `.rev-head` and `#findings`:

```html
    <div id="findings-view" hidden>
      <div class="rev-head">
        <span id="rev-target" class="rev-target"></span>
        <span id="rev-counts" class="rev-counts"></span>
      </div>
      <div id="rev-pipeline" hidden></div>
      <div id="findings"></div>
    </div>
```

Replace the existing `.finding-loc` rule (currently `.finding-loc { font-size: 12px; opacity: .6; }`) and add the pipeline CSS:

```css
  .finding-loc { font-size: 12px; opacity: .6; background: none; border: 0; padding: 0; margin: 0; color: inherit; font: inherit; cursor: pointer; }
  .finding-loc:hover { opacity: .9; text-decoration: underline; }
  #rev-pipeline { margin-bottom: 12px; }
  .rev-pipe-label { font-size: 11px; text-transform: uppercase; letter-spacing: .04em; opacity: .5; margin-bottom: 6px; }
```

* [ ] **Step 4: Implement `renderFindings` + `copyLoc` + the click branch in `public/client.js`**

Replace the body of `renderFindings(v)` with (adds the pipeline strip; emits the location as a button):

```js
function renderFindings(v) {
  setText("rev-target", v.reviewTarget || "Review");
  const total = v.findingGroups.reduce((n, g) => n + g.items.length, 0);
  setText("rev-counts", total === 1 ? "1 finding" : `${total} findings`);
  const pipe = document.getElementById("rev-pipeline");
  if (pipe) {
    const subs = v.subagents || [];
    if (subs.length) {
      pipe.hidden = false;
      pipe.innerHTML = `<div class="rev-pipe-label">Live reviewers</div>` + subs.map((a) =>
        `<div class="sub-card"><div class="av">${initials(a.name)}</div>
          <div style="flex:1"><div class="nm">${esc(a.name)}</div><div class="meta">${esc(a.role ?? "")}</div></div>
          <span class="tagidle">${esc(a.status)}</span></div>`).join("");
    } else { pipe.hidden = true; pipe.innerHTML = ""; }
  }
  setHtml("findings", v.findingGroups.map((g) =>
    `<div class="sev-group sev-${esc(g.severity)}">
       <div class="sev-label">${esc(SEV_LABEL[g.severity] || g.severity)} (${g.items.length})</div>
       ${g.items.map((f) => {
         const loc = f.file ? esc(f.file) + (f.line != null ? ":" + esc(String(f.line)) : "") : "";
         return `<div class="finding">
            <div class="finding-top">
              <span class="finding-title">${esc(f.title)}</span>
              ${f.file ? `<button type="button" class="finding-loc" data-loc="${loc}" title="Copy location">${loc}</button>` : ""}
            </div>
            ${f.detail ? `<div class="finding-detail">${esc(f.detail)}</div>` : ""}
          </div>`;
       }).join("")}
     </div>`).join("")
    || `<div class="meta">No findings.</div>`);
}
```

Add the `copyLoc` helper near the other top-level client helpers (for example just above `function renderFindings`):

```js
function copyLoc(btn) {
  const text = btn.dataset.loc;
  try { if (navigator.clipboard) navigator.clipboard.writeText(text); } catch { /* clipboard unavailable */ }
  btn.textContent = "copied";
  setTimeout(() => { btn.textContent = text; }, 1200);
}
```

In the document click listener, add the copy branch immediately after the existing `#decision-flow [data-choice]` (`fchoice`) branch:

```js
  const loc = e.target.closest(".finding-loc[data-loc]");
  if (loc) { copyLoc(loc); return; }
```

* [ ] **Step 5: Run the focused test, then tsc + node --check**

Run: `npx vitest run tests/findings-client.test.ts && npx tsc --noEmit && node --check public/client.js`
Expected: the new tests PASS; tsc clean; client.js syntax OK.

* [ ] **Step 6: Run the whole suite**

Run: `npx vitest run`
Expected: ALL green (no other suite depends on `.finding-loc` being a span; if one does, update it to the button).

* [ ] **Step 7: Commit**

```bash
git add rpi-cockpit/public/index.html rpi-cockpit/public/client.js rpi-cockpit/tests/findings-client.test.ts
git commit -m "feat(cockpit): findings panel shows the reviewer pipeline + copyable file:line"
```

---

### Task 2: Agent contract for reviewer progress and narrative reviewers

**Files:**
* Modify: `rpi-cockpit/agents/cockpit-instructions.md` (the reviews/audits section)

**Interfaces:**
* Consumes: nothing in code; this is the narration contract every agent reads.

* [ ] **Step 1: Edit the contract**

In `rpi-cockpit/agents/cockpit-instructions.md`, under the reviews/audits section (the one describing `review_start` and `add_finding`), add these two bullets:

```markdown
* If your review runs a pipeline of subagents (profile, assess, verify, report), call `subagent_start(name, role)` / `subagent_stop(name, result)` for each: the findings panel shows them as a live "reviewers" strip above the findings, so the user sees progress during a long scan instead of an empty panel.
* If your review is narrative rather than a list of graded findings (for example a PR walkthrough of design forks and architectural shape), render it with `show_screen(html, title)` as rendered markdown; reserve `review_start` + `add_finding` and the findings panel for severity-graded findings.
```

* [ ] **Step 2: Lint from the repo root**

Run: `cd "/Volumes/Main External/Development/hve-core" && npx markdownlint-cli2 "rpi-cockpit/agents/cockpit-instructions.md"`
Expected: `Summary: 0 error(s)`. (Fix with `--fix` if needed, then re-run.)

* [ ] **Step 3: Commit**

```bash
git add rpi-cockpit/agents/cockpit-instructions.md
git commit -m "docs(cockpit): contract for reviewer pipeline progress and narrative reviewers"
```

---

## Final verification (after Task 2)

* [ ] `cd rpi-cockpit && npx tsc --noEmit && npx vitest run` fully green; `node --check public/client.js` OK.
* [ ] `npm run build`, then verify live in the Preview pane: drive a producer that calls `review_start`, a couple of `subagent_start` calls, and several `add_finding` calls across severities; confirm the "Live reviewers" strip renders above the findings and a `file:line` button copies on click.
* [ ] Push to `fork` (PR #1).

## Self-Review

**Spec coverage:** orchestrator pipeline progress via reused subagents (Task 1, strip) — covered. file:line copy affordance (Task 1, button + copyLoc) — covered. PR Walkthrough / narrative contract (Task 2) — covered. The orchestrator-progress contract line (Task 2) — covered. No state/tool change, matching the spec's "no new MCP tools" constraint.

**Placeholder scan:** no TBD/TODO; every code step shows complete code. The one judgment note (a sibling suite that might assert `.finding-loc` is a span) is guarded by Step 6 running the whole suite.

**Type consistency:** `v.subagents` shape (`name`/`status`/`role?`) matches the view-model and the `.sub-card` reuse. `data-loc`/`copyLoc`/`finding-loc` names are identical across the markup, the renderer, the helper, the click branch, and the tests.
