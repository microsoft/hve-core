---
description: "How to read the rpi-tracking-audit report, the task state vocabulary, and the answer shape for each question type."
---

# RPI Tracking Audit Report Template

In chat, send the task state (or the lead) and the first actions first, then offer the remaining sections by name; keep tables to three or four columns. Use the full structure when the user asks for a report or a document. Cite finding IDs (F1, F2, …) and rule IDs (PL1, RV4, …) wherever a statement rests on the audit, and artifact paths with section names or marker IDs wherever it rests on the tracking files. Finding numbers are assigned per run; rule IDs are stable.

## What the report looks like

```markdown
# HVE Core RPI tracking audit

| Item                                           | Value                                                                                                               |
|------------------------------------------------|---------------------------------------------------------------------------------------------------------------------|
| Workspace                                      | /path/to/repo                                                                                                       |
| Tracking folder                                | .copilot-tracking                                                                                                   |
| RPI artifacts (current format)                 | 6 (1 research, 2 plan, 1 plan critique, 1 changes record, 1 review record) in 3 tasks                               |
| Legacy artifacts (retired Task Planner format) | 7 in 2 tasks                                                                                                        |
| Reference date (--as-of)                       | 2026-11-02                                                                                                          |
| HVE Core conventions                           | the RPI phase skill templates and the `rpi` skill State contract of the hve-core release that ships this skill; ... |
| Other tracking areas (not audited)             | security-plans (1)                                                                                                  |
| Session state files                            | 2 files                                                                                                             |
| Symbolic links skipped                         | none                                                                                                                |
| Rules not evaluated                            | TK6 (--stale-days 0)                                                                                                |
| Not visible to this audit                      | whether a person approved a plan or decided a finding, ...                                                          |
| Tool                                           | rpi_tracking_audit 0.0.0                                                                                            |

## Summary
42 findings: 3 high, 17 medium, 17 low, 5 info. 4 artifacts need attention plus 2 workspace-level items. 3 tasks on the board, 2 legacy tasks.
## Task board
| Task | State | Phase reached | Plan | Readiness | Execution | Review exec / assessed outcome | Final outcome | Open decisions | Blockers | Undecided RV | Last change |
### Next action per task
- **report-export**: /rpi-implement plan=.copilot-tracking/plans/2026-10-20/report-export-plan.md task=P01-T02
### Legacy tasks (retired Task Planner format, not audited)
## Artifacts needing attention
| Task | Artifact | High | Medium | Findings |
## Findings
### High (3) ... ### Medium ... ### Low ... ### Info
| # | Rule | Task | Artifact | Finding |
## Remediation plan
### Secrets / ### Plan markers and headings / ### Completion evidence / ### Cross-artifact links / ### Decisions and gates / ### Session state / ### Template completion / ### Folder layout
- **PL6 Task checked without a changes-record entry**, 1 medium on 1 artifact. Why: ... Verify: ... Fix: ... Refs: F14.
## Inventory
### <task slug>  (artifact table; plan marker table with Depends on; review finding table with destinations and decision)
### <slug> (legacy) / ### Files in RPI areas not matching the naming convention / ### Session state files / ### Other tracking areas / ### Nested tracking folders
## Method and limits
```

How to read it:

* The state is derived in a fixed order and uses these words: `researching`, `researched`, `researched, no handoff` (Planning Readiness `Not applicable`), `planning`, `planning, critique in progress`, `planned`, `implementing`, `blocked in implementation`, `implemented, not reviewed`, `implemented, review skipped` and `completed, review skipped` (a joined state file records the session's `Review step` decision as `skip`, with task `status` `completed` for the second), `review in progress`, `reviewed, evidence missing`, `reviewed, findings open` (a finding is undecided, or the assessed outcome is Defects found, Residual work, or Not accepted), `reviewed, decision pending` (execution Complete with the final outcome still pending), `review complete` (execution Complete with a final outcome recorded and the conditions for accepted not met: the final outcome is not Conformant, or a Critical or High finding is deferred or skipped), `review partial`, `review blocked`, `review incomplete` (execution not recorded), `accepted`, `unknown`, `session only` (a session state file names the task and no artifact exists yet, as for a new child loop), `not derived` (a single-file run, which reads one artifact and cannot place the task).
* The `accepted` state requires all of: the plan and changes record exist, every plan task is checked, the latest review covers the full task (its `Review scope` names no `Pxx` or `Pxx-Txx`), its execution is Complete, its Parent Decision Record records a final outcome of Conformant or Conformant with justified divergence, and no Critical or High finding is undecided, deferred, or skipped. A later review of a bounded scope therefore takes the task out of `accepted`.
* The review column shows the Executive Summary's execution and assessed outcome, which is the reviewer's proposal; `started` means the review is still being written. The final outcome column is Current Disposition. Quote both and keep them apart.
* The next action is the command the artifacts' own fields imply, prefixed with a repair note when the task's artifacts carry high findings and suffixed when a blocker is recorded. When a session state file is joined to the task, the next action follows the `rpi` contract: `/rpi task=<slug>` leads for an automatic session, a completed task, a Follow-up phase, or a session with child tasks, with the phase command shown as what the artifacts alone imply; a manual session keeps the phase command and adds `/rpi task=<slug>`; a session blocker is named before the command and after any repair note. A rejected review finding, or one whose final destination is `none`, does not route. A finding whose row records a walkthrough Skip asks for a route to be chosen, because the Skip declined the proposed one. A deferred finding produces a request to gather the evidence its decision event names before any route runs. The next action is a suggestion to confirm, not something the audit ran.
* A session state file is joined to the task of the first artifact its `artifact_paths` names, read as review, changes, critique, then plan, and otherwise to the task its `task_slug` names. It also reaches the tasks whose plans, critiques, changes records, or reviews its `documents` list. Reused research joins nothing, and a task's own state file always governs it.
* Superseded critiques and reviews keep their findings at info severity with a "superseded by" note, except HY1.
* The JSON report carries `schema_version` (1), a `summary` with all four severities, the board rows with a `session` object where a state file is joined, `unreadable_folders`, and `invalid_state_files`. Line numbers in finding text count from 1; a `line` or `enclosing_line` field inside an artifact's `model` is a zero-based index.
* Any value matching a credential pattern is replaced with `[redacted ...]` before parsing, so every derived field, state value, and both report formats carry the placeholder. Detection covers common token shapes only. Do not look a redacted value up in the source file to quote it. Quoted artifact text is escaped for Markdown: a code span that quotes an element or a link carries an invisible zero-width space after `<` and between `](`, so retype such a value instead of copying it; plan markers are not affected.
* A task-filtered run (`--task`) keeps that task plus workspace-level items, such as the `.gitignore` check, nested folders, and other areas, and drops the other tasks' artifacts, state files, and findings. The state file of a session that reaches the task through its `documents` is kept with its findings, because the task's next action is read from it. Check the header and inventory before handing it over.
* The brief report (`--brief`) has the header without the inventory rows, the summary, a four-column board, the attention table, high and medium findings in three columns, one line per low or info rule without finding IDs, and a one-line remediation plan per rule. Ask for the full report or the JSON before detailing a low or info finding.
* A single-file report (`--file`) makes paths relative to the parent of the nearest `.copilot-tracking` ancestor and lists every cross-artifact rule as not evaluated. One file cannot place a task, so the board's state reads `not derived` and the next action is to run the audit on the workspace. A file whose name follows the retired Task Planner layout is refused with a pointer to the workspace run; a retired-format research or changes file at a current path is listed as legacy and flagged LY9, not audited.
* A table ending "... and N more" is truncated; ask for `--max-rows` or the JSON before detailing that rule.

## Task status

1. State in one sentence: the task, its state from the board, the phase reached, and the plan progress, citing the artifact paths.
2. What the artifacts say: research readiness and disposition; plan readiness, critique verdict, open decisions; changes execution status, declared scope, blockers, remaining markers; review execution, assessed outcome, final outcome, review scope, undecided findings, and their proposed and final destinations.
3. Integrity: high and medium findings on this task's artifacts with consequence and fix. If none, say the audit found no high or medium findings on N artifacts and name the rules not evaluated.
4. Next action: the command with arguments spelled out and the file the phase writes, plus what to open first.
5. To confirm: what only the user knows.

## Resume brief

1. The command with `plan=`, `task=`, `research=`, or `changes=` arguments as workspace-relative paths.
2. The artifact the phase reads first and the IDs to look at.
3. The artifact it writes.
4. Whether to start a fresh chat (a new task, a changed lifecycle concept, or visibly degraded behavior).
5. The blockers, open decisions, or undecided findings the phase will stop on.
6. One line on anything to repair first (high findings on the plan, a stale marker, a missing critique result).

## Handover

1. A board of tasks with state, plan progress, blockers, and next action.
2. Per task: the confirmed decisions, the open decisions (Planning Decisions and Feedback rows, undecided RV findings, a pending final outcome), the blockers, the follow-up items, and the artifact paths in phase order.
3. Legacy tasks with their checklist progress and the re-plan option.
4. The integrity findings to repair before continuing.
5. What the handover cannot carry: chat context; the RPI session's mode and participation preferences unless a state file records them; who approved what; anything outside the tracking folder.
6. The fresh-chat advice and the first command for each task.

## Integrity audit

1. Lead: two or three sentences on how many tasks and artifacts the folder holds, the leading theme, and whether any artifact cannot be navigated or exposes a secret. Then the **first five actions**, ordered high to low, each with finding IDs and the file.
2. Scope and evidence: workspace, reference date, artifacts by kind, tasks, legacy tasks, other areas, state files, symbolic links skipped, nested folders, rules not evaluated with the reason, what is not visible.
3. The task board with next actions, and the legacy table.
4. Findings by theme, in the order of the report's remediation plan (secrets, plan markers and headings, completion evidence, cross-artifact links, decisions and gates, session state, template completion, folder layout), built around tasks and artifacts, then rolled up per rule.
5. A remediation plan by control. Name the RPI step that repairs each where one exists: `/rpi-plan task=<slug>` to revise a plan or record a missing critique result, and `/rpi-review` to decide findings. Stale markers (CH2, PL5) and other marker or metadata edits are plain-text edits the user makes after confirming the changes entry.
6. Open questions: which tasks are still active, whether older dated files are superseded, whether two slugs are one session's later work or a renamed task, whether a nested folder was intentional, whether a state file belongs to a finished session.
7. Unverifiable items: human approval, chat history, host and model, validation execution, git tracking state.

## Review routing

1. Execution, assessed outcome, and final outcome as recorded, kept apart, and the review scope.
2. A table of `RV-xxx` findings with severity, proposed destination, final destination (or `-`), and decision (or undecided).
3. What each destination means in commands: `/rpi-implement plan=...` for defects, `/rpi-plan task=...` for decision gaps, `/rpi-research topic=...` for evidence gaps, a separate task for follow-ups.
4. The findings that must be decided before the final outcome can be recorded, and whether the assessed outcome is consistent with the decisions so far (RV6).
5. The next action.

## Artifact review

1. The artifact kind and the task it belongs to.
2. Whether a downstream phase can navigate it (markers, IDs, required sections).
3. The findings with rule IDs, consequence, and fix in severity order.
4. The cross-artifact rules that could not run and the workspace command that evaluates them.
5. The corrected fragment as a fenced Markdown block when the fix is a marker, heading, or metadata line.

## Readiness check

When asked whether a task is "done", "ready", or "clean": say what the artifacts record (execution status, assessed and final outcome, readiness, checked markers over total), what the audit evaluated (N of 73 rules on M artifacts, rules not evaluated and why), and what it found. Close with the record of acceptance that the Guardrails in `SKILL.md` name, not with a verdict.
