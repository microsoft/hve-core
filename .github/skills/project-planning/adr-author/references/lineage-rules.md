---
title: ADR Lineage Rules
description: Five supersession and lineage rules enforced by the adr-author skill validators (GP-06)
author: microsoft/hve-core
ms.date: 2026-05-02
ms.topic: reference
keywords:
  - adr
  - architecture-decision-record
  - lineage
  - supersession
  - project-planning
---

# ADR Lineage Rules (GP-06)

The five rules below govern supersession and lineage for ADRs authored by the `adr-author` skill. All five are enforced by `scripts/validate_frontmatter.py` and `scripts/update_lineage.py`. Violations are hard-fail validation errors.

## 1. Field Shape

`supersedes` is an array of zero or more ADR identifiers (for example, `["ADR-0007", "ADR-0011"]`). `superseded-by` is a scalar string or `null` (for example, `"ADR-0042"` or `null`). The validator rejects array values for `superseded-by`.

- Valid: `superseded-by: null`, `superseded-by: "ADR-0042"`.
- Invalid (counter-example): `superseded-by: ["ADR-0042", "ADR-0043"]` — rejected because supersession is single-parent (see Rule 2).

## 2. Single-Parent Supersession

Any given ADR has at most one `superseded-by`. Once an ADR is superseded, a second supersession attempt against the same predecessor fails validation. To replace a successor, supersede the successor itself; do not rewrite the predecessor's `superseded-by`.

- Valid: ADR-0007 → superseded-by ADR-0042. Later, ADR-0042 → superseded-by ADR-0099. ADR-0007 still points to ADR-0042; the chain is walked forward.
- Invalid (counter-example): rewriting ADR-0007's `superseded-by` from `ADR-0042` to `ADR-0099` to "skip" the intermediate decision — rejected.

## 3. Status Transition Rule

The superseding ADR's `status` becomes `accepted` (or remains `proposed` until the Govern phase accepts it). The superseded ADR's `status` becomes `superseded`. The validator rejects any other final-state combination (for example, marking the predecessor `deprecated` while pointing `superseded-by` at a successor).

- Valid: successor `status: accepted`, predecessor `status: superseded`.
- Invalid (counter-example): successor `status: rejected` paired with predecessor `status: superseded` — rejected because a rejected ADR cannot supersede anything.

## 4. Atomic Update Rule

Both ADR files MUST be modified in the same Govern phase invocation. `scripts/update_lineage.py` writes both files (predecessor `superseded-by` update and successor `supersedes` entry) or neither. Partial writes are rolled back. There is no two-step "update predecessor later" flow.

- Valid: a single Govern invocation produces a commit (or staged change set) that contains edits to both files.
- Invalid (counter-example): writing the successor's `supersedes` now and "remembering" to update the predecessor in a follow-up session — rejected because the lineage allocator refuses partial application.

## 5. Single-Writer Rule for `last_decision_id`

`scripts/update_lineage.py` is the only writer of `last_decision_id` in `.adr-config.yml`. Manual edits to `last_decision_id` are forbidden. `scripts/validate_frontmatter.py` detects drift (for example, when the highest existing ADR identifier on disk does not equal `last_decision_id`) and rejects the workspace until reconciled by re-running the lineage script.

- Valid: `last_decision_id` is updated only by the script during ADR allocation in the Govern phase.
- Invalid (counter-example): a contributor hand-edits `.adr-config.yml` to bump `last_decision_id` ahead of the next allocation — rejected on next validation pass.

## Validation Failure Modes

The validator emits one of the following five error categories when a lineage rule is violated. Each maps one-to-one with the rule above.

1. `LINEAGE_FIELD_SHAPE` — `superseded-by` is not a scalar string or `null`, or `supersedes` is not an array.
2. `LINEAGE_MULTIPLE_PARENTS` — an ADR already has a non-null `superseded-by` and a second supersession is attempted against it.
3. `LINEAGE_BAD_STATUS_TRANSITION` — successor or predecessor ends in a status other than the permitted (`accepted`/`proposed`, `superseded`) combination.
4. `LINEAGE_ATOMIC_VIOLATION` — exactly one of the two affected ADR files was modified in the Govern invocation; both must be present in the change set.
5. `LINEAGE_LAST_DECISION_DRIFT` — `last_decision_id` in `.adr-config.yml` does not match the highest ADR identifier on disk, indicating an unauthorized manual edit or a missed script run.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
