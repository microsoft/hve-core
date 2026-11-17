---
description: 'Readiness review reference for Code Review covering PR packaging, validation evidence, and changed documentation under the functional vector.'
---

# Readiness review

## Goal

Verify that the change is accurately described and backed by required delivery and documentation evidence under the `functional` review vector. Follow [review-contract.md](review-contract.md).

## Review

Compare stated purpose, captured changes, validation results, and follow-up items. Report material scope omissions or unsupported claims. Review changed documentation against the implementation and referenced contracts, reading surrounding sections when needed to catch broken or misleading instructions and links.

For a PR/MR with captured metadata:

* Check the PR description against the actual changed surface.
* Compare linked-issue intent with the change, recording any deliverable-only acceptance criteria assigned to `readiness` as `Implemented`, `Partial`, `Not found`, or `Not assessed` with evidence in `observations`.
* Report unchecked required checklist items as at least `Medium` and name their clearing action. Never check a human-review box.
* Report a non-open target, merge conflicts, blocked merge state, or failing required checks from captured metadata. Pending and unknown checks are not passing.

Use `side: "metadata"` anchors naming the exact captured field for PR-deliverable findings, and changed-line anchors for documentation findings. Missing PR metadata permits no assumption about PR contents: record unavailable checks explicitly. Non-PR targets skip PR-only checks without inventing a PR.

## Completion

Record the evaluated metadata and documentation scope in the result. Stop `blocked` when required delivery evidence is unavailable rather than normalizing the gap into readiness. Never modify a checklist.
