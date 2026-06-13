---
description: 'Cite-only pointer to Weighted Shortest Job First (WSJF) - names the SAFe® program-level prioritization technique, links to the upstream publisher, and does not redistribute upstream prose or SAFe® trademarked material - Brought to you by microsoft/hve-core'
---

# Weighted Shortest Job First (WSJF) - Cite-Only Pointer

This document is a cite-only pointer. It names the Weighted Shortest Job First (WSJF) technique and the factor structure the BRD Builder workflow references, links to the upstream publisher, and does not redistribute upstream prose or trademarked material from the Scaled Agile Framework (SAFe®).

## What WSJF Is

Weighted Shortest Job First is a program-level prioritization technique published as part of the Scaled Agile Framework (SAFe®) by Scaled Agile, Inc.
The technique sequences work items by dividing an estimated Cost of Delay by an estimated Job Duration (or job size).
Cost of Delay is itself decomposed into three components: user/business value, time criticality, and risk reduction / opportunity enablement.
The result is a numeric score that prioritizes items with high Cost of Delay and short duration ahead of items with lower delay cost or longer duration.

The technique is intended to operate inside a SAFe cadence (Portfolio, Large Solution, or Agile Release Train level), where the items being scored share a common relative-sizing convention and the program has an established forum for value-component estimation.

The BRD Builder references WSJF by name as a cite-only alternative prioritization scheme for organizations already operating SAFe. The BRD Builder does not redistribute SAFe's published WSJF guidance, scoring tables, or training material.

## Why Cite-Only

SAFe® is a registered trademark of Scaled Agile, Inc., and the SAFe framework content, including the WSJF article and its scoring guidance, is published under Scaled Agile's terms. Trademark and copyright posture require that this repository reference WSJF by name only and avoid embedding upstream prose, scoring guidance, or trademarked imagery.

The BRD Builder's posture is:

* Reference WSJF by name when stakeholders propose it because their program already operates SAFe.
* Use the factor names (Cost of Delay, user/business value, time criticality, risk reduction / opportunity enablement, Job Duration) and the formula structure without quoting Scaled Agile's prose.
* Include the SAFe® trademark attribution wherever the technique is referenced in BRD outputs.
* Link to the upstream Scaled Agile page when a stakeholder wants the canonical technique description.

## Upstream Source

[https://scaledagileframework.com/wsjf/](https://scaledagileframework.com/wsjf/) (accessed 2026-05-25) - the Scaled Agile Framework article describing Weighted Shortest Job First, published by Scaled Agile, Inc.

## Trademark Attribution

SAFe® and Scaled Agile Framework® are registered trademarks of Scaled Agile, Inc. This skill references the WSJF technique by name only. No endorsement by or affiliation with Scaled Agile, Inc. is asserted.

## How the BRD Builder Uses WSJF

The BRD Builder applies WSJF under the following operating rules, which are original Microsoft synthesis informed by the scheme selector in [../SKILL.md](../SKILL.md):

* WSJF is proposed only when the consuming program is already operating a SAFe cadence; outside that context, MoSCoW or RICE is preferred.
* Every BRD prioritization section that declares WSJF must record the sizing convention the program uses for Job Duration (story points, t-shirt sizes, or comparable), since scores are not portable across programs with different conventions.
* All three Cost of Delay components must be present for each scored item; collapsing Cost of Delay to value alone is flagged by the assessor as a pitfall.
* BRD outputs that cite WSJF carry the SAFe® trademark attribution.

## License

This pointer file is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). WSJF, SAFe®, and Scaled Agile Framework® are the property of Scaled Agile, Inc., and are subject to their own terms at the upstream source.

> Brought to you by microsoft/hve-core

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
