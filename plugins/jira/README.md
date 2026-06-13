<!-- markdownlint-disable-file -->
# Jira Integration

Jira backlog management, PRD issue planning, and issue operations through agents, prompts, instructions, and a Python skill

## Overview

Manage Jira backlog workflows and PRD-driven issue planning from VS Code. This collection adds dedicated Jira agents, prompts, and instructions on top of the Jira skill so discovery, triage, execution, and planning workflows use the same tracking and handoff patterns as the rest of HVE Core.

## Included Artifacts

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Chat Agents

| Name                     | Description                                                                                         |
|--------------------------|-----------------------------------------------------------------------------------------------------|
| **jira-backlog-manager** | Jira backlog orchestrator for discovery, triage, execution, and single-issue actions                |
| **jira-prd-to-wit**      | Product Manager expert for analyzing PRDs and planning Jira issue hierarchies without mutating Jira |

### Prompts

| Name                     | Description                                                                                                    |
|--------------------------|----------------------------------------------------------------------------------------------------------------|
| **jira-discover-issues** | Discover Jira issues via user queries, artifact analysis, or JQL search and produce planning files             |
| **jira-execute-backlog** | Execute a Jira backlog plan by creating, updating, transitioning, and commenting on issues from a handoff file |
| **jira-prd-to-wit**      | Analyze PRD artifacts and plan Jira issue hierarchies without mutating Jira                                    |
| **jira-setup**           | Interactive, verification-first Jira credential configuration assistant (non-destructive)                      |
| **jira-triage-issues**   | Triage Jira issues with field recommendations, duplicate detection, and optional updates                       |

### Instructions

| Name                            | Description                                                                                                                                                                                                                                                 |
|---------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **jira/jira-backlog-discovery** | Jira issue backlog discovery: user-centric, artifact-driven, JQL-based                                                                                                                                                                                      |
| **jira/jira-backlog-planning**  | Jira backlog management: planning files, search conventions, similarity assessment, and state persistence                                                                                                                                                   |
| **jira/jira-backlog-triage**    | Jira issue backlog triage: field recommendations, duplicate detection, and controlled execution                                                                                                                                                             |
| **jira/jira-backlog-update**    | Jira backlog execution: consumes planning handoffs and applies sequential Jira operations                                                                                                                                                                   |
| **jira/jira-wit-planning**      | Jira PRD work item planning: hierarchy mapping, field validation, and handoff contracts                                                                                                                                                                     |
| **shared/hve-core-location**    | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

### Skills

| Name     | Description                                                                                                                                                                                                                                                                                           |
|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **jira** | Jira issue workflows for search, issue updates, transitions, comments, and field discovery via the Jira REST API. Use when you need to search with JQL, inspect an issue, create or update work items, move an issue between statuses, post comments, or discover required fields for issue creation. |

<!-- END AUTO-GENERATED ARTIFACTS -->

## Install

```bash
copilot plugin install jira@hve-core
```

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

