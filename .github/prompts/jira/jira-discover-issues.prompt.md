---
description: 'Discover Jira issues through user-centric queries, artifact-driven analysis, or JQL-based exploration and produce planning files for review'
agent: Jira Backlog Manager
argument-hint: "[project=...] [documents=...] [jql=...] [searchTerms=...]"
---

# Discover Jira Issues

Classify the discovery request and delegate to the appropriate Jira backlog discovery workflow.

Follow all instructions from #file:../../instructions/jira/jira-backlog-discovery.instructions.md while executing this workflow.
Follow all instructions from #file:../../instructions/jira/jira-backlog-planning.instructions.md for shared conventions.

## Inputs

* `${input:project}`: (Optional) Jira project key used to scope searches, field discovery, and issue creation plans.
* `${input:documents}`: (Optional) Document paths or attached files to analyze for issue extraction. Triggers artifact-driven discovery when provided.
* `${input:jql}`: (Optional) Explicit JQL query to execute. Triggers JQL-based discovery when provided.
* `${input:searchTerms}`: (Optional) Plain-language search terms to convert into bounded JQL when `jql` is not provided.
* `${input:includeComments:false}`: (Optional, defaults to false) Include issue comments in hydrated discovery results.
* `${input:autonomy:partial}`: (Optional, defaults to partial) Autonomy tier controlling confirmation gates during handoff review. Values: `full`, `partial`, `manual`.

## Requirements

1. Use `documents` for artifact-driven discovery, `jql` or `searchTerms` for bounded query discovery, and user-centric discovery only when the request clearly asks for assigned-issue or backlog visibility without source artifacts.
2. When `documents`, `jql`, and `searchTerms` are all omitted and the request does not clearly indicate user-centric discovery, ask the user to clarify the discovery goal before proceeding.
3. Keep discovery read-only with respect to Jira mutations.
4. For artifact-driven discovery, create planning artifacts under `.copilot-tracking/jira-issues/discovery/<scope-name>/`, including `planning-log.md`, `issue-analysis.md`, `issues-plan.md`, and `handoff.md`.
5. For user-centric or JQL-based discovery, use bounded JQL, optionally hydrate comments when `${input:includeComments}` is true, and return a conversational summary while recording discovery progress in `planning-log.md`.
6. Apply `${input:autonomy}` only to review gates and handoff presentation, not to Jira mutations.