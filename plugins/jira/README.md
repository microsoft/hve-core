<!-- markdownlint-disable-file -->
# Jira Integration

Jira backlog management, PRD issue planning, and issue operations through agents, prompts, instructions, and a Python skill

## Overview

Manage Jira backlog workflows and PRD-driven issue planning from VS Code. This collection adds dedicated Jira agents, prompts, and instructions on top of the Jira skill so discovery, triage, execution, and planning workflows use the same tracking and handoff patterns as the rest of HVE Core.

This collection includes:

- A Jira Backlog Manager agent for discovery, triage, execution, and single-issue backlog actions
- A Jira PRD to WIT planning agent for converting requirements documents into Jira-ready issue hierarchies
- Jira prompts for backlog discovery, triage, execution, and PRD planning workflows
- Jira planning instructions for discovery, triage, execution, and PRD handoff artifacts
- The Jira skill for JQL search, issue inspection, creation, updates, transitions, comments, and field discovery

## Install

```bash
copilot plugin install jira@hve-core
```

## Agents

| Agent                | Description                                                                                                                                                      |
|----------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| jira-backlog-manager | Orchestrator agent for Jira backlog management workflows including discovery, triage, execution, and single-issue actions - Brought to you by microsoft/hve-core |
| jira-prd-to-wit      | Product Manager expert for analyzing PRDs and planning Jira issue hierarchies without mutating Jira - Brought to you by microsoft/hve-core                       |

## Commands

| Command              | Description                                                                                                                                 |
|----------------------|---------------------------------------------------------------------------------------------------------------------------------------------|
| jira-discover-issues | Discover Jira issues through user-centric queries, artifact-driven analysis, or JQL-based exploration and produce planning files for review |
| jira-execute-backlog | Execute a Jira backlog plan by creating, updating, transitioning, and commenting on issues from a handoff file                              |
| jira-prd-to-wit      | Analyze PRD artifacts and plan Jira issue hierarchies without mutating Jira                                                                 |
| jira-triage-issues   | Triage Jira issues with bounded JQL, field recommendations, duplicate detection, and optional execution of confirmed updates                |

## Instructions

| Instruction                         | Description                                                                                                                                                                                                                                                 |
|-------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| hve-core-location.instructions      | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |
| jira-backlog-discovery.instructions | Discovery protocol for Jira backlog management with user-centric, artifact-driven, and JQL-based issue discovery - Brought to you by microsoft/hve-core                                                                                                     |
| jira-backlog-planning.instructions  | Reference specification for Jira backlog management tooling, planning files, search conventions, similarity assessment, and state persistence - Brought to you by microsoft/hve-core                                                                        |
| jira-backlog-triage.instructions    | Triage workflow for Jira backlog management with field recommendations, duplicate detection, and controlled execution - Brought to you by microsoft/hve-core                                                                                                |
| jira-backlog-update.instructions    | Execution workflow for Jira backlog management that consumes planning handoffs and applies sequential Jira operations - Brought to you by microsoft/hve-core                                                                                                |
| jira-wit-planning.instructions      | Reference specification for Jira PRD work item planning files, hierarchy mapping, field validation, and handoff contracts - Brought to you by microsoft/hve-core                                                                                            |

## Skills

| Skill | Description                                                                                                                                                                                                                                                                                                                                  |
|-------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| jira  | Jira issue workflows for search, issue updates, transitions, comments, and field discovery via the Jira REST API. Use when you need to search with JQL, inspect an issue, create or update work items, move an issue between statuses, post comments, or discover required fields for issue creation. - Brought to you by microsoft/hve-core |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

