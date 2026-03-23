<!-- markdownlint-disable-file -->
# Azure DevOps Integration

Azure DevOps work item management, build monitoring, and pull request creation

## Overview

Manage Azure DevOps work items, monitor builds, create pull requests, and convert requirements documents into structured work item hierarchies — all from within VS Code.

This collection includes agents and prompts for:

- **Work Item Management** — Discover, create, update, and plan work items across ADO projects
- **Build Monitoring** — Query build status, review logs, and diagnose failures
- **Pull Request Creation** — Generate PRs with linked work items and reviewer identification
- **PRD-to-Work-Item Conversion** — Transform Product Requirements Documents into ADO feature/user-story/task hierarchies
- **Backlog Management** — Orchestrated triage, discovery, sprint planning, and work item creation workflows through a central ADO Backlog Manager agent

## Install

```bash
copilot plugin install ado@hve-core
```

## Agents

| Agent                     | Description                                                                                                                                                                                      |
|---------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ado-prd-to-wit.agent      | Product Manager expert for analyzing PRDs and planning Azure DevOps work item hierarchies                                                                                                        |
| ado-backlog-manager.agent | Orchestrator agent for Azure DevOps backlog management workflows including triage, discovery, sprint planning, PRD-to-work-item conversion, and execution - Brought to you by microsoft/hve-core |

## Commands

| Command                                            | Description                                                                                                                                 |
|----------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------|
| ado-create-pull-request.prompt                     | Generate pull request description, discover related work items, identify reviewers, and create Azure DevOps pull request with all linkages. |
| ado-get-build-info.prompt                          | Retrieve Azure DevOps build information for a Pull Request or specific Build Number.                                                        |
| ado-get-my-work-items.prompt                       | Retrieve user's current Azure DevOps work items and organize them into planning file definitions                                            |
| ado-process-my-work-items-for-task-planning.prompt | Process retrieved work items for task planning and generate task-planning-logs.md handoff file                                              |
| ado-update-wit-items.prompt                        | Prompt to update work items based on planning files                                                                                         |
| ado-add-work-item.prompt                           | Create a single Azure DevOps work item with conversational field collection and parent validation                                           |
| ado-discover-work-items.prompt                     | Discover Azure DevOps work items through user-centric queries, artifact-driven analysis, or search-based exploration                        |
| ado-sprint-plan.prompt                             | Plan an Azure DevOps sprint by analyzing iteration coverage, capacity, dependencies, and backlog gaps                                       |
| ado-triage-work-items.prompt                       | Triage untriaged Azure DevOps work items with field classification, iteration assignment, and duplicate detection                           |

## Instructions

| Instruction                            | Description                                                                                                                                                                                                                                                 |
|----------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ado-create-pull-request.instructions   | Required protocol for creating Azure DevOps pull requests with work item discovery, reviewer identification, and automated linking.                                                                                                                         |
| ado-get-build-info.instructions        | Required instructions for anything related to Azure Devops or ado build information including status, logs, or details from provided pullrequest (PR), build Id, or branch name.                                                                            |
| ado-update-wit-items.instructions      | Work item creation and update protocol using MCP ADO tools with handoff tracking                                                                                                                                                                            |
| ado-wit-discovery.instructions         | Protocol for discovering Azure DevOps work items via user assignment or artifact analysis with planning file output                                                                                                                                         |
| ado-wit-planning.instructions          | Reference specification for Azure DevOps work item planning files, templates, field definitions, and search protocols                                                                                                                                       |
| ado-backlog-sprint.instructions        | Sprint planning workflow for Azure DevOps iterations with coverage analysis, capacity tracking, and gap detection - Brought to you by microsoft/hve-core                                                                                                    |
| ado-backlog-triage.instructions        | Triage workflow for Azure DevOps work items with field classification, iteration assignment, and duplicate detection - Brought to you by microsoft/hve-core                                                                                                 |
| ado-interaction-templates.instructions | Work item description and comment templates for consistent Azure DevOps content formatting - Brought to you by microsoft/hve-core                                                                                                                           |
| hve-core-location.instructions         | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

## Skills

| Skill        | Description                                                                                                                                                                                                                                                                                                                                                                                                         |
|--------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| pr-reference | Generates PR reference XML containing commit history and unified diffs between branches with extension and path filtering. Includes utilities to list changed files by type and read diff chunks. Use when creating pull request descriptions, preparing code reviews, analyzing branch changes, discovering work items from diffs, or generating structured diff summaries. - Brought to you by microsoft/hve-core |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

