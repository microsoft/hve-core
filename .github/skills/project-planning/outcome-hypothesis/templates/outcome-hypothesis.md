---
title: "Outcome Hypothesis: <Title>"
description: "Evidence-grounded outcome hypothesis for <Project or initiative>."
author: "<Name or Author TBD>"
ms.date: 2026-08-18
ms.topic: concept
---

<!-- Replace this marker with the complete `Outcome-Hypothesis` CAUTION from
../../../../instructions/shared/disclaimer-language.instructions.md verbatim.
Do not retain this marker in the rendered document. -->

`ms.date` is template metadata. Replace it with the actual ISO 8601 render date and, before saving, the actual persistence or update date.

**Project / Initiative:** `<Project or initiative>`
**Status:** `<Draft | Provisional | Committed>`
**Confidence:** `<Low | Medium | High>`

The status lifecycle is closed: `Draft`, `Provisional`, and `Committed`. Status is human-owned. Persist a Ready hypothesis as `Draft` and a Provisional hypothesis as `Provisional`. Only explicit human approval may update an existing persisted, eligible artifact to `Committed`; do not set `Committed` automatically.

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

The targets in either Expected Outcomes form are authoritative. Each indicator-table Target value must exactly match its corresponding statement target.

## Validation & Measurement

### Indicator detail

| Type    | Indicator           | Definition                 | Baseline                                                                      | Target                             | Source                                | Owner                                  |
|---------|---------------------|----------------------------|-------------------------------------------------------------------------------|------------------------------------|---------------------------------------|----------------------------------------|
| Leading | `<Named indicator>` | `<Operational definition>` | `<Current value and measurement period, or explicit baselining prerequisite>` | `<Exact Expected Outcomes target>` | `<System or dashboard, or dated gap>` | `<Named person or role, or dated gap>` |
| Lagging | `<Named indicator>` | `<Operational definition>` | `<Current value and measurement period, or explicit baselining prerequisite>` | `<Exact Expected Outcomes target>` | `<System or dashboard, or dated gap>` | `<Named person or role, or dated gap>` |

Include at least one leading and one lagging indicator. Limit the document to three indicators total.

### Outcome chain

* **Business outcome:** `<beneficiary result>`
  * **Lagging indicator:** `<metric that confirms the outcome>`
    * **Leading indicators:** `<metrics that predict progress>`
      * **Technical intervention:** `<specific capability or workflow change>`

### Measurement plan

* Measurement granularity: `<Aggregate | Cohort | Individual>`
* Individual-level necessity and proportionality: `<Why aggregate or cohort-level measurement cannot answer the hypothesis, or Not applicable>`
* Privacy review result: `<Completed Privacy Planner result, or documented qualified-human review when Privacy Planner is unavailable, or Not applicable>`
* Measurement method and source: `<system, query, or dashboard>`
* Measurement owner: `<name or explicit owner resolution gap>`
* Attribution approach: `<control, pre/post, counterfactual, or matched cohort>`
* Leading checkpoints: `<dates or intervals and reviewer>`
* Lagging checkpoints: `<dates or intervals and reviewer>`

Default to aggregate or cohort-level indicators. Complete the individual-level justification only when that granularity is necessary and proportionate. If an individual-level measure uses personal or sensitive data, stop before drafting and invoke `Privacy Planner`; create or resume the draft only after its completed result is available. If `Privacy Planner` is unavailable, remain stopped until a documented review by a qualified privacy professional is supplied.

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

| ID | Gap              | Why it matters                              | Owner                        | Target date (ISO 8601)     |
|----|------------------|---------------------------------------------|------------------------------|----------------------------|
| Q1 | `<Specific gap>` | `<How it weakens or blocks the hypothesis>` | `<Named owner or Owner TBD>` | `<YYYY-MM-DD or Date TBD>` |

Use unique `Q1`-style IDs for source gaps. When no gaps remain, retain the table with no body rows; do not add a `None` row. Every populated target date must use ISO 8601 `YYYY-MM-DD`.

For a Provisional hypothesis:

* Set Status to `Provisional` and Confidence to `Low`.
* Complete Background, Expected Outcomes, and Open Questions & Resolution Gaps from available evidence.
* Insert this marker in any unsupported section:

> **TBD**: This section is blocked on `<specific scorecard gap>`. Owner: `<name or Owner TBD>`. Target resolution: `<date or Date TBD>`.
