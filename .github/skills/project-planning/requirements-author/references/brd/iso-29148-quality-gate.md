---
description: 'BRD scoring anchors and Define/Govern gate overlay for ISO/IEC/IEEE 29148 individual-requirement quality'
---

# BRD ISO 29148 Quality Gate Overlay

This BRD overlay applies the shared ISO/IEC/IEEE 29148 individual-requirement characteristics from [../_shared/iso-29148-quality-attrs.md](../_shared/iso-29148-quality-attrs.md) to BRD Quality Reviewer scoring. It preserves BRD gate semantics while keeping the neutral characteristic definitions in shared scope.

## BRD Scoring Procedure

For each `FR`, `NFR`, and `CON` item in the BRD, the BRD Quality Reviewer scores all nine shared characteristics on a 0-3 scale.

| Score | Anchor name | Status contribution | BRD interpretation                                                                   |
|-------|-------------|---------------------|--------------------------------------------------------------------------------------|
| `0`   | Absent      | `RISK`              | The characteristic is not addressed or cannot be evaluated from the BRD text         |
| `1`   | Implied     | `CAUTION`           | The characteristic is implied but requires reviewer inference                        |
| `2`   | Explicit    | `COVERED`           | The characteristic is explicit enough for downstream PRD, architecture, or test use  |
| `3`   | Traceable   | `COVERED`           | The characteristic is explicit, evidenced, and linked to BRD context or traceability |

The row-level status is the worst status across the nine characteristic statuses.

## Define to Govern Gate Rule

The BRD Define to Govern hard gate applies these thresholds:

* Every requirement must score at least `2` on `necessary`, `unambiguous`, `singular`, and `verifiable`.
* A score below `2` on any of those four characteristics blocks the gate through `BRD_QUALITY_REPORT_V1.gate_decisions`.
* The other five characteristics, `appropriate`, `complete`, `feasible`, `correct`, and `conforming`, are reported in reviewer findings but do not by themselves block the gate.
* Traceability is assessed through [../_shared/traceability-naming.md](../_shared/traceability-naming.md) and BRD matrix rules rather than as an ISO 29148 characteristic score.

## Characteristic Anchors

The shared characteristic meanings live in [../_shared/iso-29148-quality-attrs.md](../_shared/iso-29148-quality-attrs.md). The BRD-specific anchors below state how the 0-3 scale is applied in BRD review output.

### Necessary

| Score | Anchor                                                                                                         |
|-------|----------------------------------------------------------------------------------------------------------------|
| `0`   | No identifiable stakeholder need; removing the requirement would have no observable consequence                |
| `1`   | A stakeholder need is implied but not named                                                                    |
| `2`   | A named stakeholder need is recorded; removal would create a described gap                                     |
| `3`   | A named stakeholder need is recorded and confirmed by evidence such as an interview, incident, KPI, or signoff |

### Appropriate

| Score | Anchor                                                                                                  |
|-------|---------------------------------------------------------------------------------------------------------|
| `0`   | The requirement targets the wrong abstraction level for a BRD                                           |
| `1`   | The level is roughly correct but leaks downstream design choices                                        |
| `2`   | The level is correct for the BRD and alignment is asserted                                              |
| `3`   | The level is correct and alignment with a named BRD goal, capability, or constraint is cross-referenced |

### Unambiguous

| Score | Anchor                                                                                    |
|-------|-------------------------------------------------------------------------------------------|
| `0`   | Multiple plausible readings or vague modifiers without quantification                     |
| `1`   | One dominant reading exists, but vague modifiers could still mislead readers              |
| `2`   | One dominant reading exists and remaining scope is bounded elsewhere in the BRD           |
| `3`   | A single reading remains; thresholds replace vague modifiers and domain terms are defined |

### Complete

| Score | Anchor                                                                                             |
|-------|----------------------------------------------------------------------------------------------------|
| `0`   | Subject, modal verb, behavior or property, or condition is missing                                 |
| `1`   | Core statement positions are present but rationale and verification pointers are missing           |
| `2`   | Statement form is complete and rationale is recorded                                               |
| `3`   | Statement form is complete, rationale is recorded, and a verification-approach pointer is attached |

### Singular

| Score | Anchor                                                                                 |
|-------|----------------------------------------------------------------------------------------|
| `0`   | The statement combines multiple subjects, behaviors, or conditions                     |
| `1`   | The statement targets one subject but bundles independently testable behaviors         |
| `2`   | The statement is singular and related obligations are cross-referenced                 |
| `3`   | The statement is singular and related obligations are split into their own identifiers |

### Feasible

| Score | Anchor                                                                                                                    |
|-------|---------------------------------------------------------------------------------------------------------------------------|
| `0`   | No feasibility assessment exists or known constraints suggest infeasibility                                               |
| `1`   | A plausibility judgment is recorded but constraint references are missing                                                 |
| `2`   | Feasibility is asserted against named constraints                                                                         |
| `3`   | Feasibility is asserted against named constraints, tradeoffs are documented, and residual risk has an owner or mitigation |

### Verifiable

| Score | Anchor                                                                     |
|-------|----------------------------------------------------------------------------|
| `0`   | No objective verification method is plausible from the statement           |
| `1`   | A verification method is plausible but not named                           |
| `2`   | A verification method is named but the artifact or threshold is incomplete |
| `3`   | A verification method, artifact, and pass condition are stated             |

### Correct

| Score | Anchor                                                                               |
|-------|--------------------------------------------------------------------------------------|
| `0`   | The requirement contradicts recorded stakeholder intent or visible facts             |
| `1`   | The requirement is plausibly correct but confirmation is missing                     |
| `2`   | The requirement matches recorded stakeholder intent by inspection                    |
| `3`   | The requirement matches recorded stakeholder intent and has stakeholder confirmation |

### Conforming

| Score | Anchor                                                                                      |
|-------|---------------------------------------------------------------------------------------------|
| `0`   | The requirement departs from the configured statement form or terminology rules             |
| `1`   | The configured statement form is followed loosely and undefined terms remain                |
| `2`   | The configured statement form is followed and glossary terms are defined                    |
| `3`   | The configured statement form is followed exactly and BRD stylistic conventions are applied |

## Sources

Full citations for ISO/IEC/IEEE 29148:2018 and related commentary live in [../_shared/iso-29148-quality-attrs.md#sources](../_shared/iso-29148-quality-attrs.md#sources).

## License

This overlay is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). ISO/IEC/IEEE 29148:2018 is cited by name and clause only and remains the property of ISO, IEC, and IEEE.


