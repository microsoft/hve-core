---
description: 'Azure DevOps work item hierarchy rules, type validation, and field conventions for read-only PRD-to-work-item planning'
---

<!-- markdownlint-disable-file -->
# Azure DevOps Hierarchy Reference

Azure DevOps hierarchy delta for the [functional-planner](../SKILL.md) skill. Read this with the core five-phase model and the selected framework lens. Concrete command surfaces, field vocabulary, the `WI` reference prefix, and action verbs come from the Azure DevOps reference of the `backlog-management` skill; this file adds only the PRD hierarchy rules and tracking path.

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
* An item holds at most one hierarchical parent. `System.Parent` is a single-valued hierarchical link, so a Feature that belongs to more than one Epic takes its owning Epic as `System.Parent` and records every additional Epic as a `Related` trace link with a one-line reason.
* A Feature without a new Epic may attach to an existing ADO Epic as its single parent.
* Do not create placeholder links solely to satisfy the hierarchy; Bug and Task links are optional traceability.
* When hierarchy support is unclear for the process, flatten the plan and mark the relationship decision `needs_review`.
* Record relationships in `work-items.md` using ADO link types (`Child`, `Parent`, `Predecessor`, `Successor`, `Related`), keeping hierarchy and trace links in separate blocks so a reviewer can tell an owning parent from an association.

## Field Mapping

Map only fields validated for the target type (see the Azure DevOps reference of the `backlog-management` skill for the field vocabulary):

* `System.WorkItemType` drawn from the Epic / Feature / User Story / Bug set.
* `System.Parent` as `none`, a `{{TEMP-N}}` reference to a planned item, or an existing `System.Id`. Exactly one value.
* A relationships block listing any `Related` associations, each with its target and reason.
* `Microsoft.VSTS.Common.AcceptanceCriteria` per User Story from the PRD's success criteria.
* A `needs_review` flag on any item whose type, parent, or field set could not be validated.

Preserve existing `System.Id` values and current field values when a candidate maps to an existing item; capture both current and suggested values in `artifact-analysis.md`.
