---
name: documentation
description: Canonical documentation capability for audit, drift, validate, and author modes in hve-core.
---

# documentation

## Overview

This skill provides the shared documentation capability used by the Documentation agent.
It centralizes the durable knowledge for audit, drift, validate, and author flows in a
single package so thin wrappers can load mode-specific guidance instead of embedding
capability prose inline.

## Mode map

The Documentation agent should load the relevant skill sections by mode:

| Mode       | Primary load targets                                                                                                                                                                   | Notes                                                                              |
|------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------|
| `audit`    | `references/conventions.md`, `references/coverage-method.md`, `references/validation-toolchain.md`, `references/content-sensitivity.md`                                                | Replaces the former Doc Ops workflow with a skill-driven audit loop.               |
| `drift`    | `references/conventions.md`, `references/code-doc-mapping.md`, `references/content-sensitivity.md`                                                                                     | Uses the repo-local mapping table and drift heuristics.                            |
| `validate` | `references/validation-toolchain.md`, `references/accessibility-checks.md`, `references/content-sensitivity.md`, `references/rai-guardrails.md`                                        | Runs docs validation and escalates formal review when needed.                      |
| `author`   | `templates/guide.md`, `templates/reference.md`, `references/conventions.md`, `references/accessibility-checks.md`, `references/content-sensitivity.md`, `references/rai-guardrails.md` | Produces narrative or reference docs with the repository's documented conventions. |

## Success criteria

For `audit` and `validate` modes, record results for all applicable local-safe checks and record existing CI status separately. Keep each CI-owned check that did not run as `Pending CI`, `Skipped`, `Deferred`, or `Unavailable`; do not report it as `Passed`.

## Non-goals

This skill does not author ADRs, BRDs, PRDs, or other planning artifacts.
It also does not embed accessibility, RAI, or security standards logic inline;
it points to the dedicated reference files and routes formal assessment to the
appropriate planner when the scenario requires it.

## Working conventions

- Prefer existing repository instructions and scripts over duplicated prose.
- In audit and validate modes, run local-safe checks by default and summarize existing CI status separately. Invoke a CI-owned lane locally only when the task specifically asks to reproduce that named lane.
- Treat browser installation, model or moderation environments, services, credentials, and interactive UI as separate prerequisites rather than automatic failure recovery.
- Keep documentation changes factual and scoped to the current task.
- Use the reference files below for mode-specific methods, heuristics, and checklists.
- Escalate to planners for formal accessibility, RAI, or security review if the work
  requires a specialist assessment.

## Stop rules

For `audit` and `validate` modes, stop after recording local-safe results and any separate CI evidence. Report missing specialized setup or required CI evidence separately; do not infer it, provision it automatically, or report it as passed.

## Session tracking

Write session state to `.copilot-tracking/documentation/` using a
`{{YYYY-MM-DD}}-session.md` file for the run, following the standard session file conventions.

## Reference files

- `references/conventions.md` — Synthesis of the repository's markdown, writing-style,
  and Docusaurus conventions.
- `references/code-doc-mapping.md` — Code-to-documentation mapping table and drift heuristics.
- `references/coverage-method.md` — Gap and coverage analysis method for audit mode.
- `references/validation-toolchain.md` — Validation command catalog and result interpretation.
- `references/accessibility-checks.md` — Inline documentation checks and handoff triggers.
- `references/content-sensitivity.md` — Pre-publish PII, secrets, confidentiality, and
  AI-disclosure checks.
- `references/rai-guardrails.md` — Injection-boundary, attribution, human-review, and
  disclaimer guidance.

## Templates

- `templates/guide.md` — Structure template for narrative guides and how-to pages.
- `templates/reference.md` — Structure template for reference and API-style documentation.
