---
description: "Deeper review protocol, templates, and validator contracts for the task-reviewer RPI skill"
---

# Task Reviewer Reference

Use this reference for the full review protocol, templates, and validator contracts while keeping the skill body brief.

## Evidence-first review discipline

* Validate against the implementation plan and research document as the source of truth.
* Cite exact file paths and line ranges when findings depend on evidence.
* Match `.github/instructions/**/applyTo` patterns to changed file types so the review uses the relevant conventions.
* Treat subagent output as an index, not the full result. Re-read the subagent file only when the next action needs evidence the summary does not contain.

## Subagent result handling

* After any subagent returns, emit one concise line per subagent: name, one-line outcome, and the tracking file path.
* Update the relevant `.copilot-tracking/` file once when the review needs a record update.
* Stop after that update. Do not re-read large planning or research files in the closing turn.

## Artifact Discovery and Path Derivation

Use one deterministic slug rule for every path in this skill:

* Derive the task slug as lower-kebab-case from the primary task or target name in the plan path or user request.
* Use the current date in `YYYY-MM-DD` as the dated segment.
* Use `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/<task-slug>-review.md` as the canonical review-log path.
* Use `.copilot-tracking/reviews/quality/{{YYYY-MM-DD}}/<review-stem>-implementation-quality.md` as the preferred standalone implementation-quality artifact path.

| Artifact               | Required path                                                                              | Notes                              |
|------------------------|--------------------------------------------------------------------------------------------|------------------------------------|
| Implementation plan    | `.copilot-tracking/plans/{{YYYY-MM-DD}}/<task-slug>-plan.instructions.md`                  | Required                           |
| Changes log            | `.copilot-tracking/changes/{{YYYY-MM-DD}}/<task-slug>-changes.md`                          | Required                           |
| Research               | `.copilot-tracking/research/{{YYYY-MM-DD}}/<task-slug>-research.md`                        | Optional when available            |
| Review log             | `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/<task-slug>-review.md`                      | Canonical review-log path          |
| Phase validation       | `.copilot-tracking/reviews/rpi/{{YYYY-MM-DD}}/<task-slug>-<NNN>-validation.md`             | One file per phase                 |
| Implementation quality | `.copilot-tracking/reviews/quality/{{YYYY-MM-DD}}/<review-stem>-implementation-quality.md` | Preferred standalone artifact path |

1. Resolve the review scope from explicit paths, attached or open files, task slug, time-based scope, then recent matching `.copilot-tracking` artifacts.
2. Derive the slug and current date from the discovered plan path or the user-provided task name, then record the related paths in the review log.
3. When a required artifact is missing, search only within the current task slug or the provided paths, and note the gap in the review log. If nothing relevant is found, stop and report a blocked review.
4. When multiple unrelated artifact sets match, present the candidate sets with plan path, changes log path, date, and task name, then stop until the user chooses one.
5. Create or update the review log at the canonical path and start it with `<!-- markdownlint-disable-file -->`.

## Phase contract

### Phase 1: Artifact Discovery

1. Use attached files, open files, or explicit paths when the user provides them.
2. When no artifacts are specified, search only the current task slug or the provided task paths under `.copilot-tracking/`.
3. Match related files by task slug and date prefix, then create the review log and proceed.

### Phase 2: RPI Validation

1. Identify plan phases from the implementation plan.
2. Run one `RPI Validator` pass per phase with `runSubagent` or `task`.
3. Read each phase-validation file and synthesize the findings into the parent review log.
4. Run additional phase validations when findings need deeper investigation.

### Phase 3: Quality Validation

1. Run `Implementation Validator` with `runSubagent` or `task` using `full-quality` scope.
2. Provide changed file paths, relevant instruction and architecture references, and the research path when available.
3. Capture implementation-quality findings and validation-command results in the review log.

### Phase 4: Review Completion

1. Finalize the review log with severity counts, missing work, follow-up items, and the final status.
2. Present the response and handoff to the user with the review log path and the next command.

## Review log contract

Use [../templates/review-log.md](../templates/review-log.md) for `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/<task-slug>-review.md`.

The review log must capture:

* review metadata: date, related plan path, changes log path, research path;
* plan-to-research alignment with status, rationale, evidence paths, and a clear note that planning alignment is distinct from implementation acceptance;
* severity summary: Critical, High, Medium, Low;
* per-phase RPI findings and status;
* implementation quality findings by category and the standalone evidence path when one is written;
* missing work and deviations;
* follow-up recommendations separated into `Discovered during review` and `Deferred from planning log` items;
* validation commands with scope, status, and summary;
* overall status: `Complete`, `Needs Rework`, or `Blocked`.

## Implementation Validator input / output contract

When dispatching `Implementation Validator`, provide:

* changed file paths from the changes log;
* validation scope (`full-quality` by default, or a narrower scope when the user requests it);
* the standalone implementation-quality artifact path under `.copilot-tracking/reviews/quality/{{YYYY-MM-DD}}/<review-stem>-implementation-quality.md` when a separate artifact is written;
* relevant instruction and architecture references from `.github/instructions/` and related docs;
* the research path when available.

Expect the subagent to return severity-graded findings and an implementation-quality artifact path. Add those findings to the parent review log under `Implementation Quality Findings`.

## Required validation command execution

The parent task-reviewer owns validation-command discovery and execution. Do not delegate this step to Implementation Validator or RPI Validator.

Discover and run validation commands when available and relevant to changed files:

* Check `package.json`, `Makefile`, CI workflow files, `pyproject.toml`, `ruff`, `uv`, `uvx`, `pytest`, and project scripts for lint, build, test, and type-check commands.
* Run commands scoped to changed files or affected components when available.
* Use diagnostics for changed files when command execution is unavailable or too broad for the current review.
* Record each command, scope, exit status, and important output summary in the parent review log.
* Record changed-file discovery and any implementation inventory that was or was not found.
* When no implementation inventory exists, record `Skipped` with an explicit reason and note any evidence-integrity checks that actually ran.
* Flag any produced code, code comments, documentation strings, or commit messages that reference `.copilot-tracking/` paths or other internal planning, research, or implementation artifacts; treat such leaks as findings.
* Treat failed validation commands as findings and include their severity in the final status.
* Do not imply broad validation passed against nonexistent implementation changes.
* Do not mark the review `Complete` unless relevant commands have passed or the skip reason is explicit.

## RPI Validator input / output contract

Run `RPI Validator` one time per plan phase when a plan is present or when plan-to-change alignment matters. Dispatch independent phases in parallel when useful.

Provide:

* plan path;
* changes log path;
* research path when available;
* phase number;
* validation output path `.copilot-tracking/reviews/rpi/{{YYYY-MM-DD}}/<task-slug>-<NNN>-validation.md`.

Treat each phase result as the source of truth for that phase and synthesize the phase status and findings into the parent review log.

## Researcher Subagent fallback contract

Prefer `RPI Validator` and `Implementation Validator` with `runSubagent` or `task`; use `Researcher Subagent` as the fallback when the review context is incomplete or findings remain ambiguous. Write the subagent output to `.copilot-tracking/research/subagents/{{YYYY-MM-DD}}/<topic>-research.md`. If dispatcher tooling is unavailable, perform the equivalent review or validation inline, record it, and continue instead of dead-stopping on the dispatcher alone.

## Severity aggregation and final status

Aggregate findings across `Implementation Validator` and all RPI phase validations.

* Count one missing changes log or changed-file inventory as a single controlling review-level Critical finding when it blocks acceptance.
* Preserve detailed per-phase findings, but keep phase-specific missing proof at High or lower unless there is a distinct critical failure.
* `Complete`: all plan items are verified and no Critical or High findings remain.
* `Needs Rework`: Critical or High findings remain and require fixes before handoff.
* `Blocked`: the review cannot proceed because artifacts are missing, an external dependency blocks validation, or unresolved clarification prevents completion.

## Response and handoff contract

Use brief, skill-forward wording and keep the review outcome fields in the final response:

```markdown
## {{status_icon}} Task Reviewer: {{task_description}}

| Summary           |                                       |
|-------------------|---------------------------------------|
| Review Log        | {{review_log_path}}                   |
| Overall Status    | {{Complete / Needs Rework / Blocked}} |
| Critical Findings | {{count}}                             |
| High Findings     | {{count}}                             |
| Medium Findings   | {{count}}                             |
| Low Findings      | {{count}}                             |
| Follow-Up Items   | {{count}}                             |

Validation activities completed: {{commands, subagents, evidence checks}}
Next step: {{/rpi-implement, /rpi-research, /rpi-plan, or return to user}}
```

When findings require rework, prefer `/rpi-implement`.

Start responses with a status header and include the validation activities completed, the findings summary, the review log path, severity counts, follow-up count, and the next step. Keep handoff commands as recommendations only unless the user explicitly requested a handoff. When the review is complete, clear the context, attach or open the review log, and start the next workflow.

## Resumption behavior

When the user resumes the review, read the saved review log and any saved `.copilot-tracking/reviews/rpi/{{YYYY-MM-DD}}/*.md` validation files first. Keep completed validations, skip duplicates, and continue from the earliest incomplete phase.
