---
title: ADR Lineage Rules
description: Five supersession and lineage rules for ADRs authored by the adr-author skill (GP-06), and which of them the scripts enforce
author: microsoft/hve-core
ms.date: 2026-10-23
ms.topic: reference
keywords:
  - adr
  - architecture-decision-record
  - lineage
  - supersession
  - project-planning
---

# ADR Lineage Rules (GP-06)

The five rules below govern supersession and lineage for ADRs authored by the `adr-author` skill. `scripts/validate_frontmatter.py` and `scripts/update_lineage.py` enforce some of them; the rest are review conventions that no script currently checks. Each rule states its enforcement, and [Validation Failure Modes](#validation-failure-modes) lists the messages and exit codes the scripts actually produce.

Two limits apply throughout:

- `scripts/validate_frontmatter.py` validates the ADR files handed to it on the command line, one file at a time. It never scans the ADR directory, never reads `.adr-config.yml`, and never compares two ADRs with each other, so it cannot enforce any cross-file rule.
- `scripts/update_lineage.py` applies its checks only when a supersession goes through the script. Frontmatter edited by hand is not checked after the fact.

## 1. Field Shape

`supersedes` is a scalar four-digit ADR identifier string (for example, `"0007"`) or `null`. `superseded-by` is likewise a scalar string or `null` (for example, `"0042"` or `null`). The validator rejects array values for either field, enforcing single-parent supersession (see Rule 2).

- Valid: `superseded-by: null`, `superseded-by: "0042"`, `supersedes: "0007"`.
- Invalid (counter-example): `superseded-by: ["0042", "0043"]` — rejected because supersession is single-parent (see Rule 2).
- Enforcement: **tooling**. `_validate_id_scalar` in `scripts/validate_frontmatter.py` rejects lists and any value that is not a four-digit string or `null`.

## 2. Single-Parent Supersession

Any given ADR has at most one `superseded-by`. Once an ADR is superseded, a second `update_lineage.py supersede` run against the same predecessor fails. To replace a successor, supersede the successor itself; do not rewrite the predecessor's `superseded-by`.

- Valid: ADR-0007 is superseded by ADR-0042. Later, ADR-0042 is superseded by ADR-0099. ADR-0007 still carries `superseded-by: "0042"`; the chain is walked forward.
- Invalid (counter-example): rewriting ADR-0007's `superseded-by` from `"0042"` to `"0099"` to "skip" the intermediate decision.
- Enforcement: **tooling, for script-driven supersession**. `supersede()` raises when the predecessor's `superseded-by` is already set. A manual edit to the field is not detected, so the counter-example above fails only when it is attempted through the script.

## 3. Status Transition Rule

The superseded ADR's `status` becomes `superseded`; `scripts/update_lineage.py` sets this value when it applies the supersession. The superseding ADR is expected to be `accepted`, or to remain `proposed` until the Govern phase accepts it.

- Valid: successor `status: accepted`, predecessor `status: superseded`.
- Invalid (counter-example): successor `status: rejected` paired with predecessor `status: superseded`, because a rejected ADR should not supersede anything.
- Enforcement: **mixed**. The script writes the predecessor's `superseded` status, but never reads or writes the successor's status, and `validate_frontmatter.py` only checks that one file's `status` is a permitted enum value. No script compares the two ADRs' statuses or rejects other final-state combinations, so the counter-example above has to be caught in review.

## 4. Atomic Update Rule

One `update_lineage.py supersede` invocation updates both ADR files: the predecessor's `superseded-by` and `status`, and the successor's `supersedes`. There is no two-step "update the predecessor later" flow.

- Valid: a single Govern invocation produces a commit, or staged change set, containing edits to both files.
- Invalid (counter-example): writing the successor's `supersedes` now and "remembering" to update the predecessor in a follow-up session.
- Enforcement: **tooling within a run, convention across a change set**. `supersede()` writes both candidates to temporary files and moves them into place with `os.replace`; if the predecessor's move fails, it restores the successor from the text it read first. That is a best-effort rollback, not a transaction, so an interruption between the two moves can still leave the pair half-applied. Nothing inspects a commit or staged change set, so the counter-example above is a review concern rather than a validation failure. The post-write `validate_lineage()` hook exists for tests to patch and returns `None` in normal use.

## 5. Single-Writer Rule for `last_decision_id`

`scripts/update_lineage.py` is the only writer of `last_decision_id` in `.adr-config.yml`; its `allocate` command bumps the value and writes the file atomically. Manual edits to `last_decision_id` are forbidden.

- Valid: `last_decision_id` is updated only by the script, during ADR allocation in the Govern phase.
- Invalid (counter-example): a contributor hand-edits `.adr-config.yml` to bump `last_decision_id` ahead of the next allocation.
- Enforcement: **convention**. No script reconciles `last_decision_id` against the ADR identifiers on disk. `validate_frontmatter.py` does not reference `last_decision_id` or `.adr-config.yml` at all, so drift is not detected automatically and has to be caught in review.

## Validation Failure Modes

The scripts emit free-form messages rather than error codes. The messages below are what a lineage violation actually produces.

| Rule | Source                        | Message                                                                                                                   | Exit code |
|------|-------------------------------|---------------------------------------------------------------------------------------------------------------------------|-----------|
| 1    | `validate_frontmatter.py`     | `<path>: superseded-by: must be a single NNNN string (GP-06 single-parent), not a list`                                   | 1         |
| 1    | `validate_frontmatter.py`     | `<path>: supersedes: must be a 4-digit ID string or null`                                                                 | 1         |
| 2    | `update_lineage.py supersede` | `update_lineage: GP-06 single-parent violation: ADR 0007 already superseded by '0042'`                                    | 2         |
| 4    | `update_lineage.py supersede` | `update_lineage: superseded ADR not found: <path>`, or `update_lineage: I/O error: <detail>` when a write fails           | 1         |
| 5    | `update_lineage.py allocate`  | `update_lineage: last_decision_id: must be int or NNNN string`, or `update_lineage: last_decision_id exhausted (>= 9999)` | 1         |

`update_lineage.py` returns `0` on success, `2` for a single-parent violation or a permission error, and `1` for other validation or I/O failures. `validate_frontmatter.py` returns `0` when every file passes and `1` when any file has errors.

Rule 3 has no entry above because no script detects a violation of it.
