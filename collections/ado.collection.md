Manage Azure DevOps work items, monitor builds, create pull requests, and convert requirements documents into structured work item hierarchies — all from within VS Code.

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Chat Agents

| Name | Description |
|------|-------------|
| **ado-backlog-manager** | Orchestrator agent for Azure DevOps backlog management workflows including triage, discovery, sprint planning, PRD-to-work-item conversion, and execution |
| **ado-prd-to-wit** | Product Manager expert for analyzing PRDs and planning Azure DevOps work item hierarchies |

### Prompts

| Name | Description |
|------|-------------|
| **ado-add-work-item** | Create a single Azure DevOps work item with conversational field collection and parent validation |
| **ado-create-pull-request** | Generate pull request description, discover related work items, identify reviewers, and create Azure DevOps pull request with all linkages. |
| **ado-discover-work-items** | Discover Azure DevOps work items through user-centric queries, artifact-driven analysis, or search-based exploration |
| **ado-get-build-info** | Retrieve Azure DevOps build information for a Pull Request or specific Build Number. |
| **ado-get-my-work-items** | Retrieve user's current Azure DevOps work items and organize them into planning file definitions |
| **ado-process-my-work-items-for-task-planning** | Process retrieved work items for task planning and generate task-planning-logs.md handoff file |
| **ado-sprint-plan** | Plan an Azure DevOps sprint by analyzing iteration coverage, capacity, dependencies, and backlog gaps |
| **ado-triage-work-items** | Triage untriaged Azure DevOps work items with field classification, iteration assignment, and duplicate detection |
| **ado-update-wit-items** | Prompt to update work items based on planning files |

### Instructions

| Name | Description |
|------|-------------|
| **ado/ado-backlog-sprint** | Sprint planning workflow for Azure DevOps iterations with coverage analysis, capacity tracking, and gap detection |
| **ado/ado-backlog-triage** | Triage workflow for Azure DevOps work items with field classification, iteration assignment, and duplicate detection |
| **ado/ado-create-pull-request** | Required protocol for creating Azure DevOps pull requests with work item discovery, reviewer identification, and automated linking. |
| **ado/ado-get-build-info** | Required instructions for anything related to Azure Devops or ado build information including status, logs, or details from provided pullrequest (PR), build Id, or branch name. |
| **ado/ado-interaction-templates** | Work item description and comment templates for consistent Azure DevOps content formatting |
| **ado/ado-update-wit-items** | Work item creation and update protocol using MCP ADO tools with handoff tracking |
| **ado/ado-wit-discovery** | Protocol for discovering Azure DevOps work items via user assignment or artifact analysis with planning file output |
| **ado/ado-wit-planning** | Reference specification for Azure DevOps work item planning files, templates, field definitions, and search protocols |
| **shared/hve-core-location** | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

### Skills

| Name | Description |
|------|-------------|
| **pr-reference** | Generates PR reference XML containing commit history and unified diffs between branches with extension and path filtering. Includes utilities to list changed files by type and read diff chunks. Use when creating pull request descriptions, preparing code reviews, analyzing branch changes, discovering work items from diffs, or generating structured diff summaries. |

<!-- END AUTO-GENERATED ARTIFACTS -->
