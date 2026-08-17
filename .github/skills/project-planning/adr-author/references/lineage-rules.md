---
title: ADR Lineage Rules
description: Five supersession and lineage rules enforced by the adr-author skill validators (GP-06)
author: microsoft/hve-core
ms.date: 2026-08-17
ms.topic: reference
keywords:
  - adr
  - architecture-decision-record
  - lineage
  - supersession
  - project-planning
---

# ADR Lineage Rules (GP-06)

The five rules below govern supersession and lineage for ADRs authored by the `adr-author` skill. The scripts enforce the structural and mutation invariants described below; workflow-only requirements are identified explicitly.

## 1. Field Shape

`supersedes` is a scalar four-digit ADR identifier string (for example, `"0007"`) or `null`. `superseded-by` is likewise a scalar string or `null` (for example, `"0042"` or `null`). The validator rejects array values for either field, enforcing single-parent supersession (see Rule 2).

- Valid: `superseded-by: null`, `superseded-by: "0042"`, `supersedes: "0007"`.
- Invalid (counter-example): `superseded-by: ["0042", "0043"]` — rejected because supersession is single-parent (see Rule 2).

## 2. Single-Parent Supersession

Any given ADR has at most one `superseded-by`. Once an ADR is superseded, a second supersession attempt against the same predecessor fails validation. To replace a successor, supersede the successor itself; do not rewrite the predecessor's `superseded-by`.

- Valid: ADR-0007 → superseded-by ADR-0042. Later, ADR-0042 → superseded-by ADR-0099. ADR-0007 still points to ADR-0042; the chain is walked forward.
- Invalid (counter-example): rewriting ADR-0007's `superseded-by` from `ADR-0042` to `ADR-0099` to "skip" the intermediate decision — rejected.

## 3. Status Transition Rule

The superseding ADR's `status` remains unchanged; it should be `accepted`, or remain `proposed` until the Govern phase accepts it. `scripts/update_lineage.py` changes the superseded ADR's `status` to `superseded`. `scripts/validate_frontmatter.py` validates each status value independently, but does not validate the status pair as a lineage transition.

- Valid: successor `status: accepted`, predecessor `status: superseded`.
- Invalid by workflow policy: successor `status: rejected` paired with predecessor `status: superseded`. The current scripts do not reject this combination automatically.

## 4. Atomic Update Rule

Both ADR files MUST be modified in the same Govern phase invocation. `scripts/update_lineage.py` writes both files (predecessor `superseded-by` update and successor `supersedes` entry) or neither. Partial writes are rolled back. There is no two-step "update predecessor later" flow.

- Valid: a single Govern invocation produces a commit (or staged change set) that contains edits to both files.
- Invalid (counter-example): writing the successor's `supersedes` now and "remembering" to update the predecessor in a follow-up session — rejected because the lineage allocator refuses partial application.

## 5. Single-Writer Rule for `last_decision_id`

`scripts/update_lineage.py` is the designated writer of `last_decision_id` in `.adr-config.yml`. Manual edits to `last_decision_id` are forbidden by workflow policy. The allocator validates that the stored value is an integer or four-digit string before incrementing it. It does not currently reconcile the value against ADR identifiers on disk.

- Valid: `last_decision_id` is updated only by the script during ADR allocation in the Govern phase.
- Invalid by workflow policy: a contributor hand-edits `.adr-config.yml` to bump `last_decision_id` ahead of the next allocation. A correctly formatted manual value is not currently distinguishable from an allocator-written value.

## Validation Failure Modes

The scripts report human-readable errors rather than stable `LINEAGE_*` category identifiers:

1. `scripts/validate_frontmatter.py` reports field-specific errors when `supersedes` or `superseded-by` is not a four-digit string or `null`.
2. `scripts/update_lineage.py` refuses a second supersession when the predecessor already has a non-empty `superseded-by` value.
3. The supersession command rejects missing files, identical paths, duplicate ADR identifiers, malformed frontmatter, and filenames without a four-digit identifier prefix.
4. Both ADR files are restored to their original contents when post-write validation fails. A failure replacing the predecessor also restores the superseder.
5. The allocator rejects a malformed or exhausted `last_decision_id`; detecting a valid but manually modified value remains a workflow responsibility.
