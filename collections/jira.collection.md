# Jira Integration

Manage Jira backlog workflows and PRD-driven issue planning from VS Code. This collection adds dedicated Jira agents, prompts, and instructions on top of the Jira skill so discovery, triage, execution, and planning workflows use the same tracking and handoff patterns as the rest of HVE Core.

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

## Chat Agents

| Name                     | Description                                                                                                               |
|--------------------------|---------------------------------------------------------------------------------------------------------------------------|
| **jira-backlog-manager** | Orchestrator agent for Jira backlog management workflows including discovery, triage, execution, and single-issue actions |
| **jira-prd-to-wit**      | Product Manager expert for analyzing PRDs and planning Jira issue hierarchies without mutating Jira                       |

## Prompts

| Name                     | Description                                                                                                                                 |
|--------------------------|---------------------------------------------------------------------------------------------------------------------------------------------|
| **jira-discover-issues** | Discover Jira issues through user-centric queries, artifact-driven analysis, or JQL-based exploration and produce planning files for review |
| **jira-execute-backlog** | Execute a Jira backlog plan by creating, updating, transitioning, and commenting on issues from a handoff file                              |
| **jira-prd-to-wit**      | Analyze PRD artifacts and plan Jira issue hierarchies without mutating Jira                                                                 |
| **jira-triage-issues**   | Triage Jira issues with bounded JQL, field recommendations, duplicate detection, and optional execution of confirmed updates                |

## Instructions

| Name                            | Description                                                                                                                                                                                                                                                 |
|---------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **jira/jira-backlog-discovery** | Discovery protocol for Jira backlog management with user-centric, artifact-driven, and JQL-based issue discovery                                                                                                                                            |
| **jira/jira-backlog-planning**  | Reference specification for Jira backlog management tooling, planning files, search conventions, similarity assessment, and state persistence                                                                                                               |
| **jira/jira-backlog-triage**    | Triage workflow for Jira backlog management with field recommendations, duplicate detection, and controlled execution                                                                                                                                       |
| **jira/jira-backlog-update**    | Execution workflow for Jira backlog management that consumes planning handoffs and applies sequential Jira operations                                                                                                                                       |
| **jira/jira-wit-planning**      | Reference specification for Jira PRD work item planning files, hierarchy mapping, field validation, and handoff contracts                                                                                                                                   |
| **shared/hve-core-location**    | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

## Skills

| Name     | Description                                                                                                                                                                                                                                                                                           |
|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **jira** | Jira issue workflows for search, issue updates, transitions, comments, and field discovery via the Jira REST API. Use when you need to search with JQL, inspect an issue, create or update work items, move an issue between statuses, post comments, or discover required fields for issue creation. |

<!-- END AUTO-GENERATED ARTIFACTS -->
