---
title: Jira
description: Jira backlog management, PRD issue planning, and issue operations through agents, prompts, instructions, and a Python skill
sidebar_position: 11
author: Microsoft
ms.date: 2026-08-03
ms.topic: reference
keywords:
  - package
  - jira
  - issues
---

Choose this package for teams that manage backlogs, PRD-derived issue planning, and issue operations in Jira.

It combines backlog and PRD planning agents, prompts for discovery through execution, workflow instructions, and a Python skill for Jira REST API operations.

Lifecycle labels are disclosure metadata. In the channel model, Stable and PreRelease have equal active content, including components labeled stable, preview, and experimental; publication cadence and source ownership can differ.

## Included Artifacts

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Chat Agents

| Name                     | Maturity | Description                                                                                         |
|--------------------------|----------|-----------------------------------------------------------------------------------------------------|
| **jira-backlog-manager** | stable   | Jira backlog orchestrator for discovery, triage, execution, and single-issue actions                |
| **jira-prd-to-wit**      | stable   | Product Manager expert for analyzing PRDs and planning Jira issue hierarchies without mutating Jira |

### Prompts

| Name                     | Maturity | Description                                                                                                    |
|--------------------------|----------|----------------------------------------------------------------------------------------------------------------|
| **jira-discover-issues** | stable   | Discover Jira issues via user queries, artifact analysis, or JQL search and produce planning files             |
| **jira-execute-backlog** | stable   | Execute a Jira backlog plan by creating, updating, transitioning, and commenting on issues from a handoff file |
| **jira-prd-to-wit**      | stable   | Analyze PRD artifacts and plan Jira issue hierarchies without mutating Jira                                    |
| **jira-setup**           | stable   | Interactive, verification-first Jira credential configuration assistant (non-destructive)                      |
| **jira-triage-issues**   | stable   | Triage Jira issues with field recommendations, duplicate detection, and optional updates                       |

### Instructions

| Name                            | Maturity | Description                                                                                                                                                                                                                                                 |
|---------------------------------|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **jira/jira-backlog-discovery** | stable   | Jira issue backlog discovery: user-centric, artifact-driven, JQL-based                                                                                                                                                                                      |
| **jira/jira-backlog-planning**  | stable   | Jira backlog management: planning files, search conventions, similarity assessment, and state persistence                                                                                                                                                   |
| **jira/jira-backlog-triage**    | stable   | Jira issue backlog triage: field recommendations, duplicate detection, and controlled execution                                                                                                                                                             |
| **jira/jira-backlog-update**    | stable   | Jira backlog execution: consumes planning handoffs and applies sequential Jira operations                                                                                                                                                                   |
| **jira/jira-wit-planning**      | stable   | Jira PRD work item planning: hierarchy mapping, field validation, and handoff contracts                                                                                                                                                                     |
| **shared/hve-core-location**    | stable   | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

### Skills

| Name     | Maturity | Description                                                                                                                                                                                                                                                                                           |
|----------|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **jira** | stable   | Jira issue workflows for search, issue updates, transitions, comments, and field discovery via the Jira REST API. Use when you need to search with JQL, inspect an issue, create or update work items, move an issue between statuses, post comments, or discover required fields for issue creation. |

<!-- END AUTO-GENERATED ARTIFACTS -->

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
