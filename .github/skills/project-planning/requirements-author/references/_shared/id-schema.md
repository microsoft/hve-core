---
description: 'Configurable requirement, outcome, and decision identifier schema for requirements-author consumers'
---

# Identifier Schema

This reference defines neutral identifier mechanics shared by requirements-author consumers. Each consumer supplies its own identifier families, prefixes, labels, and relationship semantics. The shared mechanics require stable family keys, unique prefixes, and numeric suffix rules.

The BRD consumer configures families such as functional requirements, acceptance criteria, non-functional requirements, constraints, business rules, business goals, and design decisions. A PRD consumer can configure product goals, features, user stories, acceptance criteria, non-functional requirements, experiments, risks, decisions, or other families without changing this shared schema.

## Identifier Family Configuration

Each consumer defines an `identifier_families` map in its local frontmatter, state, or schema contract. The map keys are stable semantic family names. The prefix strings are the visible labels used in the authored artifact.

```yaml
identifier_families:
  primary_requirement:
    prefix: "FR"
    label: "Functional requirement"
    role: "requirement"
  acceptance_criterion:
    prefix: "AC"
    label: "Acceptance criterion"
    role: "verification"
  outcome:
    prefix: "BG"
    label: "Business goal"
    role: "outcome"
  decision:
    prefix: "DD"
    label: "Design decision"
    role: "decision"
```

Consumers can name families according to their document type. The shared files do not require a fixed count of families or a fixed set of prefixes.

## Required Family Fields

| Field                    | Required | Purpose                                                                                                        |
|--------------------------|----------|----------------------------------------------------------------------------------------------------------------|
| `prefix`                 | Yes      | Visible identifier prefix before the hyphen                                                                    |
| `label`                  | Yes      | Human-readable family name used in tables and review output                                                    |
| `role`                   | Yes      | Semantic role such as `requirement`, `verification`, `quality`, `constraint`, `rule`, `outcome`, or `decision` |
| `description`            | No       | Short consumer-owned explanation of what the family captures                                                   |
| `required_relationships` | No       | Relationship rules consumed by [traceability-matrix.md](traceability-matrix.md)                                |

## Identifier Pattern

Every configured family uses this pattern:

```text
PREFIX-###
```

Validation regex per configured prefix:

```text
^<prefix>-\d{3,}$
```

Rules:

* Prefixes are case-sensitive ASCII alphanumeric strings with optional internal underscores.
* Prefixes must be unique within one artifact.
* Numeric suffixes use at least three digits.
* Numbering is sequential within each family.
* Existing identifiers are not renumbered after deletion or reordering.
* Each identifier is unique within the artifact.

## Consumer Configuration Examples

### BRD Consumer Example

```yaml
identifier_families:
  functional_requirement:
    prefix: "FR"
    label: "Functional requirement"
    role: "requirement"
  acceptance_criterion:
    prefix: "AC"
    label: "Acceptance criterion"
    role: "verification"
  non_functional_requirement:
    prefix: "NFR"
    label: "Non-functional requirement"
    role: "quality"
  constraint:
    prefix: "CON"
    label: "Constraint"
    role: "constraint"
  business_rule:
    prefix: "BR"
    label: "Business rule"
    role: "rule"
  business_goal:
    prefix: "BG"
    label: "Business goal"
    role: "outcome"
  design_decision:
    prefix: "DD"
    label: "Design decision"
    role: "decision"
```

### PRD Consumer Example

```yaml
identifier_families:
  product_goal:
    prefix: "PG"
    label: "Product goal"
    role: "outcome"
  feature:
    prefix: "FEAT"
    label: "Feature"
    role: "requirement"
  user_story:
    prefix: "US"
    label: "User story"
    role: "requirement"
  acceptance_criterion:
    prefix: "AC"
    label: "Acceptance criterion"
    role: "verification"
  non_functional_requirement:
    prefix: "NFR"
    label: "Non-functional requirement"
    role: "quality"
  decision:
    prefix: "DD"
    label: "Decision"
    role: "decision"
```

The examples preserve existing BRD behavior while letting PRD and future consumers supply their own families.

## What Is Configurable

| Aspect                              | Configurable | Notes                                                                  |
|-------------------------------------|--------------|------------------------------------------------------------------------|
| Family count                        | Yes          | Consumers define the families they need                                |
| Family prefix strings               | Yes          | Prefixes are supplied per consumer                                     |
| Family labels and roles             | Yes          | Labels and roles drive authoring and matrix wording                    |
| Relationship rules between families | Yes          | Rules are supplied to [traceability-matrix.md](traceability-matrix.md) |
| Hyphen separator                    | No           | Keeps identifiers easy to parse                                        |
| Minimum three-digit numeric suffix  | No           | Keeps alphabetic and numeric sort aligned                              |
| Uniqueness within an artifact       | No           | Required for traceability and review output                            |

Attempting to assign the same prefix to two families in one artifact is rejected because tooling cannot classify identifiers unambiguously.

## Validation Patterns

Tooling classifies an identifier by matching it against the configured family prefixes. With the BRD example configuration, `FR-001`, `AC-017`, and `BG-003` are valid. With the PRD example configuration, `FEAT-001`, `US-042`, and `PG-002` are valid.

Invalid examples for every consumer:

| Identifier    | Reason                                     |
|---------------|--------------------------------------------|
| `FR-1`        | Numeric suffix has fewer than three digits |
| `FR01`        | Missing hyphen separator                   |
| `FR-ABC`      | Suffix is not numeric                      |
| `UNKNOWN-001` | Prefix is not configured for the artifact  |

## Cross-References

* Parent skill: [`../../SKILL.md`](../../SKILL.md)
* Sibling reference: [traceability-matrix.md](traceability-matrix.md)
* Sibling reference: [traceability-naming.md](traceability-naming.md)
* Sibling reference: [design-decisions.md](design-decisions.md)
* Standards registry: [standards-excerpts.md](standards-excerpts.md#isoiecieee-291482018)


