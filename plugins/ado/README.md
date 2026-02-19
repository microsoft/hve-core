<!-- markdownlint-disable-file -->
# Azure DevOps Integration

Azure DevOps work item management, build monitoring, and pull request creation

## Install

```bash
copilot plugin install ado@hve-core
```

## Agents

| Agent          | Description                                                                               |
|----------------|-------------------------------------------------------------------------------------------|
| ado-prd-to-wit | Product Manager expert for analyzing PRDs and planning Azure DevOps work item hierarchies |

## Commands

| Command                                     | Description                                                                                                                                 |
|---------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------|
| ado-create-pull-request                     | Generate pull request description, discover related work items, identify reviewers, and create Azure DevOps pull request with all linkages. |
| ado-get-build-info                          | Retrieve Azure DevOps build information for a Pull Request or specific Build Number.                                                        |
| ado-get-my-work-items                       | Retrieve user's current Azure DevOps work items and organize them into planning file definitions                                            |
| ado-process-my-work-items-for-task-planning | Process retrieved work items for task planning and generate task-planning-logs.md handoff file                                              |
| ado-update-wit-items                        | Prompt to update work items based on planning files                                                                                         |

## Instructions

| Instruction             | Description                                                                                                                                                                                                                                                 |
|-------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ado-create-pull-request | Required protocol for creating Azure DevOps pull requests with work item discovery, reviewer identification, and automated linking.                                                                                                                         |
| ado-get-build-info      | Required instructions for anything related to Azure Devops or ado build information including status, logs, or details from provided pullrequest (PR), build Id, or branch name.                                                                            |
| ado-update-wit-items    | Work item creation and update protocol using MCP ADO tools with handoff tracking                                                                                                                                                                            |
| ado-wit-discovery       | Protocol for discovering Azure DevOps work items via user assignment or artifact analysis with planning file output                                                                                                                                         |
| ado-wit-planning        | Reference specification for Azure DevOps work item planning files, templates, field definitions, and search protocols                                                                                                                                       |
| hve-core-location       | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

## Skills

| Skill        | Description  |
|--------------|--------------|
| pr-reference | pr-reference |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

