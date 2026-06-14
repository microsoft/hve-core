---
description: "Planning template and compact protocol detail for the task-planner RPI skill"
---

# Task Planner Reference

Use this reference when the skill needs a compact planning contract rather than a long inline protocol.

## Implementation Plan sections

Use the dated implementation plan at `.copilot-tracking/plans/{{YYYY-MM-DD}}/<task>-plan.instructions.md`.

Start the file with frontmatter and markdownlint suppression:

```yaml
---
applyTo: '.copilot-tracking/changes/{{YYYY-MM-DD}}/<task>-changes.md'
---
```

Then add `<!-- markdownlint-disable-file -->` before the H1.

* Overview: one-sentence summary of the implementation approach and expected outcome.
* User requirements: capture the user-stated goals and record the source of each requirement.
* Derived objectives: add planner-derived objectives and the reasoning behind them.
* Context summary: reference the research artifact, current code paths, and any subagent findings.
* Implementation checklist: break work into phases and steps, annotate parallelizable work with `<!-- parallelizable: true -->`, and point each step to the details file lines.
* Final validation phase: include full project validation, minor fix iteration, and blocking issue reporting.
* Planning log reference: link to `.copilot-tracking/plans/logs/{{YYYY-MM-DD}}/<task>-log.md` for discrepancy handling and alternatives.
* Dependencies: list toolchain, build, or environment prerequisites.
* Success criteria: capture verifiable completion markers that trace back to the research or user requirements.

## Implementation Details sections

Use the dated details artifact at `.copilot-tracking/details/{{YYYY-MM-DD}}/<task>-details.md`.

Start the file with `<!-- markdownlint-disable-file -->`.

* Context references: cite the primary research file and any relevant subagent outputs.
* Phase and step details: describe each implementation phase, file operations, and validation scope.
* File operations: list the exact files to create or modify and the purpose of each change.
* Discrepancy references: link steps to DR, DD, or RI items recorded in the planning log.
* Success criteria: list what must be verified after each phase or step.
* Dependencies: note prerequisites and sequencing rules for each detail entry.
* Validation commands: name the relevant lint, build, or test commands for the phase.

## Planning Log sections

Use the dated planning log at `.copilot-tracking/plans/logs/{{YYYY-MM-DD}}/<task>-log.md`.

Start the file with `<!-- markdownlint-disable-file -->`.

* Discrepancy Log: capture DR/DD/RI items, sources, impact, and resolution status.
* Implementation Paths Considered: record the selected path and the viable alternatives that were rejected.
* Suggested Follow-On Work: note any remaining work, research gaps, or validation items outside the current scope.

## Compact protocol detail

1. Start from the current research artifact and create or update the dated planning files in place.
2. If research is missing or incomplete, create a lightweight research brief under `.copilot-tracking/research/{{YYYY-MM-DD}}/<task>-research.md` and delegate deeper gaps to the Researcher Subagent when available.
3. Build the plan and details from evidence, not assumptions, and keep the selected implementation path explicit.
4. Dispatch the Plan Validator with the research path, plan path, details path, planning log path, and a brief user-requirements summary.
5. Stop and tell the user if `runSubagent` or `task` is unavailable for required research or validation dispatch.
6. Update only the Planning Log Discrepancy Log when the validator reports issues, fix critical and major findings, and re-run validation until only minor findings remain.
7. Re-enter the same dated planning artifacts when material edits are needed, preserving completed work and refreshing references.

## Research fallback

When research is absent, incomplete, or stale:

* Prefer a completed `/task-researcher` artifact when one exists.
* Create or extend a lightweight research brief at `.copilot-tracking/research/{{YYYY-MM-DD}}/<task>-research.md` for the current task.
* Use `runSubagent` or `task` for deeper gaps and write the dated subagent output under `.copilot-tracking/research/subagents/{{YYYY-MM-DD}}/<topic>-research.md`.
* Stop and report the missing dispatch capability when deeper research is required but no subagent dispatch tool is available.

## Validation and resumption

* Re-run validation after material edits to planning files.
* Refresh line references and cross-links whenever the plan, details, or log is updated.
* Treat critical and major Plan Validator findings as blocking. Minor findings may remain only when documented as non-blocking in the planning log.
* When a decision point remains unresolved, document the selected default in the planning log and note the follow-up work.

## Handoff compatibility

Use `/task-implementor` as the skill-forward implementation handoff. `/task-implement` is the legacy prompt alias for the older agent path and should not replace the skill-forward handoff in new planner output.

## Decision-point handling

* If the research evidence is sufficient, record the decision and rationale in the implementation plan.
* If multiple approaches remain viable, capture the trade-offs in the planning log and choose one path with explicit justification.
* If the decision requires user input, note it in the planning log and proceed with the fallback recommendation only when the evidence is strong enough.
