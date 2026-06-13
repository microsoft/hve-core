---
name: traceability-naming
description: 'Canonical four-tier requirement identifier schema (FR / AC / NFR / BR) and bidirectional traceability matrix conventions used across the HVE-Core BRD Builder workflow - Brought to you by microsoft/hve-core'
license: CC-BY-4.0
---

# Traceability and Naming — Skill Entry

## Overview

This skill owns two BRD-wide conventions: the identifier schema used to label every requirement-like statement in a BRD draft, and the traceability matrix shape used to record relationships between those statements. Both are structural conventions of the HVE-Core BRD template; they exist so that downstream consumers (the `brd-standard-assessor` subagent, the PRD/ADR/test handoffs, and any tooling that parses BRD frontmatter) can rely on a consistent vocabulary.

The schema is four-tier: `FR-###` for functional requirements, `AC-###` for acceptance criteria, `NFR-###` for non-functional requirements, and `BR-###` for business rules. The four namespaces are *structural* and are not collapsible. Only the prefix strings themselves are overridable, via a `.brd-config.yml` field documented in [`references/id-schema.md`](references/id-schema.md).

This file is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

## When to Apply

Apply this skill when:

* Assigning an identifier to any newly captured requirement, acceptance criterion, non-functional requirement, or business rule during the Define phase.
* Reviewing a BRD draft for identifier-prefix consistency before the Define→Govern transition.
* Authoring or refreshing the traceability matrix section of a BRD draft.
* Computing acceptance-criteria coverage (the percentage of FRs that carry at least one AC) for the `brd-standard-assessor` rubric.
* Translating a BRD's identifier set into downstream PRD or test artifacts that need to back-reference BRD requirements.

## Four-Tier Identifier Schema

The HVE-Core BRD template partitions every captured requirement-like statement into one of four namespaces:

| Tier | Default prefix | Captures                                                  | Owning skill                                         |
|------|----------------|-----------------------------------------------------------|------------------------------------------------------|
| FR   | `FR-`          | Functional requirements (observable solution behaviors)   | [`requirements-definition`](../requirements-definition/SKILL.md) |
| AC   | `AC-`          | Acceptance criteria (testable conditions on FRs)          | [`requirements-definition`](../requirements-definition/SKILL.md#acceptance-criteria) |
| NFR  | `NFR-`         | Non-functional requirements (ISO/IEC 25010 categories)    | [`requirements-definition`](../requirements-definition/SKILL.md#quality-dimensions-and-rubrics) |
| BR   | `BR-`          | Business rules, policies, regulatory obligations          | this skill (authoring convention)                    |

The four namespaces are kept separate because each is consumed differently downstream: FRs become PRD features, ACs become test cases, NFRs become quality gates, and BRs become policy controls. Collapsing namespaces (for example, prefixing acceptance criteria as `FR-###.a`) loses that downstream separation and is therefore not supported.

Per-project override of the prefix *strings* is supported through the `.brd-config.yml` `requirement_id_prefixes` field. The namespace *count* of four is not configurable. The full schema, regex patterns, override semantics, and example identifiers are documented in [`references/id-schema.md`](references/id-schema.md).

## Traceability Matrix

The HVE-Core BRD template includes a single traceability matrix section that records the relationships between the four identifier tiers and the business goals captured in the BRD's Goals section. The matrix uses three relationship classes:

* **Required**: FR ↔ AC. Every FR must have at least one AC; the matrix is the place where this is visible to a human reviewer and machine-checkable by the `brd-standard-assessor`.
* **Optional**: FR ↔ BG (business goal). Recording the goal each FR supports is recommended but not gate-blocking.
* **Informational**: BR ↔ FR. Recording which FRs enforce which business rules is helpful for downstream policy review; in v1 of the schema this is an authoring convention only and is not machine-enforced.

The matrix template, row and column conventions, the FR↔AC coverage column, and worked examples are documented in [`references/traceability-matrix.md`](references/traceability-matrix.md).

### Optional Authoring Convention: `enforces`

An FR may declare an `enforces: [BR-###, BR-###]` field in its metadata block to record which business rules the FR exists to enforce. This is an authoring convention only in v1 of the schema; the `brd-standard-assessor` does not currently validate that every BR is enforced by at least one FR, nor that referenced BRs exist. Schema-level enforcement of the `enforces` field is tracked for a future version.

## Decision Tree

Use this quick-select when assigning an identifier:

1. Does the statement describe a behavior the solution must produce? Assign `FR-###`.
2. Does the statement describe a testable condition on a specific FR (or set of FRs)? Assign `AC-###` and record the FR(s) it covers in the matrix.
3. Does the statement describe a measurable quality property of the solution (performance, security, availability, etc.)? Assign `NFR-###` under the appropriate ISO/IEC 25010 category.
4. Does the statement describe a policy, regulatory obligation, or operating rule that the solution must respect but does not itself implement as a single behavior? Assign `BR-###` and optionally record which FRs enforce it.
5. Is the statement a desired outcome with no described behavior? It is a business goal, not a requirement; record it in the Goals section and decompose during Define.

## References

Internal:

* [references/id-schema.md](references/id-schema.md) - Four-tier namespace definitions, regex validation patterns, example identifiers, and `.brd-config.yml` override semantics.
* [references/traceability-matrix.md](references/traceability-matrix.md) - Matrix template, row and column conventions, FR↔AC coverage column, and worked examples.
* [`requirements-definition`](../requirements-definition/SKILL.md) - FR / NFR / CON taxonomy, canonical requirement-statement form, acceptance criteria patterns (`AC-###`), and ISO/IEC 25010 NFR category taxonomy used to organize `NFR-###` items.

External (cite-only, no embedded text):

* ISO/IEC/IEEE 29148:2018 §6.2.3 (traceability) - [https://www.iso.org/standard/72089.html](https://www.iso.org/standard/72089.html)
* ISO/IEC 25010 (NFR quality model that scopes the `NFR-###` namespace) - [https://www.iso.org/standard/35733.html](https://www.iso.org/standard/35733.html)

## License

Original content in this skill is licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), copyright (C) Microsoft Corporation. The four-tier namespace partitioning and the matrix conventions documented here are HVE-Core conventions; the outbound ISO references above are cited by name and clause only.

> Brought to you by microsoft/hve-core

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
