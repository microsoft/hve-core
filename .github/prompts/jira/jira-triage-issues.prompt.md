---
description: 'Triage Jira issues with bounded JQL, field recommendations, duplicate detection, and optional execution of confirmed updates'
agent: Jira Backlog Manager
argument-hint: "[project=...] [jql=...] [maxIssues=20] [autonomy={full|partial|manual}]"
---

# Triage Jira Issues

Fetch bounded Jira issues, analyze them for triage recommendations, and prepare reviewable updates.

Follow all instructions from #file:../../instructions/jira/jira-backlog-triage.instructions.md while executing this workflow.
Follow all instructions from #file:../../instructions/jira/jira-backlog-planning.instructions.md for shared conventions.

## Inputs

* `${input:project}`: (Optional) Jira project key used to scope triage when `jql` is not provided.
* `${input:jql}`: (Optional) Explicit bounded JQL query selecting the issues to triage.
* `${input:maxIssues:20}`: (Optional, defaults to 20) Maximum issues to process per batch.
* `${input:autonomy:partial}`: (Optional, defaults to partial) Autonomy tier controlling confirmation gates. Values: `full`, `partial`, `manual`.

## Requirements

1. Require a bounded triage scope from `${input:jql}` or `${input:project}` and ask the user for one of them before proceeding when both are missing.
2. When only `${input:project}` is provided, derive a bounded default query and process at most `${input:maxIssues}` issues in the batch.
3. Create triage planning artifacts under `.copilot-tracking/jira-issues/triage/{{YYYY-MM-DD}}/`, including `planning-log.md` and `triage-plan.md`.
4. Record field recommendations, duplicate signals, rationale, and no-change outcomes for each processed issue.
5. Respect `${input:autonomy}` for review gates and only execute supported Jira updates after the delegated triage workflow determines they are confirmed.
6. Present ambiguous duplicates, missing scope, or stale issue state for review instead of guessing.