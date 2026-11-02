---
description: "The 73 rules the rpi-tracking-audit script evaluates on .copilot-tracking/, with severity, the control each belongs to, why it matters, what to verify, and the fix."
---

# RPI Tracking Audit Rule Catalog

The 73 rules `scripts/rpi_tracking_audit` evaluates on the RPI artifacts under `.copilot-tracking/`. Titles are the script's titles, so a report line can be matched here by rule ID or title. The rules approximate the conventions in the `copilot-tracking` instructions, the `rpi-*` skill templates and references, and the `rpi` skill's State contract. The RPI phase skills reconcile these files at each handoff, and the RPI Workflow canvas warns about content it cannot read in an open session; no hve-core script or lint checks the files against each other, and the folder is exempt from the repository's Markdown lint, so these rules are this skill's reading of those conventions.

Severity is a heuristic for ordering work, not a rating of the task: **high** means a downstream RPI phase cannot navigate the artifact, or a secret is exposed; **medium** means artifacts disagree in a way that misleads a resume or a review, or a gate is bypassed; **low** means convention or template completeness; **info** means a fact for the task board. Count artifacts and tasks, not findings, when stating scale.

The newest dated file of each kind is the task's current artifact; earlier plans, changes records, and research files are listed under TK5, and numbered critiques and reviews appear only in the inventory. A rule the run could not evaluate is listed in the report header as not evaluated, with the reason. Symbolic links are never followed and are listed in the header. A nested `.copilot-tracking` folder is listed and not read. Files in an RPI area whose names do not match the convention are listed under LY4 and not modeled. Files in the retired Task Planner format are listed under LY9 and not audited. Credential detection uses a handful of token shapes and assignment patterns; it will miss many real credentials, so a clean HY1 is not an assurance. Matched values are replaced before parsing, so no derived field, state value, or report carries them.

Each rule names its **control**, the heading the report's remediation plan groups it under.

## Folder layout (LY1 to LY5, LY9, TK6, HY2)

**LY1 Tracking folder not git-ignored.** No `.copilot-tracking/` line (also accepted: `/.copilot-tracking`, `.copilot-tracking/**`, `**/.copilot-tracking`) in the root `.gitignore`. Only these literal forms are recognized: a wildcard pattern that happens to cover the folder still reports LY1, and text after the pattern on the same line makes it a different pattern, as it does for git. Medium. *Why:* tracking files carry paths, decisions, and sometimes quoted text, and the install guide tells you to add the ignore line. *Verify:* the root `.gitignore`; the audit does not run `git` and cannot tell whether files are already tracked. *Fix:* add the line; if files were committed, remove them from the index.

**LY2 Tracking folder below the workspace root.** A `.copilot-tracking` folder in a subfolder (searched six levels deep). Medium. *Why:* the RPI skills resolve only the root folder, so nested artifacts are invisible to a resume. *Fix:* move the artifacts to the root folder and keep one.

**LY3 Artifact not directly under a YYYY-MM-DD folder of its area.** Low. *Why:* artifacts are addressed by `{area}/{date}/{slug}-{kind}.md`. *Fix:* move the file.

**LY4 File name does not match the area's convention.** A file in `plans/` not ending in `-plan.md`, in `changes/` not `-changes.md`, in `reviews/plans/` not `-plan-critique.md` or `-plan-critique-N.md`, in `reviews/logs/` not `-review.md` or `-review-N.md`, in `research/` not `-research.md`, in `challenges/` not `-challenge.md`, in `walkthroughs/` not `-decisions.md`. Low. The file is listed in the inventory and never appears as a task. Files that other hve-core workflows write into these areas (`research/*-research-topic.md`, `research/subagents/*-mcsb.md`, `plans/*-network-isa95-assessment.md`) are counted under other tracking areas, not reported here. A single-file run refuses a file that is named for one area and stored in another, and points to the workspace run. *Fix:* rename.

**LY5 Task slug is not lower-kebab-case or exceeds 60 characters.** Low. *Why:* the slug names every tracking file and appears in every command; `Bad_Task` and `bad-task` are two tasks to the skills, and the 60-character cap keeps paths within Windows path limits. *Fix:* rename the task's artifacts to one slug.

**LY9 Artifact in the retired Task Planner format.** A `{slug}-plan.instructions.md`, anything under `details/`, `plans/logs/`, `research/subagents/`, `reviews/{date}/`, or `reviews/rpi/`, or a research or changes file at a current path that lacks the current sections and carries legacy markers (`## Implementation Checklist`, `<!-- parallelizable`, references to `details/`) or belongs to a slug with legacy siblings. Info, one finding per task. *Fix:* re-plan with `/rpi-plan task=<slug> draft=<old plan path>`.

**TK6 Open task without a change for longer than the stale threshold.** The newest modification time across the task's artifacts is more than `--stale-days` (default 30) before the reference date, and the task is neither accepted nor completed with the Review step skipped. Info. *Verify:* modification times reset when a folder is copied. *Fix:* finish, hand over, or delete the task's artifacts.

**HY2 Non-Markdown file in an RPI area.** Info. JSON in these folders is usually session state, which the audit detects by shape; anything else is unexpected.

## Plan markers and headings (PL1 to PL4, PC1, RV1)

**PL1 Phase or task marker has no matching heading.** A `<!-- rpi:phase -->` or `<!-- rpi:task -->` marker whose next line is not an ID heading, a heading preceded by a marker with a different ID, a marker separated from its heading by a blank line, or a marker that shares its line with other text or is written with spaces around `=`. A marker quoted in inline code is an example and is not read. High. *Why:* `rpi-implement` navigates by marker; a mismatched marker makes the item unreachable by `task=` or attributes work to the wrong ID, and the RPI Workflow canvas reads a marker only when it fills the line directly above its heading, so it drops a phase or task whose marker is separated or malformed. *Fix:* one marker on the line directly above its heading, alone on that line, written `id=` with the same ID.

**PL2 Phase or task heading has no marker.** Medium. *Why:* readable, but `/rpi-implement` navigates a plan by its markers, and without one the item has only its heading to be found by. *Fix:* add the marker.

**PL3 Duplicate phase or task ID.** High. *Fix:* renumber and reconcile the artifacts that cite the ID.

**PL4 Task ID does not belong to its enclosing phase.** `P02-T01` under the `P01` heading. Medium. *Fix:* renumber or move.

**PC1 Critique finding marker and heading disagree or repeat. RV1 Review finding marker and heading disagree or repeat.** Medium. *Why:* the plan's Critique Disposition and the review's Decision History key on these IDs. *Fix:* one marker and heading per finding.

## Completion evidence (PL5, PL6, CH2, CH4, CH5, CH9, CH10)

**PL5 Phase checked while one of its tasks is unchecked.** Medium. *Why:* a resume treats a checked phase as done and skips the task. *Fix:* uncheck the phase or finish the task.

**PL6 Task checked without a changes-record entry.** No changes record exists, or none of its Completed Work entries or Completed scope markers names the task. Medium. *Why:* completion is the checked marker plus the changes record. *Fix:* add the entry or uncheck.

**CH2 Changes record completes a task whose plan marker is unchecked.** Medium. *Why:* the plan is stale; the next `rpi-implement` resumes from the first unchecked item and may redo finished work. *Fix:* check the marker in the plan after confirming the entry.

**CH4 Status Complete for the full plan while plan markers remain unchecked.** Medium. *Fix:* correct the status and scope.

**CH5 Completed-work entry without a validation line.** Low. *Fix:* add `* Validation:`.

**CH9 Review readiness ready while blockers or remaining work are listed.** A readiness line that is negated or conditional (`not ready`, `nearly ready`, `ready once CI passes`, `Ready - waiting for approval`) is read as not ready. Low. *Fix:* set not ready with the reason, or clear the lists.

**CH10 Validation failed or unavailable.** Info. Carried into review as a limitation.

## Cross-artifact links (PL14, PL17, PC3, CH1, CH6, RV5, TK1 to TK5)

**PL14 Critique recorded in the plan but no critique file found.** Medium. *Fix:* restore the file, fix the path, or record `skipped` with provenance.

**PL17 Task slug in the plan differs from the file name.** Low. *Fix:* align.

**PC3 Critique points at a plan file that does not exist; CH6 Changes record points at a plan file that does not exist; RV5 Review points at a plan or changes file that does not exist.** The critique's `Plan:`, the changes record's `Related plan:`, or the review's `Plan:` and `Changes:` resolve to nothing. Medium. *Verify:* link destinations resolve relative to the artifact file; plain paths are workspace-relative. *Fix:* correct the path.

**CH1 Changes record names a task the plan does not define.** Medium. *Fix:* correct the ID, or add the task as an implementation-time plan update.

**TK1 Changes record without a plan. TK2 Review without a changes record. TK3 Critique without a plan.** Medium. *Fix:* restore the missing artifact or record where it lives.

**TK4 Task ID differs across the task's artifacts.** The newest plan, critique, changes record, and review of one slug record different Task IDs. Medium. *Fix:* align the Metadata of each file. The audit does not report two slugs that share one Task ID: that is usually later work in one RPI session, named for the work by design; see Troubleshooting in SKILL.md.

**TK5 Several artifacts of one kind for one slug.** Info. Findings on an older critique or review that a numbered file supersedes are downgraded to info with a "superseded by" note, except HY1. *Fix:* confirm which is current.

## Decisions and gates (PL12, PL13, PL15, PL16, PL18, PL19, PC2, PC6, CH7, CH8, RV2, RV4, RV6 to RV8, RS1, RS4, TK10)

**PL15 Planning Readiness is Ready without a critique result or an explicit skip.** Planning Readiness is Ready, no `Pass`, `Revise`, or `Blocked` verdict appears in Critique Disposition or the Latest critique row (read as a word, never out of a file name), and no skip is recorded; typical statuses are `started`, `not run`, `not produced`, or a `Complete` critique whose verdict is `unavailable`. Medium. *Fix:* run `/rpi-plan task=<slug>` so the planner runs the critique and records its result, or `/rpi-plan task=<slug> critique=skip` to record a skip with its provenance.

**PL18 Critique finding without a disposition in the plan.** A `PC-xxx` in the latest finished critique has no Critique Disposition row. Medium. A critique still `started` is skipped, because its finding set is not complete.

**PL12 Requirement not cited by any task. PL13 Task cites a requirement the plan does not define.** Low. A requirement cited from another document, such as `PRD-2026-004 FR-012 (docs/prd.md)`, is not a plan requirement and is not counted; the document ID may be linked, lower-case, or followed by a colon, and may cite several requirements. PL13 is not reported for a plan that defines no requirements.

**PL16 Open planning decision.** A Planning Decisions and Feedback row with status proposed, unresolved, or input requested, which blocks the tasks it names and comes before `/rpi-implement` in the next action. `needs input` counts as open too. A deferred row is listed and does not block: a deferral is a recorded choice not to decide now. The first status word that is not negated counts, so `resolved (was proposed)` is resolved. Info.

**PL19 Plan marked Not ready or Blocked.** Info, with the blocker text.

**PC2 Critique verdict missing or outside Pass, Revise, Blocked, unavailable.** Medium. Not reported while execution is `started`. *Fix:* record one value; `unavailable` when no assessment was produced, never Pass.

**PC6 Critique started and not finished.** Execution is still `started`. Info. *Why:* the record is written before the first lens runs and leaves `started` only when complete. *Fix:* let the running critique finish, or rerun it through `/rpi-plan`.

**CH7 Business Alignment entry pending a decision.** Medium. **CH8 Changes record reports a blocker.** A bullet that reads `None`, `Not applicable`, `N/A`, `Nothing yet`, `No open blockers`, `No release blockers`, or `None - all cleared in P02` records nothing; `None, apart from the failing test`, `None - all resolved; no access to prod yet`, and `No access to the staging database` are blockers. Info.

**RV2 Review finding without a proposed destination.** Not reported while the review is `started`. Medium. **RV4 Review finding with no decision event.** No `RD-xxx` row decides the `RV-xxx`: a row decides when its status reads accepted, rejected, deferred, skipped, changed, or resolved; a status that starts with `pending` or `proposed`, or negates the word (`not resolved`, `no change yet`), records the item and is not a decision. When a status carries two of the words, the one that leaves the finding open decides (`accepted, but deferred to the next release` is deferred), unless it describes an earlier state (`accepted (was deferred in RD-001)` is accepted); not reported while the review is `started`. Medium.

**RV6 Conformant outcome while a Critical or High finding is undecided, deferred, or skipped.** The assessed outcome or the recorded final outcome is Conformant. Medium. A rejected finding is closed and does not block `accepted`. A Skip rejects the proposed route and keeps the finding: it is read from a status that says skip (`Skip`, `skipped`, `rejected; user chose Skip`), or from a rejected row whose later cell is `skipped` or names the skip beside the walkthrough or the route, reported as `rejected (skipped)`. A Skip recorded only as `rejected`, with nothing else in the row, cannot be told apart from a rejected finding and reads as closed.

**RV7 Final outcome pending in the Parent Decision Record.** Review execution is Complete and Current Disposition records no final outcome, or `pending`. The outcome is final only when the value starts with it: `Awaiting parent decision (assessed: Conformant)` quotes the reviewer's proposal and reads as pending, as does a value marked proposed, provisional, tentative, conditional (`Conformant if RV-002 is fixed`), rejected, or not yet decided. Quotation marks, emphasis, and a `Final:` label before the outcome are ignored. Info.

**RV8 Review started and not finished.** The Review Record's execution is `started` and the Executive Summary records no execution yet. Info. *Fix:* let the review finish, or resume it with `/rpi-review`.

**RS1 Planning Readiness missing or outside Ready, Not ready, Not applicable, Blocked.** Low. **RS4 Research not ready for planning.** Info.

**TK10 Research exists but planning has not started.** Info for the board.

## Session state (TK7 to TK9, TK11 to TK14)

**TK7 Session state points at an artifact that does not exist.** An `artifact_paths` value, or a `documents` entry other than the current one, names a missing file. Medium. A critique or review path that is missing and not yet in `documents` is skipped, because the session records it before the record is first written. A path that leaves the workspace or passes through a symbolic link counts as missing and is never probed. *Why:* the RPI session reconciles these paths on recovery; a missing file is a recovery blocker. *Fix:* correct or restore.

**TK8 Session state phase disagrees with the artifacts.** `next_action.phase` (or `active_phase`) is Implement, Review, or Follow-up and the task has no plan, no changes record for Review and Follow-up, or no recognized artifacts at all. Medium. A state file joins its task through the artifacts `artifact_paths` names, then through `task_slug`. *Fix:* reconcile before resuming; the artifacts are canonical.

**TK9 Session state marks the task completed while plan markers remain unchecked.** Low. Not reported when the latest review's execution is Complete, because the contract sets `completed` at that point and the review routes the remaining work.

**TK11 Session state file outside its session folder.** The file is not at `.copilot-tracking/rpi-sessions/{YYYY-MM-DD}/{session}/{task_slug}-state.json`. Low. *Why:* the RPI session matches state in session folders and moves a state file it finds elsewhere on the next resume. *Fix:* let `/rpi` move it on the next resume, or move it yourself.

**TK12 Parent or child state link is broken.** A `parent_task.state_path` names a missing file, the parent does not list this state in `child_tasks`, or a listed child's state names a different parent. Paths are compared after normalization, so `./` and backslashes do not matter, and a link whose `state_path` is null or empty matches by `task_id`, or by `task_slug` when the ID is null too. Medium. A listed child without a state file is not reported, because the session records the child before creating it. *Fix:* correct the `state_path`, or restore the linked file.

**TK13 Current artifact path missing from the documents list.** An `artifact_paths` value is not in the same kind's `documents` list. Low. Skipped for a critique or review the session is still writing: one whose file is missing or whose execution is `started`. *Fix:* append the path.

**TK14 Session state file cannot be read as state.** A `*-state.json` file under `rpi-sessions/` is not valid JSON, is not a JSON object, lacks `task_slug`, `active_phase`, or `artifact_paths`, is nested deeper than 64 levels, holds `NaN`, `Infinity`, or a number too large to represent, is larger than 5 MB, or cannot be read. The file name is matched without regard to letter case. Medium. *Why:* `/rpi` and the RPI Workflow canvas look for state in the session folder, and a failed state write is a recovery blocker. *Fix:* restore the file from the artifacts it should point at, or remove it and let `/rpi` rebuild the state on the next resume.

## Template completion (PL7 to PL11, PC4, PC5, CH3, RV3, RS2, RS3, LY6 to LY8, LY10)

**LY10 Empty, unreadable, or unrecognized artifact.** The file is empty, cannot be read (the detail gives the error), or carries none of its kind's sections. Medium, reported once instead of one PL10 per section, and the file is excluded from the board.

**PL9 Unfilled template placeholder.** `{{...}}` left in the artifact. Medium in plans, critiques, changes records, and reviews; low in research, challenge, and walkthrough files. Not reported for a critique or review whose execution is `started`, which still carries its template's placeholders.

**PL7 Task block missing a labeled block.** Goals, Requirements, Details, References, or Dependencies. **PL8 Phase block missing Goals, Dependencies, or Changes in the map.** Low. A phase's blocks and its `Changes in the map:` line are read up to its first task heading. A phase that holds its own Mermaid diagram or a `Highlighted work` line needs no `Changes in the map:` line.

**PL10 Required section missing.** Plan: Task Metadata, Executive Summary, Phase Checklist, User Decisions and Requirements, Planning Readiness and Next Step, Critique Disposition, Artifact Self-Check, Follow-Up Items, Handoff. Changes record: Metadata, Execution Status, Completed Work, Validation Record, Return-to-Caller State. Review record: Executive Summary, Findings and Proposed Routes, Parent Decision Record, Review Record. Research: Executive Summary, Findings, Planning Readiness and Next Step, Research Record. Critique: Metadata, Verdict, Findings, Recommended Next Action. Low.

**PL11 Follow-Up Items not immediately before Handoff.** Low.

**PC4 Follow-up critique without Earlier Finding Reconciliation.** A numbered critique file, or a Critique type that starts with `follow-up`. Low. **PC5 Critique execution missing or outside started, Complete, Partial, Blocked, Not produced.** Low. **CH3 Execution status missing or outside Complete, Partial, Blocked.** Low. **RV3 Review execution or assessed outcome missing or outside the vocabulary.** Low; not reported while the review is `started`. **RS3 Research disposition missing or outside executed, reused, satisfied-and-skipped.** Low.

**RS2 Evidence ID cited but not defined in the Evidence Log.** Low. Citations are read from `* Evidence:` lines and from table cells that hold only evidence IDs, so prose such as "the C4 model" is not read as a citation. Not reported when the Evidence Log defines no IDs.

**LY6 Generated artifact does not start with the markdownlint disable comment.** Info. **LY7 Line-number reference in a tracking artifact.** `path.py:42`, `#L12`, or "line 12" outside code spans. Low. **LY8 #file: directive in a tracking artifact.** Low. Artifacts written from a host that does not apply instruction files automatically may miss these conventions; confirm the host before treating them as drift.

## Secrets (HY1)

**HY1 Possible credential in a tracking artifact.** An AWS access key, GitHub token, private key block, Slack token, JSON web token, bearer token, Azure storage account key, shared access signature, a token or password assignment (quoted, unquoted with letters and digits, or JSON), a password in a connection string, keyword list, or `password:` line, or a URL with an embedded password or token, in an RPI artifact, a legacy artifact, or a session state file. One finding per line that holds such a value, up to five lines per file, with the remaining lines counted in one more finding. High. *Why:* tracking files are pasted into chats and reports. *Verify:* the line named in the finding; the pattern is a heuristic. The value is replaced with `[redacted ...]` before any field is parsed, a state value under a credential-like key (`accessToken`, `client_secret`, `dbPassword`, and the like) is replaced whole, and the JSON report carries only the State contract's fields; the artifact itself is unchanged. *Fix:* remove the value and rotate it if it is real.

## Not covered

Whether the change map is current, whether a `Guidance:` block should exist, whether validation actually ran, whether a decision recorded as the user's was in fact theirs, whether the RPI session honored a `before-implementation` boundary, whether an artifact's first heading names its kind as the RPI Workflow canvas expects (`# RPI Plan:`, `# RPI Plan Critique:`, `# Task Research:`, `# RPI Changes:`, `# Review:`), the contents of nested tracking folders, and anything in the planner, reviewer, coach, and builder areas outside RPI.
