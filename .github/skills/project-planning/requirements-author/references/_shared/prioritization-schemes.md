---
description: 'MoSCoW prioritization guidance for BRD requirements and business goals'
---

# Prioritization Schemes — Skill Entry

## Overview

This skill documents the required MoSCoW prioritization scheme the BRD Builder uses for ordering requirements and business goals during Define. MoSCoW is referenced by name; this skill provides original Microsoft synthesis of when to use it, what inputs the workflow must gather, what outputs it produces, and which pitfalls reviewers watch for.

The skill is consumed by:

* the `BRD Author` skill (prioritization-section authoring guidance);
* the BRD Quality Reviewer (rubric for evaluating the prioritization section of a BRD draft);
* the BRD-phase instruction file for Define.

## When to Apply

Apply this skill in the following situations:

* A stakeholder asks "how should we prioritize this list of requirements?" during Define.
* A draft BRD contains a prioritization section that does not declare which scheme was used.
* The Define-exit rubric is grading whether the BRD's prioritization section is internally consistent and stakeholder-aligned.
* A handoff to PRD or downstream planning needs to surface the prioritization scheme as a structured field.
* A stakeholder is trying to decide whether a requirement is a Must, Should, Could, or Won't for the current delivery boundary.

## Required Scheme

The BRD Builder uses MoSCoW because it is widely recognized in business-analysis practice and maps cleanly to BRD and PRD handoff fields. When stakeholders have another scheme in mind, capture the rationale in `DD-###` and translate the final BRD priority field back to MoSCoW labels before Govern handoff.

| Label  | Meaning in a BRD                                               | Required author evidence                             | Common pitfall                                                           |
|--------|----------------------------------------------------------------|------------------------------------------------------|--------------------------------------------------------------------------|
| MUST   | Required for the agreed release or Govern handoff to be viable | Stakeholder owner, rationale, and impact if omitted  | Inflating too many items into Must without delivery capacity evidence    |
| SHOULD | Important and expected when capacity allows                    | Rationale and acceptance impact if deferred          | Treating Should as optional nice-to-have with no consequence             |
| COULD  | Useful but not required for the current boundary               | Rationale for lower urgency                          | Keeping Could items in scope without pruning during tradeoff discussions |
| WONT   | Explicitly out of current scope or release boundary            | Rationale and target revisit trigger when applicable | Treating Won't as never rather than not in this boundary                 |

The table is original Microsoft synthesis. The MoSCoW technique is referenced by name only; upstream source prose is not redistributed here.

## How to Apply MoSCoW

The BRD Builder applies MoSCoW in this order:

1. Establish the delivery boundary, time-box, or Govern handoff scope.
2. Classify each `BG-###`, `FR-###`, `NFR-###`, `CON-###`, and `BR-###` item with one MoSCoW label.
3. Record a short rationale for every Must and Won't item.
4. Challenge Must inflation by asking what breaks if the item moves to Should.
5. Carry the final label into `business_goals[].priority` and requirement metadata used by downstream PRD planning.

The BRD Builder records the chosen scheme as a structured field on the BRD so downstream consumers (PRD Builder, planners) can carry the categorization forward without re-deriving it.

## References

Internal:

* [moscow.md](moscow.md) - MoSCoW pattern, DSDM origin, cite-only.
* [standards-excerpts.md](standards-excerpts.md#moscow-prioritization) - Central standards registry entry for MoSCoW.
* [`requirements-definition`](requirements-definition.md) - Requirement taxonomy whose statements are prioritized using the schemes documented here.
* [`traceability-naming`](traceability-naming.md) - Identifier schema for the requirements being prioritized.

External (cite-only, no embedded text):

* MoSCoW prioritization (DSDM Consortium) - [https://www.agilebusiness.org/dsdm-project-framework/moscow-prioririsation.html](https://www.agilebusiness.org/dsdm-project-framework/moscow-prioririsation.html)

## License

Original content in this skill is licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), copyright (C) Microsoft Corporation. MoSCoW and its upstream sources remain the property of their respective rights holders.


