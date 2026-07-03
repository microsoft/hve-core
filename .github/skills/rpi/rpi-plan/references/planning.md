---
description: "Planning template and protocol detail for the rpi-plan skill"
---

# RPI Plan Reference

Use this reference when the skill needs planning detail beyond the main body in SKILL.md.

Derive `{{task_slug}}` from the primary task or target with lower-kebab-case, and replace `YYYY-MM-DD` with the current date at execution time.

## Implementation Plan sections

Use [../templates/implementation-plan.md](../templates/implementation-plan.md) for `.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.instructions.md`.

Artifact path scheme:

* `.copilot-tracking/research/{{YYYY-MM-DD}}/{{task_slug}}-research.md` for the primary research record.
* `.copilot-tracking/research/subagents/{{YYYY-MM-DD}}/<topic>-research.md` for subagent findings.
* `.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.instructions.md` for the implementation plan.
* `.copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-details.md` for the step-by-step detail file.
* `.copilot-tracking/plans/logs/{{YYYY-MM-DD}}/{{task_slug}}-log.md` for the planning log.
* `.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md` for the downstream implementation handoff path.

Start the file with frontmatter and markdownlint suppression:

```yaml
---
applyTo: '.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md'
---
```

Then add `<!-- markdownlint-disable-file -->` before the H1.

* Overview: one-sentence summary of the implementation approach and expected outcome.
* User requirements: capture the user-stated goals and record the source of each requirement, including a source reference for every caller-stated constraint.
* Derived objectives: add planner-derived objectives and the reasoning behind them, citing the research finding or reasoning that created them.
* Context summary: reference the research artifact, current code paths, and any subagent findings.
* Risks and mitigations: capture each material research risk, likelihood, impact or magnitude, priority basis, and whether it was resolved, mitigated, deferred with rationale, or recorded as a blocker.
* Implementation checklist: break work into phases and steps, annotate parallelizable work with `<!-- parallelizable: true -->`, and point each step to the details file lines.
* Final validation phase: include full project validation, minor fix iteration, and blocking issue reporting.
* Planning log reference: link to `.copilot-tracking/plans/logs/{{YYYY-MM-DD}}/{{task_slug}}-log.md` for discrepancy handling, validator findings, implementation paths considered, deferred work, and validation coverage.
* Dependencies: list toolchain, build, or environment prerequisites.
* Success criteria: capture verifiable completion markers that trace back to the research or user requirements.

## Implementation Details sections

Use [../templates/implementation-details.md](../templates/implementation-details.md) for `.copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-details.md`.

Start the file with `<!-- markdownlint-disable-file -->`.

* Context references: cite the primary research file and any relevant subagent outputs.
* Requirement evidence: cite the source and reasoning that support each planned step.
* Phase and step details: describe each implementation phase, file operations, and validation scope.
* File operations: list the exact files to create or modify and the purpose of each change.
* Discrepancy references: link steps to DR, DD, or RI items recorded in the planning log.
* Success criteria: list what must be verified after each phase or step.
* Dependencies: note prerequisites and sequencing rules for each detail entry.
* Validation commands: name the relevant lint, build, or test commands for the phase.

## Planning Log sections

Use [../templates/planning-log.md](../templates/planning-log.md) for `.copilot-tracking/plans/logs/{{YYYY-MM-DD}}/{{task_slug}}-log.md`.

Start the file with `<!-- markdownlint-disable-file -->`.

* Discrepancy Log: capture DR/DD/RI items, sources, impact, and resolution status.
* Validator Findings: record Plan Validator findings, severity, and follow-up actions.
* Validation Coverage: record coverage, requirement alignment, detail-line verification, and final validation phase checks; if scratch evidence is used, cite its path and summarize the result in the planning log.
* Implementation Paths Considered: record the selected path and the viable alternatives that were rejected.
* Suggested Follow-On Work: note any remaining work, research gaps, or validation items outside the current scope, including deferred work with source evidence.

## Planning protocol detail

1. Follow the four phases in order: Context Assessment, Planning, Plan Validation, Completion.
2. Use plain-text workspace-relative paths for all planning artifacts and references. Do not convert these paths to markdown links in the planning files.
3. Implementation details may cite `.copilot-tracking/` research and plan artifacts to guide logic, but must not instruct embedding those paths or other internal references into production code, code comments, documentation strings, or commit messages.
4. Prefer the Researcher Subagent at `.github/agents/hve-core/subagents/researcher-subagent.agent.md` for deeper research gaps via `runSubagent` or `task`. If dispatch tooling is unavailable, perform the equivalent research inline and record the result in the primary research artifact; do not dead-stop on tooling alone.
5. Prefer the Plan Validator at `.github/agents/hve-core/subagents/plan-validator.agent.md` after the plan and details files are drafted, via `runSubagent` or `task`. If dispatch tooling is unavailable, perform the equivalent validation inline and record the findings in the Planning Log Validator Findings section. Required input: research path, implementation plan path, implementation details path, planning log path, and a concise user-requirements summary. Expected output: planning log path, validation status, severity-ordered findings, and clarifying questions.
6. Treat Critical and High findings as blocking. Update the Planning Log Discrepancy Log and Validator Findings section, fix the blocking issues in the plan and details files, then rerun validation until no Critical and High findings remain.
7. Author `implementation-details.md` first, then cite its line ranges from the implementation plan using the `Details: (Lines X-Y)` convention. This keeps the plan traceable to the detailed step file without redesigning the format.
8. Re-enter dated planning artifacts when material edits are needed, keep completed work, and refresh line references.
9. Stop only for genuine blockers, such as missing task context, unwritable research paths, or unresolved Critical and High findings that materially affect implementation readiness.
10. When a plan affects RPI skills, check `rpi-quick` orchestration references, granular phase-skill boundaries, and RPI templates when those surfaces are relevant. Do not copy the full Task Planner agent protocol.

## Per-step input and output contract

* Phase 1 input: user request, attached context, current research artifact, and any existing planning files.
* Phase 1 output: updated research file with scope, findings, gaps, and constraints.
* Phase 2 input: research findings, requirements summary, and the dated artifact paths.
* Phase 2 output: implementation plan, implementation details, and planning log files with cross-references and path notes.
* Phase 3 input: the four planning artifact paths and the user-requirements summary.
* Phase 3 output: validator findings, severity labels, and any required follow-up questions.
* Phase 4 input: validated planning files and any remaining follow-up work.
* Phase 4 output: concise handoff summarizing the implementation plan artifacts created, any scope items deferred for future planning, validation status, and next implementation steps.

## Research fallback

When research is absent, incomplete, or stale:

* Prefer a completed `/rpi-research` artifact when one exists.
* Create or extend a lightweight research brief at `.copilot-tracking/research/{{YYYY-MM-DD}}/{{task_slug}}-research.md` for the current task.
* Use `runSubagent` or `task` for deeper gaps and write the dated subagent output under `.copilot-tracking/research/subagents/{{YYYY-MM-DD}}/<topic>-research.md`.
* Perform the equivalent research inline when deeper research is required but no subagent dispatch tool is available, and record the result in the research artifact.

## Validation and resumption

* Re-run validation after material edits to planning files.
* Refresh line references and cross-links whenever the plan, details, or log is updated.
* Treat Critical and High Plan Validator findings as blocking. Minor findings may remain only when documented as non-blocking in the planning log and recorded in the Validator Findings section.
* When a decision point remains unresolved, record the selected default in the planning log and note the follow-up work.

## Implementation Handoff

Use `/rpi-implement` as the implementation handoff in planner output only when the caller expects normal progression.

* Return the plan file path, details file path, planning log path, validation status, any scope items deferred for future planning, and next implementation steps.
* For planning-only, comparison, audit, analysis, or explicitly no-handoff invocations, return the validated planning artifacts and next-step guidance without presenting `/rpi-implement` as an immediate handoff.
* Keep the response concise and evidence-based, with the most actionable artifact paths last.
* When the user needs a decision, present the option table, recommendation, and impact if deferred before the final handoff.

## Decision-point handling

* If the research evidence is sufficient, record the decision and rationale in the implementation plan.
* If multiple approaches remain viable, capture the trade-offs in the planning log and choose one path with explicit justification.
* If the decision requires user input, note it in the planning log and proceed with the fallback recommendation only when the evidence is strong enough.
* Use the Planning Decisions format when the user must choose between options, then update the planning files after the answer is recorded.
