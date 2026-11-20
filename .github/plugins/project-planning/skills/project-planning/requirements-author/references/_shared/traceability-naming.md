---
description: 'Configurable identifier routing and traceability naming conventions for requirements-author consumers'
---

# Traceability and Naming

## Overview

Traceability and naming connect authored requirement statements, outcomes, verification evidence, constraints, rules, and decisions without assuming a specific document type. Consumers supply their identifier families through [id-schema.md](id-schema.md) and their required relationship pairs through [traceability-matrix.md](traceability-matrix.md).

The shared convention has three responsibilities:

* Assign each captured item to one configured identifier family.
* Preserve stable identifiers once assigned.
* Record relationship links using configured family keys rather than hard-coded prefixes.

## When to Apply

Apply this reference when:

* Assigning an identifier to a newly captured requirement-like, outcome, verification, rule, constraint, risk, or decision item.
* Reviewing a draft for prefix consistency.
* Authoring or refreshing a traceability matrix.
* Computing configured coverage metrics between two identifier families.
* Translating one document's identifiers into downstream artifacts that need stable back-references.

## Configured Identifier Families

The canonical identifier mechanics are defined in [id-schema.md](id-schema.md). Consumers choose their own families and prefixes. A family must declare a semantic role so routing can stay neutral across BRD and PRD use cases.

Common roles:

| Role           | Captures                                                                   |
|----------------|----------------------------------------------------------------------------|
| `requirement`  | Binding behavior, capability, feature, story, or product requirement       |
| `verification` | Acceptance criterion, test condition, validation example, or evidence item |
| `quality`      | Non-functional requirement, quality attribute, or service-level target     |
| `constraint`   | Imposed delivery, technology, legal, or operational boundary               |
| `rule`         | Business, policy, regulatory, or domain rule the solution must uphold      |
| `outcome`      | Goal, outcome, metric, objective, or customer value statement              |
| `decision`     | Design, scope, prioritization, or interpretation decision                  |

## Relationship Semantics

Traceability relationships are consumer-owned. Each relationship rule names a source family, a target family, and an enforcement posture.

```yaml
traceability_relationships:
  requirement_to_acceptance:
    source_family: functional_requirement
    target_family: acceptance_criterion
    posture: required
    minimum_targets_per_source: 1
  requirement_to_goal:
    source_family: functional_requirement
    target_family: business_goal
    posture: target
    minimum_targets_per_source: 1
  rule_to_requirement:
    source_family: business_rule
    target_family: functional_requirement
    posture: informational
```

Posture values are neutral:

| Posture         | Meaning                                                                          |
|-----------------|----------------------------------------------------------------------------------|
| `required`      | Missing links fail the consumer's active quality rule                            |
| `target`        | Missing links are tracked against a target and can be handled by consumer policy |
| `informational` | Links aid review but do not affect scoring by themselves                         |
| `optional`      | Links are allowed but no completeness calculation is required                    |

## Decision Tree

Use this quick-select when assigning a family. Replace the bracketed family names with the active consumer configuration.

1. Does the statement describe a behavior, capability, feature, story, or binding product/system obligation? Assign the configured requirement family.
2. Does the statement describe a testable condition, validation example, or acceptance check for another item? Assign the configured verification family and link the item it covers.
3. Does the statement describe a measurable quality property rather than a behavior? Assign the configured quality family.
4. Is the statement imposed from outside the product or requirements activity and not negotiable within the artifact scope? Assign the configured constraint family.
5. Does the statement describe a policy, regulatory obligation, or operating rule the solution must respect? Assign the configured rule family.
6. Does the statement express a desired outcome with no described implementation behavior? Assign the configured outcome family and decompose later when the consumer workflow calls for it.
7. Is the statement an authoring, scope, prioritization, or interpretation choice that affects downstream readers? Assign the configured decision family.

## Authoring Rules

* Keep identifiers stable after assignment; do not renumber to close gaps.
* Use the configured prefix exactly, including case.
* Do not overload one prefix for multiple families.
* Record relationships by identifier, not by heading text or row order.
* Keep relationship tables single-purpose so coverage calculations remain inspectable.
* Let consumer overlays decide whether a missing relationship blocks, warns, or remains informational.

## References

Internal:

* [id-schema.md](id-schema.md) - Configurable identifier families and validation pattern.
* [traceability-matrix.md](traceability-matrix.md) - Matrix template, relationship classes, and coverage calculation mechanics.
* [design-decisions.md](design-decisions.md) - Decision registry for configured decision identifiers.
* [requirements-definition.md](requirements-definition.md) - Neutral requirement categories, statement form, and acceptance-criteria guidance.

External (cite-only, no embedded text):

* ISO/IEC/IEEE 29148:2018 section 6.2.3 traceability - [https://www.iso.org/standard/72089.html](https://www.iso.org/standard/72089.html)

## License

Original content in this reference is licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), copyright (C) Microsoft Corporation. External standards are cited by name and clause only.


