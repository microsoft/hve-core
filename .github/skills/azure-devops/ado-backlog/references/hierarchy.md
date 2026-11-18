---
description: 'Azure DevOps work item hierarchy rules, type validation, and field conventions for read-only PRD-to-work-item planning'
---

<!-- markdownlint-disable-file -->
# Azure DevOps Hierarchy Reference

Apply these rules during read-only PRD planning with `functional-planner` and its selected framework lens. Use the [Azure Boards bindings](platform.md) for commands, fields, and relationship semantics.

## Tracking Path

Planning-only artifacts live under `.copilot-tracking/workitems/prds/<artifact-normalized-name>/`:

* `artifact-analysis.md` — human-readable PRD analysis
* `work-items.md` — the plan file (source of truth for planned operations)
* `planning-log.md` — progress and resumable state
* `handoff.md` — the reviewable execution contract for the `Backlog Manager`

## Supported Hierarchy

Plan conservatively against the project's process; validate types with read-only work-item reads before proposing creates.

| Level | Type       | Rule                                                                |
|-------|------------|---------------------------------------------------------------------|
| 1     | Epic       | At most one per major product outcome unless the PRD specifies more |
| 2     | Feature    | Zero or more; requires an Epic parent                               |
| 3     | User Story | Zero or more; requires a Feature parent                             |
| 4     | Task, Bug  | Optional beneath a User Story; add only when the PRD warrants it    |

Hierarchy rules:

* A Feature requires an Epic parent; a User Story requires a Feature parent.
* Apply [Relationship Semantics](platform.md#relationship-semantics) to distinguish the owning parent from any additional Epic associations.
* A Feature without a new Epic may attach to an existing ADO Epic as its single parent.
* Do not create placeholder links solely to satisfy the hierarchy; Bug and Task links are optional traceability.
* When hierarchy support is unclear for the process, flatten the plan and mark the relationship decision `needs_review`.
* Record relationships in `work-items.md` using ADO link types (`Child`, `Parent`, `Predecessor`, `Successor`, `Related`), keeping hierarchy and trace links in separate blocks so a reviewer can tell an owning parent from an association.

## Field Mapping

Map only fields validated for the target type (see [Field Vocabulary](platform.md#field-vocabulary)):

* `System.WorkItemType` drawn from the validated types in the supported hierarchy above.
* `System.Parent` as `none`, a `{{TEMP-N}}` reference to a planned item, or an existing `System.Id`. Exactly one value.
* A relationships block listing any `Related` associations, each with its target and reason.
* `Microsoft.VSTS.Common.AcceptanceCriteria` per User Story from the PRD's success criteria.
* A `needs_review` flag on any item whose type, parent, or field set could not be validated.

Preserve existing `System.Id` values and current field values when a candidate maps to an existing item; capture both current and suggested values in `artifact-analysis.md`.
