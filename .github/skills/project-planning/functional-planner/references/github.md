---
description: 'GitHub issue hierarchy rules, type validation, and field conventions for read-only PRD-to-issue planning'
---

<!-- markdownlint-disable-file -->
# GitHub Hierarchy Reference

GitHub hierarchy delta for the [functional-planner](../SKILL.md) skill. Read this with the core five-phase model and the selected framework lens. Concrete command surface, field vocabulary, the `IS` reference prefix, action verbs, label taxonomy, and milestone semantics come from the GitHub reference of the `backlog-management` skill; this file adds only the PRD hierarchy rules, capability validation, and tracking path.

## Tracking Path

Planning-only artifacts live under `.copilot-tracking/github-issues/prds/<artifact-normalized-name>/`:

* `artifact-analysis.md` — human-readable PRD analysis
* `issues-plan.md` — the plan file (source of truth for planned operations)
* `planning-log.md` — progress and resumable state
* `handoff.md` — the reviewable execution contract for the `Backlog Manager`

## Read-Only Discovery

GitHub has no dedicated hierarchy API to probe, so validate capability through read-only calls before proposing any structure:

* `mcp_github_list_issue_types` for the owner, to determine whether the organization enables issue types and which values are valid.
* `mcp_github_get_label` for every label the plan intends to apply.
* `mcp_github_search_issues` and `mcp_github_issue_read` (`get`, `get_sub_issues`) to find existing coverage and observe how the repository already models parent and child work.

Never call `mcp_github_issue_write`, `mcp_github_add_issue_comment`, or `mcp_github_sub_issue_write` during planning. A capability that cannot be confirmed with a read is marked `needs_review`, not assumed.

## Supported Hierarchy

GitHub has no native Epic, Feature, or Story taxonomy. Hierarchy is expressed through sub-issue relationships, and optionally through organization issue types.

| Level | Representation                  | Rule                                                                        |
|-------|---------------------------------|-----------------------------------------------------------------------------|
| 1     | Tracking issue (parent)         | Prefer one per major product outcome; type `Feature` when types are enabled |
| 2     | Sub-issue of the tracking issue | One per deliverable outcome; type `Task` when types are enabled             |
| 3     | Nested sub-issue                | Only when a level-2 item is itself a container of independent work          |

Hierarchy rules:

* Model every parent-child relationship as a sub-issue link. Labels and milestones are planning attributes, not hierarchy.
* Use the `type` field only after `mcp_github_list_issue_types` confirms support and returns the exact value. Without type support, convey level through the parent's Children list and the sub-issue links alone.
* Do not create a parent tracking issue for a single child. A requirement that maps to exactly one deliverable is planned as a single issue.
* Nest no deeper than three levels. A candidate that needs a fourth level is flattened and marked `needs_review` for the user to reshape.
* When sub-issue support, issue-type support, or the correct parent is unclear, flatten the affected branch and mark the relationship `needs_review` rather than guessing.
* Record every relationship in `issues-plan.md` even when the final linkage differs by repository configuration.

## Field Mapping

Map only fields validated for the repository (see the GitHub reference of the `backlog-management` skill for the field vocabulary and Issue Field Matrix):

* `title` in conventional-commit form so downstream triage can classify it.
* `body` composed from the Issue Body Template in the GitHub reference of the `backlog-management` skill, including the Children section on parents and an Acceptance Criteria checklist on every item.
* `labels` drawn from the confirmed subset of the Label Taxonomy Reference; an unconfirmed label is recorded as `needs_review` rather than applied.
* `milestone` recommended through the Milestone Discovery and Recommendation protocol in the GitHub reference of the `backlog-management` skill, including the `.github/milestone-strategy.yml` override when discovery confidence is low.
* `type` drawn only from the values `mcp_github_list_issue_types` returned.
* `parent` as `none`, a `{{TEMP-N}}` reference to a planned issue, or an existing `#number`.
* A `needs_review` flag on any item whose type, label, milestone, or parent linkage could not be validated.

Preserve existing issue numbers and current field values when a candidate maps to an existing issue; capture both current and suggested values in `artifact-analysis.md`.

## Handoff

The plan ends at a reviewable `handoff.md` for the `Backlog Manager`. Order its operations using the GitHub row of the Operation Contract in the workflows reference of the `backlog-management` skill, and record `Link` operations for every sub-issue relationship so execution creates the hierarchy after both endpoints exist.
