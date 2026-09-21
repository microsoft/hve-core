---
description: 'Azure DevOps platform bindings for backlog workflows: work item types, field mappings, query syntax, interaction templates, and per-workflow deltas'
---

<!-- markdownlint-disable-file -->
# Azure DevOps Platform Reference

Azure DevOps delta for the [backlog-management](../SKILL.md) skill. Read this with the core conventions and [workflows.md](workflows.md). This reference names Azure DevOps's command surface, field vocabulary, planning-file bindings, reference-ID prefix, action verbs, PRD hierarchy and relationship rules, discovery and triage deltas, content-format handling, and tracking paths. Everything structural — planning-file lifecycle, similarity, autonomy, sanitization, state persistence — comes from the core.

Two Azure DevOps workflows extend this reference rather than restating it: [ado-pull-request.md](ado-pull-request.md) for pull request creation with work item discovery and reviewer identification, and [ado-build-info.md](ado-build-info.md) for build and pipeline information. Load either only when its workflow is active.

## Command Surface

Azure DevOps backlog operations run through the MCP ADO tools. Most read and write tools require an explicit `project`; resolve identities with `mcp_ado_core_get_identity_ids` before assigning work.

| Category      | Tool                                         | Purpose                                                                                                                                                      |
|---------------|----------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Discover      | `mcp_ado_search_workitem`                    | Search work items by text, type, or state. Params: `searchText` (required), `project`, `workItemType`, `state`, `top`, `skip`.                               |
| Discover      | `mcp_ado_wit_get_work_item`                  | Retrieve a single work item. Params: `id` (required), `project` (required), `expand`, `fields`.                                                              |
| Discover      | `mcp_ado_wit_get_work_items_batch_by_ids`    | Retrieve multiple work items. Params: `ids` (required), `project` (required), `fields`.                                                                      |
| Discover      | `mcp_ado_wit_my_work_items`                  | Retrieve items assigned to or touched by the current user. Params: `project` (required), `type` (`assignedtome` or `myactivity`), `includeCompleted`, `top`. |
| Discover      | `mcp_ado_wit_list_backlog_work_items`        | List backlog items not assigned to an iteration. Params: `project` (required), `team`, `backlogId`.                                                          |
| Discover      | `mcp_ado_wit_get_query_results_by_id`        | Execute a saved query. Params: `id` (required), `project`, `team`, `responseType`, `top`.                                                                    |
| Iteration     | `mcp_ado_wit_get_work_items_for_iteration`   | Retrieve items for a sprint. Params: `project` (required), `iterationId` (required), `team`.                                                                 |
| Iteration     | `mcp_ado_work_list_team_iterations`          | List team iterations and sprints. Params: `project` (required), `team`, `timeframe`.                                                                         |
| Mutate        | `mcp_ado_wit_create_work_item`               | Create a work item. Params: `project` (required), `workItemType` (required), `fields` (required name/value array).                                           |
| Mutate        | `mcp_ado_wit_add_child_work_items`           | Add children to a parent. Params: `parentId` (required), `project` (required), `workItemType` (required), `items` (required array).                          |
| Mutate        | `mcp_ado_wit_update_work_item`               | Update one work item. Params: `id` (required), `updates` (required path/value array).                                                                        |
| Mutate        | `mcp_ado_wit_update_work_items_batch`        | Batch-update multiple items. Params: `updates` (required id/path/value array).                                                                               |
| Relationships | `mcp_ado_wit_work_items_link`                | Link work items. Params: `project` (required), `updates` (required id/linkToId/type array).                                                                  |
| Relationships | `mcp_ado_wit_link_work_item_to_pull_request` | Link a work item to a PR. Params: `workItemId`, `projectId` (GUID), `repositoryId` (GUID), `pullRequestId`.                                                  |
| Context       | `mcp_ado_wit_list_work_item_comments`        | List comments on a work item. Params: `workItemId` (required), `project` (required).                                                                         |
| Mutate        | `mcp_ado_wit_add_work_item_comment`          | Add a comment. Params: `workItemId` (required), `project` (required), `comment` (required).                                                                  |
| Identity      | `mcp_ado_core_get_identity_ids`              | Resolve identity GUIDs from an email or name. Params: `searchFilter` (required).                                                                             |

Prefer the batch read and update tools when operating on several items, and pass an explicit `fields` list on reads to keep output bounded.

## Platform Bindings

| Binding                 | Azure DevOps value                                                                                                                                               |
|-------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Platform tracking root  | `.copilot-tracking/workitems/`                                                                                                                                   |
| Reference-ID prefix     | `WI` (for example `WI001`)                                                                                                                                       |
| Item vocabulary         | "work item"; item key is `System.Id` (for example `1071`)                                                                                                        |
| Item types              | Epic, Feature, User Story, Task, Bug (validate against the project's process)                                                                                    |
| Type discovery          | No MCP tool lists a project's process types. Ask the user to confirm the process or template, and record the types as unvalidated rather than claiming discovery |
| Priority scale          | `Microsoft.VSTS.Common.Priority` (1 highest – 4 lowest)                                                                                                          |
| Action verbs            | Create, Update, Link, Comment, No Change                                                                                                                         |
| Analysis file           | `artifact-analysis.md`                                                                                                                                           |
| Plan file               | `work-items.md`                                                                                                                                                  |
| Planning-type additions | Beyond the core enum, ADO uses `pr` (PR work-item linking), `sprint`, and `backlog`                                                                              |

Azure DevOps has no Close or Transition verb in this workflow: a state change is an Update to `System.State`. Order operations as Create, Update, Link, Comment, No Change per the Operation Contract in [workflows.md](workflows.md).

Map the core three-tier autonomy model onto ADO operations. A change to `System.State` is a transition for autonomy purposes even though the MCP verb is Update, because operation risk and user-visible state change define the tier, not the transport verb. Under Partial and Manual autonomy, request confirmation before any `System.State` change, including resolution and closure. Creates, child additions, links, comments, and ambiguous duplicate handling gate the same way. Other validated field updates remain low risk and auto-execute under Full and Partial.

## Field Vocabulary

Azure DevOps fields are namespaced (`System.*`, `Microsoft.VSTS.*`). Map only fields present on the item's process; preserve organization-specific custom fields already on a work item.

| Field                                      | Use                                                |
|--------------------------------------------|----------------------------------------------------|
| `System.Title`                             | Required for create payloads                       |
| `System.WorkItemType`                      | Required for create payloads                       |
| `System.Description`                       | Primary item body                                  |
| `System.State`                             | Workflow state (highlight `Resolved` on discovery) |
| `System.Parent`                            | Parent linkage in the hierarchy                    |
| `System.AreaPath` / `System.IterationPath` | Team area and sprint placement                     |
| `System.Tags`                              | Lightweight categorization                         |
| `System.AssignedTo`                        | Owner assignment (resolve GUID via identity tool)  |
| `Microsoft.VSTS.Common.AcceptanceCriteria` | Story acceptance criteria                          |
| `Microsoft.VSTS.Common.Priority`           | Triage and sequencing                              |

Field rules:

* Preserve existing `System.Id` values and current field values when planning updates; capture both current and suggested values in the analysis file.
* Store create or update payloads in `work-items.md` using only validated fields.
* Do not invent custom field names; when a project needs a custom hierarchy or classification field, note it as `Needs Review` instead of guessing.
* Capture the current value of every field planned for modification before updating.

## PRD-to-Work-Item Planning

PRD-driven planning produces planning-only artifacts under `.copilot-tracking/workitems/prds/<artifact-normalized-name>/` (`artifact-analysis.md`, `work-items.md`, `planning-log.md`, `handoff.md`) for a separate execution pass. During planning, do not call `mcp_ado_wit_create_work_item`, `mcp_ado_wit_add_child_work_items`, `mcp_ado_wit_update_work_item`, `mcp_ado_wit_work_items_link`, or `mcp_ado_wit_add_work_item_comment`.

Hierarchy rules — plan conservatively and only with process-supported types:

* Use the process's supported work-item types as the source of truth.
* Prefer the standard hierarchy Epic → Feature → User Story, with Task or Bug beneath a User Story.
* A Feature requires an Epic parent; a User Story requires a Feature parent. Do not create placeholder links solely to satisfy the hierarchy.
* Bug links are optional; add relationships when they provide helpful traceability.
* When hierarchy support is unclear, flatten the plan and mark the relationship decision as `Needs Review`.
* Record relationships in planning files using the ADO link types (`Child`, `Parent`, `Predecessor`, `Successor`, `Related`).

The PRD plan extends the shared plan-file template with `System.WorkItemType` drawn from the Epic/Feature/User Story/Bug set, a `System.Parent` reference (`none`, a `{{TEMP-N}}` reference, or an existing `System.Id`), a `needs_review` flag, and an acceptance-criteria block and relationships block per item.

## Relationship Semantics

Azure DevOps parent-child is a hierarchical, single-parent link type. A work item holds at most one `System.Parent`. `Related` is the non-hierarchical, many-to-many link type.

| Intent                                               | Representation                                         |
|------------------------------------------------------|--------------------------------------------------------|
| The single owning parent in the backlog hierarchy    | `System.Parent`, exactly one value                     |
| A secondary association with another Epic or Feature | A `Related` link through `mcp_ado_wit_work_items_link` |
| Sequencing between peers                             | `Predecessor` and `Successor` links                    |

Rules:

* Never plan more than one hierarchical parent for an item. A second parent is not representable and is planned as a `Related` link instead.
* When a Feature belongs to more than one Epic, choose the owning Epic as `System.Parent` and record every additional Epic as a `Related` link with a one-line reason.
* Keep hierarchy and trace links visually separate in the analysis file, the plan file, and the handoff so a reviewer can tell an owning parent from an association.
* A `Related` link never implies rollup, ordering, or inherited area and iteration paths.

## Discovery Search Protocol

The five shared steps live in the Search Protocol section of [workflows.md](workflows.md). Azure DevOps adds the following query and filtering rules for `mcp_ado_search_workitem` (page size 50).

* Maintain an ordered list of keyword groups; each group holds 1-4 specific terms (multi-word phrases allowed) joined by `OR`.
* Compose `searchText`: a single group as `(term1 OR "multi word")`; multiple groups as `(group1) AND (group2)`.
* Filter results to candidates whose highlights match the planned item's core concepts, whose type is the same or one level above or below the planned item, and which are not already linked to it.
* For each candidate, fetch the full item with `mcp_ado_wit_get_work_item`, run the core Similarity Assessment, assign an action, and record it in `planning-log.md`.

## Content Format Detection

Azure DevOps Services renders work-item descriptions and comments as Markdown; Azure DevOps Server renders HTML. Detect the target and format outbound content accordingly; the content structure is identical across formats, only the syntax differs. Apply the interaction templates below in the detected format.

Conversion rules when the target renders HTML:

* Headings, bold, italic, inline code, and links convert to their HTML equivalents.
* Markdown checklists convert to an unordered list whose items begin with `<input type="checkbox" disabled />` for a pending item or `<input type="checkbox" checked disabled />` for a complete one, because Azure DevOps Server does not render task-list syntax. This is the same markup the shared `backlog-templates` skill and the ADR handoff instruction already emit into Azure DevOps HTML description fields.
* Fenced code blocks convert to `<pre><code>` and their content is HTML-escaped.
* Tables convert to `<table>` markup; a table that cannot be converted cleanly is replaced by a definition-style list rather than emitted as raw Markdown.
* Never send a mixed payload. Detect once per run, record the detected format in `planning-log.md`, and use it for every outbound field.

## Interaction Templates

Templates for work-item field values and comments. The Discovery, Triage, and Execution workflows use these whenever they author Azure DevOps content. Quality conventions — what belongs in a description, how acceptance criteria are written, which level an item belongs at — come from [story-quality.md](story-quality.md); this section supplies only the Azure DevOps rendering.

Emit the format matching the detected content format above. All templates use `{{placeholder}}` syntax for substitution at execution time.

### Voice

* Professional and concise. No emoji in work-item content.
* Every comment provides information or requests action. Omit warmth-building preambles, hedging, or filler.
* Reference specific work item IDs, PR numbers, or iteration paths.
* State what happened factually. Avoid narrative commentary or reasoning chains.

Azure DevOps work items are internal team artifacts, so this voice is deliberately flatter than the community-facing voice GitHub uses.

### Description templates by level

Field: `System.Description`, except where noted. The level names map onto the hierarchy in [story-quality.md](story-quality.md).

#### Epic

```markdown
## Business Goal

{{business_goal_paragraph}}

## Scope

### In scope

* {{in_scope_item_1}}
* {{in_scope_item_2}}

### Out of scope

* {{out_of_scope_item_1}}
* {{out_of_scope_item_2}}

## Success Metrics

* {{metric_1}}
* {{metric_2}}

## Dependencies

* {{dependency_1}}
* {{dependency_2}}
```

#### Feature

```markdown
## Overview

{{overview_paragraph}}

## User Impact

{{user_impact_statement}}

## Technical Approach

{{technical_approach_paragraph}}

## Acceptance Criteria

- [ ] {{criterion_1}}
- [ ] {{criterion_2}}
- [ ] {{criterion_3}}
```

#### User Story

```markdown
As a {{persona}}, I want {{capability}} so that {{outcome}}.

## Requirements

1. {{requirement_1}}
2. {{requirement_2}}
3. {{requirement_3}}

## Context

{{background_information}}

Related work items: {{related_ids}}
```

User Story acceptance criteria go in `Microsoft.VSTS.Common.AcceptanceCriteria` rather than the description:

```markdown
- [ ] {{functional_criterion_1}}
- [ ] {{functional_criterion_2}}
- [ ] {{edge_case_criterion}}
- [ ] {{performance_criterion}}
```

#### Task

```markdown
## Objective

{{objective_paragraph}}

## Approach

1. {{step_1}}
2. {{step_2}}
3. {{step_3}}

## Definition of Done

- [ ] {{done_criterion_1}}
- [ ] {{done_criterion_2}}
- [ ] {{done_criterion_3}}
```

#### Bug

Field: `Microsoft.VSTS.TCM.ReproSteps`

```markdown
## Summary

{{summary_paragraph}}

## Repro Steps

1. {{step_1}}
2. {{step_2}}
3. {{step_3}}

## Expected Behavior

{{expected_behavior}}

## Actual Behavior

{{actual_behavior}}

## Environment

* OS: {{os}}
* Browser: {{browser}}
* Version: {{version}}

## Additional Context

{{screenshots_logs_or_notes}}
```

### HTML rendering

When the detected format is HTML, emit the same structure using HTML syntax. Headings become `<h2>`, paragraphs `<p>`, ordered lists `<ol>`, unordered lists `<ul>`, and checklist items become list items carrying a disabled checkbox input, because Azure DevOps Server does not render task-list syntax.

Use `<input type="checkbox" disabled />` for a pending item and `<input type="checkbox" checked disabled />` for a complete one. That is the repository's existing convention for this rendering target: the shared `backlog-templates` skill emits it in its Azure DevOps HTML work-item template, and the ADR handoff instruction emits it in its Azure DevOps work-item template. Emitting anything else here would put this reference in conflict with a shared skill writing to the same field.

The element is disabled because the field is a rendered description rather than an interactive form. Do not substitute a ballot-box character or entity: it has no checked counterpart, so it cannot express both states.

For example, the User Story description renders as:

```html
<p>As a {{persona}}, I want {{capability}} so that {{outcome}}.</p>

<h2>Requirements</h2>
<ol>
<li>{{requirement_1}}</li>
<li>{{requirement_2}}</li>
</ol>

<h2>Context</h2>
<p>{{background_information}}</p>
<p>Related work items: {{related_ids}}</p>
```

and its acceptance criteria render as:

```html
<ul>
<li><input type="checkbox" disabled /> {{functional_criterion_1}}</li>
<li><input type="checkbox" disabled /> {{edge_case_criterion}}</li>
</ul>
```

Apply the same transformation to every template above. The content structure never changes between formats.

### Comment templates

Templates for `mcp_ado_wit_add_work_item_comment`.

| Scenario          | Template                                                                                                                     |
|-------------------|------------------------------------------------------------------------------------------------------------------------------|
| Status update     | `**Status Update**: {{action_taken}}` followed by `{{details}}`                                                              |
| State transition  | `**State Change**: {{previous_state}} → {{new_state}}` followed by `Reason: {{reason}}`                                      |
| Duplicate closure | `**Duplicate**: Closing as duplicate of work item #{{original_id}}.` followed by `Details merged into the original item.`    |
| Blocking          | `**Blocked**: This item is blocked by #{{blocker_id}}.` followed by `Context: {{why_this_blocks_progress}}`                  |
| Request info      | `**Information Needed**: {{specific_question}}` followed by `Context: {{why_this_information_is_required_to_proceed}}`       |
| Sprint rollover   | `**Sprint Rollover**: Moved from {{previous_iteration}} to {{new_iteration}}.` followed by `Reason: {{reason_for_rollover}}` |
| PR linked         | `**PR Linked**: PR #{{pr_id}} in {{repository}} (branch: {{branch_name}})`                                                   |

Each template's lead line and its detail line are separated by a blank line.

## Sprint Planning Delta

The platform-agnostic protocol lives in [sprint-planning.md](sprint-planning.md). Azure DevOps resolves its bindings as follows.

| Binding                 | Azure DevOps resolution                                                                                                   |
|-------------------------|---------------------------------------------------------------------------------------------------------------------------|
| Iteration container     | Iteration, addressed by iteration path                                                                                    |
| Enumerate containers    | `mcp_ado_work_list_team_iterations`                                                                                       |
| Retrieve planned items  | `mcp_ado_wit_get_work_items_for_iteration`, hydrated via `mcp_ado_wit_get_work_items_batch_by_ids`                        |
| Retrieve unplanned work | `mcp_ado_wit_list_backlog_work_items`                                                                                     |
| Effort field            | `Microsoft.VSTS.Scheduling.StoryPoints` for User Stories; `Microsoft.VSTS.Scheduling.OriginalEstimate` for Tasks and Bugs |
| Burndown fields         | `Microsoft.VSTS.Scheduling.RemainingWork` and `Microsoft.VSTS.Scheduling.CompletedWork`                                   |
| Grouping field          | `System.AreaPath`                                                                                                         |
| Assignment field        | `System.AssignedTo`                                                                                                       |
| Initial state           | `New`                                                                                                                     |
| Tracking root           | `.copilot-tracking/workitems/sprint/{{iteration-kebab}}/`                                                                 |

Azure DevOps models the full four-level hierarchy, so the hierarchy coverage matrix applies in full. Hydration is mandatory: the iteration query returns sparse items, and every analysis field above must be requested explicitly.

## Triage Delta

ADO triage evaluates existing work items against process field conventions rather than a label taxonomy.

Scope the pass with `mcp_ado_wit_my_work_items`, `mcp_ado_wit_list_backlog_work_items`, or a saved query through `mcp_ado_wit_get_query_results_by_id`, then hydrate with `mcp_ado_wit_get_work_items_batch_by_ids` and an explicit `fields` list.

| Signal                                                              | Suggested triage action                                                      |
|---------------------------------------------------------------------|------------------------------------------------------------------------------|
| `System.State` is `New` and the item has an owner and estimate      | Suggest an Update moving `System.State` to the process's active state        |
| `System.State` is `Resolved`                                        | Surface for closure review; ADO discovery highlights `Resolved` deliberately |
| `Microsoft.VSTS.Common.Priority` is unset                           | Suggest a priority from item type and stated impact                          |
| `System.AreaPath` or `System.IterationPath` is the project root     | Suggest the owning team's area or the current iteration                      |
| `System.AssignedTo` is empty on an active item                      | Flag for user assignment; do not guess an identity                           |
| `Microsoft.VSTS.Common.AcceptanceCriteria` is empty on a User Story | Flag for grooming rather than authoring criteria automatically               |
| A User Story has no `System.Parent`                                 | Flag as an orphan for hierarchy review                                       |

A state change in ADO is carried by an Update to `System.State`, but it is gated as a transition under Partial and Manual autonomy, not as an ordinary field update. Duplicate handling uses the core Similarity Assessment Framework; record the comparison aspects that drove the category, and never merge or close a duplicate without user review.

## Human Review Triggers (Azure DevOps additions)

Alongside the core triggers, pause when: the target `project` is unknown; work-item-type support is unclear for the process; a parent-child link depends on an unvalidated custom field; an assignment cannot be resolved to an identity GUID; or a required field is outside the validated field set for the item's type.
