---
description: 'Canonical five-tier requirement identifier schema (FR / AC / NFR / CON / BR) and bidirectional traceability matrix conventions used across the HVE-Core BRD Builder workflow - Brought to you by microsoft/hve-core'
---

# Traceability and Naming — Skill Entry

## Overview

This skill owns two BRD-wide conventions: the identifier schema used to label every requirement-like statement in a BRD draft, and the traceability matrix shape used to record relationships between those statements. Both are structural conventions of the HVE-Core BRD template; they exist so that downstream consumers (the BRD Quality Reviewer, the PRD handoff, and any tooling that parses BRD frontmatter) can rely on a consistent vocabulary.

The canonical schema is defined in [id-schema.md](id-schema.md). It has five requirement tiers: `FR-###` for functional requirements, `AC-###` for acceptance criteria, `NFR-###` for non-functional requirements, `CON-###` for imposed constraints, and `BR-###` for business rules. It also defines adjacent `BG-###` business goals and `DD-###` design decisions. Requirement prefix strings are configurable only through BRD frontmatter `requirement_id_prefixes`.

This file is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

## When to Apply

Apply this skill when:

* Assigning an identifier to any newly captured requirement, acceptance criterion, non-functional requirement, constraint, or business rule during the Define phase.
* Reviewing a BRD draft for identifier-prefix consistency before the Define→Govern transition.
* Authoring or refreshing the traceability matrix section of a BRD draft.
* Computing acceptance-criteria coverage and business-goal coverage for the BRD Quality Reviewer rubric.
* Translating a BRD's identifier set into downstream PRD or test artifacts that need to back-reference BRD requirements.

## Five-Tier Identifier Schema

The HVE-Core BRD template partitions every captured requirement-like statement into one of five namespaces. Prefix and digit rules are owned by [id-schema.md](id-schema.md):

| Tier | Default prefix | Captures                                                  | Owning skill                                         |
|------|----------------|-----------------------------------------------------------|------------------------------------------------------|
| FR   | `FR`           | Functional requirements (observable solution behaviors)   | [`requirements-definition`](requirements-definition.md) |
| AC   | `AC`           | Acceptance criteria (testable conditions on FRs)          | [`requirements-definition`](requirements-definition.md#acceptance-criteria) |
| NFR  | `NFR`          | Non-functional requirements (ISO/IEC 25010 categories)    | [`requirements-definition`](requirements-definition.md#quality-dimensions-and-rubrics) |
| CON  | `CON`          | Constraints (imposed boundaries on the solution or its delivery) | [`requirements-definition`](requirements-definition.md#requirement-categories) |
| BR   | `BR`           | Business rules, policies, regulatory obligations          | [`requirements-definition`](requirements-definition.md#requirement-categories) |

The five namespaces are kept separate because each is consumed differently downstream: FRs become PRD features, ACs become test cases, NFRs become quality gates, CONs bound the solution space, and BRs become policy controls. Collapsing namespaces (for example, prefixing acceptance criteria as `FR-###.a`) loses that downstream separation and is therefore not supported.

Per-BRD override of requirement prefix strings is supported through the YAML frontmatter `requirement_id_prefixes` field. The namespace count, hyphen separator, and numeric suffix rule are not configurable. Full regex patterns and example identifiers are documented in [id-schema.md](id-schema.md).

## Traceability Matrix

The HVE-Core BRD template includes a single traceability matrix section that records the relationships between the five identifier tiers and the business goals captured in the BRD's Goals section. The matrix uses three relationship classes:

* **Required**: FR to AC. Every FR must have at least one AC; the matrix is the source for FR-to-AC coverage.
* **Govern target**: FR to BG. Every FR should support at least one `BG-###`; Govern targets `100.0%` coverage and requires a waiver for gaps.
* **Informational**: BR to FR. Recording which FRs enforce which business rules is helpful for downstream policy review and human review.

The matrix template, row and column conventions, the FR↔AC coverage column, and worked examples are documented in [`traceability-matrix.md`](traceability-matrix.md).

### Optional Authoring Convention: `enforces`

An FR may declare an `enforces: [BR-###, BR-###]` field in its metadata block to record which business rules the FR exists to enforce. The author-maintained BR-to-FR table is the visible review surface for this relationship.

## Decision Tree

Use this quick-select when assigning an identifier:

1. Does the statement describe a behavior the solution must produce? Assign `FR-###`.
2. Does the statement describe a testable condition on a specific FR (or set of FRs)? Assign `AC-###` and record the FR(s) it covers in the matrix.
3. Does the statement describe a measurable quality property of the solution (performance, security, availability, etc.)? Assign `NFR-###` under the appropriate ISO/IEC 25010 category.
4. Is the statement an imposed boundary on the solution or its delivery that is not negotiable within the BRD scope? Assign `CON-###` and record the imposing source.
5. Does the statement describe a policy, regulatory obligation, or operating rule that the solution must respect but does not itself implement as a single behavior? Assign `BR-###` and optionally record which FRs enforce it.
6. Is the statement a desired outcome with no described behavior? It is a business goal, not a requirement; record it as `BG-###` in the Goals section and decompose during Define.
7. Is the statement an authoring or scope choice that affects downstream interpretation? Record it as `DD-###` in the Design Decisions section.

## References

Internal:

* [id-schema.md](id-schema.md) - Requirement-tier, business-goal, and design-decision namespace definitions plus regex validation patterns.
* [traceability-matrix.md](traceability-matrix.md) - Matrix template, row and column conventions, FR↔AC coverage column, and worked examples.
* [design-decisions.md](design-decisions.md) - Design decision registry for `DD-###` entries.
* [`requirements-definition`](requirements-definition.md) - FR / AC / NFR / CON / BR taxonomy, canonical requirement-statement form, acceptance criteria patterns (`AC-###`), and ISO/IEC 25010 NFR category taxonomy used to organize `NFR-###` items.

External (cite-only, no embedded text):

* ISO/IEC/IEEE 29148:2018 §6.2.3 (traceability) - [https://www.iso.org/standard/72089.html](https://www.iso.org/standard/72089.html)
* ISO/IEC 25010 (NFR quality model that scopes the `NFR-###` namespace) - [https://www.iso.org/standard/35733.html](https://www.iso.org/standard/35733.html)

## License

Original content in this skill is licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), copyright (C) Microsoft Corporation. The five-tier namespace partitioning and the matrix conventions documented here are HVE-Core conventions; the outbound ISO references above are cited by name and clause only.

> Brought to you by microsoft/hve-core

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
