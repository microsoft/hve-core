---
name: code-review-functional
description: 'Review assigned snapshot evidence for behavioral defects and regressions. Use for the functional perspective of Code Review.'
license: CC-BY-4.0
user-invocable: false
---

# Functional review

## Goal

Find changed behavior that violates an intended contract or causes a concrete
regression. Use the `code-review-core` contract, activating it when not preloaded.

## Review

Read the assignment and captured hunks, then trace only the caller/callee context
needed to assess success paths, failure paths, boundary inputs, concurrency,
resource ownership, persistence, and compatibility. Apply the assigned depth.
Use existing tests and evidence; distinguish a test's presence from its result.

Compare supplied acceptance criteria with delivered behavior. Record each as
Implemented, Partial, Not found, or Not assessed with evidence and gaps in the
result observations for the parent's coverage table. Missing story text is
unassessed. The parent assigns each criterion to one perspective.

Report a finding only when the changed path supports the claim and consequence.
Check plausible counter-evidence before returning it. Preserve removed-line
anchors for deletion regressions. Pre-existing unrelated defects remain factual
out-of-scope observations, excluded from the verdict.

General style belongs to standards; deliverable metadata belongs to readiness.
Hand security or accessibility observations to the parent rather than grading
the same defect repeatedly.

## Completion

Success requires supported behavioral claims and accurate coverage. Stop blocked
when a missing contract or unresolved evidence prevents the assigned check, and
state the smallest needed input.
