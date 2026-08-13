---
title: "Outcome Hypothesis: <Title>"
description: "Evidence-grounded outcome hypothesis for <Project or initiative>."
author: "<Name or Author TBD>"
ms.date: <YYYY-MM-DD>
ms.topic: concept
---

> [!CAUTION]
> **Disclaimer:** This skill is an assistive decision-support tool only. It does
> not provide financial or professional investment advice and does not replace
> affected stakeholders, measurement owners, accountable sponsors or decision
> owners, or other qualified human reviewers. The investability verdict is an
> evidence-readiness signal only: "investable" means the defined evidence gates
> passed, and "not investable" means required evidence is incomplete. All
> scorecards, outcome hypotheses, investability verdicts, targets, and
> measurement plans must be independently reviewed and validated by affected
> stakeholders, the measurement owner, and the accountable sponsor or decision
> owner before funding, commitment, or implementation. Outputs from this tool
> do not constitute investment approval, funding authorization, stakeholder
> commitment, or measurement sign-off.

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

| Type    | Indicator           | Definition                 | Baseline                                                                      | Target                     | Source                                | Owner                                  |
|---------|---------------------|----------------------------|-------------------------------------------------------------------------------|----------------------------|---------------------------------------|----------------------------------------|
| Leading | `<Named indicator>` | `<Operational definition>` | `<Current value and measurement period, or explicit baselining prerequisite>` | `<Numeric value and unit>` | `<System or dashboard, or dated gap>` | `<Named person or role, or dated gap>` |
| Lagging | `<Named indicator>` | `<Operational definition>` | `<Current value and measurement period, or explicit baselining prerequisite>` | `<Numeric value and unit>` | `<System or dashboard, or dated gap>` | `<Named person or role, or dated gap>` |

Include at least one leading and one lagging indicator. Limit the document to three indicators total.

### Outcome chain

* **Business outcome:** `<beneficiary result>`
  * **Lagging indicator:** `<metric that confirms the outcome>`
    * **Leading indicators:** `<metrics that predict progress>`
      * **Technical intervention:** `<specific capability or workflow change>`

### Measurement plan

* Measurement granularity: `<Aggregate | Cohort | Individual>`
* Individual-level necessity and proportionality: `<Why aggregate or cohort-level measurement cannot answer the hypothesis, or Not applicable>`
* Privacy Planner result: `<Completed result or evidence reference when individual-level measurement uses personal or sensitive data, or Not applicable>`
* Measurement method and source: `<system, query, or dashboard>`
* Measurement owner: `<name or explicit owner resolution gap>`
* Attribution approach: `<control, pre/post, counterfactual, or matched cohort>`
* Leading checkpoints: `<dates or intervals and reviewer>`
* Lagging checkpoints: `<dates or intervals and reviewer>`

Default to aggregate or cohort-level indicators. Complete the individual-level justification only when that granularity is necessary and proportionate. If an individual-level measure uses personal or sensitive data, stop before drafting and invoke `Privacy Planner`; create or resume the draft only after its completed result is available.

## Assumptions & Risks

### Assumptions

| #  | Assumption              | Evidence / Status                              | If false, impact |
|----|-------------------------|------------------------------------------------|------------------|
| A1 | `<Load-bearing belief>` | `<Untested / Partially supported / Evidenced>` | `<What breaks>`  |
| A2 | `<Load-bearing belief>` | `<Untested / Partially supported / Evidenced>` | `<What breaks>`  |
| A3 | `<Load-bearing belief>` | `<Untested / Partially supported / Evidenced>` | `<What breaks>`  |

Add up to four more assumptions when needed.

### Affected groups and trade-offs

* Other affected groups or paths: `<adjacent teams, excluded segments, and people relying on fallback or accessibility paths>`
* Transferred impacts: `<privacy, accessibility, workload, or operational impacts, plus mitigation or an explicit evidence gap>`

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
