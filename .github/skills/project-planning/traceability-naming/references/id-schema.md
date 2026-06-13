---
description: 'Four-tier requirement identifier schema (FR / AC / NFR / BR) with regex validation patterns, example identifiers, and .brd-config.yml prefix-override semantics for the HVE-Core BRD Builder - Brought to you by microsoft/hve-core'
---

# Four-Tier Identifier Schema

This reference defines the canonical four-tier identifier schema used by the HVE-Core BRD Builder template. The schema is consumed by the `brd-standard-assessor` subagent (coverage math, prefix-consistency checks) and by any downstream tooling that parses a BRD draft.

The four namespaces are *structural* and are not collapsible. Only the prefix strings themselves are overridable. See [Override Semantics](#override-semantics) below.

## The Four Namespaces

### FR - Functional Requirements

`FR-###` identifies a functional requirement: a statement of what the solution must do, captured under the [`requirements-definition`](../../requirements-definition/SKILL.md) skill's canonical FR form.

* Default prefix: `FR-`
* Regex (default prefix): `^FR-\d{3,}$`
* Examples: `FR-001`, `FR-042`, `FR-128`

Numbering is sequential within the BRD draft, zero-padded to at least three digits. Gaps are permitted (an FR may be removed after numbering) and existing identifiers are not renumbered when new FRs are added.

### AC - Acceptance Criteria

`AC-###` identifies an acceptance criterion: a testable condition on one or more FRs, captured under the [`requirements-definition`](../../requirements-definition/SKILL.md#acceptance-criteria) skill's Gherkin-style or table-driven form.

* Default prefix: `AC-`
* Regex (default prefix): `^AC-\d{3,}$`
* Examples: `AC-001`, `AC-017`

Each AC references the FR(s) it covers in its metadata block (for example, `covers: [FR-001, FR-002]`). The bidirectional FR↔AC mapping is also surfaced in the traceability matrix; see [`traceability-matrix.md`](traceability-matrix.md).

### NFR - Non-Functional Requirements

`NFR-###` identifies a non-functional requirement: a measurable quality property of the solution, organized under the ISO/IEC 25010 quality characteristics taxonomy referenced by the [`requirements-definition`](../../requirements-definition/SKILL.md#quality-dimensions-and-rubrics) skill (DD-12).

* Default prefix: `NFR-`
* Regex (default prefix): `^NFR-\d{3,}$`
* Examples: `NFR-001`, `NFR-023`

The NFR namespace is partitioned by ISO/IEC 25010 category headings inside the BRD's NFR section (for example, *Performance Efficiency*, *Security*, *Reliability*); identifiers are sequential across categories, not restarted per category.

### BR - Business Rules

`BR-###` identifies a business rule: a policy, regulatory obligation, or operating rule that the solution must respect but does not itself implement as a single behavior. Business rules are distinct from constraints (which are imposed boundaries on the solution) and distinct from FRs (which are behaviors).

* Default prefix: `BR-`
* Regex (default prefix): `^BR-\d{3,}$`
* Examples: `BR-001` (a regulatory data-residency rule), `BR-014` (an organizational approval-threshold policy)

An FR may optionally declare which business rules it enforces via an `enforces: [BR-###]` field in its metadata block. In v1 of the schema this is an authoring convention only; the `brd-standard-assessor` does not currently validate the `enforces` field. See the parent SKILL's *Optional Authoring Convention: `enforces`* section.

## Override Semantics

The `.brd-config.yml` file at the BRD draft's root may declare a `requirement_id_prefixes` block to override the *prefix strings* used by a specific project. The *count* of namespaces (always four) is not configurable.

### Default Configuration

When `.brd-config.yml` is absent or omits the `requirement_id_prefixes` block, the BRD Builder applies the defaults:

```yaml
requirement_id_prefixes:
  fr: "FR-"
  ac: "AC-"
  nfr: "NFR-"
  br: "BR-"
```

### Per-Project Override Example

A project that prefers a domain-specific prefix may override any subset of the four:

```yaml
requirement_id_prefixes:
  fr: "FEAT-"
  ac: "TEST-"
  nfr: "QUAL-"
  br: "POL-"
```

Under this configuration, identifiers in the BRD draft would read `FEAT-001`, `TEST-017`, `QUAL-023`, `POL-014`. The `brd-standard-assessor` reads the configured prefixes and applies the regex `^<prefix>\d{3,}$` per namespace.

### What Is and Is Not Overridable

| Aspect of the schema                                               | Overridable?         |
|--------------------------------------------------------------------|----------------------|
| The four-namespace separation (FR / AC / NFR / BR conceptually)    | **No** - structural  |
| The prefix string applied to each namespace                        | **Yes** - via config |
| The zero-padded numeric suffix format (minimum three digits)       | **No** - structural  |
| The within-BRD sequential numbering rule                           | **No** - structural  |
| Whether identifiers must be unique within a BRD draft              | **No** - structural  |

Attempting to collapse two namespaces into one (for example, by setting `fr` and `nfr` to the same prefix) is rejected by the `brd-standard-assessor` because it makes coverage math and category-presence checks ambiguous.

## Validation Patterns

Tooling that needs to classify an identifier in a BRD draft applies the regex per the configured prefix. Using the default prefixes:

| Namespace | Regex          | Matches              | Does not match              |
|-----------|----------------|----------------------|-----------------------------|
| FR        | `^FR-\d{3,}$`  | `FR-001`, `FR-1024`  | `FR-1`, `FR-01`, `FRA-001`  |
| AC        | `^AC-\d{3,}$`  | `AC-001`, `AC-099`   | `AC-1`, `ACK-001`           |
| NFR       | `^NFR-\d{3,}$` | `NFR-001`, `NFR-050` | `NFR-50`, `NF-001`          |
| BR        | `^BR-\d{3,}$`  | `BR-001`, `BR-014`   | `BR-1`, `BRA-001`           |

Numeric suffixes are at least three digits to keep alphabetic sort and numeric sort aligned in the BRD's table-of-contents view.

## Cross-References

* Parent skill: [`../SKILL.md`](../SKILL.md)
* Sibling reference: [`traceability-matrix.md`](traceability-matrix.md)
* External cite-only: ISO/IEC/IEEE 29148:2018 §6.2.3 (traceability) - [https://www.iso.org/standard/72089.html](https://www.iso.org/standard/72089.html)
* External cite-only: ISO/IEC 25010 (NFR quality model) - [https://www.iso.org/standard/35733.html](https://www.iso.org/standard/35733.html)

> Brought to you by microsoft/hve-core

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
