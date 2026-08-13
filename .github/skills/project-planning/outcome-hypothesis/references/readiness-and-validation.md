---
description: "Readiness scoring, validation rules, investability gates, and correction guidance for outcome hypotheses"
---

# Readiness and Validation

Use this reference during readiness scoring and create or assess validation. Apply readiness rules and validation rules in their listed order.

## D1-D7 Scorecard

| Pillar                   | Evaluate                                                                                                                            |
|--------------------------|-------------------------------------------------------------------------------------------------------------------------------------|
| D1 Strategic context     | Priority, business direction, and why the outcome matters now                                                                       |
| D2 Problem definition    | Specific pain or opportunity and its business impact                                                                                |
| D3 Beneficiary clarity   | Affected role or segment and the before/after workflow                                                                              |
| D4 Measurement baseline  | Numeric current-state baselines and measurement periods for at least one leading and one lagging indicator, plus source credibility |
| D5 Intervention clarity  | Candidate capability or workflow changes in scope                                                                                   |
| D6 Targets and timeframe | Numeric targets with units for at least one leading and one lagging indicator, plus a timeframe anchored to an event or date        |
| D7 Measurement ownership | Owners, methods, cadence, attribution, and the end-to-end intervention-to-outcome chain                                             |

Assign one status to each pillar:

* Green: fact-based and sourced.
* Amber: plausible but unconfirmed.
* Red: missing, conflicting, or speculative.

When a pillar evaluates multiple required facts, assign the least-ready status among them. A missing required fact makes that pillar Red even when another fact in the same pillar is evidenced.

Show the scorecard before drafting or reporting assessment findings:

| Pillar                   | Status              | Source / Gap                    |
|--------------------------|---------------------|---------------------------------|
| D1 Strategic context     | Green / Amber / Red | Evidence source or specific gap |
| D2 Problem definition    | Green / Amber / Red | Evidence source or specific gap |
| D3 Beneficiary clarity   | Green / Amber / Red | Evidence source or specific gap |
| D4 Measurement baseline  | Green / Amber / Red | Evidence source or specific gap |
| D5 Intervention clarity  | Green / Amber / Red | Evidence source or specific gap |
| D6 Targets and timeframe | Green / Amber / Red | Evidence source or specific gap |
| D7 Measurement ownership | Green / Amber / Red | Evidence source or specific gap |

## Readiness Precedence

Apply the first matching rule:

1. If D2 is Red, or at least three pillars are Red, choose **Investigate**.
2. Otherwise, if any pillar is Red, choose **Provisional**.
3. Otherwise, if at most two pillars are Amber, choose **Ready to author**.
4. Otherwise, choose **Provisional**.

The decisions mean:

* Ready to author: Draft a Full Outcome Hypothesis.
* Provisional: Draft a Provisional Outcome Hypothesis with explicit resolution gaps.
* Investigate: Do not draft. Name blocking pillars and propose targeted discovery actions. A read-only assessment of supplied content may continue.

A current D1-D7 scorecard must exist before drafting or reporting assessment findings.

## Provisional Content

This section applies to create mode.

Use Status `Provisional` and Confidence `Low`.

When evidence cannot support a section, add:

> **TBD**: This section is blocked on `<specific scorecard gap>`. Owner: `<name or Owner TBD>`. Target resolution: `<date or Date TBD>`.

Do not invent an owner or date. Every Amber and Red pillar must appear in Open Questions & Resolution Gaps.

## Validation Procedure

Apply OH.0-OH.12 in order after scoring D1-D7.

### Create validation

OH.0 passes when a current D1-D7 scorecard exists and readiness is Ready or Provisional. When it fails, emit its warning in chat and stop without a draft. For every OH.1-OH.12 failure, add a warning immediately after the affected section and repeat it in chat:

> **VALIDATION WARNING: Rule OH.X**: `<description>`

Use the failed rule's Requirement text as the warning description. When multiple rules fail in one section, emit one warning per rule in numeric order.

### Assess validation

OH.0 passes when a supplied hypothesis or outcome document is present. Any readiness result, including Investigate, is permitted because assessment does not authorize a replacement draft. When OH.0 fails, ask for the document and stop without further validation.

Preserve the supplied content unchanged. Apply OH.1-OH.12 to that content and report every result in numeric order:

| Rule | Result      | Evidence or location          | Gap or correction                  |
|------|-------------|-------------------------------|------------------------------------|
| OH.X | Pass / Fail | Section, statement, or Missing | Specific gap or correction / None |

Use `Fail` when required content is missing or unsupported. Do not insert validation warnings into the supplied document. Offer a revised draft only after reporting the complete assessment and only as a separate create or revision request.

### Validation rules

| Rule  | Section                          | Requirement                                                                                                                                                                                                                                                                                                                   |
|-------|----------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| OH.0  | Precondition                     | Create: a current D1-D7 scorecard exists and readiness is Ready or Provisional; return to discovery when no scorecard exists and do not draft for Investigate. Assess: a supplied hypothesis or outcome document is present; any readiness result is permitted and no replacement draft is produced.                         |
| OH.1  | Expected Outcomes                | The multi-line form contains Due to, We believe that, Will result in, Observable by, Within, and Validated by with at least one leading and one lagging target. A tightly scoped pilot sub-hypothesis may instead name intervention, beneficiary, KPI baseline and target, timeframe, and measurement method in one sentence. |
| OH.2  | Expected Outcomes                | Every indicator target is a concrete number with units. Vague qualifiers fail.                                                                                                                                                                                                                                                |
| OH.3  | Expected Outcomes                | The timeframe is a specific window anchored to an event or date.                                                                                                                                                                                                                                                              |
| OH.4  | Expected Outcomes                | The beneficiary is a specific role, segment, or business unit rather than generic users or customers.                                                                                                                                                                                                                         |
| OH.5  | Background                       | The intervention describes a capability or workflow change rather than only an artifact such as an MVP, proof of concept, or chatbot.                                                                                                                                                                                         |
| OH.6  | Validation & Measurement         | The lagging indicator has a named source and owner, or an explicit owner gap with a target resolution date.                                                                                                                                                                                                                   |
| OH.7  | Validation & Measurement         | Every indicator has a numeric current-state baseline or explicitly makes baselining a prerequisite with a target completion date.                                                                                                                                                                                             |
| OH.8  | Validation & Measurement         | The chain connects business outcome, lagging indicator, leading indicators, and intervention end to end.                                                                                                                                                                                                                      |
| OH.9  | Validation & Measurement         | The plan names who measures, how they measure, and the cadence or checkpoints for leading and lagging indicators.                                                                                                                                                                                                             |
| OH.10 | Assumptions & Risks              | At least three assumptions each include Untested, Partially supported, or Evidenced status and the impact if false.                                                                                                                                                                                                           |
| OH.11 | Assumptions & Risks              | At least one explicit condition would disprove the hypothesis.                                                                                                                                                                                                                                                                |
| OH.12 | Open Questions & Resolution Gaps | Every Amber and Red scorecard item appears in the gaps table.                                                                                                                                                                                                                                                                 |

## Investability

If OH.1, OH.2, OH.3, OH.7, or OH.8 fails:

* Label the hypothesis **not investable**.
* Identify the failed rule or rules.
* Recommend returning to evidence gathering to strengthen the affected pillars.

Other warnings lower confidence but do not automatically make the hypothesis not investable.

## Indicator and Chain Guidance

Require at least one leading and one lagging indicator. Allow up to one additional leading indicator, but no more than three indicators total.

Targets and timeframes belong in the canonical statement. The indicator table adds operational definition, baseline, source, and owner.

In create mode, draw this chain. In assess mode, evaluate whether the supplied content contains the chain:

* Business outcome
  * Lagging indicator
    * Leading indicator or indicators
      * Technical intervention or interventions

If the chain breaks because evidence is missing, return to evidence gathering. In create mode, redraft inconsistent logic before delivery. In assess mode, fail OH.8 and report the inconsistency without rewriting it.

## Assumptions and Falsification

List three to seven load-bearing assumptions. Probe data quality, adoption, attribution, workflow, and commercial model when the initial list is too narrow.

Define:

* A numeric condition that disproves the outcome prediction
* Confounds that could create a false positive or false negative
* Exit or pivot criteria

## Common Failure Corrections

In create mode, apply these corrections before delivery. In assess mode, report the applicable correction without changing the supplied content.

| Failure                                          | Correction                                                                                          |
|--------------------------------------------------|-----------------------------------------------------------------------------------------------------|
| The statement describes building an artifact     | Rewrite it around the measurable beneficiary result and treat the artifact as the delivery vehicle. |
| The target uses vague uplift language or a range | Require one committed numeric target; otherwise record a gap with owner and date.                   |
| No baseline exists                               | Retrieve it or make baselining the first prerequisite activity with a completion date.              |
| The beneficiary is generic                       | Ask for the role, segment, scale, geography, or channel that experiences the change.                |
| Fewer than three assumptions exist               | Probe data quality, adoption, attribution, workflow, and commercial assumptions.                    |
| No falsification condition exists                | Add a threshold and timeframe that would disprove the prediction.                                   |

## Guardrails

* Never fabricate baselines, targets, owners, stakeholder names, sources, or dates.
* Never bypass or hide the readiness scorecard.
* Never draft for an Investigate decision. A read-only assessment may continue.
* Never infer inaccessible or protected source content.
* Never persist a created draft before presenting it inline and obtaining destination confirmation.
* Never alter supplied content during assessment.
