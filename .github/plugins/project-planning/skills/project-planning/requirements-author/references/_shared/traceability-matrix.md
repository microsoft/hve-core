---
description: 'Configurable traceability matrix templates and coverage calculations for requirements-author consumers'
---

# Traceability Matrix Template

This reference defines neutral traceability matrix mechanics for requirements-author consumers. It does not assume fixed identifier prefixes or BRD-only relationship pairs. Each consumer supplies the active identifier families from [id-schema.md](id-schema.md) and the relationship rules it wants the matrix to track.

## Relationship Classes

The matrix records configured relationship classes, each with a source family, target family, and enforcement posture.

| Class               | Required configuration                             | Shared interpretation                                                  |
|---------------------|----------------------------------------------------|------------------------------------------------------------------------|
| Required coverage   | Source family, target family, minimum target count | Missing targets fail the consumer's active quality rule                |
| Target coverage     | Source family, target family, target percentage    | Missing targets are measured against a consumer-owned target           |
| Informational trace | Source family, target family                       | Links aid review and handoff without shared scoring semantics          |
| Optional trace      | Source family, target family                       | Links are allowed when useful; no completeness calculation is required |

Consumer overlays decide which relationship classes block, warn, require a waiver, or remain advisory.

## Configured Relationship Example

```yaml
traceability_relationships:
  requirement_to_acceptance:
    source_family: functional_requirement
    target_family: acceptance_criterion
    posture: required
    minimum_targets_per_source: 1
    source_label: "Functional requirement"
    target_label: "Acceptance criteria"
  requirement_to_goal:
    source_family: functional_requirement
    target_family: business_goal
    posture: target
    target_coverage_pct: 100.0
    source_label: "Functional requirement"
    target_label: "Business goals"
  rule_to_requirement:
    source_family: business_rule
    target_family: functional_requirement
    posture: informational
    source_label: "Business rule"
    target_label: "Enforcing requirements"
```

The example preserves existing BRD relationships while keeping the shared matrix parameterized. A PRD consumer can configure feature-to-user-story, user-story-to-acceptance-criterion, feature-to-metric, risk-to-mitigation, or other pairs.

## Coverage Table Template

Use one table per configured relationship so the source, target, and coverage columns remain unambiguous.

```markdown
| Source ID | Source title (short) | Target ID(s)   | Coverage |
|-----------|----------------------|----------------|----------|
| FR-001    | Submit timesheet     | AC-001         | 1        |
| FR-002    | Route for approval   | AC-002, AC-003 | 2        |
| FR-003    | Notify approver      | (none)         | 0        |
```

Column semantics:

* `Source ID` uses the configured source-family prefix.
* `Source title (short)` is for reviewer readability and is not authoritative.
* `Target ID(s)` lists configured target-family identifiers in numeric order, separated by commas.
* `Coverage` is the count of target identifiers in the target cell.
* `(none)` is the literal marker for no linked targets; empty cells are not used.

## Coverage Calculation

For required or target coverage relationships, compute:

```text
coverage percentage = count of source rows meeting minimum target count / count of source rows * 100
```

Shared zero-row behavior:

* If the source family has zero rows, report `0.0%` and include a note that no source rows were present.
* The shared reference does not decide whether zero source rows are acceptable.
* Consumer overlays decide whether zero source rows are informational, cautionary, blocking, or waiver-bound.

This keeps the zero functional-requirement BRD disposition out of shared scope. BRD-specific handling belongs in BRD quality overlays.

## Informational Trace Template

Informational relationships use the same one-table-per-relationship shape, without coverage scoring.

```markdown
| Source ID | Source title (short) | Target ID(s) |
|-----------|----------------------|--------------|
| BR-001    | Approval threshold   | FR-002       |
| BR-002    | Residency policy     | (none)       |
```

The target column can use `(none)` to make gaps visible for human review without assigning shared severity.

## Matrix Section Layout

Consumers can choose their section headings, but each relationship table should keep a stable heading so tooling can locate it.

Recommended layout:

1. Traceability matrix heading.
2. Optional reading note naming the configured relationship rules.
3. One subsection per required or target coverage relationship.
4. One subsection per informational or optional relationship.

## Cross-References

* Parent skill: [`../../SKILL.md`](../../SKILL.md)
* Sibling reference: [id-schema.md](id-schema.md)
* Sibling reference: [traceability-naming.md](traceability-naming.md)
* Standards registry: [standards-excerpts.md](standards-excerpts.md#isoiecieee-291482018)


