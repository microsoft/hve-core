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

## Team orchestration (an orchestrator running subagents)

* `team_start(task, orchestrator)` to open the team board.
* `add_agent(id, name, role?, status)` (status queued|running|blocked|done|failed), `update_agent(id, status?, action?)` as each subagent progresses, and `remove_agent(id)` when one leaves.
* The user's pause, swap, and spawn interventions arrive as directives: call `check_directives()` and act on them. The cockpit expresses intent only and never controls agents directly.

## Codebase navigation (research and large edits)

* `codemap_set(nodes[])` with the slice of files relevant to the task (each node has id, path, kind file|dir, and an optional group). This opens the spatial codebase map.
* `codemap_focus(id)` as you move to a file, and `codemap_touch(id, kind)` to mark a node read or edit (your trail through the code).

## When the tools are not available

Do not call them. The user's steering is still readable from disk: notes and approach picks are appended to `<state-dir>/directives.jsonl` and answered decisions to `<state-dir>/decisions.jsonl`, one JSON object per line. The `<state-dir>` is printed on startup (`rpi-cockpit: state dir <state-dir>`).
