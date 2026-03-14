---
description: 'Reference specification for Jira backlog management tooling, planning files, search conventions, similarity assessment, and state persistence'
applyTo: '**/.copilot-tracking/jira-issues/**'
---

# Jira Backlog Planning File Instructions

## Purpose and Scope

Templates, field conventions, Jira command references, and state persistence rules for Jira backlog planning files. Workflow files consume this specification by including a cross-reference at the top of their content.

Cross-reference pattern for consuming files:

```markdown
Follow all instructions from #file:./jira-backlog-planning.instructions.md while executing this workflow.
```

Inline reference pattern when citing specific sections:

```markdown
per templates in #file:./jira-backlog-planning.instructions.md
using the matrix from #file:./jira-backlog-planning.instructions.md
```

## Jira Command Catalog

Use the Jira skill through `.github/skills/jira/jira/scripts/jira.py`.

### Discovery and Retrieval

* `search`: Search for issues with bounded JQL. Key parameters: `'<jql>'`, optional `max_results`, optional `--fields`.
* `get`: Read one issue with an explicit field list. Key parameters: `<ISSUE-KEY>`, optional `--fields`.
* `comments`: Retrieve comments for one or more issues. Key parameters: `<ISSUE-KEY> [ISSUE-KEY ...]`, optional `--fields`.
* `fields`: Discover issue types for a project or required create fields for a specific issue type. Key parameters: `<PROJECT-KEY> [issue-type-id]`.

### Creation and Updates

* `create`: Create an issue from a JSON payload. Key parameters: JSON on stdin or as an argument.
* `update`: Update an issue from a JSON payload. Key parameters: `<ISSUE-KEY>`, JSON on stdin or as an argument.
* `transition`: Move an issue to a new status by transition name or ID. Key parameters: `<ISSUE-KEY>`, `<transition-name-or-id>`.
* `comment`: Add a comment to an issue. Key parameters: `<ISSUE-KEY>`, comment body on stdin or as an argument.

## Planning File Definitions and Directory Conventions

Root planning workspace structure:

```text
.copilot-tracking/
  jira-issues/
    <planning-type>/
      <scope-name>/
        issue-analysis.md
        issues-plan.md
        planning-log.md
        handoff.md
        handoff-logs.md
```

Valid `<planning-type>` values:

* `discovery`: Issue discovery from artifacts, requirements, or search scopes
* `triage`: Issue triage, field cleanup, duplicate review, and workflow-state recommendations
* `execution`: Issue creation, update, transition, and comment processing from finalized plans

Normalization rules for `<scope-name>`:

* Use lower-case, hyphenated form without extension.
* Replace spaces and punctuation with hyphens.
* Choose the primary artifact when multiple documents are provided.
* For triage scopes, use the date as the scope name.
* For execution scopes, use the date as the scope name unless the handoff file already defines a clearer slug.

## Planning File Requirements

Planning markdown files must start with:

```markdown
<!-- markdownlint-disable-file -->
<!-- markdown-table-prettify-ignore-start -->
```

Planning markdown files must end with:

```markdown
<!-- markdown-table-prettify-ignore-end -->
```

## Planning File Templates

### issue-analysis.md

Use `issue-analysis.md` when discovery starts from documents or user-provided requirements. The file captures evolving human-readable analysis before finalizing `issues-plan.md`.

#### Template

````markdown
# [Planning Type] Jira Issue Analysis - [Summarized Title]

* **Artifact(s)**: [relative/path/to/artifact.md]
* **Project**: [PROJECT]
* **Source Query**: [(Optional) JQL used during discovery]

## Planned Issues

### JI001 - [Create|Update|Transition|Comment|No Change] - [Summarized Issue Title]

* **Working Summary**: [Single-line summary]
* **Working Issue Type**: [Task|Bug|Story|Epic|...] 
* **Key Search Terms**: [Keyword groups]
* **Working Description**:
  ```markdown
  [Evolving description content constructed from artifacts and discovery]
  ```
* **Working Labels**: [Comma-separated labels]
* **Working Priority**: [Highest|High|Medium|Low|Lowest]
* **Working Target Status**: [(Optional) In Progress|To Do|Done|...]
* **Found Issue Field Values**:
  * Status: [Current status]
  * Labels: [Current labels]
  * Priority: [Current priority]
* **Suggested Issue Field Values**:
  * Labels: [Target labels]
  * Priority: [Target priority]
  * Status: [Target status]

#### JI001 - Related and Discovered Information

* **Requirements**:
  * REQ-001: [Requirement text]
* **Key Details**:
  * [Supporting detail from artifact, query result, or comment]
* **Potential Matches**:
  * [ISSUE-KEY]: [Match|Similar|Distinct|Uncertain]
````

### issues-plan.md

`issues-plan.md` is the source of truth for planned Jira operations.

#### Template

````markdown
# Jira Issues Plan

* **Project**: [PROJECT]
* **Source Scope**: [Artifact name, query slug, or date]

## JI001 - [Create|Update|Transition|Comment|No Change] - [Summarized Title]

[1-5 sentence explanation of the planned change]

JI001 - Similarity: [PROJ-123=Match, PROJ-456=Similar]

* JI001 - issue_key: [PROJ-123 or {{TEMP-1}}]
* JI001 - summary: [Issue summary]
* JI001 - issue_type: [Task|Bug|Story|Epic|...]
* JI001 - status: [Current status or planned status]
* JI001 - labels: [Comma-separated labels]
* JI001 - priority: [Highest|High|Medium|Low|Lowest]
* JI001 - assignee: [Display name, account id, or none]

### JI001 - body

```markdown
[Issue body or comment body content]
```

### JI001 - payload

```json
{
  "fields": {}
}
```
````

### planning-log.md

`planning-log.md` tracks workflow progress and resumable state.

#### Template

````markdown
# Jira Planning Log - [Scope Name]

* **Planning Type**: [discovery|triage|execution]
* **Project**: [PROJECT or unknown]
* **Status**: [Not Started|In Progress|Waiting for Review|Complete|Blocked]

## Progress Log

* [YYYY-MM-DD HH:MM UTC] Initialized workflow.
* [YYYY-MM-DD HH:MM UTC] Executed JQL: `[query]`.
* [YYYY-MM-DD HH:MM UTC] Updated handoff after user review.

## Resume Context

* **Current Phase**: [Phase name]
* **Completed Items**: [Summary]
* **Pending Items**: [Summary]
* **Open Questions**: [Summary]
````

### handoff.md

`handoff.md` is the user-reviewable execution contract.

#### Template

````markdown
# Jira Handoff - [Scope Name]

* **Project**: [PROJECT]
* **Autonomy**: [full|partial|manual]

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

## Planning Files

* `issue-analysis.md`
* `issues-plan.md`
* `planning-log.md`
````

### handoff-logs.md

`handoff-logs.md` records execution checkpoints.

#### Template

````markdown
# Jira Handoff Logs - [Scope Name]

## Execution Summary

* **Status**: [In Progress|Complete|Blocked]
* **Created**: 0
* **Updated**: 0
* **Transitioned**: 0
* **Commented**: 0
* **Failed**: 0
* **Skipped**: 0

## Operation Log

* [YYYY-MM-DD HH:MM UTC] JI001 - Create - `{{TEMP-1}}` - Success - Created `PROJ-123`
* [YYYY-MM-DD HH:MM UTC] JI002 - Update - `PROJ-456` - Failed - Invalid field payload

## Temporary ID Mapping

* `{{TEMP-1}}` -> `PROJ-123`
````

## Similarity Assessment Framework

Classify candidate-to-existing-issue comparisons using these categories:

| Category  | Meaning                                                                              |
|-----------|--------------------------------------------------------------------------------------|
| Match     | Existing issue already covers the requirement with minor or no edits                 |
| Similar   | Existing issue overlaps but requires user review to decide whether to merge or split |
| Distinct  | Existing issue does not cover the requirement                                        |
| Uncertain | Available evidence is insufficient for a confident decision                          |

Assess similarity using summary overlap, issue type compatibility, status, labels, and requirement coverage from the source artifact.

## Jira Field Guidance

Prefer these fields for MVP planning when available:

| Field         | Use                                 |
|---------------|-------------------------------------|
| `project`     | Required for create operations      |
| `summary`     | Required for create operations      |
| `issuetype`   | Required for create operations      |
| `description` | Primary body content                |
| `labels`      | Lightweight categorization          |
| `priority`    | Triage and execution prioritization |
| `assignee`    | Optional ownership assignment       |

Call `fields` before creating issues when the project or issue type is not already validated in the plan.

## Content Sanitization Guards

Before sending text to Jira through `create`, `update`, or `comment`:

* Remove `.copilot-tracking/` paths and local planning file references.
* Remove planning reference IDs such as `JI001` unless the user explicitly wants them preserved in Jira.
* Replace unresolved `{{TEMP-N}}` placeholders with descriptive text when a Jira comment is being posted before the create step has run.
* Keep committed repository file paths only when they are useful to the user and safe to expose in Jira.

## Three-Tier Autonomy Model

| Mode              | Behavior                                                                                             |
|-------------------|------------------------------------------------------------------------------------------------------|
| Full              | Execute all supported Jira operations without confirmation                                           |
| Partial (default) | Auto-execute low-risk field updates, but gate creates, transitions, and ambiguous duplicate handling |
| Manual            | Require confirmation for every Jira mutation                                                         |

## State Persistence Protocol

When a conversation resumes after summarization or interruption:

1. Read `planning-log.md` first.
2. If execution has started, read `handoff.md` and `handoff-logs.md`.
3. Rebuild any `{{TEMP-N}}` mappings from `handoff-logs.md` before continuing.
4. Continue from the first unchecked or unlogged operation.

## Human Review Triggers

Pause and ask for guidance when:

* The project key or issue type for a planned create is still unknown.
* Similarity assessment returns Uncertain.
* Multiple existing issues are Similar matches for one candidate.
* A transition target is not available for the issue.
* A create or update would touch fields not covered by the validated field payload.

---

Brought to you by microsoft/hve-core