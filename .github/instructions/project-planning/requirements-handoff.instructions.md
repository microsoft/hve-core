---
description: 'Handoff-phase rules for the Requirements Builder agent: emit active-requirements index, coverage disclosure, and downstream recommendations.'
applyTo: '**/.copilot-tracking/requirements-sessions/**'
---

# Requirements Builder — Phase 6: Handoff

Phase 6 emits three handoff artifacts under `.copilot-tracking/requirements-sessions/{slug}/handoff/` and updates `state.handoff` with their resolved paths.

## `handoff/active-requirements.json`

Machine-readable index of every drafted document. Schema:

```json
{
  "schemaVersion": "1.0.0",
  "slug": "<state.meta.slug>",
  "generatedAt": "<ISO-8601>",
  "drafts": [
    {
      "frameworkId": "requirements-prd",
      "frameworkVersion": "1.0.0",
      "path": "docs/prds/<slug>.md",
      "format": "markdown",
      "sha256": "<file-bytes-sha256>",
      "sectionsCompleted": ["vision", "personas", ...],
      "sectionsSkipped": [{ "id": "instrumentation", "reason": "deferred-to-v1.1" }]
    }
  ],
  "intake": {
    "evidencePath": "intake/evidence.yml",
    "stakeholdersPath": "intake/stakeholders.yml"
  }
}
```

Every `path` is repo-relative. Persist the resolved path in `state.handoff.activeRequirementsPath`.

## `handoff/coverage-disclosure.md`

Human-readable summary intended to ship alongside the drafted documents. Required sections:

* **Disclaimer** — render the canonical text from [`#file:../shared/disclaimer-language.instructions.md`](../shared/disclaimer-language.instructions.md) and reference `state.meta.disclaimerVersion` (sha256) for pinning.
* **Frameworks Active** — table of selected frameworks with id, version, output path, and section completion count.
* **Frameworks Disabled** — table of frameworks marked `disabled: true` with `disabledReason` and `disabledAtPhase` (audit trail required by the atomic-disabled rule in `requirements-state.schema.json`).
* **Open Findings** — every Phase 5 review finding still in non-resolved state, grouped by severity.
* **Evidence Sources** — list of inputs read from `intake/evidence.yml` and any external references cited. Evidence row formatting (path, line span, kind qualifiers) defers to the canonical rule in [`#file:../shared/evidence-citation.instructions.md`](../shared/evidence-citation.instructions.md).

Persist the resolved path in `state.handoff.coverageDisclosurePath`.

## `handoff/downstream-recommendations.md`

Conditional next-step guidance for the six downstream entrypoints. For each entry, render the recommendation only when the listed precondition is met by the active framework set or intake findings:

| Downstream agent / prompt | Invoke when                                                                                                | Suggested entrypoint                                                 |
|---------------------------|------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------|
| `rai-planner`             | Initiative includes any AI/ML capability, automated decisioning, or content generation surfaced in intake. | `/rai-plan-from-prd` referencing `docs/prds/<slug>.md`.              |
| `sssc-planner`            | Initiative ships software that consumes third-party packages, container images, or build pipelines.        | `/sssc-from-prd` referencing `docs/prds/<slug>.md`.                  |
| `sustainability-planner`  | Initiative has measurable compute/storage/network footprint or sustainability goals captured in intake.    | `/sustainability-from-prd` referencing `docs/prds/<slug>.md`.        |
| `accessibility-planner`   | Initiative ships any user-facing surface (web, desktop, mobile, voice).                                    | Invoke `accessibility-planner` referencing the drafted requirements. |
| `ado-prd-to-wit`          | User confirms ADO is the backlog target.                                                                   | `/ado-prd-to-wit` referencing `docs/prds/<slug>.md`.                 |
| `jira-prd-to-wit`         | User confirms Jira is the backlog target.                                                                  | `/jira-prd-to-wit` referencing `docs/prds/<slug>.md`.                |

Persist each recommendation in `state.handoff.downstreamRecommendations[]` with `{ target, rationale, priority }` where `priority` follows the categorical model in [`#file:../shared/planner-priority-rules.instructions.md`](../shared/planner-priority-rules.instructions.md).

## Exit Criteria

Phase 6 is complete when:

* All three handoff files exist on disk and validate (`active-requirements.json` parses; `coverage-disclosure.md` and `downstream-recommendations.md` lint clean).
* `state.handoff.activeRequirementsPath`, `state.handoff.coverageDisclosurePath`, and `state.handoff.downstreamRecommendations[]` are populated.
* `state.phase` is set to `6.handoff`.

Append a final summary entry to `compaction-log.md` listing the three handoff paths and the active framework ids; the session is now ready to hand off.
