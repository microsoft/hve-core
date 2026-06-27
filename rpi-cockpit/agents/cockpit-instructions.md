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

## Guided document builders (PRD, BRD, ADR, security, RAI, accessibility plans)

* `interview_start(docType)` when you begin the guided interview.
* Ask each question with `ask_question(prompt)` (it blocks for the answer); render the growing draft with `show_screen(html, "…")`.

## Backlog orchestration (GitHub, ADO, Jira: discover, triage, sprint, execute)

* `backlog_start(target, columns[])` to open the board (target is the sprint, repo, or project; columns are the ordered state names).
* `add_item(id, title, column, kind?, tier?)` to add or update a work item, `move_item(id, column)` as it progresses, and `set_backlog_action(text)` to show the action you are taking (null clears it).

## Team orchestration (an orchestrator running subagents)

* `team_start(task, orchestrator)` to open the team board.
* `add_agent(id, name, role?, status)` (status queued|running|blocked|done|failed), `update_agent(id, status?, action?)` as each subagent progresses, and `remove_agent(id)` when one leaves.
* The user's pause, swap, and spawn interventions arrive as directives: call `check_directives()` and act on them. The cockpit expresses intent only and never controls agents directly.

## Codebase navigation (research and large edits)

* `codemap_set(nodes[])` with the slice of files relevant to the task (each node has id, path, kind file|dir, and an optional group). This opens the spatial codebase map.
* `codemap_focus(id)` as you move to a file, and `codemap_touch(id, kind)` to mark a node read or edit (your trail through the code).

## When the tools are not available

Do not call them. The user's steering is still readable from disk: notes and approach picks are appended to `<state-dir>/directives.jsonl` and answered decisions to `<state-dir>/decisions.jsonl`, one JSON object per line. The `<state-dir>` is printed on startup (`rpi-cockpit: state dir <state-dir>`).
