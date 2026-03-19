---
description: 'Triage workflow for Jira backlog management with field recommendations, duplicate detection, and controlled execution - Brought to you by microsoft/hve-core'
applyTo: '**/.copilot-tracking/jira-issues/triage/**'
---

# Jira Backlog Triage Instructions

## Purpose and Scope

This workflow analyzes Jira issues in a bounded scope, suggests field updates, highlights duplicate signals, recommends workflow transitions, and records execution checkpoints.

Follow all instructions from #file:./jira-backlog-planning.instructions.md while executing this workflow.

## Autonomy Behavior for Triage Operations

| Operation                | Full         | Partial      | Manual       |
|--------------------------|--------------|--------------|--------------|
| Field update             | Auto-execute | Auto-execute | Gate on user |
| Transition               | Auto-execute | Gate on user | Gate on user |
| Comment                  | Auto-execute | Gate on user | Gate on user |
| Duplicate recommendation | Auto-execute | Gate on user | Gate on user |

## Required Phases

### Phase 1: Analyze

Fetch and analyze in-scope issues to build a triage assessment.

#### Step 1: Fetch Issues

1. Use the provided bounded JQL query.
2. When no JQL is provided, derive a bounded query from the project key.
3. Execute `search` with a concise field list.
4. Hydrate each returned issue with `get`.
5. Create `planning-log.md` in `.copilot-tracking/jira-issues/triage/{{YYYY-MM-DD}}/` and record the fetched issues.

When no issues are found, inform the user and end the workflow.

#### Step 2: Analyze Each Issue

For each issue:

1. Review summary, description, labels, assignee, priority, and status.
2. Suggest labels and priority based on the issue summary, acceptance criteria, and known team conventions.
3. Search for duplicate candidates using narrow JQL derived from the summary and key nouns.
4. Recommend a status transition only when the available evidence makes the target state clear.
5. Recommend a comment when follow-up context should be added without mutating structured fields.

#### Step 3: Record Analysis

Create `triage-plan.md` and record:

* Issue key and summary
* Current fields
* Suggested field changes with rationale
* Duplicate candidates with Match, Similar, Distinct, or Uncertain classification
* Recommended transition or comment actions

### Phase 2: Plan and Execute

Produce a triage plan for review and execute confirmed recommendations.

#### Step 1: Generate Triage Plan

Use this summary table format in `triage-plan.md`:

```markdown
| Issue | Summary | Suggested Fields | Suggested Transition | Duplicates | Action |
| ----- | ------- | ---------------- | -------------------- | ---------- | ------ |
```

#### Step 2: Present for Review

Present the triage plan to the user, highlighting issues with:

* High-confidence field updates
* Potential duplicates
* Ambiguous transitions
* Missing project or issue-type context that would block later execution

#### Step 3: Execute Confirmed Recommendations

Before composing any Jira-bound text, apply the Content Sanitization Guards from #file:./jira-backlog-planning.instructions.md.

Use only supported Jira skill commands:

* Field updates: `update <ISSUE-KEY> '<json>'`
* Status changes: `transition <ISSUE-KEY> '<transition>'`
* Context notes: `comment <ISSUE-KEY> '<body>'`

Update `planning-log.md` after each executed change.

## Duplicate Detection

Use narrow JQL searches based on summary keywords and project scope.

| Similarity Category | Action                                                                   |
|---------------------|--------------------------------------------------------------------------|
| Match               | Recommend user review before any duplicate-related comment or transition |
| Similar             | Present both issues for review                                           |
| Distinct            | Proceed with normal triage                                               |
| Uncertain           | Ask the user for guidance                                                |

Because the MVP uses only the documented Jira skill commands, do not assume issue-linking APIs are available in this workflow.

## Error Handling

* Invalid JQL: log the failure in `planning-log.md`, suggest a narrower query, and pause.
* Invalid field payload: log the error, keep the recommendation in `triage-plan.md`, and continue with the remaining issues.
* Transition not found: record the available transitions in `planning-log.md` and gate on user input.
* Concurrent modification: re-fetch the issue before applying updates.

## Output

The triage workflow produces files in `.copilot-tracking/jira-issues/triage/{{YYYY-MM-DD}}/`:

* `planning-log.md`
* `triage-plan.md`

---

Brought to you by microsoft/hve-core