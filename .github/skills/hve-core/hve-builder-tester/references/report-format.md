---
description: 'Behavior-test finding categories, evidence boundaries, report structure, and human-review requirements.'
---
<!-- markdownlint-disable-file -->
# HVE Artifact Test Report Format

The HVE Builder Tester lead composes one durable report from the final design, execution log, and independent grade. Keep execution status, quality verdict, fidelity, and limitations separate.

Fidelity describes how the target was exercised: `simulation` or `native`, or `Not applicable` for a supported skip. Evidence class describes an individual action or observation: `observed`, `simulated`, or `emulated`. An emulated action within a simulation is not a third execution fidelity and does not support a claim that the action ran.

## Finding Categories

| Category    | Meaning                                                                                          |
|-------------|--------------------------------------------------------------------------------------------------|
| improvement | The behavior passed, but an evidence-backed change would improve quality                         |
| adjustment  | A rule behaved differently than intended and should be tuned                                     |
| deletion    | Evidence supports retiring an obsolete or redundant instruction without losing required behavior |
| correction  | The artifact produced incorrect behavior                                                         |
| miss        | Required behavior was absent or untested                                                         |

Every finding records one category, mapped requirement or review dimension, target, profile, fidelity, evidence class, durable evidence pointer, severity, and smallest resolving change. Mark each finding as a required correction or an advisory suggestion. A deletion recommendation follows the requirements catalog's maintenance decisions; one scenario that does not need a rule is not evidence that no supported use case needs it.

## Verdict Rules

* Pass requires gradeable evidence, complete material coverage, and no required correction. Advisory improvements do not prevent Pass.
* Revise means the evidence demonstrates a target defect or unmet acceptance criterion at any severity.
* Untested material behavior is a coverage miss, not proof of a target defect. Record execution Partial when usable evidence is incomplete; the grader states whether the available evidence warrants Revise or is insufficient for a verdict, Blocked. Partial never supports overall Pass.
* Blocked means independent grading cannot establish a credible verdict. If execution or grading never produced an independent grade, use verdict Not available with execution Deferred or Blocked and the exact reason.

## Report Structure

```markdown
# HVE Artifact Test Report: {{artifact_or_set}}

* Candidate revision: {{source_revision_or_equivalent_provenance}}
* Tested profile and model: {{profile_requested_model_host_binding_evidence_and_actual_model_when_exposed}}
* Behavior disposition: {{Executed_or_Satisfied-and-skipped}}
* Fidelity: {{simulation_native_or_Not_applicable}}
* Execution status: {{Complete_Partial_Deferred_Blocked_or_Not_run}}
* Verdict: {{Pass_Revise_Blocked_Not_available_or_Not_applicable}}
* Sandbox: {{cleaned_up_or_retained_path}}

## Summary

{{What ran, at which fidelity, and the headline result.}}

## Fidelity and Limitations

{{Observed, simulated, and emulated actions; proxy use; unsupported claims; and material gaps.}}

## Findings

{{Repeat the following block per finding, or write None.}}

### {{finding_id}}: {{short_title}}

* Action category: {{improvement_adjustment_deletion_correction_or_miss}}
* Disposition: {{required_correction_or_advisory_suggestion}}
* Mapped requirement or dimension: {{criterion}}
* Artifact: {{target}}
* Profile: {{profile}}
* Fidelity: {{simulation_or_native}}
* Evidence class: {{observed_simulated_or_emulated}}
* Severity: {{Critical_High_Medium_or_Low}}
* Evidence: {{durable_pointer_and_decisive_observation}}
* Resolving change: {{smallest_supported_change}}

## Coverage

{{Requirements and scenarios exercised, behavior that passed, and contracted behavior left untested.}}

## Retained Evidence

{{Scenario inputs, requirement-to-scenario map, decisive trace excerpts, and independent grading rationale, or pointers to durable companion evidence outside the sandbox.}}

## Containment

{{Pre-run and post-run workspace state, enforced controls, and unexpected effects.}}

## Satisfied-and-Skipped

{{No-runtime targets and evidence-backed reasons, or Not applicable.}}

## Human Review

* [ ] Reviewed and validated by a qualified human reviewer
```

## Rules

* Order findings by severity and consolidate overlapping issues.
* Use `native` only for directly observed native execution and `simulation` for literal contained execution. Mark an action that did not run with evidence class `emulated`; retain the run's actual fidelity.
* A proxy run cannot claim target-profile equivalence. An unexpected out-of-sandbox write prevents Pass.
* Use Not available only when execution is Deferred or Blocked before independent grading. Pass, Revise, and Blocked verdicts require grading evidence.
* Pair `Satisfied-and-skipped` with fidelity `Not applicable`, execution `Not run`, verdict `Not applicable`, and a reason.
* Leave the human-review checkbox unchecked.
* Cite tracking and sandbox paths as plain text. Use Markdown links only for durable human-facing files.
