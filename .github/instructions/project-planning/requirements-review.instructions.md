---
description: 'Review-phase rules for the Requirements Builder agent: gap surfacing, evidence completeness, and applicability mismatch detection.'
applyTo: '**/.copilot-tracking/requirements-sessions/**'
---

# Requirements Builder — Phase 5: Review

Phase 5 audits the drafted artifacts before handoff. The agent does not silently fix issues — it surfaces them to the user with a clear remediation path.

## Gap Surfacing

For every selected framework:

* Report any `state.drafts.outputs[].sectionsPending[]` that is non-empty as a Phase 4 completeness gap. List the item ids and the reason they were skipped (token unresolved, hand-edit drift, applicability changed, …).
* Report any `state.drafts.outputs[].sectionsSkipped[]` entries with their drift hashes so the user can audit which hand-edited sections were preserved.

## Evidence Completeness

Every claim drafted into a `success-metrics`, `scope`, `requirements-functional`, `requirements-non-functional`, or `constraints` style section must be traceable. For each draft:

1. Resolve the section text against the source FSI item's `inputs[].name` list.
2. For each resolved input value, verify a matching entry exists in `intake/evidence.yml` (by `claimId` or by exact value match) **or** that the section text contains an explicit `inferred` marker (`<!-- inferred: <rationale> -->`).
3. Surface every claim missing both a citation and an `inferred` marker as ❓ for the user; record the resolution path under `state.drafts.outputs[].reviewFindings[]`.

## Applicability Mismatch Detection

For every drafted section, re-check the source item's `applicability.audience` against the active persona set in `state.intake.answeredQuestions[]` (theme `Personas`). When a section was drafted for an item whose audience does not match (e.g. a sponsor-audience item drafted for an engineering-only persona set), warn the user with the option to retain or remove the section. Record the resolution under `state.drafts.outputs[].reviewFindings[]` with `kind: applicability-mismatch`.

## Persistence

* `state.drafts.outputs[].reviewFindings[]` gains one entry per finding: `{ id, kind, sectionId, severity, message, resolution?, resolvedAt? }`.
* Findings remain in state through handoff so the Phase 6 coverage disclosure can render them.

## Exit Criteria

Phase 5 is complete when:

* Every finding with `severity: blocker` is resolved (the user has explicitly accepted, deferred, or fixed it).
* The user has confirmed they have reviewed any `severity: warning` findings.

Append a one-paragraph summary of finding counts and resolutions to `compaction-log.md` and advance to Phase 6.
