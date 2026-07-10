---
description: 'Original Microsoft atomicity checklist used by the BRD Builder assessor to validate that an acceptance criterion is testable, atomic, and unambiguous - CC BY 4.0'
---

# Acceptance Criterion Atomicity Checklist

This checklist is the authoritative rubric the BRD Builder's `BRD Quality Reviewer` subagent applies to every candidate acceptance criterion before it is recorded in a BRD draft or emitted into a per-partition handoff payload. It is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

The checklist is format-neutral: it applies equally to a Given/When/Then triplet, a flat checklist entry, a rule-with-examples row, and a non-functional threshold statement.

## Scoring Model

Each candidate criterion is scored against the seven rules below. Scoring values:

* `PASS` - the rule is satisfied as written.
* `REWRITE` - the rule is not satisfied and the criterion is rewritten before it is recorded.
* `N/A` - the rule does not apply to the criterion format (for example, rule 2 on independent preconditions does not apply when no `Given` clause is used).

A criterion is recorded only when every applicable rule scores `PASS`. A criterion that scores `REWRITE` on any applicable rule is rewritten and re-scored.

## The Seven Rules

### Rule 1 - One behavior per criterion

The criterion describes one and only one behavior. Multiple behaviors joined by `and`, `or`, or a comma are split into separate criteria.

* Triggers a `REWRITE` when the `When` clause (or the equivalent action in another format) contains a conjunction that joins two independent actions.
* Triggers a `REWRITE` when one criterion describes both a happy path and an error path.

### Rule 2 - Independent preconditions are split

When the `Given` clause (or its equivalent context section) lists preconditions that can vary independently across test cases, each precondition cluster gets its own criterion.

* Triggers a `REWRITE` when the `Given` clause combines preconditions that exercise different code paths.
* Does not apply when the preconditions co-vary by design (for example, "a registered account with a valid email and password" is one precondition cluster, not two).

### Rule 3 - One observable outcome per criterion

The criterion describes one and only one observable outcome. `Then` clauses chained with `and` are split when the outcomes can fail independently of one another.

* Triggers a `REWRITE` when one outcome is a UI change and the other is a backend side effect that can fail without the UI change failing (or vice versa).
* Does not apply when the chained clauses describe one composite observable outcome (for example, an HTTP response that includes both a status code and a body).

### Rule 4 - Externally observable outcomes only

The outcome named in the criterion is observable by the user, by another system, or by an external monitor. Solution-internal state changes are out of scope unless the requirement is explicitly about that internal state.

* Triggers a `REWRITE` when the outcome names a table row, a log line, a queue depth, or a private method invocation as the sole observable.
* Does not apply when the requirement is specifically about an audit, logging, or persistence behavior whose observable surface is the internal state in question.

### Rule 5 - No unmeasured quantifiers

Words that imply a measurable quantity without naming the measurement are rewritten with a threshold or removed. Examples of words that trigger this rule: `quickly`, `easily`, `most`, `usually`, `often`, `rarely`, `large`, `small`, `responsive`, `intuitive`.

* Triggers a `REWRITE` when any such word appears in the criterion.
* Replacement guidance: pair the quantifier with a measurable threshold (for example, "p95 latency under 200 ms" replaces "quickly") or remove it when the requirement does not actually have a quantitative target.

### Rule 6 - Stable, single subject

Each criterion has one actor and one system under test. The actor is the subject of the `When` clause (or its equivalent); the system under test is the subject of the `Then` clause.

* Triggers a `REWRITE` when the criterion combines two actors performing different roles in the same triplet.
* Triggers a `REWRITE` when the system under test changes mid-criterion (for example, the criterion conflates the web client and the backend service).

### Rule 7 - No solution-internal references

The criterion does not name internal modules, table names, API routes, or class names unless the requirement is explicitly about that component. Acceptance criteria describe what the solution does, not how it is built.

* Triggers a `REWRITE` when the criterion names an implementation artifact that the stakeholder cannot observe or verify.
* Does not apply when the requirement is explicitly about a named external API or a contracted integration point.

## Application Order

The assessor applies the rules in the order above. The first three rules detect compound criteria and split them; the remaining four rules validate the resulting atomic criteria. Applying the rules in this order avoids re-evaluating a compound criterion against the later rules.

## Outputs

The assessor records per-criterion results in the plan-mode report using this structure:

* Criterion identifier (assigned by the BRD Builder at capture time).
* Per-rule score: `PASS`, `REWRITE`, or `N/A`.
* Rewrite text when any rule scored `REWRITE`.
* Disposition: `RECORDED` (all applicable rules passed) or `REWRITTEN` (one or more rules triggered a rewrite that was applied).

The plan-mode report format is owned by [`brd-quality-formats`](../brd/brd-quality-formats.md) (when published).

## License

This checklist is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), copyright (C) Microsoft Corporation.


