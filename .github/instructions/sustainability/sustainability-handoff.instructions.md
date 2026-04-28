---
description: "Phase 6 review and handoff with active-controls.json, sci-budgets, LICENSING.md and reciprocal handoff recommendations for Sustainability Planner."
applyTo: '**/.copilot-tracking/sustainability-plans/**'
---

# Sustainability Phase 6 — Review and Handoff (DD-13)

Validate the assessment, emit machine-readable handoff artifacts with mandatory inline disclaimers, and recommend reciprocal handoffs to the Security, SSSC, and RAI planners. Phase 6 produces the artifacts downstream backlog managers and reviewers consume.

Attach the Sustainability Planning disclaimer block from [`#file:../shared/disclaimer-language.instructions.md`](../shared/disclaimer-language.instructions.md) at the top of every Markdown artifact written by this phase.

Inputs:

* `state.standardsMapping.activeControls[]`, `state.standardsMapping.skipped[]` from Phase 3 ([`#file:./sustainability-standards.instructions.md`](./sustainability-standards.instructions.md)).
* `state.gapAnalysis.*` from Phase 4 ([`#file:./sustainability-gap-analysis.instructions.md`](./sustainability-gap-analysis.instructions.md)).
* `state.backlog.items[]`, `state.backlog.sciBudgets{}` from Phase 5 ([`#file:./sustainability-backlog.instructions.md`](./sustainability-backlog.instructions.md)).
* `state.frameworksDisabled[]` from Phase 1.
* `state.licenseRegister[]` accumulated through Phases 2-3.
* `state.meta.disclaimerVersion` (SHA-256 hash of the rendered disclaimer block).
* `state.workloadAssessment.capabilities[]` (used to detect ML capabilities for RAI handoff trigger).

## Handoff Outputs

Phase 6 writes the following files under `.copilot-tracking/sustainability-plans/{project-slug}/`:

| Path                             | Format | Purpose                                                   |
|----------------------------------|--------|-----------------------------------------------------------|
| `active-controls.json`           | JSON   | Machine-readable export of activated controls and gaps.   |
| `sci-budgets/{workload-id}.json` | JSON   | Per-workload SCI budget (carried forward from Phase 5).   |
| `sci-budgets/{workload-id}.yml`  | YAML   | Per-workload SCI budget (YAML form) with verbatim header. |
| `LICENSING.md`                   | MD     | Bundle attribution and disclaimer drift hash.             |
| `handoff.md`                     | MD     | Human-readable summary, audit appendix, recommendations.  |

### `active-controls.json` Shape

```json
{
  "projectSlug": "<slug>",
  "generatedAt": "<ISO-8601-UTC>",
  "surfaces": ["<surface>", "..."],
  "activeFrameworks": ["<framework-id>", "..."],
  "activeControls": [
    { "frameworkId": "<id>", "controlId": "<id>", "status": "verified|partial|absent|manual", "category": "<adoption-category>" }
  ],
  "skipped": [
    { "frameworkId": "<id>", "controlId": "<id-or-null>", "reason": "<reason>" }
  ],
  "frameworksDisabled": [
    { "id": "<id>", "reason": "<reason>", "atPhase": 1 }
  ],
  "disclaimer": "Directional sustainability estimate produced by an AI planner. Not an audited disclosure. Review by a qualified sustainability professional and applicable disclosure-framework counsel (CSRD/ESRS, SEC climate rules, GHG Protocol, TCFD, ISO 14064/14067) is required before external use."
}
```

### `sci-budgets/{workload-id}.yml` Shape

The YAML form mirrors the JSON skeleton from Phase 5 but prepends the verbatim header from [Mandatory Inline Disclaimers](#mandatory-inline-disclaimers).

### `LICENSING.md` Shape

```markdown
# Sustainability Planning — Bundle Attribution

This assessment loaded the following framework skill bundles:

| Bundle | Version | License | Attribution Required | Loaded At |
|--------|---------|---------|----------------------|-----------|
| <id>   | <ver>   | <lic>   | true|false           | <ISO>     |

Disclaimer source: `.github/instructions/shared/disclaimer-language.instructions.md`
Disclaimer SHA-256 hash: `<state.meta.disclaimerVersion>`
```

`LICENSING.md` is sourced from `state.licenseRegister[]`; one row per registered bundle.

## Coverage Disclosure

Render `state.controlTracker[]` as a table so reviewers can distinguish what was assessed from what was skipped. This section is always rendered (never collapsed):

```markdown
## Coverage Disclosure

The following table records every control referenced during this assessment. Controls with `mappedInPhase3 = false` were not read in Phase 2 standards-mapping and therefore have no gap-analysis evidence; their `suggestedStatus` reflects only structural defaults, not assessment.

| Framework | Control     | Mapped in Phase 2 | Suggested Status                                                  | Notes |
|-----------|-------------|-------------------|-------------------------------------------------------------------|-------|
| {fw-id}   | {controlId} | {true|false}      | {addressed|partial|not-addressed|deferred|not-applicable}         | {why} |
```

When `state.controlTracker[]` is empty, render a single line: `_No controls were tracked during this assessment._` and proceed.

## Reciprocal Handoff Recommendations

Phase 6 always evaluates and conditionally recommends reciprocal handoffs. Each recommendation is rendered in `handoff.md` as a section with a one-paragraph justification and the trigger evidence.

| Target           | Trigger                                                                                                | Always render?         |
|------------------|--------------------------------------------------------------------------------------------------------|------------------------|
| Security Planner | Material Phase 4 finding affects supply-chain dependency choice OR fleet/edge surface present.         | Conditional            |
| SSSC Planner     | Build-system or release-channel choice affects SCI inputs (e.g. CI image churn, workflow concurrency). | Conditional            |
| RAI Planner      | `state.workloadAssessment.capabilities[]` contains `ml-training-job` or `ml-inference-service`.        | Always when triggered. |

When no trigger fires for a target, render a one-line "No recommendation" entry in `handoff.md` so the audit trail records the deliberate decision. Render the trigger evidence cited in each recommendation as the canonical Evidence row defined in [`#file:../shared/evidence-citation.instructions.md`](../shared/evidence-citation.instructions.md).

## Evidence Citation Format

Every evidence pointer surfaced in `handoff.md` (reciprocal-handoff trigger evidence, gap-analysis citations carried into the human-readable summary, audit appendix cross-references) follows the canonical Evidence row defined in [`#file:../shared/evidence-citation.instructions.md`](../shared/evidence-citation.instructions.md). Bare workflow paths without line spans (or the appropriate `kind:` qualifier) are not acceptable evidence in the handoff artifact.

## Audit Appendix

`handoff.md` ends with an audit appendix:

1. **Disabled frameworks** — table sourced verbatim from `state.frameworksDisabled[]` with columns `id`, `reason`, `atPhase`.
2. **Skipped controls** — table sourced verbatim from `state.standardsMapping.skipped[]`.
3. **Refusals** — table sourced verbatim from `state.refusalLog[]` with columns `turnId`, `intentSignal`, `atPhase`, `atTime`.
4. **Loaded bundles** — table sourced verbatim from `state.licenseRegister[]`.

The audit appendix is not optional; it provides the traceability counsel and reviewers require under DD-13.

## Mandatory Inline Disclaimers

The following inline disclaimers are inserted verbatim. Wording, line breaks, and casing are hashed by `Test-FsiSustainabilityProfile.ps1`; do **not** edit, abbreviate, reword, translate, or reflow.

### `active-controls.json` — `disclaimer` field

The top-level `disclaimer` string field is required and MUST contain exactly:

```
Directional sustainability estimate produced by an AI planner. Not an audited disclosure. Review by a qualified sustainability professional and applicable disclosure-framework counsel (CSRD/ESRS, SEC climate rules, GHG Protocol, TCFD, ISO 14064/14067) is required before external use.
```

### `sci-budgets/{workload-id}.yml` — required 3-line header

Every YAML SCI budget file MUST begin with these three lines, in this order, with no blank line above them:

```
# Directional SCI estimate (gCO2eq, per functional unit) generated by an AI planner.
# Measurement-class precedence: deterministic > estimated > heuristic > user-declared.
# Not an audited disclosure; review by qualified sustainability and disclosure-framework counsel required before external use.
```

### `LICENSING.md` — disclaimer citation

`LICENSING.md` MUST cite [`#file:../shared/disclaimer-language.instructions.md`](../shared/disclaimer-language.instructions.md) by path and MUST include the SHA-256 hash recorded in `state.meta.disclaimerVersion`. When `state.meta.disclaimerVersion` is missing or empty, the agent halts Phase 6 and asks the user to re-render the Startup Announcement before retrying.

## Validation Protocol

Before declaring Phase 6 complete, the agent runs the following checks and refuses to proceed on any failure:

1. Every entry in `state.backlog.items[]` is reflected in `sustainability-backlog.md` from Phase 5.
2. Every workload-id in `state.backlog.sciBudgets{}` has both `.json` and `.yml` forms on disk.
3. Every loaded bundle in `state.licenseRegister[]` appears in `LICENSING.md`.
4. The `disclaimer` field of `active-controls.json` matches the verbatim text above byte-for-byte.
5. The first three lines of every `sci-budgets/*.yml` match the verbatim header above byte-for-byte.
6. The audit appendix in `handoff.md` includes all four required tables.

## Output

Update `state.json`:

* Set `state.handoffGenerated` to the ISO 8601 UTC timestamp of successful emission.
* Append a final entry to `skills-loaded.log` summarising the Phase 6 emission (`phase=6.handoff kind=handoff artifacts=<count>`).
* Do not advance `phase` further; Phase 6 is terminal for this assessment.

## Phase Exit Gate

The phase concludes only when:

* All Validation Protocol checks pass.
* All recommended reciprocal handoffs have been rendered (or marked "No recommendation" with reasoning).
* The user has explicitly acknowledged the handoff package.
