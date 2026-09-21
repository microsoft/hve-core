---
description: 'Jira issue hierarchy rules, type validation, and field conventions for read-only PRD-to-issue planning'
---

<!-- markdownlint-disable-file -->
# Jira Hierarchy Reference

Jira hierarchy delta for the [functional-planner](../SKILL.md) skill. Read this with the core five-phase model and the selected framework lens. Concrete command surface (delegated to the `jira` skill), field vocabulary, the `JI` reference prefix, and action verbs come from the Jira reference of the `backlog-management` skill; this file adds only the PRD hierarchy rules and tracking path.

## Tracking Path

Planning-only artifacts live under `.copilot-tracking/jira-issues/prds/<artifact-normalized-name>/`:

* `artifact-analysis.md` — human-readable PRD analysis
* `issues-plan.md` — the plan file (source of truth for planned operations)
* `planning-log.md` — progress and resumable state
* `handoff.md` — the reviewable execution contract for the `Backlog Manager`

## Supported Hierarchy

Plan conservatively and only with project-validated issue types. Discover types and required create fields by invoking the Jira capability of the `backlog-management` skill (`fields <PROJECT-KEY>`) before proposing creates.

| Level | Type     | Rule                                                                 |
|-------|----------|----------------------------------------------------------------------|
| 1     | Epic     | Prefer one per major product outcome when the project supports Epics |
| 2     | Story    | Beneath an Epic when the project uses Epic-style hierarchy           |
| 3     | Task     | Beneath a Story or Epic per project configuration                    |
| 4     | Sub-task | Only when the project supports it and the parent issue is explicit   |

Hierarchy rules:

* Use project-supported issue types (from `fields`) as the source of truth; never assume Epic Link, Parent, or custom hierarchy fields.
* When hierarchy support is unclear, flatten the plan and mark the relationship decision `needs_review`.
* Record relationships in `issues-plan.md` even when the final Jira linkage field differs by project configuration.

## Field Mapping

Map only fields validated through `fields` or observed on existing issues (see the Jira reference of the `backlog-management` skill for the field vocabulary):

* `item_type` drawn from the Epic / Story / Task / Bug / Sub-task set.
* `parent` as `none`, a `{{TEMP-N}}` reference to a planned item, or an existing issue key.
* An acceptance-criteria block per item from the PRD's success criteria.
* A `needs_review` flag on any item whose issue type, parent linkage, or field set could not be validated.

Preserve existing issue keys and current field values when a candidate maps to an existing issue; capture both current and suggested values in `artifact-analysis.md`.
