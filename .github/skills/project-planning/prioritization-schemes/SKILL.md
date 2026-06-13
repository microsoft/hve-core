---
name: prioritization-schemes
description: 'Selector and pattern catalog for the four prioritization schemes the BRD Builder helps stakeholders choose between (MoSCoW, RICE, WSJF, Kano); each scheme is referenced by name with original Microsoft synthesis of when-to-use, inputs, outputs, and pitfalls - Brought to you by microsoft/hve-core'
license: CC-BY-4.0
---

# Prioritization Schemes — Skill Entry

## Overview

This skill documents the four prioritization schemes the BRD Builder offers stakeholders for ordering requirements during the Define phase. Each scheme is treated as a cite-only third-party technique referenced by name; this skill provides original Microsoft synthesis of when each scheme is appropriate, what inputs the workflow must gather before applying it, what outputs the scheme produces, and which pitfalls the assessor watches for.

The skill is consumed by:

* the `BRD Author` skill (prioritization-section authoring guidance);
* the `brd-standard-assessor` subagent (rubric for evaluating the prioritization section of a BRD draft);
* the BRD-phase instruction file for Define.

## When to Apply

Apply this skill in the following situations:

* A stakeholder asks "how should we prioritize this list of requirements?" during Define.
* A draft BRD contains a prioritization section that does not declare which scheme was used.
* The Define-exit rubric is grading whether the BRD's prioritization section is internally consistent and stakeholder-aligned.
* A handoff to PRD or downstream planning needs to surface the prioritization scheme as a structured field.
* A stakeholder is debating between two schemes (for example, "should we use MoSCoW or RICE?") and needs a selector-grade comparison.

## Scheme Selector

The BRD Builder's default prioritization scheme is MoSCoW because it is the most universally recognized in business-analysis practice. The other three schemes are offered as alternatives for contexts where MoSCoW's four-bucket categorization is too coarse or too binary. When the stakeholder has no preference, the BRD Builder proposes MoSCoW and explains the alternatives.

| Scheme | When to Use | Inputs Required | Outputs | Pitfalls |
|--------|-------------|-----------------|---------|----------|
| MoSCoW | Default. Use when stakeholders need a fast, jargon-light categorization that maps cleanly to release commitments; ideal for fixed-deadline, fixed-budget delivery and for stakeholder workshops where the audience is non-technical. | A list of candidate requirements; a stakeholder forum that can agree on a delivery commitment; an explicit time-box or release boundary the categorization applies to. | Each requirement classified into one of four buckets (Must / Should / Could / Won't-this-time) with a recorded rationale and the bound time-box. | Inflation of "Must" beyond what fits the time-box; treating "Won't" as "never" instead of "not in this release"; categorization without a time-box that makes Must / Should comparisons meaningless. |
| RICE | Use when the team is making product-investment choices across many independent opportunities, has quantitative reach and effort data, and needs a numeric ordering rather than a categorical one. Strong fit for backlog grooming where opportunities compete for the same engineering capacity. | Estimated reach (users or events per time period); per-user impact rating; confidence percentage in the estimates; effort in person-weeks or comparable unit; an agreed time horizon for reach. | A numeric RICE score per item (Reach × Impact × Confidence / Effort) and a ranked order; recorded inputs so the score can be recomputed. | Treating impact as a continuous metric when it is a discrete rubric value; ignoring confidence so the score over-weights speculative reach; comparing scores across teams whose effort units differ; recomputing scores without recording the inputs. |
| WSJF | Use in SAFe-adopting or large-program contexts that need a structured way to sequence work across multiple teams when delay cost matters. Appropriate when the program has a Portfolio or ART-level cadence and the items being prioritized share a common "duration" unit. | Estimated user / business value; time criticality; risk reduction / opportunity enablement; job duration or size for each item; an established relative-sizing convention across the program. | A numeric WSJF score per item (Cost of Delay divided by Job Duration) and a sequenced backlog; documented Cost of Delay components per item. | Conflating WSJF with a generic priority score outside a SAFe-style cadence; inconsistent sizing units across teams making scores non-comparable; omitting risk reduction and opportunity enablement so Cost of Delay collapses to value plus urgency; using WSJF without the SAFe trademark attribution required by the upstream framework. |
| Kano | Use when the BRD covers a product or customer-facing experience and the team needs to distinguish must-have hygiene features from differentiating delighters. Strong fit during product-led discovery where customer satisfaction data is available or can be gathered. | Customer-facing requirement candidates; access to customer feedback, surveys, or interview data; a way to test functional and dysfunctional questions per requirement; segmentation if the product serves multiple customer types. | Each requirement classified into a Kano category (must-be, performance, attractive, indifferent, or reverse); a recorded evidence trail per categorization. | Using Kano without customer evidence (designer guesses substitute for survey data); category drift over time (today's attractive becomes tomorrow's must-be) without re-validation; applying Kano to internal-tool requirements where the customer-satisfaction axis is not meaningful; ignoring the reverse category, which signals requirements that hurt some users. |

The selector table itself is original Microsoft synthesis. The named schemes (MoSCoW, RICE, WSJF, Kano) are referenced by name only; their full descriptions, scoring tables, and source prose are not redistributed here. Each scheme has a dedicated reference file under [`references/`](references/) containing a cite-only pointer to the upstream source.

## How to Choose a Scheme

The BRD Builder offers the schemes in the following order of preference, downgrading only when the higher-preference scheme's preconditions are not met:

1. MoSCoW — propose first for any BRD where stakeholders are not already using a different scheme. Proceed if stakeholders have an agreed time-box.
2. Kano — propose when the BRD is product-led, customer-facing, and customer-satisfaction evidence exists or can be gathered before Define-exit.
3. RICE — propose when the BRD's prioritization decisions feed a product backlog with measurable reach and effort, and stakeholders have a quantitative culture.
4. WSJF — propose only when the consuming program is already operating a SAFe cadence; otherwise its overhead exceeds its benefit.

The BRD Builder records the chosen scheme as a structured field on the BRD so downstream consumers (PRD Builder, planners) can carry the categorization forward without re-deriving it.

## References

Internal:

* [references/moscow.md](references/moscow.md) - MoSCoW pattern, DSDM origin, cite-only.
* [references/rice.md](references/rice.md) - RICE scoring pattern, Intercom origin, cite-only.
* [references/wsjf.md](references/wsjf.md) - Weighted Shortest Job First, SAFe® framework, cite-only.
* [references/kano.md](references/kano.md) - Kano model, Noriaki Kano 1984, cite-only.
* [`../requirements-definition/SKILL.md`](../requirements-definition/SKILL.md) - Requirement taxonomy whose statements are prioritized using the schemes documented here.
* [`../traceability-naming/SKILL.md`](../traceability-naming/SKILL.md) - Identifier schema for the requirements being prioritized.

External (cite-only, no embedded text):

* MoSCoW prioritization (DSDM Consortium) - [https://www.agilebusiness.org/dsdm-project-framework/moscow-prioririsation.html](https://www.agilebusiness.org/dsdm-project-framework/moscow-prioririsation.html)
* RICE scoring (Intercom) - [https://www.intercom.com/blog/rice-simple-prioritization-for-product-managers/](https://www.intercom.com/blog/rice-simple-prioritization-for-product-managers/)
* WSJF (Scaled Agile, Inc., SAFe®) - [https://scaledagileframework.com/wsjf/](https://scaledagileframework.com/wsjf/)
* Kano model (Noriaki Kano et al., 1984) - [https://en.wikipedia.org/wiki/Kano_model](https://en.wikipedia.org/wiki/Kano_model)

## License

Original content in this skill — including the scheme selector table, the how-to-choose guidance, and the pitfalls catalog — is licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), copyright (C) Microsoft Corporation.
The named schemes (MoSCoW, RICE, WSJF, Kano) and the upstream sources cited in each reference file remain the property of their respective rights holders.
SAFe® is a registered trademark of Scaled Agile, Inc.; this skill references the WSJF technique by name only and does not assert any endorsement by or affiliation with Scaled Agile, Inc.

> Brought to you by microsoft/hve-core

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
