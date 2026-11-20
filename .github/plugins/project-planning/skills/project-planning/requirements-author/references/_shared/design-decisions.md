---
description: 'Design decision registry for BRD DD identifiers and downstream traceability'
---

# BRD Design Decisions

This reference defines how BRD authors record `DD-###` design decision codes. Design decisions are adjacent identifiers, not requirement tiers. Their identifier rules are owned by [id-schema.md](id-schema.md).

## When To Record A Decision

Record a `DD-###` entry when a decision affects:

* BRD scope boundaries or exclusions
* Requirement taxonomy or classification
* Traceability interpretation
* Prioritization rationale
* Handoff assumptions for PRD consumers
* Waivers or accepted quality tradeoffs

Do not create a design decision for routine wording edits, obvious typo fixes, or decisions already captured as an approved constraint, business rule, or signoff waiver.

## Registry Shape

Use this shape in the BRD Design Decisions section:

```markdown
| Decision ID | Decision                               | Rationale                          | Decision Maker | Date       | Related IDs    |
|-------------|----------------------------------------|------------------------------------|----------------|------------|----------------|
| DD-008      | Use MoSCoW as the BRD priority scheme. | Aligns BRD and PRD handoff fields. | Product Lead   | 2026-06-08 | BG-001, FR-001 |
```

## Rules

* Use `DD-###` with at least three digits.
* Keep identifiers stable after review begins.
* Link related `BG-###`, `FR-###`, `CON-###`, `BR-###`, or waiver IDs when the decision affects traceability.
* Use a new decision entry when a prior decision changes materially; do not rewrite historical rationale without noting the replacement decision.

## Cross-References

* [id-schema.md](id-schema.md) - Canonical identifier pattern for `DD-###`.
* [traceability-naming.md](traceability-naming.md) - Decision tree for choosing requirement, goal, and decision identifiers.
* [brd-to-prd-handoff-v1.md](../brd/brd-to-prd-handoff-v1.md) - Handoff contract that carries downstream consumer notes and waivers.


