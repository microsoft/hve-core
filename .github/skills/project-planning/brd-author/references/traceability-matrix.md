---
description: 'Author-maintained BRD traceability matrix template with FR-to-AC, FR-to-BG, and BR-to-FR coverage formulas - Brought to you by microsoft/hve-core'
---

# Traceability Matrix Template

This reference defines the shape of the traceability matrix section that appears in every HVE-Core BRD draft. The matrix records the relationships between the five identifier tiers ([FR / AC / NFR / CON / BR](id-schema.md)) and the business goals captured in the BRD's Goals section.

The matrix is authored and maintained in the BRD. The BRD Quality Reviewer verifies the matrix at the Define-to-Govern transition, and the Govern handoff uses it as the source for FR-to-AC and FR-to-BG coverage metrics.

## Relationship Classes

The matrix records three classes of relationship, each with a different enforcement posture:

| Class           | Pair      | Posture       | Enforcement                                                          |
|-----------------|-----------|---------------|----------------------------------------------------------------------|
| Required        | FR to AC | Gate-blocking | Every FR must have at least one AC; coverage gates Define and Govern |
| Govern target   | FR to BG | Waivable      | Every FR should support at least one BG; Govern target is 100%       |
| Informational   | BR to FR | Advisory      | Recording which FRs enforce which business rules aids policy review  |

The three classes share the same matrix section but are presented as separate tables to keep each table single-purpose and easy to scan.

## Required Table: FR-to-AC Coverage

This table is the source of truth for acceptance-criteria coverage. One row per FR; the *Acceptance Criteria* column lists every AC identifier that covers that FR; the *Coverage* column records the count of ACs covering that FR.

```markdown
| FR ID  | FR Title (short)               | Acceptance Criteria      | Coverage |
|--------|--------------------------------|--------------------------|----------|
| FR-001 | Submit timesheet               | AC-001, AC-002, AC-003   | 3        |
| FR-002 | Route timesheet for approval   | AC-004, AC-005           | 2        |
| FR-003 | Notify approver of new entry   | AC-006                   | 1        |
| FR-004 | Export approved timesheet      | (none)                   | 0        |
```

### Coverage Calculation

The FR-to-AC coverage percentage is computed from this table:

$$\text{coverage \%} = \frac{\text{count of FRs with Coverage} \geq 1}{\text{count of FRs in BRD}} \times 100$$

If the BRD has zero FR rows, report `0.0%` coverage. Treat the result as a caution when the BRD is intentionally non-functional-only and as blocking when the active threshold requires functional scope.

In the worked example above, three of four FRs carry at least one AC, so coverage is `75.0%`.

The current rubric posture:

* Hard gate at Define to Govern: greater than or equal to `fr_to_ac_coverage_threshold_pct`, default `80.0`.
* Warning at Govern: less than `100.0%` FR-to-AC coverage emits a reviewer warning recorded in `BRD_QUALITY_REPORT_V1.warnings[]`.

### Row and Column Conventions

* One row per FR. Do not merge rows for related FRs.
* The *FR Title (short)* column is a five-to-eight word summary copied from the FR's `title` field; it exists for reviewer readability and is not authoritative (the FR body in the requirements section is).
* The *Acceptance Criteria* column lists AC identifiers comma-separated, in numeric order, with the literal string `(none)` when no AC covers the FR. Empty cells are not used.
* The *Coverage* column is the integer count of ACs in the cell to its left; `(none)` counts as zero.
* FRs are listed in numeric order of FR ID, not in section order or priority order.

## Govern Target Table: FR-to-Business Goal

This table records which business goal each FR exists to advance. It supports backwards traceability ("why does this FR exist?") and helps reviewers spot FRs that have drifted away from any captured goal.

```markdown
| FR ID  | Business Goal(s) Supported     |
|--------|--------------------------------|
| FR-001 | BG-001, BG-003                 |
| FR-002 | BG-001                         |
| FR-003 | BG-002                         |
| FR-004 | (none)                         |
```

The `BG-###` identifier family is defined in [id-schema.md](id-schema.md). Goals themselves are captured in the BRD's Goals section under the SMART rubric owned by [requirements-definition.md](requirements-definition.md#quality-dimensions-and-rubrics).

### FR-to-BG Coverage Calculation

The FR-to-BG coverage percentage is computed from this table:

$$\text{coverage \%} = \frac{\text{count of FRs with at least one BG link}}{\text{count of FRs in BRD}} \times 100$$

If the BRD has zero FR rows, report `0.0%` coverage. Govern target is `100.0%`. Any gap requires an active waiver in `signoff.waivers[]` before `BRD_TO_PRD_HANDOFF_V1` is emitted.

## Informational Table: BR-to-FR

This table records which FRs enforce which business rules. It is the reverse view of the optional `enforces:` metadata field documented in [`id-schema.md`](id-schema.md) and the parent SKILL.

```markdown
| BR ID  | Business Rule (short)                       | Enforcing FR(s) |
|--------|---------------------------------------------|-----------------|
| BR-001 | Timesheets must be approved within 7 days   | FR-002          |
| BR-002 | Overtime requires explicit manager approval | FR-002, FR-005  |
| BR-014 | Data residency: EU users data stored in EU  | (none)          |
```

The *Enforcing FR(s)* column lists FRs that exist to enforce the business rule. A `(none)` entry is a signal for the reviewer: either an FR is missing, or the business rule is enforced by a non-functional control, an imposed constraint, or an operational procedure outside the BRD's implementation scope.

## Matrix Section Layout

The traceability matrix section of a BRD draft is laid out in this order:

1. `## Traceability Matrix` heading.
2. Optional one-paragraph reading note (for example, "Coverage is computed from the FR↔AC table below.").
3. `### FR-to-AC Coverage` (required table).
4. `### FR-to-Business Goal` (Govern target table).
5. `### BR-to-FR Enforcement` (informational table; same `(no entries)` treatment when omitted).

Sub-section headings are fixed strings so the assessor can locate the FR↔AC coverage table by heading text without parsing the whole BRD.

## Cross-References

* Parent skill: [`../SKILL.md`](../SKILL.md)
* Sibling reference: [`id-schema.md`](id-schema.md)
* Standards registry: [standards-excerpts.md](standards-excerpts.md#isoiecieee-291482018)

> Brought to you by microsoft/hve-core

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
