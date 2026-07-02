# Cockpit instrumentation

When the `rpi-cockpit` MCP tools are available, narrate your work to the cockpit by calling them. Pick the surface that matches what you are doing: the cockpit renders one view per kind of work, so a reviewer drives the findings panel, a backlog manager drives the kanban, an orchestrator drives the team board, and so on. These calls are informational and non-blocking unless noted. When the tools are not available, do nothing extra (the user's steering is still readable from disk, see the end).

## Always, in any workflow

* At the start of a coding session or build, call `session_begin(task, host)`.
* Call `set_context(instructions, skills, collection)` to show which coding standards, skills, and collection are active for this work. Pass everything currently active; omitting a field clears that group.
* At each major step, and before any decision, call `check_directives()`. It returns immediately with any notes or picks the user queued in the cockpit (or "no pending directives"). You MUST read and act on them.
* To let the user choose what to do, call `present_workflows()` (a native choice card in the chat), or `open_navigator()` to pop the in-cockpit workflow picker (for example on a `/Nav` request).
* To show the user's app under development beside the cockpit, call `set_app_frame(url)` with a loopback http(s) URL (localhost, 127.0.0.1, or [::1]); non-loopback URLs are rejected. Pass null to clear it.

## Asking the user (any workflow, these BLOCK)

* `present_options(prompt, options[])` for a bounded choice: it blocks until the user picks (in the cockpit or the native card) and returns the chosen `id`. Act on the returned id.
* `ask_question(prompt)` for a free-text answer: it blocks until the user answers and returns the text.
* The cockpit shows your questions and decisions as a navigable flow. If `check_directives()` returns a note like `revise decision "…" (id X)`, the user wants to change an earlier answer: re-ask that decision by calling the same tool with `id: "X"`, then reconsider the questions that follow, since the new answer may change them.

## RPI build loop (research, plan, implement, review, discover)

* `phase_enter(phase)` on entering each phase (research|plan|implement|review|discover).
* `subagent_start(name, role)` before a subagent and `subagent_stop(name, result)` after.
* `artifact_update(path, summary)` after writing a tracking file.
* `validate(check, status)` on each validation check (status ok|running|fail|pending).
* `offer_approaches(label, options[])` to populate the cockpit's Steer select with the real choices for the next phase (non-blocking).
* `show_screen(html, title?)` and `clear_screen()` for arbitrary static HTML (a mockup, a diff, rendered markdown, a diagram) in a sandboxed pane.

## Reviews and audits (code review, PR review, security, accessibility, RAI)

* `review_start(target)` when you begin a review (target is the branch, PR, or scope).
* `add_finding(severity, title, file?, line?, detail?)` per finding (severity critical|high|medium|low|info). The cockpit groups findings by severity with file links.
* If your review runs a pipeline of subagents (profile, assess, verify, report), call `subagent_start(name, role)` / `subagent_stop(name, result)` for each: the findings panel shows them as a live "reviewers" strip above the findings, so the user sees progress during a long scan instead of an empty panel.
* If your review is narrative rather than a list of graded findings (for example a PR walkthrough of design forks and architectural shape), render it with `show_screen(html, title)` as rendered markdown; reserve `review_start` + `add_finding` and the findings panel for severity-graded findings.
* If `check_directives()` returns a note like `open <file>:<line> in the editor`, the user clicked a finding's open control: open that file (at the line, if given).

## Guided document builders (PRD, BRD, ADR, security, RAI, accessibility plans)

* `interview_start(docType)` when you begin the guided interview.
* Ask each question with `ask_question(prompt)` (it blocks for the answer); render the growing draft with `show_screen(html, "…")`.
* If your interview runs a multi-step program (a phase-gated planner like ADR Frame/Decide/Govern or a six-phase assessment, or a coach running a curriculum or
  method sequence), call `set_steps(steps, current, label?, progress?)` when you begin and again as you advance (a higher `current`): the interview view shows a
  progress stepper above the conversation so the user sees the whole roadmap and the current step. Re-declare `steps` if an adaptive program's path changes.
  Pass progress as { done, total } to show sub-progress on the active step (for example a comprehension check 2 of 3).

## Backlog orchestration (GitHub, ADO, Jira: discover, triage, sprint, execute)

* `backlog_start(target, columns[])` to open the board (target is the sprint, repo, or project; columns are the ordered state names).
* `add_item(id, title, column, kind?, tier?, parent?)` to add or update a work item, `move_item(id, column)` as it progresses, and `set_backlog_action(text)` to show the action you are taking (null clears it).
* Pass `parent` (a parent item's id) to nest the item: the board indents a child under its parent when both are in the same column and shows "↳ under {parent}" when they are not. A PRD-to-WIT planner proposing an Epic→Feature→Story→Task tree should pass `parent` and add the items to one planning column so the whole tree nests.

## Data science (dataset profiling, notebooks, dashboards)

* `dataset_profile(name, rows?, columns?, source?)` opens the data-profile table view; then call `add_column(name, dtype, nullPct?, distinct?, stat?, quality?)` once per field, with `quality` one of ok/warn/risk for a data-quality flag. Use this for a data dictionary or profile (the Data Spec agent).
* For a generated notebook or data spec document, render the preview with `show_screen(html, title)`.
* For a Streamlit (or other) dashboard you are running, call `set_app_frame(url)` with its loopback URL to embed the live app beside the cockpit; when testing it, pair `set_app_frame` with `review_start` + `add_finding` so the running app and its issues show together.
* For interview-driven dataset curation (the evaluation dataset creator), use the guided question flow (`ask_question`).

## Gallery (show several things at once)

* `gallery_open(title, items, size?)` opens a scrollable grid of scaled live thumbnails. Each item is one of a live `url` (a website or a loopback dev server, framed live) OR an inline `html` snapshot, plus a `label`, optional `group` (a section header), and optional `caption`. `url` must be a loopback http(s) URL or an external https URL. `size` is s/m/l (default m).
* `gallery_add(item)` adds or updates one tile by `id`; `gallery_clear()` empties the board.
* Use it to compare several running apps or sites side by side (`url` items), or several rendered states (`html` items). Clicking a tile expands it; external sites that block framing show blank, so an open-in-tab link is always offered.
* On a `/gallery` request from the user, open this view: call `gallery_open` with whatever they name (sites, running apps, rendered states), or the full HVE Core agent showcase (`rpi-cockpit/tools/agent-gallery.mjs`) when they do not specify.

## Prompt engineering (the prompt workbench)

* `promptlab_start(name, prompt?, round?)` opens the prompt workbench (a behavior test bench) and switches the cockpit to it. The Prompt Builder calls this when it begins hardening a prompt; pass the prompt's current text as `prompt` and the iteration round (default 1). Re-call with `round + 1` for a fresh pass.
* `add_case(id, scenario, output?, verdict?, note?)` adds or updates one test case. The Prompt Tester calls `add_case(id, scenario)` as it picks each scenario, then updates the same id with the literal output it produced, a verdict (pending/running/pass/warn/fail), and an optional note once it runs and the Prompt Evaluator judges.
* When the Prompt Evaluator's output is prompt-wide rather than per-case, it may still narrate severity findings via `review_start` + `add_finding`.

## Memory (the memory store)

* `memory_open(title?)` opens the Memory view and switches the cockpit to it; optionally name the collection. The Memory agent calls this when it activates.
* `add_memory(id, content, category, tag?, title?)` adds or updates one memory entry: a recalled or written fact, grouped by `category` (a memory type like user/feedback/project/reference, or a source). Tag it `recalled` (loaded into context), `added` (written this session), or `updated`; give an optional short `title`.
* `add_handoff(id, from, summary, action?)` records another agent handing state to Memory: `from` is the agent's name, `summary` is what was handed, `action` is stored/merged/recalled.
* The context badges (`set_context`) remain the active-standards strip and are orthogonal to this store.

## Agentic workflows (the flow canvas)

* `flow_open(title?)` opens the flow canvas (the gh-aw agentic-workflow pipeline as a node graph) and switches the cockpit to it. The GitHub Agentic Workflows agent calls this when it begins working a pipeline.
* `add_flow_node(id, kind, label, scope?, sub?, status?)` adds or updates one node. Use `kind: workflow` (scope orchestration, the default) for each workflow in the pipeline, and `kind` trigger/guard/agent/output/mcp with `scope` set to a workflow's node id for that workflow's anatomy. `status` (idle/running/passed/failed/skipped/stale) drives the live-run look; `sub` is a short subtitle.
* `add_flow_edge(id, from, to, scope?, label?, kind?, status?)` wires two nodes. Orchestration handoffs use `kind` label/event/output with the handoff `label` (for example a label name like `agent-ready`); anatomy steps use `kind: step`. Set `status: active` on the edge currently firing.
* Narrate a live run by re-calling `add_flow_node` / `add_flow_edge` with a new `status` as the pipeline fires, and `flow_focus(workflow)` to drill the pane into a workflow (or `flow_focus()` to return to the pipeline), for example to show where a run failed.
* This surface narrates and the user steers (via `check_directives`); it does not author or run workflows. The agent edits the `.md` and runs `gh aw compile` / `logs` / `audit` itself.

## Team orchestration (an orchestrator running subagents)

* `team_start(task, orchestrator)` to open the team board.
* `add_agent(id, name, role?, status)` (status queued|running|blocked|done|failed), `update_agent(id, status?, action?)` as each subagent progresses, and `remove_agent(id)` when one leaves.
* The user's pause, swap, and spawn interventions arrive as directives: call `check_directives()` and act on them. The cockpit expresses intent only and never controls agents directly.

## Codebase navigation (research and large edits)

* `codemap_set(nodes[])` with the slice of files relevant to the task (each node has id, path, kind file|dir, and an optional group). This opens the spatial codebase map.
* `codemap_focus(id)` as you move to a file, and `codemap_touch(id, kind)` to mark a node read or edit (your trail through the code).

## When the tools are not available

Do not call them. The user's steering is still readable from disk: notes and approach picks are appended to `<state-dir>/directives.jsonl` and answered decisions to `<state-dir>/decisions.jsonl`, one JSON object per line. The `<state-dir>` is printed on startup (`rpi-cockpit: state dir <state-dir>`).
