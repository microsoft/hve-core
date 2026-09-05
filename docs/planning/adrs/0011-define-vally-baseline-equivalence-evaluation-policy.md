---
id: "0011"
title: "Define the Vally baseline-equivalence evaluation policy"
description: "Define launch-based agent invocation, authoritative evidence, report-only comparison calibration, model scope, and trial posture for the baseline-equivalence suite."
author: "HVE Core Maintainers"
ms.date: "2026-08-21"
ms.topic: "reference"
status: "proposed"
proposed_date: "2026-08-01"
accepted_date: null
deciders:
  - "HVE Core Maintainers"
consulted:
  - "HVE Core evaluation maintainers"
informed:
  - "hve-core contributors"
effort: "M"
tags:
  - "evaluation"
  - "vally"
  - "ci"
  - "baseline-equivalence"
affected_components:
  - "package.json"
  - "evals/baseline-equivalence/"
  - ".github/workflows/eval-validation.yml"
  - "scripts/evals/Invoke-BaselineEquivalence.ps1"
  - "scripts/evals/Invoke-VallyEvals.ps1"
  - "scripts/evals/lib/EquivalenceParsing.psm1"
  - "scripts/evals/lib/EquivalenceEnvironment.psm1"
supersedes: null
superseded-by: null
related:
  - path: "0002-adopt-vally-as-agent-and-skill-behavior-evaluation-framework.md"
    relation: "influenced-by"
    note: "Sets the evaluation policy for the baseline-equivalence guarantee ADR 0002 adopted Vally to provide."
  - path: "0010-stabilize-pr-time-vally-evaluation-execution.md"
    relation: "influenced-by"
    note: "Extends ADR 0010's typed-record parsing rule to the equivalence results reader and renames the tier vocabulary it described as PR and nightly."
asr_triggers:
  - kind: "maintainability"
    evidence: "The suite emitted a single verdict derived from a statistical comparison, so a failed customization guard and a statistically significant regression were indistinguishable in the reported result."
    note: "Two questions folded into one verdict left neither independently answerable or actionable."
  - kind: "compliance"
    evidence: "Comparison judging is model-backed, so the rubric source and judge model determine whether two runs are reproducibly comparable."
    note: "An unpinned judge or an implicit rubric makes a verdict unreproducible across runs."
  - kind: "maintainability"
    evidence: "The advisory and authoritative modes were named pr and nightly, which described CI triggers rather than exit policy, and each carried a different gating consequence."
    note: "Trigger-shaped names invited a caller to select an exit policy by accident."
success_criteria:
  - metric: "gate-separation"
    target: "every run separates authoritative deterministic and structural evidence from report-only comparative and boundary evidence"
    measurement_window: "every baseline-equivalence run"
    source: "scripts/evals/lib/EquivalenceParsing.psm1 and scripts/tests/evals/EquivalenceParsing.Tests.ps1"
  - metric: "structural-fail-closed"
    target: "zero-trial and data-quality failures report fail at every tier, including the advisory tier"
    measurement_window: "every baseline-equivalence run"
    source: "scripts/tests/evals/EquivalenceParsing.Tests.ps1"
  - metric: "contract-version-rejection"
    target: "a consumer reading an unsupported summary major version fails loudly rather than reading absent fields as zeros"
    measurement_window: "every equivalence dispatch"
    source: "scripts/tests/evals/Invoke-VallyEvals.Tests.ps1"
decisionMetadata:
  driverToTriggerMap:
    "Auditable verdict": "A single blended verdict could not distinguish an undocumented behavior change from a failed customization guard, so the two gates are reported and evaluated separately."
    "Reproducible judging": "Comparison is model-backed, so the rubric source and judge model are fixed and visible in the invocation rather than implied by a spec file."
    "Honest failure posture": "An incomplete comparison cannot evidence equivalence, so structural failures fail closed at every tier while statistical results stay advisory in the local loop."
    "Calibration honesty": "Thresholds that have not been calibrated are reported rather than enforced, so the gate never asserts a bar no one has validated."
    "Low local friction": "Contributors iterate against the suite locally, so the advisory tier never blocks on a model-backed statistical result while still failing closed on a structurally broken run."
---

## Context

The baseline-equivalence suite asks whether the hve-core customization layer changes underlying GitHub Copilot model behavior beyond the divergences the suite explicitly declares. ADR 0002 adopted Vally partly because `vally compare` offered that guarantee. ADR 0010 then corrected PR-time execution semantics and selected a faster low-profile model.

Neither ADR fixed the evaluation policy itself. The suite ran, but several policy questions were answered implicitly by whatever the driver happened to do:

* Which rubric judges a comparison, and which judge model applies it.
* Whether a failed customization guard and a statistically significant regression produce distinguishable results.
* What an advisory run means versus an authoritative one, and which failures are allowed to be advisory.
* Whether an uncalibrated threshold gates or reports.

Those answers were spread across a driver, a parser, and a CI dispatcher, and in some cases contradicted each other. The suite's verdict therefore did not mean one auditable thing, which is a problem for an evaluation whose entire purpose is producing a trustworthy signal.

## Decision Drivers

* Auditable verdict
* Reproducible judging
* Honest failure posture
* Calibration honesty
* Low local friction

## Considered Options

* Option A: Keep one blended verdict and document how to interpret it case by case.
* Option B: Separate the gates but keep the existing trigger-shaped tier names and the implicit rubric source.
* Option C: Separate the gates, fix the rubric and judge model explicitly, rename tiers to describe exit policy, and report uncalibrated thresholds instead of enforcing them.

## Decision Outcome

| Decision driver        | Option A: blended verdict | Option B: partial separation | Option C: full policy definition |
|------------------------|---------------------------|------------------------------|----------------------------------|
| Auditable verdict      | No                        | Yes                          | Yes                              |
| Reproducible judging   | No                        | No                           | Yes                              |
| Honest failure posture | Partial                   | Partial                      | Yes                              |
| Calibration honesty    | No                        | No                           | Yes                              |
| Low local friction     | Yes                       | Yes                          | Yes                              |

Chosen option: **Option C**, because the policy questions are coupled. Separating the gates without fixing the rubric source leaves the verdict reproducible only by accident, and renaming tiers without defining which failures may be advisory leaves the exit policy ambiguous at the moment it matters most.

The decision has eight parts.

**1. The comparison rubric is an explicit repository contract, and the judge model is pinned on the invocation.** `vally compare` treats `--eval-spec` as an optional override of its embedded rubric.
Relying on that default proved unsound: the embedded rubric asks which response is better, and two runs of one configuration still differ in wording, so the judge picks winners even when customization changed nothing.
Measured against a preference judge, the tie ratio reports judge tie-breaking propensity rather than equivalence.
The driver therefore passes `--eval-spec evals/baseline-equivalence/compare.eval.yml`, a contract carrying one rubric entry per canonical stimulus. Each equivalent-policy entry instructs a tie when both variants satisfy the same behavioral contract despite differing wording.
Deterministic validation rejects any missing, duplicated, unknown, or policy-mismatched entry before a run is paid for.
The judge model is passed explicitly as `--judge-model`, defaulting to `claude-haiku-4.5`, so both the rubric and the judge are visible in the command.

**2. Agent invocation is part of the treatment and must be evidenced.** The baseline sends the canonical question as one prompt. The customized variant follows the repository's established conformance pattern: turn 0 launches `.github/agents/hve-core/rpi-agent.agent.md`, and turn 1 sends the same canonical question.
Copying an agent file into a workspace is not invocation. Every customized `model|stimulus|trial` identity must have one successful structured read of the exact staged agent path with non-empty RPI Agent content. Failed reads, wrong paths, missing identities, duplicates, and malformed evidence are structural failures.

**3. Comparison is report-only calibration until valid post-launch evidence supports a non-inferiority policy.** The 35 stimuli all carry the `equivalent` policy. Signed scores, mean, standard deviation, 95% confidence bounds, and per-stimulus dispersion are computed separately for each model. Complete-delivery evidence resolved the boundary-stimulus decision by showing that five removed guards measured lifecycle phase behavior rather than nominal model non-degradation.
Tie ratio and Vally's all-policy aggregate fields remain diagnostics. No comparative pass or fail state exists until a later human-owned decision defines score direction, hypotheses, numeric degradation margin, confidence level, boundary inequality, missing-bound behavior, and a rule forbidding pass-seeking recalibration. Historical values from before launch-based invocation are not comparable to the first valid calibration.

**4. Tiers separate local iteration from two-model calibration while preserving authoritative evidence.** `devloop` runs one selected model and remains advisory. `calibration` and `ci` run the fixed pair `gpt-5.6-luna` and `claude-sonnet-4.6`. Comparison and persona-bleed guards are report-only at every current tier.
Deterministic invariants, successful agent invocation, run health, and structural data quality remain authoritative in `calibration` and `ci`; structural failures fail closed even in `devloop`.
The former `pr` and `nightly` names remain rejected rather than aliased.

**5. Judge errors are counted and structural exclusions fail closed.** `judgeErrors` and `judgeErrorRate` appear in every summary. Any missing or judge-excluded comparison population is a data-quality violation and invalidates calibration rather than silently reducing the denominator.
Their acceptable bar is unresolved pending the calibration work, and a gate that enforces an uncalibrated threshold asserts a standard no one has validated.
A judge failure is not silently tolerated: a comparison that yields no records the judge could score is a run-health failure, so an unusable judge already fails closed without a numeric budget.
Model scope follows cost: `devloop` resolves an explicit `-Model` override, then the agent's frontmatter `model:` hint, then the low-cost default `gpt-5.6-luna`; `calibration` and `ci` sweep the fixed pair. No floating alias such as `latest` is used.

**6. Stage 1 measures one subject; the multi-agent sweep is staged behind it.** The executable Launch turn targets the RPI Agent, while backlinks identify related artifacts rather than authorize equivalence subjects. The corpus is excluded from generic tag-filtered dispatch, which previously produced partial and zero-stimulus runs that reported success without evidencing anything.
Expanding to per-subject conditional guards across all nine agents is deferred until one clean run under the restored comparison contract exists, so the expansion multiplies a measurement that has been shown to work rather than one that has not.

Declared invariants and declared divergence guards are reconciled against an expected stimulus, grader, and trial manifest in both directions.
Presence of a signal is not coverage: a grader declared in the canonical library but absent from an executable spec is never evaluated, so a name-scoped reader would report zero failures over a population that never ran.
Missing, duplicate, misplaced, and malformed results are data-quality violations, and a run whose declared population was incomplete cannot be cached as a reusable baseline.

**7. Gating invariants are limited to comparative evidence; other graders report without gating.** Invariants are read from the baseline run, so a declared invariant asserts something about the uncustomized model.
A grader whose outcome records how that model chose to respond cannot distinguish a customization effect from an underlying model preference, which is the only question this suite asks, so it runs and reports without entering the verdict.
`asks-clarifying-question` and `mentions-print-paren` report under this rule: the first records whether the baseline asked rather than attempted an underspecified request, and the second records which illustration it chose.
`mentions-scripts-or-deps` continues to gate, because its stimulus reads a file the shared seed workspace provides and a sibling stimulus reads the same file, so intermittent failure is evidence the read is unreliable rather than evidence of a preference.
This is not a mechanism for quieting a failing check. It is available only where the grader measures the baseline model rather than the customization, the grader keeps executing and reporting so a change stays visible, and the reasoning is recorded with the stimulus.
Threshold and run-count relaxation remain prohibited regardless.

**8. Evaluation execution has layered timeout containment.** Every canonical, baseline, and customized stimulus declares a 285-second agent working-duration limit below the 300-second hard timeout. Vally 0.12 owns bounded abort and disconnect cleanup for an active Copilot SDK request. The owning CI shard has a 240-minute outer timeout so an unexpected process-level cleanup failure cannot consume a runner indefinitely.
An agent-duration result remains part of the required population and is evaluated by the existing run-health and data-quality rules. Timeout containment never permits silent exclusion or a reduced denominator.

The reporting contract carries `schemaVersion: "2.1.0"`. Consumers reject an unsupported major version loudly rather than reading absent fields as zeros. Version 2.1 adds invocation evidence and per-model report-only calibration fields while preserving the 2.x structural contract.

### Consequences

* Good, because a reviewer can tell from the summary whether authoritative delivery or data evidence failed, while comparative and boundary behavior remains explicitly report-only.
* Good, because the judge model and rubric source are visible in the invocation, so two runs of the same commit are comparable.
* Good, because an incomplete or structurally broken run can never report a pass, at any tier.
* Good, because the local loop stays non-blocking, so contributors are not gated on a model-backed statistical result while iterating.
* Good, because a stalled executor request is bounded at both trial and job scope instead of preventing summary generation indefinitely.
* Bad, because the versioned reporting contract and separate evidence classes are more surface for downstream consumers to track.
* Bad, because comparative non-inferiority remains unclassified until valid post-launch evidence supports a margin and confidence policy.
* Neutral, because this policy adds no production telemetry emitter. The suite's observable outputs are the summary contract and CI artifacts, which are evaluation evidence rather than service telemetry, so no trace, metric, or log instrumentation is introduced.

### Confirmation

This decision remains `proposed` until a qualified human reviewer approves it and a later human-owned change records the acceptance.
Approval of the migration pull request alone does not confirm or adopt it.
The authoritative/report-only separation, fail-closed rules, population reconciliation, invocation evidence, and contract-version rejection are covered by tests in `scripts/tests/evals/EquivalenceParsing.Tests.ps1`, `scripts/tests/evals/Invoke-BaselineEquivalence.Tests.ps1`, and `scripts/tests/evals/Invoke-VallyEvals.Tests.ps1`.

## Pros and Cons of the Options

### Option A: Keep one blended verdict

* Good, because it is the smallest change and the existing consumers keep working unmodified.
* Bad, because the verdict conflates two independent questions, so an operator cannot act on a failure without re-reading the raw comparison output.
* Bad, because case-by-case interpretation guidance rots faster than code.

### Option B: Separate the gates only

* Good, because it resolves the most visible problem, which is the ambiguous verdict.
* Good, because it requires no change to the tier vocabulary or the CI dispatch surface.
* Bad, because the rubric source stays implicit, so a comparison remains reproducible only as long as nothing changes the spec files the judge might read.
* Bad, because trigger-shaped tier names continue to invite selecting an exit policy by accident.

### Option C: Full policy definition

* Good, because every policy question has one recorded answer that a reviewer can check against the code.
* Good, because the fail-closed and advisory rules are explicit, so the suite cannot quietly report a pass it did not measure.
* Bad, because it is the largest change and touches the driver, the parser, the dispatcher, and the reporting contract at once.

## Affected Components

* package.json
* evals/baseline-equivalence/
* .github/workflows/eval-validation.yml
* scripts/evals/Invoke-BaselineEquivalence.ps1
* scripts/evals/Invoke-VallyEvals.ps1
* scripts/evals/lib/EquivalenceParsing.psm1
* scripts/evals/lib/EquivalenceEnvironment.psm1

## More Information

* [package.json](../../../package.json) pins the Vally CLI version whose executor timeout and cleanup semantics the suite relies on.
* [evals/baseline-equivalence/](pathname://../../../evals/baseline-equivalence/) holds the stimulus corpus and the paired baseline and customized specs this policy governs; its [README.md](pathname://../../../evals/baseline-equivalence/README.md) documents the runtime behavior, the summary field contract, and the pass and fail interpretation rules.
* [.github/workflows/eval-validation.yml](../../../.github/workflows/eval-validation.yml) owns the outer eval-shard timeout and credentialed calibration dispatch.
* [scripts/evals/Invoke-BaselineEquivalence.ps1](../../../scripts/evals/Invoke-BaselineEquivalence.ps1) is the single entry point that owns tier validation, model resolution, the pinned judge invocation, and the exit policy in parts 1, 3, and 4.
* [scripts/evals/lib/EquivalenceParsing.psm1](../../../scripts/evals/lib/EquivalenceParsing.psm1) computes both gates and the verdict described in parts 2 and 4, and reads comparison and guard results.
* [scripts/evals/lib/EquivalenceEnvironment.psm1](../../../scripts/evals/lib/EquivalenceEnvironment.psm1) materializes the per-agent customized environment and its referenced artifacts.
* [scripts/evals/Invoke-VallyEvals.ps1](../../../scripts/evals/Invoke-VallyEvals.ps1) dispatches the suite in CI and is the consumer that rejects an unsupported reporting-contract major version.
* ADR 0002 adopted Vally and identified the baseline-equivalence guarantee this policy governs.
* ADR 0010 corrected PR-time execution semantics; its typed-record parsing rule is extended here to the equivalence results reader, and the tier vocabulary it described as PR and nightly is renamed by part 4 of this decision.

## ADR Planning

> [!CAUTION]
> **Disclaimer:** This agent is an assistive tool only. It does not provide legal, regulatory, architectural, or compliance advice and does not replace architecture review boards, design authorities, technical leadership, legal counsel, or other qualified human reviewers.
> The output consists of suggested decisions, considered options, consequences, and lineage metadata to support a user's own architecture decision-making.
> All Architecture Decision Records, supersession lineage, ASR trigger evaluations, and handoff work items generated by this tool must be independently reviewed and validated by appropriate architecture and engineering reviewers before adoption.
> Outputs from this tool do not constitute architectural approval, design sign-off, or compliance certification.

* [ ] Reviewed and validated by a qualified human reviewer

---

🤖 *Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
