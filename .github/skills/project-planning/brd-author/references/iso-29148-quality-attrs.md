---
description: 'Cite-only summary of the nine ISO/IEC/IEEE 29148:2018 §5.2.5 individual-requirement characteristics the BRD Builder uses, with the 0-3 anchor scale the BRD Quality Reviewer applies at Define exit - Brought to you by microsoft/hve-core'
---

# ISO/IEC/IEEE 29148:2018 - Individual-Requirement Quality Characteristics (Cite-Only)

This document is a cite-only summary. It names the nine ISO/IEC/IEEE 29148:2018 §5.2.5 individual-requirement characteristics the BRD Builder applies, defines each one in original Microsoft prose, and supplies the 0-3 anchor scale the `BRD Quality Reviewer` subagent uses. It does not redistribute ISO/IEC/IEEE 29148:2018 text.

## What This Document Is

ISO/IEC/IEEE 29148:2018, *Systems and software engineering - Life cycle processes - Requirements engineering*, enumerates nine characteristics of a well-formed individual requirement in §5.2.5. The BRD Builder adopts those nine characteristics, paraphrased into original Microsoft prose, as the per-requirement scoring dimension at the Define → Govern gate. Set-of-requirements characteristics (§5.2.6) are out of scope for this rubric; cross-cutting concerns such as traceability are handled by adjacent skills (see the [`traceability-naming`](traceability-naming.md) skill).

## Nine Individual-Requirement Characteristics (§5.2.5)

Each characteristic below carries a Microsoft-authored definition and a 0-3 anchor scale. The scale is original HVE-Core content; ISO 29148 does not prescribe a numeric scoring scheme.

### 1. Necessary

A requirement is *necessary* when it addresses a real stakeholder need or organizational objective and would leave a real gap if removed.

| Score | Anchor                                                                                                                |
|-------|-----------------------------------------------------------------------------------------------------------------------|
| 0     | No identifiable stakeholder need; removing the requirement would have no observable consequence.                       |
| 1     | A stakeholder need is implied but not named; the requirement looks plausible but its absence is not justified.         |
| 2     | A named stakeholder need is recorded; removal would create a described, but not yet evidenced, gap.                    |
| 3     | A named stakeholder need is recorded and confirmed; removal would create an evidenced gap (incident, interview, KPI).  |

### 2. Appropriate

A requirement is *appropriate* when it sits at the right level of the architecture and aligns with the system strategy expressed in the BRD.

| Score | Anchor                                                                                                                      |
|-------|-----------------------------------------------------------------------------------------------------------------------------|
| 0     | The requirement targets the wrong layer (for example, prescribes an implementation detail, or restates an enterprise goal). |
| 1     | The level is roughly correct, but the requirement leaks design choices that belong downstream in the PRD or solution spec.  |
| 2     | The level is correct for the BRD; alignment with the system strategy is asserted but not cross-referenced.                  |
| 3     | The level is correct for the BRD; alignment with a named BRD goal, business capability, or constraint is cross-referenced.  |

### 3. Unambiguous

A requirement is *unambiguous* when every reader reaches the same interpretation.

| Score | Anchor                                                                                                                                |
|-------|---------------------------------------------------------------------------------------------------------------------------------------|
| 0     | Multiple plausible readings, or contains vague modifiers (`fast`, `easy`, `seamless`, `robust`) with no quantification.               |
| 1     | One dominant reading exists, but vague modifiers remain and could mislead a reader unfamiliar with the project.                       |
| 2     | One dominant reading; remaining vagueness is bounded by explicit scope statements elsewhere in the BRD.                               |
| 3     | A single reading; quantitative thresholds replace every vague modifier; domain terms are defined in the BRD glossary when introduced. |

### 4. Complete

A requirement is *complete* when it carries every element of the canonical statement form and needs no external lookup to satisfy the underlying need.

| Score | Anchor                                                                                                                        |
|-------|-------------------------------------------------------------------------------------------------------------------------------|
| 0     | Subject, modal verb, behavior or property, or condition is missing.                                                           |
| 1     | All four positions of the canonical statement form are present; rationale and verification pointers are missing.              |
| 2     | Canonical statement form is complete and rationale is recorded; verification pointer is missing.                              |
| 3     | Canonical statement form is complete, rationale is recorded, and a verification-approach pointer is attached.                 |

### 5. Singular

A requirement is *singular* when it states one and only one requirement: one subject, one behavior or property, one condition.

| Score | Anchor                                                                                                                                      |
|-------|---------------------------------------------------------------------------------------------------------------------------------------------|
| 0     | The statement combines multiple subjects, behaviors, or conditions joined by `and`, `or`, or punctuation that hides separate obligations.   |
| 1     | The statement targets one subject but bundles two or more behaviors that could be tested independently.                                     |
| 2     | The statement is singular; a related obligation is mentioned only by cross-reference to another requirement identifier.                     |
| 3     | The statement is singular; any related obligation is split into its own requirement with its own identifier; no compound phrasing remains.  |

### 6. Feasible

A requirement is *feasible* when it can be implemented within identified cost, schedule, technical, and resource constraints recorded in or referenced from the BRD.

| Score | Anchor                                                                                                                            |
|-------|-----------------------------------------------------------------------------------------------------------------------------------|
| 0     | No feasibility assessment exists; the requirement may be infeasible against known constraints (budget, runtime, regulation).      |
| 1     | A plausibility judgment is recorded but constraint references are missing; feasibility was assumed, not analyzed.                 |
| 2     | Feasibility is asserted against the BRD's named constraints (budget, timeline, technology, staffing) but trade-offs are implicit. |
| 3     | Feasibility is asserted against named constraints; trade-offs are documented; any residual risk has a named mitigation or owner.  |

### 7. Verifiable

A requirement is *verifiable* when an objective method (inspection, analysis, demonstration, or test) can decide whether it is met.

| Score | Anchor                                                                                                                                                                    |
|-------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 0     | No verification method is plausible because the statement is subjective or unquantified.                                                                                  |
| 1     | A verification method is plausible but not named; the requirement uses verifiable language without naming the method.                                                     |
| 2     | A verification method is named (for example, "verified by integration test") but the specific artifact or threshold is not yet identified.                                |
| 3     | A verification method is named, the artifact (test name, demonstration script, inspection checklist, or analysis report) is identified, and the pass condition is stated. |

### 8. Correct

A requirement is *correct* when it accurately reflects the underlying stakeholder intent and is free of factual, semantic, or scope errors.

| Score | Anchor                                                                                                                              |
|-------|-------------------------------------------------------------------------------------------------------------------------------------|
| 0     | The requirement contradicts the stakeholder intent it claims to represent, or contains a factual error visible to the reviewer.     |
| 1     | The requirement is plausibly correct, but the stakeholder intent is paraphrased loosely and no confirmation is recorded.            |
| 2     | The requirement matches the recorded stakeholder intent; correctness was checked by inspection but not confirmed by the stakeholder.|
| 3     | The requirement matches the recorded stakeholder intent and has been confirmed by the named stakeholder (signoff, review, or test). |

### 9. Conforming

A requirement is *conforming* when it follows the format, structure, and language standards established for the BRD's requirement set, including the canonical statement form and the BRD glossary.

| Score | Anchor                                                                                                                                          |
|-------|-------------------------------------------------------------------------------------------------------------------------------------------------|
| 0     | The requirement departs from the canonical statement form or uses terms outside the BRD glossary without definition.                            |
| 1     | The canonical statement form is followed loosely; one or more terms outside the glossary are used without definition.                           |
| 2     | The canonical statement form is followed; all glossary terms are defined; minor stylistic departures (modal verb, casing, ordering) remain.     |
| 3     | The canonical statement form is followed exactly; all glossary terms are defined; stylistic conventions of the BRD requirement set are applied. |

## Define → Govern Gate Rule

The Define → Govern hard gate uses these thresholds:

* Every requirement must score at least 2 on *unambiguous*, *verifiable*, *singular*, and *necessary*; a score below 2 on any of those four blocks the gate. These four characteristics are the most expensive to repair downstream and the most frequently cited in the requirements-engineering literature as the hardest to retrofit.
* The other five characteristics (*appropriate*, *complete*, *feasible*, *correct*, *conforming*) are reported but do not by themselves block the gate; the `BRD Quality Reviewer` subagent surfaces them in the narrative.
* Traceability is no longer assessed under this rubric. Cross-cutting traceability is enforced by the [`traceability-naming`](traceability-naming.md) skill (identifier schema, backward and forward links, traceability matrix).

## Sources

* ISO/IEC/IEEE 29148:2018, *Systems and software engineering - Life cycle processes - Requirements engineering*. Authoritative source for the nine §5.2.5 individual-requirement characteristics. Paywalled (~$200 USD). ISO catalog: [https://www.iso.org/standard/72089.html](https://www.iso.org/standard/72089.html). IEEE Xplore: [https://ieeexplore.ieee.org/document/8559686](https://ieeexplore.ieee.org/document/8559686).
* Sahu, A. et al. (2024). Survey-based commentary on the §5.2.5 characteristics, in *Journal of Computing and Information Science in Engineering*, ASME. [https://asmedigitalcollection.asme.org/computingengineering/article/24/9/091003/1198902](https://asmedigitalcollection.asme.org/computingengineering/article/24/9/091003/1198902).
* Gramajo, M. G., Ballejos, L., and Ale, M. (2021). *Seizing Requirements Engineering Issues through Supervised Learning Techniques*. arXiv:2105.04757. [https://arxiv.org/abs/2105.04757](https://arxiv.org/abs/2105.04757).
* Ferrari, A. *Requirements Engineering* glossary entry, in *Handbook of Software Engineering* (Springer). [https://doi.org/10.1007/978-3-031-71992-8_4](https://doi.org/10.1007/978-3-031-71992-8_4).

Citation policy: this file references ISO/IEC/IEEE 29148:2018 by name, designator, and clause only. The standard's prose is not redistributed.

## License

This pointer file is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). ISO/IEC/IEEE 29148:2018 is the property of ISO, IEC, and IEEE and is subject to the publisher's terms at the upstream sources listed above.

> Brought to you by microsoft/hve-core

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
