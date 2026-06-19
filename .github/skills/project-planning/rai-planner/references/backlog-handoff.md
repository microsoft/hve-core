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

## Final Handoff Summary

When presenting the final handoff to the user, render the produced artifacts as a descriptive table rather than a flat list of filenames. Group rows by the phase that produced each artifact, link to the real relative paths under the project slug folder, and give each artifact a short "what it contains" description so the user knows why to open it.

Apply these rules to the artifacts table:

* Use relative links to the actual files, never absolute or editor-shell paths. Do not wrap links in backticks.
* Keep one row per artifact with columns for phase, artifact, and a concise description of the contents.
* Replace bracketed placeholders with the values from session state; omit rows for artifacts the session did not produce.

| Phase         | Artifact                                                        | What it contains                                                                                            |
|---------------|-----------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------|
| 1 — Scoping   | [system-definition-pack.md]({slug}/system-definition-pack.md)   | System boundary, components, data flows, and intended use                                                   |
| 1 — Scoping   | [stakeholder-impact-map.md]({slug}/stakeholder-impact-map.md)   | Affected stakeholders and how each is impacted                                                              |
| 3 — Standards | [rai-standards-mapping.md]({slug}/rai-standards-mapping.md)     | Framework mapping across the selected trustworthiness characteristics                                       |
| 4 — Threats   | [rai-threat-addendum.md]({slug}/rai-threat-addendum.md)         | Identified threats with IDs and the high-concern subset                                                     |
| 5 — Impact    | [control-surface-catalog.md]({slug}/control-surface-catalog.md) | Controls and their coverage across the framework functions                                                  |
| 5 — Impact    | [evidence-register.md]({slug}/evidence-register.md)             | Evidence backing each control claim                                                                         |
| 5 — Impact    | [rai-tradeoffs.md]({slug}/rai-tradeoffs.md)                     | Tradeoffs needing human adjudication                                                                        |
| 6 — Handoff   | [rai-review-summary.md]({slug}/rai-review-summary.md)           | Posture, gaps, and the human-review gate                                                                    |
| 6 — Handoff   | [ado-backlog-handoff.md]({slug}/ado-backlog-handoff.md)         | Drafted backlog items in ADO format (present when the target system includes ADO), ready after review       |
| 6 — Handoff   | [github-backlog-handoff.md]({slug}/github-backlog-handoff.md)   | Drafted backlog items in GitHub format (present when the target system includes GitHub), ready after review |

## Content Hygiene

Keep the handoff clear and reviewable:

* preserve RAI characteristic names and framework references
* avoid speculative claims that are not supported by the session evidence
* note when a recommendation needs human review or compliance validation

### Artifact Signing

After backlog generation and before broader distribution, the RAI planner may sign session artifacts. Use `npm run rai:sign -- -ProjectSlug {slug}`. The signing workflow produces a SHA-256 manifest for the generated artifacts, optionally signs them with cosign when the environment is configured for it, and writes `artifact-manifest.json` for the project slug. Reference the manifest in the handoff summary and retain it with the assessment artifacts.
