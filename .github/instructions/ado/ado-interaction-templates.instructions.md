---
description: "Work item description and comment templates for consistent Azure DevOps content formatting - Brought to you by microsoft/hve-core"
applyTo: '**/.github/instructions/ado/**'
---

# ADO Interaction Templates

Work item description and comment templates for consistent formatting across Azure DevOps operations. These templates replace the GitHub community interaction model with patterns suited to internal team workflows.

Templates are provided in Markdown (default for Azure DevOps Services) and HTML (for Azure DevOps Server). Select the format matching the detected content format per [Content Format Detection](./ado-wit-planning.instructions.md#content-format-detection). The content structure is identical across formats; only the syntax differs.

## Voice Foundation

Every work item field value and comment follows these conventions:

* Professional and concise. No emoji in work item content.
* Every comment provides information or requests action. Omit warmth-building preambles, hedging language, or filler phrases.
* Comments reference specific work item IDs, PR numbers, or iteration paths.
* State what happened factually. Avoid narrative commentary or reasoning chains.
* Use `{{placeholder}}` syntax where agents substitute values at execution time.

## Category A: Work Item Description Templates (Markdown)

Templates for `System.Description`, `Microsoft.VSTS.Common.AcceptanceCriteria`, and `Microsoft.VSTS.TCM.ReproSteps` fields. Use these templates when the detected content format is Markdown.

### A1: User Story Description

Field: `System.Description`

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

### A2: User Story Acceptance Criteria

Field: `Microsoft.VSTS.Common.AcceptanceCriteria`

```markdown
- [ ] {{functional_criterion_1}}
- [ ] {{functional_criterion_2}}
- [ ] {{edge_case_criterion}}
- [ ] {{performance_criterion}}
```

### A3: Bug Description

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

### A4: Task Description

Field: `System.Description`

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

### A5: Epic Description

Field: `System.Description`

```markdown
## Business Goal

{{business_goal_paragraph}}

## Scope

**In scope:**

* {{in_scope_item_1}}
* {{in_scope_item_2}}

**Out of scope:**

* {{out_of_scope_item_1}}
* {{out_of_scope_item_2}}

## Success Metrics

* {{metric_1}}
* {{metric_2}}

## Dependencies

* {{dependency_1}}
* {{dependency_2}}
```

### A6: Feature Description

Field: `System.Description`

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

## Category A-HTML: Work Item Description Templates (HTML)

HTML equivalents of the Category A templates. Use these templates when the detected content format is HTML (Azure DevOps Server). The content structure matches the Markdown templates; only the syntax differs.

### A1-HTML: User Story Description

Field: `System.Description`

```html
<p>As a {{persona}}, I want {{capability}} so that {{outcome}}.</p>

<h2>Requirements</h2>
<ol>
<li>{{requirement_1}}</li>
<li>{{requirement_2}}</li>
<li>{{requirement_3}}</li>
</ol>

<h2>Context</h2>
<p>{{background_information}}</p>
<p>Related work items: {{related_ids}}</p>
```

### A2-HTML: User Story Acceptance Criteria

Field: `Microsoft.VSTS.Common.AcceptanceCriteria`

```html
<ul>
<li>&#9744; {{functional_criterion_1}}</li>
<li>&#9744; {{functional_criterion_2}}</li>
<li>&#9744; {{edge_case_criterion}}</li>
<li>&#9744; {{performance_criterion}}</li>
</ul>
```

### A3-HTML: Bug Description

Field: `Microsoft.VSTS.TCM.ReproSteps`

```html
<h2>Summary</h2>
<p>{{summary_paragraph}}</p>

<h2>Repro Steps</h2>
<ol>
<li>{{step_1}}</li>
<li>{{step_2}}</li>
<li>{{step_3}}</li>
</ol>

<h2>Expected Behavior</h2>
<p>{{expected_behavior}}</p>

<h2>Actual Behavior</h2>
<p>{{actual_behavior}}</p>

<h2>Environment</h2>
<ul>
<li>OS: {{os}}</li>
<li>Browser: {{browser}}</li>
<li>Version: {{version}}</li>
</ul>

<h2>Additional Context</h2>
<p>{{screenshots_logs_or_notes}}</p>
```

### A4-HTML: Task Description

Field: `System.Description`

```html
<h2>Objective</h2>
<p>{{objective_paragraph}}</p>

<h2>Approach</h2>
<ol>
<li>{{step_1}}</li>
<li>{{step_2}}</li>
<li>{{step_3}}</li>
</ol>

<h2>Definition of Done</h2>
<ul>
<li>&#9744; {{done_criterion_1}}</li>
<li>&#9744; {{done_criterion_2}}</li>
<li>&#9744; {{done_criterion_3}}</li>
</ul>
```

### A5-HTML: Epic Description

Field: `System.Description`

```html
<h2>Business Goal</h2>
<p>{{business_goal_paragraph}}</p>

<h2>Scope</h2>
<p><strong>In scope:</strong></p>
<ul>
<li>{{in_scope_item_1}}</li>
<li>{{in_scope_item_2}}</li>
</ul>
<p><strong>Out of scope:</strong></p>
<ul>
<li>{{out_of_scope_item_1}}</li>
<li>{{out_of_scope_item_2}}</li>
</ul>

<h2>Success Metrics</h2>
<ul>
<li>{{metric_1}}</li>
<li>{{metric_2}}</li>
</ul>

<h2>Dependencies</h2>
<ul>
<li>{{dependency_1}}</li>
<li>{{dependency_2}}</li>
</ul>
```

### A6-HTML: Feature Description

Field: `System.Description`

```html
<h2>Overview</h2>
<p>{{overview_paragraph}}</p>

<h2>User Impact</h2>
<p>{{user_impact_statement}}</p>

<h2>Technical Approach</h2>
<p>{{technical_approach_paragraph}}</p>

<h2>Acceptance Criteria</h2>
<ul>
<li>&#9744; {{criterion_1}}</li>
<li>&#9744; {{criterion_2}}</li>
<li>&#9744; {{criterion_3}}</li>
</ul>
```

## Category B: Work Item Comment Templates

Templates for `mcp_ado_wit_add_work_item_comment`.

### B1: Status Update

```text
**Status Update**: {{action_taken}}

{{details}}
```

### B2: State Transition

```text
**State Change**: {{previous_state}} → {{new_state}}

Reason: {{reason}}
```

### B3: Duplicate Closure

```text
**Duplicate**: Closing as duplicate of work item #{{original_id}}.

Details merged into the original item.
```

### B4: Blocking/Dependency

```text
**Blocked**: This item is blocked by #{{blocker_id}}.

Context: {{why_this_blocks_progress}}
```

### B5: Request Information

```text
**Information Needed**: {{specific_question}}

Context: {{why_this_information_is_required_to_proceed}}
```

### B6: Sprint Rollover

```text
**Sprint Rollover**: Moved from {{previous_iteration}} to {{new_iteration}}.

Reason: {{reason_for_rollover}}
```

### B7: PR Linked

```text
**PR Linked**: PR #{{pr_id}} in {{repository}} (branch: {{branch_name}})
```

## Integration Instructions

Consuming files reference these templates via:

```markdown
#file:./ado-interaction-templates.instructions.md
```

Primary consumers:

* `ado-update-wit-items.instructions.md` for work item creation and updates
* `ado-wit-discovery.instructions.md` for discovered work item descriptions
* `ado-backlog-triage.instructions.md` for triage result comments

Template conventions:

* All templates use `{{placeholder}}` syntax for agent substitution at execution time.
* Agents select the appropriate template based on work item type and operation context.
* PR descriptions are excluded from this file; see `ado-create-pull-request.instructions.md` for PR content templates.
* PR comment templates are excluded; no `mcp_ado_repo_add_pr_comment` tool exists in the current tooling.

---

Brought to you by microsoft/hve-core
