<!-- markdownlint-disable-file -->
# Azure DevOps Integration

Azure DevOps work item management, build monitoring, and pull request creation

## Overview

Manage Azure DevOps work items, monitor builds, create pull requests, and convert requirements documents into structured work item hierarchies - all from within VS Code.

## Included Artifacts

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Chat Agents

| Name                    | Description                                                                                                          |
|-------------------------|----------------------------------------------------------------------------------------------------------------------|
| **ado-backlog-manager** | Azure DevOps backlog orchestrator for triage, discovery, sprint planning, PRD-to-work-item conversion, and execution |
| **ado-prd-to-wit**      | Product Manager expert for analyzing PRDs and planning Azure DevOps work item hierarchies                            |

### Prompts

| Name                                            | Description                                                                                                       |
|-------------------------------------------------|-------------------------------------------------------------------------------------------------------------------|
| **ado-add-work-item**                           | Create a single Azure DevOps work item with conversational field collection and parent validation                 |
| **ado-create-pull-request**                     | Create an Azure DevOps pull request with generated description, linked work items, and reviewers                  |
| **ado-discover-work-items**                     | Discover Azure DevOps work items via user queries, artifact analysis, or search                                   |
| **ado-get-build-info**                          | Retrieve Azure DevOps build status and logs for a pull request or build number                                    |
| **ado-get-my-work-items**                       | Retrieve your assigned Azure DevOps work items into a planning file                                               |
| **ado-process-my-work-items-for-task-planning** | Process retrieved work items for task planning and generate task-planning-logs.md handoff file                    |
| **ado-sprint-plan**                             | Plan an Azure DevOps sprint by analyzing iteration coverage, capacity, dependencies, and backlog gaps             |
| **ado-triage-work-items**                       | Triage untriaged Azure DevOps work items with field classification, iteration assignment, and duplicate detection |
| **ado-update-wit-items**                        | Update Azure DevOps work items from planning files                                                                |

### Instructions

| Name                              | Description                                                                                                                                                                                                                                                 |
|-----------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **ado/ado-backlog-sprint**        | Sprint planning workflow for Azure DevOps iterations with coverage analysis, capacity tracking, and gap detection                                                                                                                                           |
| **ado/ado-backlog-triage**        | Triage workflow for Azure DevOps work items with field classification, iteration assignment, and duplicate detection                                                                                                                                        |
| **ado/ado-create-pull-request**   | Azure DevOps pull request creation with work item discovery, reviewer identification, and automated linking                                                                                                                                                 |
| **ado/ado-get-build-info**        | Azure DevOps build information: status, logs, and details from a PR, build ID, or branch name                                                                                                                                                               |
| **ado/ado-interaction-templates** | Work item description and comment templates for consistent Azure DevOps content formatting                                                                                                                                                                  |
| **ado/ado-update-wit-items**      | Work item creation and update protocol using MCP ADO tools with handoff tracking                                                                                                                                                                            |
| **ado/ado-wit-discovery**         | Azure DevOps work item discovery via user assignment or artifact analysis with planning file output                                                                                                                                                         |
| **ado/ado-wit-planning**          | Azure DevOps work item planning files, templates, field definitions, and search protocols                                                                                                                                                                   |
| **shared/hve-core-location**      | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

### Skills

| Name             | Description                                                                                                                                                                                                                                                                                      |
|------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **pr-reference** | Generates PR reference XML with commit history and unified diffs between branches, with extension and path filtering. Use when creating pull request descriptions, preparing code reviews, analyzing branch changes, discovering work items from diffs, or generating structured diff summaries. |

<!-- END AUTO-GENERATED ARTIFACTS -->

## Install

```bash
copilot plugin install ado@hve-core
```

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

