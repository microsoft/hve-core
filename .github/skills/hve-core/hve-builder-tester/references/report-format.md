---
description: 'Behavior-test finding categories, evidence boundaries, report structure, and human-review requirements.'
---
<!-- markdownlint-disable-file -->
# HVE Artifact Test Report Format

The HVE Builder Tester lead composes one durable report from the final design, execution log, and independent grade. Keep execution status, quality verdict, fidelity, and limitations separate.

## Finding Categories

| Category    | Meaning                                                                  |
|-------------|--------------------------------------------------------------------------|
| improvement | The behavior passed, but an evidence-backed change would improve quality |
| adjustment  | A rule behaved differently than intended and should be tuned             |
| deletion    | An instruction fired without value or caused noise                       |
| correction  | The artifact produced incorrect behavior                                 |
| miss        | Required behavior was absent or untested                                 |

Every finding records one category, mapped requirement or review dimension, target, profile, fidelity, evidence class, test-log pointer, severity, and smallest resolving change.

## Report Structure

```markdown
# HVE Artifact Test Report: {{artifact_or_set}}

* Candidate revision: {{source_revision_or_equivalent_provenance}}
* Tested profile and model: {{profile_and_model_per_target}}
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

| # | Action | Mapped dimension | Artifact | Profile | Evidence class | Severity | Evidence | Resolving change |
|---|---|---|---|---|---|---|---|---|

## Coverage

{{Requirements and scenarios exercised, behavior that passed, and contracted behavior left untested.}}

## Containment

{{Pre-run and post-run workspace state, enforced controls, and unexpected effects.}}

## Satisfied-and-Skipped

{{No-runtime targets and evidence-backed reasons, or Not applicable.}}

## Human Review

* [ ] Reviewed and validated by a qualified human reviewer
```

## Rules

* Order findings by severity and consolidate overlapping issues.
* Use `native` only for directly observed native execution, `simulation` for literal contained execution, and `emulated` for actions that did not run.
* A proxy run cannot claim target-profile equivalence. An unexpected out-of-sandbox write prevents Pass.
* Use Not available only when execution is Deferred before independent grading. Pass, Revise, and Blocked require grading evidence.
* Pair `Satisfied-and-skipped` with fidelity `Not applicable`, execution `Not run`, verdict `Not applicable`, and a reason.
* Leave the human-review checkbox unchecked.
* Cite tracking and sandbox paths as plain text. Use Markdown links only for durable human-facing files.