<!-- markdownlint-disable-file -->
# Azure DevOps Integration

Azure DevOps work item management, build monitoring, and pull request creation

## Install

```bash
copilot plugin install ado@hve-core
```

## Agents

| Agent            | Description                                                                                                                                                       |
|------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ado-prd-to-wit   | Product Manager expert for analyzing PRDs and planning Azure DevOps work item hierarchies                                                                         |
| rpi-agent        | Autonomous RPI orchestrator dispatching task-* agents through Research → Plan → Implement → Review → Discover phases - Brought to you by microsoft/hve-core       |
| task-researcher  | Task research specialist for comprehensive project analysis - Brought to you by microsoft/hve-core                                                                |
| task-planner     | Implementation planner for creating actionable implementation plans - Brought to you by microsoft/hve-core                                                        |
| task-implementor | Executes implementation plans from .copilot-tracking/plans with progressive tracking and change records                                                           |
| task-reviewer    | Reviews completed implementation work for accuracy, completeness, and convention compliance - Brought to you by microsoft/hve-core                                |
| memory           | Conversation memory persistence for session continuity - Brought to you by microsoft/hve-core                                                                     |
| prompt-builder   | Prompt engineering assistant with phase-based workflow for creating and validating prompts, agents, and instructions files - Brought to you by microsoft/hve-core |

## Commands

| Command                                     | Description                                                                                                                                 |
|---------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------|
| ado-create-pull-request                     | Generate pull request description, discover related work items, identify reviewers, and create Azure DevOps pull request with all linkages. |
| ado-get-build-info                          | Retrieve Azure DevOps build information for a Pull Request or specific Build Number.                                                        |
| ado-get-my-work-items                       | Retrieve user's current Azure DevOps work items and organize them into planning file definitions                                            |
| ado-process-my-work-items-for-task-planning | Process retrieved work items for task planning and generate task-planning-logs.md handoff file                                              |
| ado-update-wit-items                        | Prompt to update work items based on planning files                                                                                         |
| rpi                                         | Autonomous Research-Plan-Implement-Review-Discover workflow for completing tasks - Brought to you by microsoft/hve-core                     |
| task-research                               | Initiates research for implementation planning based on user requirements - Brought to you by microsoft/hve-core                            |
| task-plan                                   | Initiates implementation planning based on user context or research documents - Brought to you by microsoft/hve-core                        |
| task-implement                              | Locates and executes implementation plans using task-implementor mode - Brought to you by microsoft/hve-core                                |
| task-review                                 | Initiates implementation review based on user context or automatic artifact discovery - Brought to you by microsoft/hve-core                |
| checkpoint                                  | Save or restore conversation context using memory files - Brought to you by microsoft/hve-core                                              |
| prompt-analyze                              | Evaluates prompt engineering artifacts against quality criteria and reports findings - Brought to you by microsoft/hve-core                 |
| prompt-build                                | Build or improve prompt engineering artifacts following quality criteria - Brought to you by microsoft/hve-core                             |
| prompt-refactor                             | Refactors and cleans up prompt engineering artifacts through iterative improvement - Brought to you by microsoft/hve-core                   |

## Instructions

| Instruction             | Description                                                                                                                                                                      |
|-------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| writing-style           | Required writing style conventions for voice, tone, and language in all markdown content                                                                                         |
| markdown                | Required instructions for creating or editing any Markdown (.md) files                                                                                                           |
| commit-message          | Required instructions for creating all commit messages - Brought to you by microsoft/hve-core                                                                                    |
| prompt-builder          | Authoring standards for prompt engineering artifacts including file types, protocol patterns, writing style, and quality criteria - Brought to you by microsoft/hve-core         |
| ado-create-pull-request | Required protocol for creating Azure DevOps pull requests with work item discovery, reviewer identification, and automated linking.                                              |
| ado-get-build-info      | Required instructions for anything related to Azure Devops or ado build information including status, logs, or details from provided pullrequest (PR), build Id, or branch name. |
| ado-update-wit-items    | Work item creation and update protocol using MCP ADO tools with handoff tracking                                                                                                 |
| ado-wit-discovery       | Protocol for discovering Azure DevOps work items via user assignment or artifact analysis with planning file output                                                              |
| ado-wit-planning        | Reference specification for Azure DevOps work item planning files, templates, field definitions, and search protocols                                                            |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

