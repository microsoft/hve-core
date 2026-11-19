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

### RAI Handoff Fields

Use an HTML description for ADO and a Markdown body with YAML metadata for GitHub. Include ID (`WI-RAI-{NNN}`; temporary `{{RAI-TEMP-N}}` for GitHub), planner, priority, standards, evidence and cross-planner references. Preserve monotonic IDs and record the real issue number after creation. Record `characteristic`, `subcategory`, `principle`, `maturity_level`, and applicable `tradeoff_ref` in the ADO description or GitHub header. Link the threat, control, implementation and verifiable acceptance criteria; include `horizon` in the GitHub header.

Before export, remove secrets, credentials, internal URLs, PII and state JSON or pointers. Replace tracking paths with descriptive citations, make other paths workspace-relative, and retain standards identifiers verbatim. Log the sanitization rules used, not the removed values. Include an unchecked qualified-review box in each item. End each handoff file with the verbatim RAI Planning CAUTION and log each emission in `noticeLog`.

## Autonomy and Output Targets

Confirm the destination and persist the user's tier. Manual emits local drafts only. Partial (default) requires approval of each batch of 5–10 items. Full requires explicit advance authorization for the scoped batch. No tier waives independent human review: never check the human-review box or send unchecked items to the backlog.

## Final Handoff Summary

When presenting the final handoff to the user, render the produced artifacts as a descriptive table rather than a flat list of filenames. The phase deliverables are sections of the single consolidated `rai-plan.md`; group rows by the phase that produced each section, link to the real relative path with the section anchor under the project slug folder, and give each row a short "what it contains" description so the user knows why to open it. The backlog-handoff files and the signing manifest remain separate files.

Apply these rules to the artifacts table:

* Use relative links to the actual files, never absolute or editor-shell paths. Do not wrap links in backticks.
* Keep one row per deliverable with columns for phase, artifact, and a concise description of the contents.
* Replace bracketed placeholders with the values from session state; omit rows for artifacts the session did not produce.

| Phase         | Target under the project slug                | What it contains                                       |
|---------------|----------------------------------------------|--------------------------------------------------------|
| 1 — Scoping   | `assessment-content.md`                      | Template-aligned content when a template was supplied  |
| 1 — Scoping   | `rai-plan.md#system-definition`              | System boundary, components, data flows and use        |
| 1 — Scoping   | `rai-plan.md#stakeholder-impact`             | Affected stakeholders and impacts                      |
| 2 — Risk      | `rai-plan.md#risk-classification-screening`  | Risk indicators and confirmed assessment depth         |
| 3 — Standards | `rai-plan.md#standards-mapping`              | Mapping across the selected characteristics            |
| 4 — Threats   | `rai-plan.md#threat-addendum`                | Threat IDs and high-concern subset                     |
| 5 — Impact    | `rai-plan.md#control-surface-catalog`        | Controls and framework coverage                        |
| 5 — Impact    | `rai-plan.md#evidence-register`              | Evidence backing each control claim                    |
| 5 — Impact    | `rai-plan.md#tradeoffs`                      | Tradeoffs needing human adjudication                   |
| 6 — Handoff   | `rai-plan.md#review-summary`                 | Posture, gaps, and the human-review gate               |
| 6 — Handoff   | `ado-backlog-handoff.md`                     | ADO drafts when this target was selected               |
| 6 — Handoff   | `github-backlog-handoff.md`                  | GitHub drafts when this target was selected            |
| 6 — Handoff   | `artifact-manifest.json`                     | SHA-256 manifest when generated with consent           |

## Content Hygiene

Keep the handoff clear and reviewable:

* preserve RAI characteristic names and framework references
* avoid speculative claims that are not supported by the session evidence
* note when a recommendation needs human review or compliance validation

### Artifact Signing

After backlog generation, offer the workspace's trusted signing capability if available (for example, its declared `rai:sign` task). Only on user consent, generate a SHA-256 `artifact-manifest.json` scoped to the assessment and sign with cosign when configured and authorized. Retain the manifest and report its actual verification status. Without a verified signature, do not label the artifacts signed.
