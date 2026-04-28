---
description: "Phase 5 dual-format work item generation with SCI budget skeletons and mandatory footer disclaimer for Sustainability Planner."
applyTo: '**/.copilot-tracking/sustainability-plans/**'
---

# Sustainability Phase 5 — Backlog Generation (DD-13)

Convert Phase 4 gap classifications ([`#file:./sustainability-gap-analysis.instructions.md`](./sustainability-gap-analysis.instructions.md)) into dual-format work items (Azure DevOps and GitHub Issues) and emit per-workload SCI budget skeletons. Every work item carries the mandatory footer in [Mandatory Footer](#mandatory-footer); every SCI budget carries the Phase 6 inline disclaimers ([`#file:./sustainability-handoff.instructions.md`](./sustainability-handoff.instructions.md)).

Attach the Sustainability Planning disclaimer block from [`#file:../shared/disclaimer-language.instructions.md`](../shared/disclaimer-language.instructions.md) at the top of `sustainability-backlog.md`.

## Decision Rule DD-13 — Dual-Format Output

Every gap that yields a work item is written in both formats. The two formats remain in lockstep — same id, same title, same priority, same body. The user chooses which format to publish at handoff.

| Field      | ADO                                     | GitHub                                          |
|------------|-----------------------------------------|-------------------------------------------------|
| Identifier | Sequential `WI-SUS-{NNN}` (zero-padded) | Temporary `{{SUS-TEMP-N}}` until issue created. |
| Type       | `User Story` or `Task`                  | `enhancement` label                             |
| Priority   | `0|1|2|3` field                         | `priority/p0`, `priority/p1`, ... label         |
| Acceptance | `Acceptance Criteria` field             | `## Acceptance Criteria` heading                |

## Priority Rules

Priority derivation across all planners follows the shared rules in [`#file:../shared/planner-priority-rules.instructions.md`](../shared/planner-priority-rules.instructions.md). Never derive priority from numerical scores.

Assign priority deterministically from the Phase 4 adoption category and the highest available `measurementClass` for the involved control:

| Trigger                                                                            | Priority | Work item theme          |
|------------------------------------------------------------------------------------|----------|--------------------------|
| `instrumentation-required` (deterministic-absent)                                  | P0       | Instrumentation          |
| `measurement-upgrade` (estimated-only — upgrade to deterministic)                  | P1       | Upgrade-to-deterministic |
| `measurement-improvement` (heuristic-only — promote to estimated or deterministic) | P2       | Measurement improvement  |
| `automation-gap`                                                                   | P2       | Control automation       |
| `process-control`                                                                  | P3       | Operational policy       |

Within each priority band, apply the principle ranking from Phase 4: items whose underlying control `appliesToPrinciples` includes `carbon-efficiency` rank above `energy-efficiency`, which ranks above `hardware-efficiency`, which ranks above all other principles.

## Work Item Body Template

Every work item — ADO and GitHub — uses this body shape:

```markdown
## Context

Workload: <project-slug>
Surface(s): <appliesTo>
Framework: <frameworkId>
Control: <controlId> — <control-summary>
Capability: <capabilityId>
Measurement class (current): <deterministic|estimated|heuristic|user-declared|none>
SCI variable: <E|I|M|R|none>

## Problem

<one-paragraph statement sourced from gap rationale>

## Acceptance Criteria

* <criterion 1>
* <criterion 2>
* ...

## Effort

T-shirt size: <XS|S|M|L>

## References

<!-- Each evidence entry is the canonical Evidence row defined in #file:../shared/evidence-citation.instructions.md -->
* Phase 4 gap entry: `gap-analysis.md#<anchor>`
* Framework skill: `<framework-id>@<version>`
* Evidence: `<path>` (Lines <start>-<end>) — <rationale>

> Directional sustainability estimate produced by an AI planner. Not an audited disclosure. Review by a qualified sustainability professional and applicable disclosure-framework counsel (CSRD/ESRS, SEC climate rules, GHG Protocol, TCFD, ISO 14064/14067) is required before external use.
```

The trailing blockquote is the [Mandatory Footer](#mandatory-footer); do not edit its wording.

## SCI Budget Skeletons

For every distinct workload-id encountered in Phase 4 measurement inputs, emit `.copilot-tracking/sustainability-plans/{project-slug}/sci-budgets/{workload-id}.json`:

```json
{
  "workloadId": "<workload-id>",
  "functionalUnit": "<unit-string>",
  "sci": {
    "value": <number-or-null>,
    "units": "gCO2eq/<functional-unit>",
    "measurementClass": "deterministic|estimated|heuristic|user-declared",
    "confidence": "low|medium|high",
    "calculation": {
      "E": { "value": <n>, "units": "kWh", "measurementClass": "...", "source": "..." },
      "I": { "value": <n>, "units": "gCO2eq/kWh", "measurementClass": "...", "source": "..." },
      "M": { "value": <n>, "units": "gCO2eq", "measurementClass": "...", "source": "..." },
      "R": { "value": <n>, "units": "<functional-units>", "measurementClass": "...", "source": "..." }
    }
  },
  "inputs": [
    { "sciVariable": "E|I|M|R", "measurementClass": "...", "value": <n>, "units": "...", "source": "..." }
  ],
  "generatedBy": "Sustainability Planner",
  "generatedAt": "<ISO-8601-UTC>"
}
```

Emission rules:

1. When `E`, `I`, `M`, and `R` are all available with `measurementClass: deterministic`, set the top-level `sci.measurementClass` to `deterministic` and compute the SCI value: `(E × I + M) / R`.
2. When at least one input is `estimated` and none below it, set `sci.measurementClass` to `estimated` and set `confidence` based on the lowest input class:
   * All `estimated` or better → `medium`.
   * Any `heuristic` → `low`.
   * Any `user-declared` → `low`.
3. When inputs are insufficient to compute SCI at all, set `sci.value` to `null` and emit the skeleton with the inputs that are available.
4. The corresponding `.yml` form is emitted in Phase 6 with the verbatim 3-line header from `sustainability-handoff.instructions.md`.

## Mandatory Footer

The following blockquote is appended verbatim to every work item body and to `sustainability-backlog.md`. The wording is hashed by `Test-FsiSustainabilityProfile.ps1`; do **not** edit, abbreviate, reword, or translate it. Drift causes the validator to fail the build.

> Directional sustainability estimate produced by an AI planner. Not an audited disclosure. Review by a qualified sustainability professional and applicable disclosure-framework counsel (CSRD/ESRS, SEC climate rules, GHG Protocol, TCFD, ISO 14064/14067) is required before external use.

## Output

Write the backlog artifact to `.copilot-tracking/sustainability-plans/{project-slug}/sustainability-backlog.md` containing:

* The Sustainability Planning disclaimer block.
* A priority-grouped table of every work item: `id`, `title`, `priority`, `category`, `size`, `surface(s)`, `framework`, `control`.
* The full ADO and GitHub bodies for every item under their `id` heading.
* The Mandatory Footer (verbatim) as the closing blockquote of the document.

Write SCI budget skeletons under `.copilot-tracking/sustainability-plans/{project-slug}/sci-budgets/{workload-id}.json` per workload.

Update `state.json`:

* Populate `state.backlog.items[]` with `{ id, title, priority }`.
* Populate `state.backlog.sciBudgets{}` keyed by workload-id with the path to the emitted skeleton.
* Advance `phase` to `6.handoff` only after explicit user confirmation that the backlog and budgets are complete.

## Phase Exit Gate

The phase advances only when:

* Every Phase 4 classification not in `validated` has at least one work item.
* Every workload-id with at least one measurement input has an SCI budget skeleton on disk.
* The Mandatory Footer is present verbatim in `sustainability-backlog.md` and in every work item body.
* The user has explicitly confirmed advancement.
