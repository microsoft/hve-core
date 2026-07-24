---
description: 'Action categories, evidence-bounded findings, fidelity disclosure, report structure, and human-review requirement for behavior tests.'
---
<!-- markdownlint-disable-file -->
# HVE Artifact Test Report Format

The `hve-builder-tester` lead merges generic evidence-grading findings into this durable report outside the sandbox. The report separates execution status, quality verdict, fidelity, and limitations so simulation evidence cannot be mistaken for native behavior.

## Action-category taxonomy

Every finding carries exactly one action category. These describe what the artifact's author should do in response to the behavior evidence:

| Category    | Meaning                                                                         |
|-------------|---------------------------------------------------------------------------------|
| improvement | The artifact worked, but a change would raise its behavior quality.             |
| adjustment  | A rule or wording behaved differently than intended and should be tuned.        |
| deletion    | An instruction fired but added no value or caused noise, and should be removed. |
| correction  | The artifact produced incorrect behavior and must be fixed.                     |
| miss        | The artifact failed to do something its contract required, a gap in coverage.   |

## Finding shape

Record each finding with a stable shape so the author can act on it directly:

* Action category, from the taxonomy above.
* The instruction-quality category or review-rubric dimension it maps to, so every finding is traceable to the standard `hve-builder` authors against.
* The target artifact and tested profile.
* Fidelity and evidence class: observed, simulated, or emulated.
* An evidence pointer into the test log: the turn, observation, or dispatch that shows the behavior.
* Severity: Critical, High, Medium, or Low, using the review-rubric scale.
* The smallest concrete change that would resolve it.

## Report structure

```markdown
# HVE Artifact Test Report: {{artifact_or_set}}

- Tested profile(s): {{Medium or Low and model per target}}
- Run type: full | correction
- Behavior gate: Executed | Satisfied-and-skipped
- Fidelity: simulation | native | Not applicable
- Execution status: Complete | Partial | Deferred | Blocked | Not run
- Verdict: Pass | Revise | Blocked | Not available | Not applicable
- Sandbox: cleaned up | retained at {{path}}

## Summary

{{One paragraph: what was exercised, at what fidelity, what was observed, and the headline findings.}}

## Fidelity and limitations

{{State which actions were observed, simulated, or emulated; identify proxy-model use; and list claims this run cannot support.}}

## Reuse eligibility

{{For a correction run, record the prior report status and verdict, open-finding state, design and scenario IDs, requirement mapping, prior and current target revisions, profile, model or proxy status, modality, fidelity, and changed-surface impact. State why each reused scenario is unaffected. For a full run, state Not applicable.}}

| Scenario        | Requirement                   | Impact disposition                     | Evidence source                     | Grade provenance                |
|-----------------|-------------------------------|----------------------------------------|-------------------------------------|---------------------------------|
| {{scenario_id}} | {{requirement_id_or_summary}} | {{affected_unaffected_or_untraceable}} | {{fresh_execution_or_prior_report}} | {{fresh_grade_or_reused_grade}} |

## Findings

{{Ordered by severity, Critical and High first. One row per finding.}}

| # | Action | Mapped dimension | Artifact | Profile | Evidence class | Severity | Evidence | Resolving change |
|---|--------|------------------|----------|---------|----------------|----------|----------|------------------|

## Coverage

{{Behaviors that ran as intended, and any contracted behavior left untested with the reason.}}

## Containment

{{Pre-run and post-run workspace status, enforced controls, and any unexpected side effect.}}

## Satisfied-and-skipped

{{Any target recorded as having no runtime behavior to exercise, with the reason.}}

## Human review

- [ ] Reviewed and validated by a qualified human reviewer
```

## Rules

* Order findings by severity, Critical and High first.
* Keep the finding set bounded and high-leverage; consolidate overlapping issues rather than padding the list.
* Use the action categories above tagged with the mapped standard dimension; do not introduce a retired taxonomy.
* Use `runtime` or `native` only for behavior observed through native fidelity. Use `simulation` for literal conformance execution and `emulated` for actions that did not run.
* A proxy-model run cannot claim target-model equivalence. An unexpected out-of-sandbox write prevents Pass.
* A correction run cannot reuse evidence unless every eligibility dimension is recorded. Untraceable scenarios are affected and require fresh execution and independent grading.
* Use Not available only when execution is Deferred before independent grading. Pass, Revise, and Blocked require grading evidence.
* Use `Satisfied-and-skipped` only for a target or change with no runtime behavior. Pair it with fidelity `Not applicable`, execution `Not run`, verdict `Not applicable`, and a reason.
* Never check the human-review checkbox; only a human converts `[ ]` to `[x]`.
* Cite `.copilot-tracking/` and sandbox log paths as plain text; use markdown links only for durable, human-facing files. The durable report is the source of truth for the behavior-test outcome.
