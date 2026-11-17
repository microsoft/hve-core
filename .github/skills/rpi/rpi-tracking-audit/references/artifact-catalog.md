---
description: "What the RPI skills write under .copilot-tracking/, how the files are named, which sections, identifiers, and status vocabularies each carries, and how a task is resumed from them."
---

# RPI Artifact Catalog

What the RPI skills write under `.copilot-tracking/` for a task that runs through Research, Plan, Implement, and Review, how the files are named, which sections and identifiers each one carries, and which status vocabularies the phases read. The source of truth is the `copilot-tracking` instructions, the templates and references of the `rpi-research`, `rpi-plan`, `rpi-plan-critique`, `rpi-implement`, `rpi-review`, `rpi-challenger`, and `rpi-walkthrough` skills, and the `rpi` skill's State contract in the same hve-core release as this skill. When a section name, field label, or vocabulary word matters and the user runs a different hve-core version, confirm it against that version's templates.

## Where the folder lives

`.copilot-tracking/` sits directly under the codebase root. It is usually git-ignored, so most search tools skip it; an empty search result is inconclusive until the folder is read directly. Durable working state lives in these files, not in chat: a resume reads the artifacts and their IDs.

Dates are ISO `YYYY-MM-DD` folders directly under the area. `{{task_slug}}` is lower-kebab-case, at most 60 characters, and names every tracking file of the task. A later request in a session names its documents for the work instead of the task, such as `task-board-polish`; the plan's critique, changes record, and review take the plan's name. Generated tracking Markdown starts with `<!-- markdownlint-disable-file -->`, uses no `#file:` directives and no line numbers, and navigates by stable IDs, markers, and headings.

## Areas and file names

| Area                             | File                                                                 | Written by           | Consumed by                                           |
|----------------------------------|----------------------------------------------------------------------|----------------------|-------------------------------------------------------|
| `research/{date}/`               | `{slug}-research.md`                                                 | `/rpi-research`      | `/rpi-plan`                                           |
| `plans/{date}/`                  | `{slug}-plan.md`                                                     | `/rpi-plan`          | `/rpi-plan-critique`, `/rpi-implement`, `/rpi-review` |
| `reviews/plans/{date}/`          | `{slug}-plan-critique.md`; follow-ups `-plan-critique-2.md`, `-3.md` | `/rpi-plan-critique` | `/rpi-plan` (disposition), `/rpi-review`              |
| `changes/{date}/`                | `{slug}-changes.md` (the changes record)                             | `/rpi-implement`     | `/rpi-review`, the next `/rpi-implement`              |
| `reviews/logs/{date}/`           | `{slug}-review.md`; new reviews `-review-2.md` (the review record)   | `/rpi-review`        | RPI session follow-up, the user                       |
| `challenges/{date}/`             | `{slug}-challenge.md`                                                | `/rpi-challenger`    | the user                                              |
| `walkthroughs/{date}/`           | `{slug}-decisions.md` (the decisions-and-changes ledger)             | `/rpi-walkthrough`   | the user, RPI follow-ons                              |
| `rpi-sessions/{date}/{session}/` | `{task_slug}-state.json` (one per task of the session)               | `/rpi`, RPI Agent    | RPI session recovery, the RPI Workflow canvas         |

Other folders (`security-plans`, `adr-plans`, `prd-sessions`, `dt`, `hve-builder`, `reviews/code-reviews`, and the rest) belong to other agents and skills. The audit lists them so the user knows they exist and does not apply its rules to them. Three file shapes that other hve-core workflows write inside the RPI areas are listed the same way and are not reported as misnamed or legacy: `research/{project-slug}-research-topic.md` (Design Thinking handoffs), `research/subagents/{date}/{component}-mcsb.md` (the `mcsb` skill), and `plans/{date}-network-isa95-assessment.md` (the Network ISA-95 Planner).

## Identity and markers

* One stable **task ID** across plan, critique, changes, and review (`* Task ID:` in each). `task_id` and `task_slug` are two fields; compare them as two fields.
* **Phases** are `Pxx` and **tasks** `Pxx-Txx`. The marker `<!-- rpi:phase id=P01 -->` or `<!-- rpi:task id=P01-T01 -->` sits immediately before the matching heading, which carries the checkbox: `### [ ] P01: name`, `#### [x] P01-T01: name`.
* **Critique findings** are `PC-xxx` with `<!-- rpi:critique id=PC-001 -->`, minted only in the critique; the plan's Critique Disposition table cites them.
* **Review findings** are `RV-xxx` with `<!-- rpi:review id=RV-001 -->`; decisions about them are `RD-xxx` events in the review's Decision History.
* **Requirements** are `FR-nnn` and `NFR-nnn` in the plan; each should be cited by at least one task's `Requirements:` block.
* **Evidence** in research is `C#` (codebase) and `W#` (external).
* **Decisions** in research and plan tables are `D1`, `D2`, …; a decision that needs the user's input may add a `D1: title` block with lettered options after the table.

## Research artifact

Sections: `## Executive Summary`, `## What You May Not Know`, `## Findings`, `## Recommendation and Alternatives`, `## Scope and Questions`, `## Decisions and Feedback`, `## Risks and Open Questions`, `## Planning Readiness and Next Step`, and `## Research Record` (Method and Boundaries, Extensions and Participation, Research Cycle Log, Evidence Log, Artifact Self-Check). The first heading reads `# Task Research: {{task_name}}`.

The **Planning Readiness and Next Step** table is the continuation record: Research disposition (`executed`, `reused`, `satisfied-and-skipped`), Planning Readiness (`Ready`, `Not ready`, `Not applicable`, `Blocked`), Blockers, Continuation owner, Next action.

## Plan

Sections in order: `## Task Metadata` (Task ID, Task slug, Plan date), `## Executive Summary`, `## Phase Checklist`, `## User Decisions and Requirements`, `## Planning Readiness and Next Step`, then `## Goals`, `## Scope and Non-Goals`, `## Functional Requirements`, `## Non-Functional Requirements`, `## Risks and Open Questions`, `## Dependencies`, `## Sources`, then `## Critique Disposition`, `## Artifact Self-Check`, `## Follow-Up Items` (immediately before Handoff), and `## Handoff`.

The Phase Checklist opens with a change map: an After Mermaid diagram, and a Before diagram only when the plan changes how parts connect. Each **phase** has `Goals:`, `Dependencies:`, and a `Changes in the map:` line. Each **task** has `Goals:`, `Requirements:`, `Details:`, optional `Guidance:`, `References:`, and `Dependencies:`. A task carries no status block: completion is the `[x]` marker plus the changes record.

**Planning Readiness and Next Step** rows include Planning execution and readiness (`Complete`, `Partial`, `Blocked`, `Needs clarification` and `Ready`, `Not ready`, `Blocked`), Blockers, Latest critique, Relevant research, Continuation owner, and Next action.

**Critique Disposition** records the setting (`standard`, `deep`, `skip`), the status (`not run`, `started`, `skipped`, `Complete`, `Partial`, `Blocked`, `not produced`), the latest critique path with its verdict, and one table row per `PC-xxx` with its disposition (`resolved`, `superseded`, `accepted with risk`, `open`). A critique that returned no result is never treated as a Pass.

## Plan critique

`## Metadata` (Task ID, Plan path, Critique execution `started`, `Complete`, `Partial`, `Blocked`, or `Not produced`, depth, type `initial` or `follow-up`), `## Inputs and Criterion Boundary`, `## Lens Assessments` (one row per lens with its status), `## Coverage Assessment`, `## Verdict` (`Pass`, `Revise`, `Blocked`, or `unavailable`), `## Earlier Finding Reconciliation` (follow-up only), `## Findings` (one `PC-xxx [Critical|High|Medium|Low]` per finding), `## Strengths and Residual Risk`, `## Questions or Blocking Evidence Gaps`, `## Limitations`, `## Recommended Next Action`.

The record is written before the first lens runs with execution `started`, and execution leaves `started` only when the record is complete. A session runs at most one critique unless the user asks for more.

## Changes record

`## Metadata` (Task ID, Related plan link), `## Execution Status` (Status `Complete`, `Partial`, `Blocked`; Declared invocation scope `full plan`, `Pxx`, or `Pxx-Txx`; Completed scope markers; All remaining active-plan markers), `## Execution Summary`, `## Completed Work` (one H3 per completed item with Related phase or task and Validation), `## Implementation-Time Plan Updates`, `## Business Alignment` (Alignment `clarification`, `divergence-confirmed`, `source-gap`, `pending-decision`), `## Validation Record`, `## Pre-Review Reconciliation` (Review readiness), `## Blockers`, `## Remaining Work`, `## Follow-Up Items`, `## Return-to-Caller State`.

A `Pxx-Txx` is checked in the plan immediately after its changes entry exists; a `Pxx` is checked only when every task in it is checked.

## Review record

`## Executive Summary` (Review execution `Complete`, `Partial`, `Blocked`; Assessed outcome `Conformant`, `Conformant with justified divergence`, `Defects found`, `Residual work`, `Not accepted`), `## What You May Not Know`, `## Findings and Proposed Routes` (one `RV-xxx [severity]` per finding with a Proposed destination `rpi-implement`, `rpi-plan`, `rpi-research`, or `follow-up`), `## Parent Decision Record` (`### Current Disposition` with Final outcome, projected from `### Decision History`, an append-only table of `RD-xxx` events with Proposed and Final destination), `## Validation Evidence`, `## Risks, Blockers, and Residual Work`, optional `## Stakeholder Note Draft`, `## Review Record` (Task ID, Review scope, Review execution, Plan, Plan critique, and Changes paths).

The record is saved while the Review Record's execution stays `started`; the finding set is complete once execution leaves `started`. The assessed outcome is the reviewer's proposal; acceptance is the Final outcome under Current Disposition. The latest Decision History event for a finding governs, and a recorded Final destination replaces the proposed one.

## RPI session state

The `rpi` skill, run as `/rpi` or preloaded by the RPI Agent, persists one JSON object per task at `.copilot-tracking/rpi-sessions/{{YYYY-MM-DD}}/{{session_slug}}/{{task_slug}}-state.json`. One folder holds every task of a session and is dated by the session's first day; `{{session_slug}}` is at most 40 characters. When the session finds a task's state file elsewhere under `.copilot-tracking`, it moves the file into its session folder on the next resume. The audit recognizes a state file anywhere in the folder by its fields: `task_slug`, `active_phase`, and `artifact_paths`.

Stable fields: `task_id`, `task_slug`, `session_name`, `parent_task` (`null` or an object with `task_id`, `task_slug`, and `state_path`), `child_tasks` (objects with the same three fields), `mode` (`manual`, `automatic`), `active_phase` (`Research`, `Plan`, `Implement`, `Review`, `Follow-up`), `status` (`active`, `blocked`, `completed`), `session_status` (`running`, `stopped`), `artifact_paths` (the current document of each kind: `research`, `plan`, `critique`, `changes`, `review`), `documents` (every document of each kind in creation order), `confirmed_decisions`, `blockers`, `next_action` (`phase`, `action`), and `prioritized_follow_ups`.

A child entry is added to the parent's `child_tasks` before the child's state file is created, so a listed child without a state file can be a session between two writes. A critique or review path is recorded in `artifact_paths` before the record is first written. On recovery the session reconciles state with the artifacts, and the artifacts win.

## Commands and arguments

| Command              | Arguments                                                                                                                  | Writes                                                  |
|----------------------|----------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------|
| `/rpi`               | `[task=...] [mode=...] [phase=...] [critique=...] [review=...] [subagents=...]`                                            | `rpi-sessions/{date}/{session}/{task_slug}-state.json`  |
| `/rpi-research`      | `[topic=...] [posture=...] [effort=...] [subagents=...] [chat]`                                                            | `research/{date}/{slug}-research.md`                    |
| `/rpi-plan`          | `[task=...] [research=...] [context=...] [draft=...] [decisions=...] [critique=...] [critique-effort=...] [subagents=...]` | the plan, and the critique through `/rpi-plan-critique` |
| `/rpi-plan-critique` | `[plan=...] [evidence=...] [output=...] [depth=...] [effort=...] [subagents=...] [prior=...]`                              | `reviews/plans/{date}/{slug}-plan-critique.md`          |
| `/rpi-implement`     | `[plan=...] [phase=...] [task=...] [subagents=...]`                                                                        | `changes/{date}/{slug}-changes.md`, plan markers        |
| `/rpi-review`        | `[task=...] [plan=...] [changes=...] [depth=...] [effort=...] [subagents=...]`                                             | `reviews/logs/{date}/{slug}-review.md`                  |
| `/rpi-challenger`    | `[subject=...] [artifacts=...] [focus=...]`                                                                                | `challenges/{date}/{slug}-challenge.md`                 |
| `/rpi-walkthrough`   | `[target=...] [detail=...] [subagents=...] [chat]`                                                                         | `walkthroughs/{date}/{slug}-decisions.md`               |

## Resuming

Continuity comes from the dated artifacts, not chat. Resume by referencing the artifact path in the command and naming the stable IDs, for example `/rpi-implement plan=.copilot-tracking/plans/2026-10-02/{slug}-plan.md task=P01-T02`. Implementation resumes from the first unchecked dependency-ready item in declared scope after reading prior changes entries, current markers, and the latest critique disposition; it does not resume a task awaiting a user decision. Review reads the Parent Decision Record before rebuilding stale projections.

A task that has a session state file can also be resumed with `/rpi task=<slug>`, which continues from the recorded phase and keeps the state file current. A phase command run directly leaves the state file as it was until the next `/rpi` resume reconciles it with the artifacts.

Start a new chat when switching tasks or when behavior has degraded, and reference the intended path when several artifact sets exist. The artifacts carry the research decisions, the remaining `Pxx-Txx` work, completed work with validation, and review findings with routes; they do not carry the conversation, or the RPI session's mode and participation preferences unless a state file records them.

## The retired Task Planner format

Earlier hve-core releases shipped the agents Task Researcher, Task Planner, Task Implementor, and Task Reviewer, which wrote a different artifact set:

| File                                                                             | Shape                                                                          |
|----------------------------------------------------------------------------------|--------------------------------------------------------------------------------|
| `plans/{date}/{task}-plan.instructions.md`                                       | `## Implementation Checklist` with `Implementation Phase N` headings and steps |
| `details/{date}/{task}-details.md`                                               | step details with line-number references                                       |
| `plans/logs/{date}/{task}-log.md`                                                | planning log                                                                   |
| `research/subagents/{date}/{topic}-research.md`                                  | subagent research                                                              |
| `reviews/{date}/{name}-review.md`, `reviews/rpi/{date}/{name}-NNN-validation.md` | review log and per-phase validation outputs                                    |

The current `rpi-*` skills do not read this layout, and no converter exists. The audit recognizes these files by path, and research or changes files by content or by legacy siblings of the same slug, and lists them per task with checklist progress. The option is to re-plan with `/rpi-plan task=<slug> draft=<old plan path>` and cite the old research and changes as context.
