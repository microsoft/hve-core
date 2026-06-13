---
description: 'BRD traceability matrix template with required FR-to-AC coverage, optional FR-to-business-goal mapping, informational business-rule-to-FR mapping, and the FR-to-AC coverage column that supports the brd-standard-assessor coverage math - Brought to you by microsoft/hve-core'
---

# Traceability Matrix Template

This reference defines the shape of the traceability matrix section that appears in every HVE-Core BRD draft. The matrix records the relationships between the four identifier tiers ([FR / AC / NFR / BR](id-schema.md)) and the business goals captured in the BRD's Goals section.

The matrix is consumed by the `brd-standard-assessor` subagent at the Define→Govern transition. The FR↔AC coverage column in particular is the source of truth for the assessor's coverage-percentage calculation.

## Relationship Classes

The matrix records three classes of relationship, each with a different enforcement posture:

| Class           | Pair      | Posture       | Enforcement                                                          |
|-----------------|-----------|---------------|----------------------------------------------------------------------|
| Required        | FR ↔ AC   | Gate-blocking | Every FR must have ≥1 AC; coverage % gates Define→Govern             |
| Optional        | FR ↔ BG   | Recommended   | Recording the goal each FR supports is encouraged but not blocking   |
| Informational   | BR ↔ FR   | Advisory      | Recording which FRs enforce which business rules aids policy review  |

The three classes share the same matrix section but are presented as separate tables to keep each table single-purpose and easy to scan.

## Required Table: FR ↔ AC Coverage

This table is the source of truth for the assessor's coverage math. One row per FR; the *Acceptance Criteria* column lists every AC identifier that covers that FR; the *Coverage* column records the count of ACs covering that FR.

```markdown
| FR ID  | FR Title (short)               | Acceptance Criteria      | Coverage |
|--------|--------------------------------|--------------------------|----------|
| FR-001 | Submit timesheet               | AC-001, AC-002, AC-003   | 3        |
| FR-002 | Route timesheet for approval   | AC-004, AC-005           | 2        |
| FR-003 | Notify approver of new entry   | AC-006                   | 1        |
| FR-004 | Export approved timesheet      | (none)                   | 0        |
```

### Coverage % Calculation (Supports DD-09)

The coverage percentage the `brd-standard-assessor` reports is computed from this table:

$$\text{coverage \%} = \frac{\text{count of FRs with Coverage} \geq 1}{\text{count of FRs in BRD}} \times 100$$

In the worked example above, three of four FRs carry at least one AC, so coverage is 75 %.

The current rubric posture:

* **Hard gate at Define→Govern**: ≥ 80 % FR↔AC coverage.
* **Warning at Govern**: < 100 % FR↔AC coverage emits a non-blocking reviewer-warning recorded in `BRD_QUALITY_REPORT_V1.warnings[]`.

### Row and Column Conventions

* One row per FR. Do not merge rows for related FRs.
* The *FR Title (short)* column is a five-to-eight word summary copied from the FR's `title` field; it exists for reviewer readability and is not authoritative (the FR body in the requirements section is).
* The *Acceptance Criteria* column lists AC identifiers comma-separated, in numeric order, with the literal string `(none)` when no AC covers the FR. Empty cells are not used.
* The *Coverage* column is the integer count of ACs in the cell to its left; `(none)` counts as zero.
* FRs are listed in numeric order of FR ID, not in section order or priority order.

## Optional Table: FR ↔ Business Goal

This table records which business goal each FR exists to advance. It supports backwards traceability ("why does this FR exist?") and helps reviewers spot FRs that have drifted away from any captured goal.

```markdown
| FR ID  | Business Goal(s) Supported     |
|--------|--------------------------------|
| FR-001 | BG-01, BG-03                   |
| FR-002 | BG-01                          |
| FR-003 | BG-02                          |
| FR-004 | (none)                         |
```

The `BG-` prefix is the BRD's business-goal identifier prefix; goals themselves are captured in the BRD's Goals section under the SMART rubric owned by the [`requirements-definition`](../../requirements-definition/SKILL.md#quality-dimensions-and-rubrics) skill.

An FR row with `(none)` in this column is permitted but is surfaced by the assessor as an informational note (not a warning or gate). It usually indicates either a missing goal in the Goals section or an FR that has expanded beyond its originating goal.

## Informational Table: BR ↔ FR

This table records which FRs enforce which business rules. It is the reverse view of the optional `enforces:` metadata field documented in [`id-schema.md`](id-schema.md) and the parent SKILL.

```markdown
| BR ID  | Business Rule (short)                       | Enforcing FR(s) |
|--------|---------------------------------------------|-----------------|
| BR-001 | Timesheets must be approved within 7 days   | FR-002          |
| BR-002 | Overtime requires explicit manager approval | FR-002, FR-005  |
| BR-014 | Data residency: EU users data stored in EU  | (none)          |
```

The *Enforcing FR(s)* column lists FRs that exist to enforce the business rule. A `(none)` entry is a signal for the reviewer: either an FR is missing, or the business rule is enforced by a non-functional control (a security NFR, an infrastructure constraint, or an operational procedure) and is not the BRD's responsibility to implement directly. In v1 of the schema the `brd-standard-assessor` does not gate on this table; it is included for human reviewer use.

## Matrix Section Layout

The traceability matrix section of a BRD draft is laid out in this order:

1. `## Traceability Matrix` heading.
2. Optional one-paragraph reading note (for example, "Coverage is computed from the FR↔AC table below.").
3. `### FR ↔ AC Coverage` (required table).
4. `### FR ↔ Business Goal` (optional table; section header is still rendered with `(no entries)` body when the project chooses to omit it).
5. `### BR ↔ FR Enforcement` (informational table; same `(no entries)` treatment when omitted).

Sub-section headings are fixed strings so the assessor can locate the FR↔AC coverage table by heading text without parsing the whole BRD.

## Cross-References

* Parent skill: [`../SKILL.md`](../SKILL.md)
* Sibling reference: [`id-schema.md`](id-schema.md)
* External cite-only: ISO/IEC/IEEE 29148:2018 §6.2.3 (traceability) - [https://www.iso.org/standard/72089.html](https://www.iso.org/standard/72089.html)

> Brought to you by microsoft/hve-core

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
