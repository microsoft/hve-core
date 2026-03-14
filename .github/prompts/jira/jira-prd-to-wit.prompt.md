---
description: 'Analyze PRD artifacts and plan Jira issue hierarchies without mutating Jira'
agent: Jira PRD to WIT
argument-hint: "[project=...] [artifacts=...] [autonomy={partial|manual|full}]"
---

# Jira PRD To Work Item Planning

## Inputs

* `${input:project}`: (Optional) Jira project key used for issue type validation, related issue discovery, and payload planning.
* `${input:artifacts}`: (Optional) PRD documents, folders, attached files, or explicit PRD source content to analyze. Defaults only to a concrete PRD source artifact from the active file or current context when omitted.
* `${input:autonomy:partial}`: (Optional, defaults to partial) Review gate level for the resulting handoff. Values: `full`, `partial`, `manual`.

## Requirements

1. Analyze the provided PRD artifacts and derive a Jira issue hierarchy that is ready for review.
2. Before delegation proceeds, validate that `${input:artifacts}` or any omitted-input fallback resolves to a concrete PRD source artifact.
3. When `${input:artifacts}` is omitted and the active file or current context is not a PRD source artifact, ask the user for the PRD artifact and stop until it is provided.
4. Keep the workflow planning-only. Do not mutate Jira as part of this prompt.
5. Use only Jira issue types and fields that are validated through the Jira skill.
6. Write planning artifacts under `.copilot-tracking/jira-issues/prds/<artifact-normalized-name>/`.
7. Produce a handoff that can be executed later through Jira backlog workflows.