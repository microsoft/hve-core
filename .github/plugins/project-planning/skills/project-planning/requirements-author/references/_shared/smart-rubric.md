---
description: 'SMART business-goal rubric per DD-008 - per-attribute (S/M/A/R/T) anchor descriptions, binary pass/fail decision, and the Discover-draft to Define-refine cadence the BRD Builder applies at the Define to Govern hard gate'
---

# SMART Business-Goal Rubric

This document defines the rubric the BRD Builder applies to every business goal in a draft BRD. The SMART mnemonic (Specific, Measurable, Achievable, Relevant, Time-bound) is a public-domain management-by-objectives convention; the rubric, anchors, and cadence below are original HVE-Core content.

## Posture per DD-008

Per DD-008, the BRD Builder applies SMART scoring on a two-phase cadence:

* **Discover (draft)** - business goals are captured in the stakeholder's own words. The BRD Builder does not block on SMART compliance during Discover. It flags goals that are obviously non-SMART and queues them for refinement.
* **Define (refine)** - every business goal is rewritten into SMART form. The `BRD Quality Reviewer` subagent applies the rubric below and emits a per-goal pass/fail. The Define → Govern hard gate requires every business goal to pass SMART.

A goal passes when all five attributes pass. Any single attribute failure marks the goal as not-SMART and blocks the Define → Govern gate.

## Per-Attribute Anchors

Each attribute below carries a single binary decision (pass / fail) and a short anchor description. The assessor's narrative records the reason for any fail.

### S - Specific

A goal is *specific* when the outcome is named in concrete domain terms and the population, scope, or system to which the outcome applies is identified.

* **Pass** - the goal names the outcome (what changes), the population or system affected (who or what), and the boundary of applicability (where or in what context).
* **Fail** - the goal uses generic language ("improve customer experience", "increase efficiency") without naming the outcome, the population, or the boundary.

### M - Measurable

A goal is *measurable* when its achievement is decided by an observable indicator with a stated baseline and target value.

* **Pass** - the goal names a quantitative indicator (a number, ratio, percentage, count, time, or money figure), states the baseline (current value) or the comparator (against what), and states the target value.
* **Fail** - the goal uses qualitative language without a quantitative indicator, or names an indicator without a baseline or target.

### A - Achievable

A goal is *achievable* when the named target value is plausibly within reach given known constraints (budget, time, staffing, technology, regulatory posture) recorded elsewhere in the BRD.

* **Pass** - the goal's target is consistent with stated constraints; if the target is stretch, the rationale and risk are recorded in the goal's narrative or in an associated open question.
* **Fail** - the goal's target is inconsistent with stated constraints (for example, requires headcount beyond the recorded budget, or a regulatory waiver that has not been pursued) with no supporting rationale.

### R - Relevant

A goal is *relevant* when it advances a named strategic intent, business outcome, or stakeholder need recorded elsewhere in the BRD.

* **Pass** - the goal carries an explicit link (identifier or short justification) to a recorded strategic intent, business outcome, or stakeholder need.
* **Fail** - the goal has no link to recorded strategy, outcomes, or needs; its presence in the BRD is not justified.

### T - Time-bound

A goal is *time-bound* when a deadline, target date, or measurement window is stated.

* **Pass** - the goal names a deadline (calendar date or relative date such as "within 90 days of GA"), a target date, or a measurement window (for example, "measured over the first quarter after launch").
* **Fail** - the goal has no deadline, target date, or measurement window.

## Combined Pass/Fail

| Attribute        | Result (pass / fail) | Reason if fail                        |
|------------------|----------------------|---------------------------------------|
| Specific         |                      |                                       |
| Measurable       |                      |                                       |
| Achievable       |                      |                                       |
| Relevant         |                      |                                       |
| Time-bound       |                      |                                       |
| **Goal verdict** | **pass / fail**      | (any single fail → goal verdict fail) |

## Discover-Draft to Define-Refine Cadence

The BRD Builder follows this cadence for every business goal:

1. **Discover capture** - capture the goal in the stakeholder's words. Apply a quick SMART triage and record the result as a draft annotation; do not block.
2. **Define rewrite** - rewrite the goal into the canonical SMART form. The author may consult the stakeholder one or more times to obtain missing baseline, target, or deadline values.
3. **Define self-score** - the BRD author applies the rubric above and records a per-attribute result.
4. **Define-exit assessment** - the `BRD Quality Reviewer` subagent re-applies the rubric and emits the per-goal verdict in `BRD_STANDARD_FINDINGS_V1`. Any goal with verdict *fail* blocks the Define → Govern gate.
5. **Govern monitoring** - the BRD Builder does not rescore SMART during Govern unless a goal is materially changed; material changes trigger a return to step 2.

## License

This rubric is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The SMART mnemonic is a public-domain management-by-objectives convention.


