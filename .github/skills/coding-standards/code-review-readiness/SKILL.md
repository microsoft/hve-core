---
name: code-review-readiness
description: 'Review change packaging, validation evidence, PR metadata, and changed documentation. Use for the readiness perspective of Code Review.'
license: CC-BY-4.0
user-invocable: false
---

# Readiness review

## Goal

Show whether the change is accurately described and supported by the required
delivery evidence. Use `code-review-core`, activating it when not preloaded.

## Review

Compare the stated purpose, captured changes, validation results, and follow-up
items. Report material scope omissions or unsupported claims. Review changed
documentation against the implementation and its referenced contracts, reading
surrounding sections when needed to detect misleading instructions or links.

For a PR/MR with captured metadata:

* Check the description against the actual changed surface.
* Compare linked-issue intent with the change. Record each acceptance criterion
  the parent assigns to readiness as Implemented, Partial, Not found, or Not
  assessed, with evidence, in the result observations for the parent's coverage
  table.
* Report unchecked required checklist items as at least Medium and name their
  clearing action. Never check a human-review box.
* Report a non-open target, conflicts, blocked merge state, or failing required
  checks from the captured fields. Pending and unknown checks are not passing.

Use metadata anchors naming the exact captured field for PR-deliverable findings.
Use changed-line anchors for documentation findings. Missing PR context permits
no assertion about its contents: record unavailable checks and their impact on
the requested coverage. Non-PR targets skip PR-only checks without inventing a PR.

Leave code correctness, standards, accessibility, and security grading to their
owners. Pass relevant observations to the parent.

## Completion

Include the evaluated metadata and documentation scope in the result. Stop
blocked when required delivery evidence is unavailable; do not normalize the gap
into readiness. Never modify a checklist.
