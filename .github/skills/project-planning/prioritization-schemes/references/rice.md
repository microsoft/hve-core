---
description: 'Cite-only pointer to RICE scoring - names the Reach / Impact / Confidence / Effort scoring technique and its Intercom origin, links to the upstream publisher, and does not redistribute upstream prose - Brought to you by microsoft/hve-core'
---

# RICE Scoring - Cite-Only Pointer

This document is a cite-only pointer. It names the RICE scoring technique and the four factors the BRD Builder workflow references, links to the upstream publisher, and does not redistribute upstream prose.

## What RICE Is

RICE is a quantitative scoring technique introduced by Sean McBride at Intercom for prioritizing product opportunities. The acronym names the four input factors: Reach, Impact, Confidence, and Effort. A RICE score is computed as `(Reach * Impact * Confidence) / Effort`, producing a numeric ordering across candidate items that can be ranked highest-first.

The technique's intent is to surface and divide-out subjective judgement: the confidence factor multiplies down speculative reach and impact estimates, and the effort divisor penalizes large items so that small high-value opportunities surface above large speculative ones.

The BRD Builder references RICE by name as an alternative prioritization scheme for product-investment decisions where stakeholders have quantitative reach and effort data. The BRD Builder does not redistribute Intercom's published scoring tables, rubric levels, or example calculations.

## Why Cite-Only

The RICE technique name, the four factor names, and the score formula are widely cited in product-management literature and can be referenced by name. Intercom's original blog post, including its specific impact rubric levels, confidence percentages, and worked examples, is published under Intercom's terms and is not redistributed here.

The BRD Builder's posture is:

* Reference RICE by name when stakeholders propose it as the prioritization scheme.
* Use the factor names (Reach, Impact, Confidence, Effort) and the score formula structure in BRD templates without quoting Intercom's prose definitions or rubric levels.
* Require BRDs that use RICE to record the rubric and units the team chose for each factor, since the upstream source is not embedded.
* Link to the upstream Intercom post when a stakeholder wants the canonical technique description.

## Upstream Source

[https://www.intercom.com/blog/rice-simple-prioritization-for-product-managers/](https://www.intercom.com/blog/rice-simple-prioritization-for-product-managers/) (accessed 2026-05-25) - Intercom's blog post introducing the RICE scoring technique, authored by Sean McBride.

## How the BRD Builder Uses RICE

The BRD Builder applies RICE under the following operating rules, which are original Microsoft synthesis informed by the scheme selector in [../SKILL.md](../SKILL.md):

* Every BRD prioritization section that declares RICE must record the units chosen for Reach (for example, users per quarter) and Effort (for example, person-weeks), and the rubric used for Impact and Confidence.
* The recorded inputs per item are required, not just the final score, so the score can be recomputed if rubric or units change.
* Scores are not comparable across teams or programs that use different rubrics or units; the assessor flags cross-team comparisons as a pitfall.
* Items with confidence below an agreed threshold are surfaced for further validation rather than ranked solely on score.

## License

This pointer file is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The RICE scoring technique was introduced by Intercom and is described in their blog post linked above; the upstream content is subject to its own terms.

> Brought to you by microsoft/hve-core

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
