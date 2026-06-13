---
description: 'Combined HVE-Core quality rubric the brd-standard-assessor subagent applies at Define exit - 0-3 ISO 29148 §5.2.5 characteristic scoring per requirement, ISO/IEC 25010 NFR category-presence per BRD per DD-12, and SMART pass/fail per business goal per DD-08, plus the Define-to-Govern gate decision rule - Brought to you by microsoft/hve-core'
---

# HVE-Core BRD Quality Rubric

This document is the single combined rubric the `brd-standard-assessor` subagent (Step 4.2) applies at Define exit, mid-Define on demand, and post-Govern drift detection. It composes three independent scoring dimensions and one diagnostic heuristic set into the payload schema emitted in `BRD_STANDARD_FINDINGS_V1`. All third-party standards (ISO/IEC/IEEE 29148:2018, ISO/IEC 25010, ISTQB Glossary) are cited by name only; the rubric itself is original Microsoft content.

## Rubric Structure

The rubric composes the artifacts shipped in this skill:

| Dimension                              | Scope               | Scoring                   | Source                                                                         |
|----------------------------------------|---------------------|---------------------------|--------------------------------------------------------------------------------|
| ISO 29148 §5.2.5 characteristic scoring | per requirement     | 0-3 per characteristic    | [iso-29148-quality-attrs.md](iso-29148-quality-attrs.md)                       |
| ISO/IEC 25010 category presence        | per BRD             | boolean per category      | [iso-25010-nfr-taxonomy.md](iso-25010-nfr-taxonomy.md)                         |
| SMART business-goal evaluation         | per business goal   | binary pass / fail        | [smart-rubric.md](smart-rubric.md)                                             |
| ISTQB testability (diagnostic)         | per requirement     | not scored                | [istqb-testability.md](istqb-testability.md)                                   |

The three scored dimensions are reported independently in the assessor's findings; they do not aggregate into a single number.

## Per-Requirement Scoring Sheet

For each FR, NFR, and CON in the BRD, the assessor emits the following row:

| Field                    | Type                          | Source                                                                       |
|--------------------------|-------------------------------|------------------------------------------------------------------------------|
| `requirement_id`         | string                        | [`traceability-naming`](../../traceability-naming/SKILL.md)                  |
| `necessary`              | integer 0-3                   | [iso-29148-quality-attrs.md §1](iso-29148-quality-attrs.md#1-necessary)      |
| `appropriate`            | integer 0-3                   | [iso-29148-quality-attrs.md §2](iso-29148-quality-attrs.md#2-appropriate)    |
| `unambiguous`            | integer 0-3                   | [iso-29148-quality-attrs.md §3](iso-29148-quality-attrs.md#3-unambiguous)    |
| `complete`               | integer 0-3                   | [iso-29148-quality-attrs.md §4](iso-29148-quality-attrs.md#4-complete)       |
| `singular`               | integer 0-3                   | [iso-29148-quality-attrs.md §5](iso-29148-quality-attrs.md#5-singular)       |
| `feasible`               | integer 0-3                   | [iso-29148-quality-attrs.md §6](iso-29148-quality-attrs.md#6-feasible)       |
| `verifiable`             | integer 0-3                   | [iso-29148-quality-attrs.md §7](iso-29148-quality-attrs.md#7-verifiable)     |
| `correct`                | integer 0-3                   | [iso-29148-quality-attrs.md §8](iso-29148-quality-attrs.md#8-correct)        |
| `conforming`             | integer 0-3                   | [iso-29148-quality-attrs.md §9](iso-29148-quality-attrs.md#9-conforming)     |
| `testability_notes`      | string (optional)             | [istqb-testability.md](istqb-testability.md)                                 |

## Per-BRD NFR Category Sheet

The assessor emits a single category-presence row per BRD:

| Field                    | Type                          | Source                                                                       |
|--------------------------|-------------------------------|------------------------------------------------------------------------------|
| `functional_suitability` | boolean                       | [iso-25010-nfr-taxonomy.md §1](iso-25010-nfr-taxonomy.md#1-functional-suitability) |
| `performance_efficiency` | boolean                       | [iso-25010-nfr-taxonomy.md §2](iso-25010-nfr-taxonomy.md#2-performance-efficiency) |
| `compatibility`          | boolean                       | [iso-25010-nfr-taxonomy.md §3](iso-25010-nfr-taxonomy.md#3-compatibility)    |
| `usability`              | boolean                       | [iso-25010-nfr-taxonomy.md §4](iso-25010-nfr-taxonomy.md#4-usability)        |
| `reliability`            | boolean                       | [iso-25010-nfr-taxonomy.md §5](iso-25010-nfr-taxonomy.md#5-reliability)      |
| `security`               | boolean                       | [iso-25010-nfr-taxonomy.md §6](iso-25010-nfr-taxonomy.md#6-security)         |
| `maintainability`        | boolean                       | [iso-25010-nfr-taxonomy.md §7](iso-25010-nfr-taxonomy.md#7-maintainability)  |
| `portability`            | boolean                       | [iso-25010-nfr-taxonomy.md §8](iso-25010-nfr-taxonomy.md#8-portability)      |
| `missing_category_notes` | string (optional)             | qualitative narrative for any category set to false                          |

## Per-Business-Goal SMART Sheet

For each business goal in the BRD, the assessor emits the following row:

| Field             | Type                                  | Source                                                                       |
|-------------------|---------------------------------------|------------------------------------------------------------------------------|
| `goal_id`         | string                                | [`traceability-naming`](../../traceability-naming/SKILL.md)                  |
| `specific`        | enum (`pass`, `fail`)                 | [smart-rubric.md §S](smart-rubric.md#s---specific)                           |
| `measurable`      | enum (`pass`, `fail`)                 | [smart-rubric.md §M](smart-rubric.md#m---measurable)                         |
| `achievable`      | enum (`pass`, `fail`)                 | [smart-rubric.md §A](smart-rubric.md#a---achievable)                         |
| `relevant`        | enum (`pass`, `fail`)                 | [smart-rubric.md §R](smart-rubric.md#r---relevant)                           |
| `time_bound`      | enum (`pass`, `fail`)                 | [smart-rubric.md §T](smart-rubric.md#t---time-bound)                         |
| `goal_verdict`    | enum (`pass`, `fail`)                 | any single attribute `fail` → `goal_verdict = fail`                          |
| `fail_reasons`    | string (optional)                     | populated when `goal_verdict = fail`                                         |

## Define → Govern Gate Decision Rule

The Define → Govern hard gate is decided by combining the three dimensions per the rule below. The gate blocks if any blocking condition is met.

| Condition                                                                                                            | Effect on gate  |
|----------------------------------------------------------------------------------------------------------------------|-----------------|
| Any requirement scores below 2 on `unambiguous`, `verifiable`, `singular`, or `necessary`                            | Block           |
| Any business goal has `goal_verdict = fail`                                                                          | Block           |
| One or more ISO 25010 NFR categories are absent (boolean false)                                                      | Flag (no block) |
| Any of `appropriate`, `complete`, `feasible`, `correct`, `conforming` scores below 2 on one or more requirements     | Flag (no block) |
| ISTQB testability notes attached to one or more requirements                                                         | Flag (no block) |

The assessor surfaces every condition it observes in the `BRD_STANDARD_FINDINGS_V1` narrative; blocking conditions also set the payload's `gate_decision` to `block` so the orchestrator halts the Define → Govern transition.

## Govern Drift Detection

The same rubric is re-applied during Govern when the assessor is invoked for drift detection. A drift event is recorded when any of the following changes occur between the last passing run and the current run:

* A requirement that previously scored at least 2 on `unambiguous`, `verifiable`, `singular`, or `necessary` drops below 2.
* A business goal that previously had `goal_verdict = pass` flips to `fail`.
* An NFR category that was previously present becomes absent.

Drift events trigger an `assessment_outcome = drift` payload but do not by themselves move the BRD out of Govern; the orchestrator decides the response based on the drift narrative.

## Sources

Full citations for the standards referenced by this rubric live in the per-source pointer files:

* ISO/IEC/IEEE 29148:2018 §5.2.5 individual-requirement characteristics — see the [Sources section of `iso-29148-quality-attrs.md`](iso-29148-quality-attrs.md#sources).
* ISO/IEC 25010 product-quality model — see [`iso-25010-nfr-taxonomy.md`](iso-25010-nfr-taxonomy.md).
* ISTQB Glossary testability terminology — see [`istqb-testability.md`](istqb-testability.md).

## License

This rubric is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Third-party standards referenced above (ISO/IEC/IEEE 29148:2018, ISO/IEC 25010, ISTQB Glossary) are cited by name only and remain the property of their respective rights holders; see the per-source pointer files for upstream links and licensing terms.

> Brought to you by microsoft/hve-core

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
