---
description: 'Canonical BRD requirement, business-goal, and design-decision identifier schema with frontmatter prefix rules - Brought to you by microsoft/hve-core'
---

# BRD Identifier Schema

This reference is the canonical identifier source for the BRD author bundle. It defines five requirement tiers and two adjacent identifier families used by the canonical BRD template, traceability matrix, quality review, and Govern handoff.

The five requirement namespaces are structural and are not collapsible. Only the requirement prefix strings are configurable, and they are configured in BRD YAML frontmatter under `requirement_id_prefixes`.

## Identifier Families

### Requirement Tiers

| Tier | Default prefix | Captures                                                | Required pattern |
|------|----------------|---------------------------------------------------------|------------------|
| FR   | `FR`           | Functional requirements, observable solution behaviors  | `PREFIX-\d{3,}` |
| AC   | `AC`           | Acceptance criteria, testable conditions on FRs         | `PREFIX-\d{3,}` |
| NFR  | `NFR`          | Non-functional requirements and quality properties      | `PREFIX-\d{3,}` |
| CON  | `CON`          | Imposed constraints on solution or delivery boundaries  | `PREFIX-\d{3,}` |
| BR   | `BR`           | Standing business rules the solution must uphold        | `PREFIX-\d{3,}` |

### Adjacent Identifiers

Adjacent identifiers are not requirement tiers, but they participate in traceability and handoff records:

| Family | Default prefix | Captures                                           | Required pattern |
|--------|----------------|----------------------------------------------------|------------------|
| BG     | `BG`           | Business goals and outcomes                       | `BG-\d{3,}`     |
| DD     | `DD`           | Design decisions recorded in the BRD decision log | `DD-\d{3,}`     |

Examples: `FR-001`, `AC-001`, `NFR-001`, `CON-001`, `BR-001`, `BG-001`, and `DD-008`.

## Requirement Tier Definitions

### FR - Functional Requirements

`FR-###` identifies a functional requirement: a statement of what the solution must do, captured under the [`requirements-definition`](requirements-definition.md) skill's canonical FR form.

* Default prefix: `FR-`
* Regex (default prefix): `^FR-\d{3,}$`
* Examples: `FR-001`, `FR-042`, `FR-128`

Numbering is sequential within the BRD draft, zero-padded to at least three digits. Gaps are permitted (an FR may be removed after numbering) and existing identifiers are not renumbered when new FRs are added.

### AC - Acceptance Criteria

`AC-###` identifies an acceptance criterion: a testable condition on one or more FRs, captured under the [`requirements-definition`](requirements-definition.md#acceptance-criteria) skill's Gherkin-style or table-driven form.

* Default prefix: `AC-`
* Regex (default prefix): `^AC-\d{3,}$`
* Examples: `AC-001`, `AC-017`

Each AC references the FR(s) it covers in its metadata block (for example, `covers: [FR-001, FR-002]`). The bidirectional FR↔AC mapping is also surfaced in the traceability matrix; see [`traceability-matrix.md`](traceability-matrix.md).

### NFR - Non-Functional Requirements

`NFR-###` identifies a non-functional requirement: a measurable quality property of the solution, organized under the ISO/IEC 25010 quality characteristics taxonomy referenced by the [`requirements-definition`](requirements-definition.md#quality-dimensions-and-rubrics) skill.

* Default prefix: `NFR-`
* Regex (default prefix): `^NFR-\d{3,}$`
* Examples: `NFR-001`, `NFR-023`

The NFR namespace is partitioned by ISO/IEC 25010 category headings inside the BRD's NFR section (for example, *Performance Efficiency*, *Security*, *Reliability*); identifiers are sequential across categories, not restarted per category.

### CON - Constraints

`CON-###` identifies a constraint: an imposed boundary on the solution or its delivery that is not negotiable within the BRD scope, captured under the [`requirements-definition`](requirements-definition.md#requirement-categories) skill's constraint category.

* Default prefix: `CON-`
* Regex (default prefix): `^CON-\d{3,}$`
* Examples: `CON-001` (a mandated cloud platform), `CON-007` (a fixed go-live date)

Constraints are distinct from business rules (`BR-###`): a constraint bounds how the solution may be built or delivered, while a business rule is a standing policy the solution must uphold. Each constraint records imposing source, affected boundary, non-negotiability, category, and impact.

### BR - Business Rules

`BR-###` identifies a business rule: a policy, regulatory obligation, or operating rule that the solution must respect but does not itself implement as a single behavior. Business rules are distinct from constraints (which are imposed boundaries on the solution) and distinct from FRs (which are behaviors).

* Default prefix: `BR-`
* Regex (default prefix): `^BR-\d{3,}$`
* Examples: `BR-001` (a regulatory data-residency rule), `BR-014` (an organizational approval-threshold policy)

An FR may optionally declare which business rules it enforces via an `enforces: [BR-###]` field in its metadata block. The BR-to-FR table in [traceability-matrix.md](traceability-matrix.md) is the human-readable reverse view.

## Adjacent Family Definitions

### BG - Business Goal

`BG-###` identifies a SMART business goal or outcome. BG identifiers support FR-to-BG traceability and the `business_goals[]` handoff payload.

* Regex: `^BG-\d{3,}$`
* Examples: `BG-001`, `BG-002`, `BG-010`

Every FR should support at least one BG. The Govern handoff target for FR-to-BG coverage is `100.0%`; gaps require an active waiver.

### DD - Design Decision

`DD-###` identifies a decision recorded in the BRD's design decision log. DD identifiers are defined further in [design-decisions.md](design-decisions.md).

* Regex: `^DD-\d{3,}$`
* Examples: `DD-001`, `DD-008`, `DD-021`

Use DD identifiers when a choice affects scope, taxonomy, traceability, prioritization, or downstream interpretation.

## Frontmatter Prefix Semantics

The BRD frontmatter `requirement_id_prefixes` block declares the prefix strings used by a specific BRD. The count and meaning of requirement namespaces are not configurable.

### Default Configuration

When the BRD omits the `requirement_id_prefixes` block, the BRD Builder applies the defaults:

```yaml
requirement_id_prefixes:
  fr: "FR"
  ac: "AC"
  nfr: "NFR"
  con: "CON"
  br: "BR"
```

### Per-Project Override Example

A BRD that prefers domain-specific requirement prefixes may override any subset of the five:

```yaml
requirement_id_prefixes:
  fr: "FEAT"
  ac: "TEST"
  nfr: "QUAL"
  con: "BOUND"
  br: "POL"
```

Under this configuration, identifiers in the BRD draft would read `FEAT-001`, `TEST-017`, `QUAL-023`, `BOUND-005`, `POL-014`. The BRD Quality Reviewer reads the configured prefixes and applies the regex `^<prefix>-\d{3,}$` per namespace.

### What Is and Is Not Overridable

| Aspect of the schema                                               | Overridable?         |
|--------------------------------------------------------------------|----------------------|
| The five-namespace separation (FR / AC / NFR / CON / BR conceptually) | **No** - structural       |
| The prefix string applied to each requirement namespace             | **Yes** - via frontmatter |
| The zero-padded numeric suffix format (minimum three digits)       | **No** - structural  |
| The within-BRD sequential numbering rule                           | **No** - structural  |
| Whether identifiers must be unique within a BRD draft              | **No** - structural  |

Attempting to collapse two namespaces into one (for example, by setting `fr` and `nfr` to the same prefix) is rejected because it makes coverage math and category-presence checks ambiguous.

## Validation Patterns

Tooling that needs to classify an identifier in a BRD draft applies the regex per the configured prefix. Using the default prefixes:

| Namespace | Regex          | Matches              | Does not match              |
|-----------|----------------|----------------------|-----------------------------|
| FR        | `^FR-\d{3,}$`  | `FR-001`, `FR-1024`  | `FR-1`, `FR-01`, `FRA-001`  |
| AC        | `^AC-\d{3,}$`  | `AC-001`, `AC-099`   | `AC-1`, `ACK-001`           |
| NFR       | `^NFR-\d{3,}$` | `NFR-001`, `NFR-050` | `NFR-50`, `NF-001`          |
| CON       | `^CON-\d{3,}$` | `CON-001`, `CON-007` | `CON-1`, `CONS-001`         |
| BR        | `^BR-\d{3,}$`  | `BR-001`, `BR-014`   | `BR-1`, `BRA-001`           |
| BG        | `^BG-\d{3,}$`  | `BG-001`, `BG-010`   | `BG-1`, `BG-01`             |
| DD        | `^DD-\d{3,}$`  | `DD-001`, `DD-008`   | `DD-1`, `DD-08`             |

Numeric suffixes are at least three digits to keep alphabetic sort and numeric sort aligned in the BRD's table-of-contents view.

## Cross-References

* Parent skill: [`../SKILL.md`](../SKILL.md)
* Sibling reference: [`traceability-matrix.md`](traceability-matrix.md)
* Sibling reference: [`traceability-naming.md`](traceability-naming.md)
* Sibling reference: [`design-decisions.md`](design-decisions.md)
* Standards registry: [standards-excerpts.md](standards-excerpts.md#isoiecieee-291482018)

> Brought to you by microsoft/hve-core

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
