---
description: 'Neutral quality status taxonomy and score-to-status mechanics for requirements-author consumers'
---

# Quality Rubric

This reference defines shared quality-status mechanics for requirements-author consumers. It supplies a status taxonomy, generic score anchors, and rollup conventions. It does not define document phases, gate decisions, blocking thresholds, reviewer agent names, or BRD/PRD payload fields.

Consumer overlays decide which dimensions to score, which thresholds apply, and how statuses affect workflow progress.

## Status Taxonomy

Every quality finding rolls up to exactly one status.

| Status           | Meaning                                                                              | Typical use                                          |
|------------------|--------------------------------------------------------------------------------------|------------------------------------------------------|
| `COVERED`        | The item meets the configured quality bar                                            | Passing evidence                                     |
| `CAUTION`        | The item has a concern worth surfacing but does not fail the shared rubric by itself | Review-needed evidence                               |
| `RISK`           | The item fails the configured quality bar or cannot be evaluated as written          | Repair or consumer-owned waiver evidence             |
| `NOT_APPLICABLE` | The item is intentionally out of scope and has a rationale                           | Excluded from calculations while retaining rationale |

Findings emit statuses and supporting evidence. Consumer-specific reports own fields such as gate decisions, exit decisions, waivers, or workflow transitions.

## Generic Score Scale

When a consumer uses numeric scoring, use the following neutral 0-3 scale.

| Score | Anchor name | Status contribution | Meaning                                                                |
|-------|-------------|---------------------|------------------------------------------------------------------------|
| `0`   | Absent      | `RISK`              | The attribute is not addressed or cannot be evaluated                  |
| `1`   | Implied     | `CAUTION`           | The attribute is only implied or depends on reader inference           |
| `2`   | Explicit    | `COVERED`           | The attribute is explicit enough for downstream use                    |
| `3`   | Traceable   | `COVERED`           | The attribute is explicit, evidenced, and linked to supporting context |

Consumers can define stricter named anchors in document-specific overlays. Shared mechanics only require the score-to-status mapping above when numeric scores are emitted.

## Row-Level Rollup

When an item has several attribute scores, its row-level status is the worst status across those attributes.

Severity order:

```text
RISK > CAUTION > COVERED
```

`NOT_APPLICABLE` is excluded from severity rollup when a rationale is recorded.

## Binary Checks

Some quality checks are binary, such as a category-presence check or a pass/fail goal review. The shared mapping is:

| Observation                                                            | Status           |
|------------------------------------------------------------------------|------------------|
| Configured evidence is present or passes                               | `COVERED`        |
| Configured evidence is absent but the absence is acceptable for review | `CAUTION`        |
| Configured evidence is absent and violates the consumer rule           | `RISK`           |
| The check is explicitly out of scope with rationale                    | `NOT_APPLICABLE` |

## Coverage Metrics

Coverage percentages come from configured relationship tables in [traceability-matrix.md](traceability-matrix.md). The shared rubric can surface coverage as evidence, but it does not decide whether a coverage percentage blocks progress.

The zero-source-row note in [traceability-matrix.md](traceability-matrix.md) is intentionally neutral. BRD-specific zero functional-requirement handling belongs in BRD overlays because it depends on BRD scope and gate posture.

## Authoring Conventions for Findings

* Emit the status alongside the underlying score, pass/fail value, or coverage metric.
* Include a concise finding description for `RISK` and `CAUTION` rows.
* Name the specific attribute, category, relationship, or evidence gap causing the status.
* Do not aggregate independent dimensions into one composite score unless a consumer overlay explicitly defines that aggregation.
* Do not include workflow decision fields in neutral findings.
* Link to the source reference that defines each scored attribute instead of restating restricted standards text.

## References

* [requirements-definition.md](requirements-definition.md) - Neutral requirement categories, statement form, and acceptance-criteria guidance.
* [iso-29148-quality-attrs.md](iso-29148-quality-attrs.md) - Neutral individual-requirement quality characteristics.
* [traceability-matrix.md](traceability-matrix.md) - Coverage metric mechanics.
* [smart-rubric.md](smart-rubric.md) - SMART goal rubric.
* [standards-excerpts.md](standards-excerpts.md) - Cite-only registry for external standards.

## License

This rubric is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Third-party standards referenced by related rubrics are cited by name only and remain the property of their respective rights holders.


