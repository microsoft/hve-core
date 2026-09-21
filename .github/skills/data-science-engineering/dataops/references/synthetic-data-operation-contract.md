---
title: Synthetic Data Operation Contract
description: Versioned preflight, lineage, subgroup-evidence, result, and guarded local replacement contract for synthetic-data generation
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
---

## Contract Boundary

`SYNTHETIC_DATA_OPERATION_V1` is the deterministic authorization and evidence boundary
for synthetic-data generation. It uses an immutable preflight record before any project
write, package installation, notebook creation, source access, or generation. A separate
result record reports observed behavior and links to the exact preflight revision.

The contract does not classify data, select protected attributes or affected groups, set
quality thresholds, determine fairness, or authorize replacement. Qualified owners make
those decisions in durable source records. This contract stores stable references,
immutable revisions, owner roles, provenance references, artifact digests, review state,
applicability, and current status so deterministic validation can reject missing or stale
authority.

Validate records with
[`synthetic-data-operation-v1.schema.json`](../assets/synthetic-data-operation-v1.schema.json)
and the `validate` command in `scripts/synthetic_data_operation.py`.

## Preflight Record

A preflight record declares one operation before execution:

* Stable operation and immutable record revision identifiers
* Intended purpose and `new-output` or `replace-local` mode
* A non-secret source reference, expected SHA-256 digest when available, and
  caller-owned tier
* Strict decision references for classification, protected-attribute applicability,
  subgroup evaluation, and replacement authority
* Planned field lineage for every output field
* Qualified activated subgroup references
* A `passed` or `blocked` gate with stable reason categories

Decision records use these qualified roles: `data-owner`, `privacy-owner`,
`rai-fairness-owner`, and `domain-owner`. Each decision reference may name more than one
role, but roles and provenance references are unique.

## Qualified Branch Rules

The schema validates structure. The validator applies these branch rules:

* Source access requires an approved, current, applicable classification decision with
  `data-owner` authority.
* Protected-attribute generation is active when its decision is applicable. It requires
  approved and current `privacy-owner`, `rai-fairness-owner`, and `domain-owner`
  authority.
* Subgroup evaluation is active when its decision is applicable. It requires approved
  and current `rai-fairness-owner` and `domain-owner` authority plus at least one
  qualified activated subgroup reference.
* `replace-local` requires approved, current, applicable `data-owner` replacement
  authority and an expected source digest.
* A current qualified `not-applicable` decision is valid only for an optional inactive
  branch. It never satisfies an activated branch.

Any missing, pending, rejected, superseded, withdrawn, or incorrectly inapplicable
required decision blocks the operation. A non-approved review state carries at least one
stable review-reason category.

## Field Lineage

Field lineage identifies each output field exactly once and records one disposition:

* `copied`: value comes directly from a source field
* `transformed`: source value is changed by a named transformation
* `generated`: value comes from a named generator without a source value
* `derived`: value is computed from one or more source or generated values
* `dropped`: planned source field is deliberately absent from output

`transformed` and `derived` entries require a transformation reference. Other
dispositions omit it unless a reviewed contract revision adds a new semantic rule.
Records carry references and identities, not raw field values.

## Result Record

A result record references the exact preflight revision and records:

* Observed source and output SHA-256 digests
* Actual field lineage
* One explicit result for every activated subgroup
* Validation checks using `passed`, `failed`, `insufficient`, `not-measured`, or
  `not-applicable`
* Commit state and `rollback-available`, `unchanged-original`, `committed-new-output`,
  `external-change-preserved`, or `not-applicable` evidence

For `replace-local`, the caller supplies a not-attempted result revision and a contained
`--final-result` destination. A successful commit publishes a distinct immutable
successor result at that destination. Its `previous_result_revision` identifies the
supplied result, while `preflight_revision` retains the exact authorizing preflight.
The five-field command summary references, but does not replace, this full result.

Missing subgroup evidence is never success. Every activated subgroup has an explicit
`passed`, `failed`, `insufficient`, or `not-measured` result. `not-applicable` is valid
only when the qualified preflight did not activate subgroup evaluation.

## Local Replacement State Model

New versioned output is the default. `replace-local` supports one existing regular file
under a caller-approved local root. Before replacement, the commit adapter:

1. Revalidates the result and matching preflight.
2. Rechecks the target SHA-256 digest against the approved precondition.
3. Creates and synchronizes a recoverable predecessor.
4. Stages and synchronizes candidate bytes beside the target.
5. Validates commit readiness, then performs one local replacement.

Every failure before the replacement leaves the entry target bytes unchanged and records
`unchanged-original` evidence, except an observed external target change, which records
`external-change-preserved` and does not overwrite those newer bytes. The adapter
rechecks the target and predecessor digests immediately before replacement. This narrows
but does not eliminate the user-space check-to-replace race; the local filesystem offers
no compare-and-swap guarantee here.

A committed replacement records the target digest and recoverable predecessor evidence.
The target replacement is the canonical commit. Successor-result publication follows it
and is not atomic with it; publication failure reports target and predecessor digests and
retains the predecessor for recovery. Directories, links, remote stores, network shares,
databases, APIs, and multi-target publication are unsupported.

## Evolution

Unknown properties are rejected. Adding an optional property requires a reviewed schema
revision. Changing semantics, required fields, or enumerated states requires a new
contract version.