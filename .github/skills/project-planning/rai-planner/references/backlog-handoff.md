---
description: Review and backlog handoff guidance for Phase 6 of the RAI Planner
---

# RAI Review and Backlog Handoff

Use this note when entering Phase 6 or preparing the final handoff summary.

## Review Rubric

Before generating backlog items, confirm that the assessment has covered the essential review dimensions:

* scope boundary clarity
* risk identification coverage
* control surface adequacy
* evidence sufficiency
* tradeoff documentation
* alignment with the selected framework

## Work Item Generation

Generate work items from the evidence register and maturity observations using the appropriate backlog format. Keep the output concise, attributable, and suitable for downstream review.

### Delegation to Shared Backlog Templates

For the full dual-format ADO and GitHub templates, content sanitization guidance, autonomy-tier vocabulary, disclaimer placement, and work-item ID naming rules, use the shared backlog templates skill at `.github/skills/shared/backlog-templates/SKILL.md`. This handoff reference stays focused on the RAI-specific review expectations and the final handoff decisions.

## Autonomy and Output Targets

Select the output target and autonomy tier that fit the project context. Persist the choice in session state and allow the user to confirm the final handoff.

## Content Hygiene

Keep the handoff clear and reviewable:

* preserve RAI characteristic names and framework references
* avoid speculative claims that are not supported by the session evidence
* note when a recommendation needs human review or compliance validation

### Artifact Signing

After backlog generation and before broader distribution, the RAI planner may sign session artifacts. Use `npm run rai:sign -- -ProjectSlug {slug}`. The signing workflow produces a SHA-256 manifest for the generated artifacts, optionally signs them with cosign when the environment is configured for it, and writes `artifact-manifest.json` for the project slug. Reference the manifest in the handoff summary and retain it with the assessment artifacts.
