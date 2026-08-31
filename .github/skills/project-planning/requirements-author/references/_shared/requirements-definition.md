---
description: 'Neutral requirement categories, statement form, and acceptance-criteria guidance for requirements-author consumers'
---

# Requirements Definition

This reference defines neutral mechanics for classifying requirements, writing requirement statements, and authoring acceptance criteria. Consumers decide which document phase, gate, data contract, and reviewer applies these mechanics.

## Requirement Categories

Requirements-author consumers can configure their own identifier families, but most artifacts use these neutral categories.

| Category                   | Captures                                                                                                                          | Typical identifier role |
|----------------------------|-----------------------------------------------------------------------------------------------------------------------------------|-------------------------|
| Functional requirement     | Observable behavior, capability, workflow step, user action, or system response                                                   | `requirement`           |
| Non-functional requirement | Measurable quality property such as performance, reliability, security, usability, maintainability, compatibility, or portability | `quality`               |
| Constraint                 | Imposed boundary on solution design, delivery, technology, budget, schedule, law, contract, or operation                          | `constraint`            |
| Business or domain rule    | Standing policy, regulatory obligation, decision rule, or operating rule the solution must uphold                                 | `rule`                  |
| Goal or outcome            | Desired business, customer, product, or organizational outcome that motivates requirements                                        | `outcome`               |
| Decision                   | Authoring, scope, interpretation, prioritization, or design choice that affects downstream readers                                | `decision`              |

The configured identifier families in [id-schema.md](id-schema.md) map these categories to document-specific prefixes.

## Canonical Statement Form

Use this statement form for requirements that need stable downstream interpretation:

```text
The <system, product, process, role, or component> shall <behavior or property> <object or target> <condition or trigger> so that <rationale or outcome>.
```

Required elements:

| Element              | Purpose                                                                         |
|----------------------|---------------------------------------------------------------------------------|
| Subject              | Names the system, product, process, role, or component that owns the obligation |
| Modal verb           | Uses `shall` for binding requirements or a consumer-approved equivalent         |
| Behavior or property | States the action, capability, rule, or measurable quality                      |
| Object or target     | Names what the behavior acts on or what the property describes                  |
| Condition or trigger | States when, where, or under what scope the requirement applies                 |
| Rationale or outcome | Explains why the requirement matters or what need it supports                   |

Consumers can omit the rationale from the visible sentence when it is stored in structured metadata, but the rationale must remain available for review and traceability.

## Functional Requirements

Functional requirements describe externally observable behavior. They use active verbs, avoid implementation-only phrasing, and state one behavior per requirement.

Good functional requirements:

* Name the actor, system, or process that performs the behavior.
* State the trigger or condition that starts the behavior.
* Identify the observable result.
* Link to acceptance criteria through the configured traceability relationship.

## Non-Functional Requirements

Non-functional requirements describe measurable quality properties. They need thresholds or observable evaluation conditions, not vague modifiers.

Useful NFR statement fields:

| Field                 | Purpose                                                                      |
|-----------------------|------------------------------------------------------------------------------|
| Quality category      | Groups the requirement under a consumer-selected quality taxonomy            |
| Measure               | Names the property being measured                                            |
| Threshold             | States the target value, range, or limit                                     |
| Operating condition   | States the load, data volume, environment, user population, or time window   |
| Verification approach | Names inspection, analysis, demonstration, test, or another objective method |

## Constraints

Constraints are externally imposed boundaries. They are distinct from non-functional requirements because the consumer cannot freely trade them off as product choices.

Record these fields when available:

* Imposing source.
* Affected system, process, data, geography, organization, or integration boundary.
* Reason the boundary is non-negotiable.
* Who can approve exceptions or changes.
* Impact on solution scope or delivery.

## Business or Domain Rules

Rules describe policy or domain logic the solution must respect. A rule may be enforced by one or more requirements, by a non-functional control, by an operational procedure, or by another downstream artifact.

Good rule statements:

* Name the policy, regulation, or domain source when known.
* State the condition that activates the rule.
* State the required or prohibited outcome.
* Link to enforcing requirements when those relationships are known.

## Goals and Outcomes

Goals and outcomes describe the value the requirements are meant to achieve. They are not implementation obligations until decomposed into requirements.

Goals are stronger when they name:

* Audience or stakeholder.
* Measurable target or observable result.
* Time horizon or decision point.
* Connection to a strategy, need, metric, or problem statement.

The shared SMART reference [smart-rubric.md](smart-rubric.md) can be used by consumers that want a goal-quality rubric.

## Acceptance Criteria

Acceptance criteria state testable conditions for a requirement. They describe externally observable behavior or evidence and avoid solution-internal implementation detail unless the requirement itself is about that implementation surface.

### Given/When/Then Format

Given/When/Then is the default format when behavior depends on context and an event. Each criterion is a triplet:

* `Given` names the precondition or context.
* `When` names the event, action, or input.
* `Then` names the observable outcome.

Additional `And` or `But` clauses can extend a triplet when they do not add a second independent behavior. The full pattern, examples, and Cucumber attribution are documented in [given-when-then.md](given-when-then.md).

### Alternative Formats

The following formats are acceptable when they fit the requirement better. Mixed formats inside one requirement set should be deliberate and documented.

| Format              | Use when                                                                               |
|---------------------|----------------------------------------------------------------------------------------|
| Flat checklist      | The behavior is tabular, batch-oriented, or state-based and triplets become repetitive |
| Rule with examples  | A compact rule plus example rows communicates the behavior more clearly                |
| Threshold statement | A quality or NFR criterion needs a measurable target under stated conditions           |

### Atomicity

Each acceptance criterion is atomic. Apply [atomicity-checklist.md](atomicity-checklist.md) before recording it:

1. One behavior per criterion.
2. One precondition cluster per criterion.
3. One observable outcome per criterion.
4. No solution-internal references unless the requirement is explicitly about that surface.
5. No quantifiers without thresholds.
6. One actor and one system under test.

## Quality References

Individual requirement quality is described in [iso-29148-quality-attrs.md](iso-29148-quality-attrs.md). General status taxonomy and score-to-status mechanics are described in [quality-rubric.md](quality-rubric.md). Consumers decide which attributes are scored, what thresholds apply, and whether a finding blocks progress.

## Decision Tree

Use this quick-select when classifying or assessing a candidate item:

1. Does the statement describe a behavior the solution or product must produce? Classify it as a functional requirement and rewrite it in the canonical statement form.
2. Does the statement describe a measurable quality property rather than a behavior? Classify it as a non-functional requirement and ensure a threshold is recorded.
3. Is the statement imposed from outside the artifact scope and not negotiable? Classify it as a constraint and record the imposing source.
4. Is the statement a standing policy, regulatory obligation, or operating rule the solution must uphold? Classify it as a business or domain rule.
5. Does the statement express a desired outcome without describing solution behavior? Classify it as a goal or outcome and decompose it later when needed.
6. Is the statement compound? Split it into atomic statements before assigning identifiers.
7. Is the item an authoring, prioritization, interpretation, or design choice? Record it as a decision when it affects downstream readers.
8. Authoring acceptance criteria? Use Given/When/Then by default, switch to an alternative format when justified, and apply the atomicity rules.

## Cite-Only Registry

The frameworks and standards below are referenced by name and clause only. Their text is not embedded in this repository.

* IIBA BABOK v3 - requirements classification taxonomy and elicitation techniques.
* ISO/IEC/IEEE 29148:2018 - requirements engineering, including individual-requirement characteristics. See [standards-excerpts.md](standards-excerpts.md#isoiecieee-291482018) and [iso-29148-quality-attrs.md](iso-29148-quality-attrs.md).
* ISO/IEC 25010 - product-quality model and quality characteristics. See [standards-excerpts.md](standards-excerpts.md#isoiec-250102023).
* Volere Requirements Specification Template - requirement-shell concept. See [standards-excerpts.md](standards-excerpts.md#volere-requirements-specification-template).
* PMI Business Analysis for Practitioners - PMI BA Practice Guide.
* Karl Wiegers, *Software Requirements* and Process Impact templates. See [standards-excerpts.md](standards-excerpts.md#karl-wiegers--software-requirements).
* arc42 - architecture documentation template.
* OMG BPMN 2.0, DMN 1.4, and UML 2.5 - notation standards owned by [process-modeling.md](process-modeling.md).
* Cucumber project - Gherkin and Given/When/Then language pattern. See [given-when-then.md](given-when-then.md).
* Mike Cohn - flat-checklist style for acceptance criteria.
* ISTQB Glossary - testability terminology.

Do not quote prose definitions from the frameworks above. When a paraphrase is needed, write original Microsoft content and cite the framework by name and clause.

## References

Internal:

* [standards-excerpts.md](standards-excerpts.md) - Cite-only registry for standards and methods.
* [iso-29148-quality-attrs.md](iso-29148-quality-attrs.md) - Neutral individual-requirement quality characteristics.
* [quality-rubric.md](quality-rubric.md) - Neutral status taxonomy and score-to-status mechanics.
* [smart-rubric.md](smart-rubric.md) - SMART goal rubric.
* [given-when-then.md](given-when-then.md) - Given/When/Then pattern with Cucumber attribution.
* [atomicity-checklist.md](atomicity-checklist.md) - Original Microsoft atomicity checklist.
* [id-schema.md](id-schema.md) - Configurable identifier family schema.
* [traceability-naming.md](traceability-naming.md) - Identifier routing and traceability naming conventions.
* [traceability-matrix.md](traceability-matrix.md) - Configurable relationship matrix mechanics.
* [prioritization-schemes.md](prioritization-schemes.md) - Prioritization taxonomy.
* [process-modeling.md](process-modeling.md) - Optional process, decision, and structural diagram guidance.

External (cite-only, no embedded text):

* IIBA BABOK v3 - [https://www.iiba.org/standards-and-resources/babok/](https://www.iiba.org/standards-and-resources/babok/)
* ISO/IEC/IEEE 29148:2018 - [https://www.iso.org/standard/72089.html](https://www.iso.org/standard/72089.html)
* ISO/IEC 25010 - [https://www.iso.org/standard/35733.html](https://www.iso.org/standard/35733.html)
* Volere Requirements Specification Template - [https://www.volere.org/](https://www.volere.org/)
* ISTQB Glossary - [https://glossary.istqb.org/](https://glossary.istqb.org/)
* Cucumber project - [https://github.com/cucumber/gherkin](https://github.com/cucumber/gherkin)
* Karl Wiegers, *Software Requirements* and Process Impact templates - [https://www.wiegers.net/](https://www.wiegers.net/)

## License

Original content in this reference is licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), copyright (C) Microsoft Corporation. Third-party frameworks and standards listed in the cite-only registry remain the property of their respective rights holders.


