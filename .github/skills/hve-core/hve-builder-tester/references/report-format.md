---
description: 'Action-category taxonomy, report structure, and human-review disclaimer for the hve-builder-tester report.'
---
<!-- markdownlint-disable-file -->
# HVE Artifact Test Report Format

The hve-builder-tester lead composes the report by merging the `HVE Artifact Test Reviewer` findings into this shape and writing it to a durable dated path outside the sandbox. The report is structured-findings-first, rendered to markdown, and ends in a human-review disclaimer the agent never checks.

## Action-category taxonomy

Every finding carries exactly one action category. These describe what the artifact's author should do in response to the observed runtime behavior:

| Category    | Meaning                                                                          |
|-------------|----------------------------------------------------------------------------------|
| improvement | The artifact worked, but a change would raise its runtime quality.               |
| adjustment  | A rule or wording behaved differently than intended and should be tuned.         |
| deletion    | An instruction fired but added no value or caused noise, and should be removed.  |
| correction  | The artifact did the wrong thing at runtime and must be fixed.                   |
| miss        | The artifact failed to do something its contract required, a gap in coverage.    |

## Finding shape

Record each finding with a stable shape so the author can act on it directly:

* Action category, from the taxonomy above.
* The instruction-quality category or review-rubric dimension it maps to, so every finding is traceable to the standard `hve-builder` authors against.
* The target artifact.
* An evidence pointer into the test log: the turn, observation, or emulated dispatch that shows the behavior.
* Severity: Critical, High, Medium, or Low, using the review-rubric scale.
* The smallest concrete change that would resolve it.

## Report structure

```markdown
# HVE Artifact Test Report: {{artifact_or_set}}

- Tested tier(s): {{tier and model per target}}
- Run status: Complete | Partial | Deferred
- Verdict: Pass | Revise | Blocked
- Sandbox: cleaned up | retained at {{path}}

## Summary

{{One paragraph: what was tested, how it behaved at runtime, and the headline findings.}}

## Findings

{{Ordered by severity, Critical and High first. One row per finding.}}

| # | Action | Mapped dimension | Artifact | Severity | Evidence | Resolving change |
|---|--------|------------------|----------|----------|----------|------------------|

## Coverage

{{Behaviors that ran as intended, and any contracted behavior left untested with the reason.}}

## Satisfied-and-skipped

{{Any target recorded as having no runtime behavior to exercise, with the reason.}}

## Human review

- [ ] Reviewed and validated by a qualified human reviewer
```

## Rules

* Order findings by severity, Critical and High first.
* Keep the finding set bounded and high-leverage; consolidate overlapping issues rather than padding the list.
* Do not use the legacy Prompt Evaluator taxonomy; use the action categories above tagged with the mapped standard dimension.
* Never check the human-review checkbox; only a human converts `[ ]` to `[x]`.
* Cite `.copilot-tracking/` and sandbox log paths as plain text; use markdown links only for durable, human-facing files.

> Brought to you by microsoft/hve-core
