---
description: 'Reference specification for Jira PRD work item planning files, hierarchy mapping, field validation, and handoff contracts'
applyTo: '**/.copilot-tracking/jira-issues/prds/**'
---

# Jira PRD Work Item Planning File Instructions

## Purpose and Scope

This file is the reference specification for PRD-driven Jira issue planning files. Use it when analyzing requirements, validating Jira issue types and fields, mapping hierarchy, and preparing handoff artifacts for a separate execution workflow.

Workflow files consume this specification by including a cross-reference at the top of their content.

Cross-reference pattern for consuming files:

```markdown
Follow all instructions from #file:./jira-wit-planning.instructions.md while executing this workflow.
```

Inline reference pattern when citing specific sections:

```markdown
per templates in #file:./jira-wit-planning.instructions.md
using the hierarchy rules from #file:./jira-wit-planning.instructions.md
```

## Jira Command Catalog for Planning

Use the Jira skill through `.github/skills/jira/jira/scripts/jira.py`.

Planning commands:

* `fields`: Discover issue types for a project and required create fields for a specific issue type.
* `search`: Search for potentially related Jira issues with bounded JQL.
* `get`: Read a single Jira issue with an explicit field list.
* `comments`: Retrieve comments when clarification from existing issue history is useful.

Planning guardrails:

* Do not call `create`, `update`, `transition`, or `comment` while executing the planning workflow.
* Use `fields <PROJECT-KEY>` before finalizing any create payload.
* Use `fields <PROJECT-KEY> <issue-type-id>` when the required create fields for an issue type are unclear.

## Planning File Definitions and Directory Conventions

Root planning workspace structure:

```text
.copilot-tracking/
  jira-issues/
    prds/
      <artifact-normalized-name>/
        artifact-analysis.md
        issues-plan.md
        planning-log.md
        handoff.md
```

Normalization rules for `<artifact-normalized-name>`:

* Use lower-case, hyphenated base filenames without extension.
* Replace spaces and punctuation with hyphens.
* Choose the primary artifact when multiple artifacts are provided.

## Planning File Requirements

Planning markdown files start with:

```markdown
<!-- markdownlint-disable-file -->
<!-- markdown-table-prettify-ignore-start -->
```

Planning markdown files end with:

```markdown
<!-- markdown-table-prettify-ignore-end -->
```

## Hierarchy Planning Rules

Plan hierarchies conservatively and only with validated Jira issue types.

* Use project-supported issue types returned by `fields` as the source of truth.
* Prefer one top-level Epic per major product outcome when the project supports Epics.
* Place Story, Task, and Bug issues beneath an Epic only when the project uses Epic-style hierarchy.
* Use Sub-task only when the project supports it and the parent issue is explicit.
* When hierarchy support is unclear, flatten the plan and mark the relationship decision as `Needs Review`.
* Record relationships in planning files even when the final Jira linkage field differs by project configuration.

## Field Mapping Guidance

Only map fields that were validated through `fields` or observed on existing issues.

Preferred planning fields:

| Field         | Use                                         |
|---------------|---------------------------------------------|
| `project`     | Required for create payloads                |
| `summary`     | Required for create payloads                |
| `issuetype`   | Required for create payloads                |
| `description` | Primary issue body                          |
| `labels`      | Lightweight categorization                  |
| `priority`    | Triage and sequencing                       |
| `assignee`    | Optional owner assignment                   |
| `parent`      | Parent linkage when the project supports it |

Field mapping rules:

* Preserve existing issue keys and current field values when planning updates.
* Capture both current and suggested field values in `artifact-analysis.md` for any planned update.
* Store create or update payloads in `issues-plan.md` using only validated fields.
* Avoid inventing Epic Link, Parent, or custom field names. If the project needs a custom hierarchy field, note it as `Needs Review` instead of guessing.

## Similarity Assessment Framework

Classify candidate-to-existing-issue comparisons using these categories:

| Category  | Meaning                                                                              |
|-----------|--------------------------------------------------------------------------------------|
| Match     | Existing issue already covers the requirement with minor or no edits                 |
| Similar   | Existing issue overlaps but requires user review to decide whether to merge or split |
| Distinct  | Existing issue does not cover the requirement                                        |
| Uncertain | Available evidence is insufficient for a confident decision                          |

Assess similarity using summary overlap, issue type compatibility, status, labels, acceptance criteria coverage, and hierarchy fit.

## artifact-analysis.md

Create `artifact-analysis.md` when beginning PRD planning. This file captures the evolving human-readable analysis of candidate Jira issues before they are finalized in `issues-plan.md`.

### Template

````markdown
# Jira PRD Analysis - [Summarized Title]

* **Artifact(s)**: [relative/path/to/artifact-a.md]
* **Project**: [PROJECT or unknown]
* **Product Scope**: [Single-line summary]

## Planned Issues

### JI001 - [Create|Update|Transition|Comment|No Change] - [Summarized Issue Title]

* **Working Summary**: [Single-line summary]
* **Working Issue Type**: [Epic|Story|Task|Bug|Sub-task|Unknown]
* **Parent Reference**: [none|JI000|PROJ-123]
* **Key Search Terms**: [Keyword groups]
* **Working Description**:
  ```markdown
  [Evolving description content constructed from artifacts and discovery]
  ```
* **Working Acceptance Criteria**:
  ```markdown
  - [ ] [Acceptance criterion 1]
  - [ ] [Acceptance criterion 2]
  ```
* **Working Labels**: [Comma-separated labels]
* **Working Priority**: [Highest|High|Medium|Low|Lowest|Unknown]
* **Found Issue Field Values**:
  * Status: [Current status]
  * Labels: [Current labels]
  * Priority: [Current priority]
  * Parent: [Current parent]
* **Suggested Issue Field Values**:
  * Issue Type: [Target issue type]
  * Labels: [Target labels]
  * Priority: [Target priority]
  * Parent: [Target parent]

#### JI001 - Related and Discovered Information

* **Requirements**:
  * REQ-001: [Requirement text]
* **Key Details**:
  * [Supporting detail from artifact, codebase, or Jira]
* **Potential Matches**:
  * [PROJ-123]: [Match|Similar|Distinct|Uncertain]
````

## issues-plan.md

`issues-plan.md` is the source of truth for planned Jira operations and hierarchy.

### Template

````markdown
# Jira PRD Issues Plan

* **Project**: [PROJECT]
* **Source Scope**: [Artifact name or slug]

## JI001 - [Create|Update|Transition|Comment|No Change] - [Summarized Title]

[1-5 sentence explanation of the planned change]

JI001 - Similarity: [PROJ-123=Match, PROJ-456=Similar]

* JI001 - issue_key: [PROJ-123 or {{TEMP-1}}]
* JI001 - summary: [Issue summary]
* JI001 - issue_type: [Epic|Story|Task|Bug|Sub-task]
* JI001 - status: [Current status or planned status]
* JI001 - labels: [Comma-separated labels]
* JI001 - priority: [Highest|High|Medium|Low|Lowest]
* JI001 - assignee: [Display name, account id, or none]
* JI001 - parent: [none|{{TEMP-2}}|PROJ-456]
* JI001 - needs_review: [true|false]

### JI001 - body

```markdown
[Issue body or comment body content]
```

### JI001 - acceptance-criteria

```markdown
- [ ] [Acceptance criterion 1]
- [ ] [Acceptance criterion 2]
```

### JI001 - payload

```json
{
  "fields": {}
}
```

### JI001 - relationships

* Parent: [none|{{TEMP-2}}|PROJ-456]
* Children: [JI002, JI003]
* Related: [PROJ-789]
````

## planning-log.md

`planning-log.md` is a living record of workflow progress and resumable context.

### Template

````markdown
# Jira PRD Planning Log - [Scope Name]

* **Project**: [PROJECT or unknown]
* **Previous Phase**: [Phase-1|Phase-2|Phase-3|Phase-4|Phase-5|Just Started]
* **Current Phase**: [Phase-1|Phase-2|Phase-3|Phase-4|Phase-5]

## Status

[Summary of progress across artifacts, code context, and Jira discovery]

**Summary**: [Current focus]

## Discovered Artifacts and Related Files

* AT001 [relative/path/to/file] - [Not Started|In Progress|Complete] - [Processing|Related|N/A]

## Discovered Jira Issues

* PROJ-123 - [Not Started|In Progress|Complete] - [Processing|Related|N/A]

## Planned Issues

### JI001 - [Epic|Story|Task|Bug|Sub-task] - [In Progress|Complete]

* Working search keywords: [keyword groups]
* Related Jira issues - Similarity: [PROJ-123=Match, PROJ-456=Similar]
* Suggested action: [Create|Update|Transition|Comment|No Change]
* Parent plan: [none|JI000|PROJ-123]

[Collected and discovered information]
````

## handoff.md

`handoff.md` is the user-reviewable execution contract for downstream Jira workflows.

### Template

````markdown
# Jira PRD Handoff

* **Project**: [PROJECT]
* **Source Scope**: [Artifact slug]
* **Autonomy**: [full|partial|manual]

## Planning Files

* `.copilot-tracking/jira-issues/prds/<artifact-normalized-name>/handoff.md`
* `.copilot-tracking/jira-issues/prds/<artifact-normalized-name>/issues-plan.md`
* `.copilot-tracking/jira-issues/prds/<artifact-normalized-name>/planning-log.md`
* `.copilot-tracking/jira-issues/prds/<artifact-normalized-name>/artifact-analysis.md`

## Summary

* Total items: 0
* Actions: create 0, update 0, transition 0, comment 0, no change 0
* Needs review: 0

## Planned Operations

### Create

* [ ] JI001 - Create - `{{TEMP-1}}` - [Summary]

### Update

* [ ] JI002 - Update - `PROJ-123` - [Summary]

### Transition

* [ ] JI003 - Transition - `PROJ-123` - Move to `In Progress`

### Comment

* [ ] JI004 - Comment - `PROJ-123` - [Summary]

### No Change

* [ ] JI005 - No Change - `PROJ-456` - Existing issue already satisfies the requirement

## Hierarchy Review

* [Relationship summary and any `Needs Review` items]
````

## Content Sanitization Guards

Before text leaves the planning workflow for any future Jira mutation:

* Remove `.copilot-tracking/` paths and local planning file references.
* Remove planning IDs such as `JI001` unless the user explicitly wants them preserved.
* Replace unresolved `{{TEMP-N}}` placeholders with descriptive text if content must be shared before execution.

## Human Review Triggers

Pause and request user guidance when:

* The project key is unknown.
* Issue type support is unclear after field discovery.
* Multiple existing issues partially match one planned issue.
* Parent-child linkage depends on an unvalidated custom field.
* The hierarchy could be either flattened or nested with plausible outcomes.

## Success Criteria

* The workflow produces planning-only artifacts under `.copilot-tracking/jira-issues/prds/<artifact-normalized-name>/`.
* Each planned issue has a clear action, hierarchy decision, and validated field mapping.
* `issues-plan.md` contains payloads that use only validated Jira fields.
* `handoff.md` is ready for a separate Jira execution workflow.
