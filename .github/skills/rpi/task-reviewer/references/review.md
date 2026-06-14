---
description: "Deeper review protocol, templates, and validator contracts for the task-reviewer RPI skill"
---

# Task Reviewer Reference

Use this reference to preserve the task-reviewer outcome set while keeping the skill body compact and skill-forward.

## Artifact Discovery and Path Derivation

1. Discover the implementation plan from the user request, attached files, the current open file, or the most recent `.copilot-tracking/plans/{{YYYY-MM-DD}}/<task>-plan.instructions.md`.
2. Derive the dated task paths from the discovered plan path:
   * plan: `.copilot-tracking/plans/{{YYYY-MM-DD}}/<task>-plan.instructions.md`
   * changes log: `.copilot-tracking/changes/{{YYYY-MM-DD}}/<task>-changes.md`
   * research: `.copilot-tracking/research/{{YYYY-MM-DD}}/<task>-research.md` when available
   * review log: `.copilot-tracking/reviews/{{YYYY-MM-DD}}/<plan-file-name-without-instructions-md>-review.md`
   * phase validation: `.copilot-tracking/reviews/rpi/{{YYYY-MM-DD}}/<plan-file-name-without-instructions-md>-<NNN>-validation.md`
3. When a required artifact is missing, search by date prefix or task description and note the gap in the review log. If nothing relevant is found, stop and report a blocked review.
4. When multiple unrelated artifact sets match, present the candidate sets with plan path, changes log path, date, and task name, then stop until the user chooses one. Do not pick by recency or partial similarity when unrelated sets are present.
5. Create or update the review log at the derived path and start it with `<!-- markdownlint-disable-file -->`.

## Review Log Template

Use [../templates/review-log.md](../templates/review-log.md) for `.copilot-tracking/reviews/{{YYYY-MM-DD}}/<plan-file-name-without-instructions-md>-review.md`.

## Implementation Validator Input / Output Contract

When dispatching `Implementation Validator` with `runSubagent` or `task`, provide:

* changed file paths from the changes log;
* validation scope (`full-quality` by default, or a narrower scope when the user requests it);
* the implementation validation log path under `.copilot-tracking/reviews/` or `.copilot-tracking/reviews/logs/`;
* applicable instruction and architecture references from `.github/instructions/` and relevant docs;
* the research path when available.

Expect the subagent to return severity-graded findings and an implementation validation log path. Incorporate those findings into the parent review log under `Implementation Quality Findings`.

## Required Validation Command Execution

The parent task-reviewer owns validation-command discovery and execution. Do not rely on Implementation Validator or RPI Validator to replace this step.

Discover and run validation commands when available and relevant to changed files:

* Check `package.json`, `Makefile`, CI workflow files, and project scripts for lint, build, test, and type-check commands.
* Run commands scoped to changed files or affected components when available.
* Use diagnostics for changed files when command execution is unavailable or too broad for the current review.
* Record each command, scope, exit status, and important output summary in the parent review log.
* Treat failed validation commands as findings and include their severity in the final status.
* When no relevant validation command exists, record `Skipped` with the reason in the review log.
* Do not mark the review `Complete` unless relevant commands have passed or have an explicit not-applicable rationale.

## RPI Validator Input / Output Contract

Run `RPI Validator` one time per plan phase when a plan is present or when plan-to-change alignment matters. Dispatch independent phases in parallel when useful. Provide:

* plan path;
* changes log path;
* research path when available;
* phase number;
* validation output path `.copilot-tracking/reviews/rpi/{{YYYY-MM-DD}}/<plan-file-name-without-instructions-md>-<NNN>-validation.md`.

Treat each phase result as the source of truth for that phase; synthesize the phase status and findings into the parent review log.

## Researcher Subagent Fallback Contract

Use `runSubagent` or `task` when the review context is incomplete or findings remain ambiguous. Write the subagent output to `.copilot-tracking/research/subagents/{{YYYY-MM-DD}}/<topic>-research.md`. Stop and ask the user only when the ambiguity cannot be resolved or subagent dispatch is unavailable.

## Severity Aggregation and Final Status

Aggregate findings across the implementation validator and all RPI phase validations.

* `Complete`: all plan items are verified and no Critical or High findings remain.
* `Needs Rework`: Critical or High findings remain and require fixes before handoff.
* `Blocked`: the review cannot proceed because artifacts are missing, an external dependency blocks validation, or unresolved clarification prevents completion.

## Response Contract

Use compact skill-forward wording while preserving the review outcome fields in the final response:

```markdown
## {{status_icon}} Task Reviewer: {{task_description}}

| Summary | |
|---------|-|
| Review Log | {{review_log_path}} |
| Overall Status | {{Complete / Needs Rework / Blocked}} |
| Critical Findings | {{count}} |
| High Findings | {{count}} |
| Medium Findings | {{count}} |
| Low Findings | {{count}} |
| Follow-Up Items | {{count}} |

Next step: {{/task-implementor, /task-researcher, /task-planner, or return to user}}
```

When findings require rework, prefer `/task-implementor`.

## Resumption Behavior

When the user resumes the review, read the existing review log and any existing `.copilot-tracking/reviews/rpi/{{YYYY-MM-DD}}/*.md` validation files first. Preserve completed validations, skip duplicates, and continue from the earliest incomplete phase.

## Handoff Notes

* Keep the parent skill compact; put deeper protocol details here rather than duplicating them in SKILL.md.
