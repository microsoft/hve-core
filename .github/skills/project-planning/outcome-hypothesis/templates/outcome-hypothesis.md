---
title: "Outcome Hypothesis: <Title>"
description: "Evidence-grounded outcome hypothesis for <Project or initiative>."
author: "<Name or Author TBD>"
ms.date: <YYYY-MM-DD>
ms.topic: concept
---

> [!CAUTION]
> This outcome hypothesis supports decision-making but does not constitute
> investment approval, stakeholder commitment, or measurement sign-off.
> Validate it with affected stakeholders, the measurement owner, and the
> accountable decision owner before using it to make commitments.

**Project / Initiative:** `<Project or initiative>`
**Status:** `<Draft | Provisional | In Review | Committed | Superseded>`
**Confidence:** `<Low | Medium | High>`

## Background

Write one to three concise paragraphs that connect:

* The strategic priority and why this outcome matters now
* The specific problem and its current operational or business cost
* The beneficiary's role, segment, scale, geography, channel, and before/after workflow
* The capability or workflow intervention at a level engineers can scope and sponsors can endorse

Describe an MVP or proof of concept only as a delivery vehicle, never as the outcome.

## Expected Outcomes

Use the initiative-level form below. Keep each clause in a separate paragraph and bold only the clause lead.

**Due to** `<business context or pain point>`,

**We believe that** `<capability or workflow intervention>`

**Will result in** `<measurable business outcome>`,

**Observable by** `<specific role, segment, or business unit>`,

**Within** `<specific window anchored to an event or date>`,

**Validated by:**

* **Leading indicator 1:** `<predictive metric with numeric target and units>`
* **Leading indicator 2:** `<optional predictive metric with numeric target and units>`
* **Lagging indicator:** `<outcome metric with numeric target and units>`

For a tightly scoped pilot sub-hypothesis, this one-sentence form is permitted:

> If we `<intervention>` for `<beneficiary>`, then `<KPI>` will improve from `<baseline>` to `<target>` within `<timeframe>`, as measured by `<method>`.

## Validation & Measurement

### Indicator detail

| Type    | Indicator           | Definition                 | Baseline                                                                      | Source / Owner                                                    |
|---------|---------------------|----------------------------|-------------------------------------------------------------------------------|-------------------------------------------------------------------|
| Leading | `<Named indicator>` | `<Operational definition>` | `<Current value and measurement period, or explicit baselining prerequisite>` | `<System or dashboard / named owner, or explicit resolution gap>` |
| Lagging | `<Named indicator>` | `<Operational definition>` | `<Current value and measurement period, or explicit baselining prerequisite>` | `<System or dashboard / named owner, or explicit resolution gap>` |

Include at least one leading and one lagging indicator. Limit the document to three indicators total.

### Outcome chain

* **Business outcome:** `<beneficiary result>`
  * **Lagging indicator:** `<metric that confirms the outcome>`
    * **Leading indicators:** `<metrics that predict progress>`
      * **Technical intervention:** `<specific capability or workflow change>`

### Measurement plan

* Measurement method and source: `<system, query, or dashboard>`
* Measurement owner: `<name or explicit owner resolution gap>`
* Attribution approach: `<control, pre/post, counterfactual, or matched cohort>`
* Leading checkpoints: `<dates or intervals and reviewer>`
* Lagging checkpoints: `<dates or intervals and reviewer>`

## Assumptions & Risks

### Assumptions

| #  | Assumption              | Evidence / Status                              | If false, impact |
|----|-------------------------|------------------------------------------------|------------------|
| A1 | `<Load-bearing belief>` | `<Untested / Partially supported / Evidenced>` | `<What breaks>`  |
| A2 | `<Load-bearing belief>` | `<Untested / Partially supported / Evidenced>` | `<What breaks>`  |
| A3 | `<Load-bearing belief>` | `<Untested / Partially supported / Evidenced>` | `<What breaks>`  |

Add up to four more assumptions when needed.

### Risks and falsification criteria

* Hypothesis is disproved when: `<numeric lagging-indicator threshold within the timeframe>`
* Potential confounds: `<false-positive and false-negative conditions>`
* Exit or pivot criteria: `<decision threshold and action>`

## Open Questions & Resolution Gaps

Map every Amber and Red D1-D7 pillar. Keep the table even when no gaps remain.

| Gap                      | Why it matters                              | Owner                        | Target date          |
|--------------------------|---------------------------------------------|------------------------------|----------------------|
| `<Specific gap or None>` | `<How it weakens or blocks the hypothesis>` | `<Named owner or Owner TBD>` | `<Date or Date TBD>` |

For a Provisional hypothesis:

* Set Status to `Provisional` and Confidence to `Low`.
* Complete Background, Expected Outcomes, and Open Questions & Resolution Gaps from available evidence.
* Insert this marker in any unsupported section:

> **TBD**: This section is blocked on `<specific scorecard gap>`. Owner: `<name or Owner TBD>`. Target resolution: `<date or Date TBD>`.
