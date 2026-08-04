---
title: Azure DevOps
description: Azure DevOps work item management, build monitoring, and pull request creation
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-03
ms.topic: reference
---

Choose this package for teams that manage work items, builds, and pull requests in Azure DevOps.

It combines backlog management and PR planning agents with task prompts, workflow instructions, and RPI and pull request reference support.

Lifecycle labels are disclosure metadata. In the channel model, Stable and PreRelease have equal active content, including components labeled stable, preview, and experimental; publication cadence and source ownership can differ.

## Included Artifacts

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Chat Agents

| Name                    | Maturity | Description                                                                                                                                           |
|-------------------------|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| **ado-backlog-manager** | stable   | Azure DevOps backlog orchestrator for triage, discovery, sprint planning, PRD-to-work-item conversion, and execution                                  |
| **ado-prd-to-wit**      | stable   | Product Manager expert for analyzing PRDs and planning Azure DevOps work item hierarchies                                                             |
| **rpi-planner**         | stable   | Revise one assigned RPI plan phase and matching phase details within a shared planning artifact. Use when a parent needs bounded phase authoring.     |
| **rpi-researcher**      | stable   | Executes one delegated internal, external, or hybrid RPI research lane and progressively writes owned evidence. Use for independent research threads. |

### Prompts

| Name                                            | Maturity | Description                                                                                                       |
|-------------------------------------------------|----------|-------------------------------------------------------------------------------------------------------------------|
| **ado-add-work-item**                           | stable   | Create a single Azure DevOps work item with conversational field collection and parent validation                 |
| **ado-create-pull-request**                     | stable   | Create an Azure DevOps pull request with generated description, linked work items, and reviewers                  |
| **ado-discover-work-items**                     | stable   | Discover Azure DevOps work items via user queries, artifact analysis, or search                                   |
| **ado-get-build-info**                          | stable   | Retrieve Azure DevOps build status and logs for a pull request or build number                                    |
| **ado-get-my-work-items**                       | stable   | Retrieve your assigned Azure DevOps work items into a planning file                                               |
| **ado-process-my-work-items-for-task-planning** | stable   | Process retrieved work items for task planning and generate task-planning-logs.md handoff file                    |
| **ado-sprint-plan**                             | stable   | Plan an Azure DevOps sprint by analyzing iteration coverage, capacity, dependencies, and backlog gaps             |
| **ado-triage-work-items**                       | stable   | Triage untriaged Azure DevOps work items with field classification, iteration assignment, and duplicate detection |
| **ado-update-wit-items**                        | stable   | Update Azure DevOps work items from planning files                                                                |

### Instructions

| Name                              | Maturity | Description                                                                                                                                                                                                                                                 |
|-----------------------------------|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **ado/ado-backlog-sprint**        | stable   | Sprint planning workflow for Azure DevOps iterations with coverage analysis, capacity tracking, and gap detection                                                                                                                                           |
| **ado/ado-backlog-triage**        | stable   | Triage workflow for Azure DevOps work items with field classification, iteration assignment, and duplicate detection                                                                                                                                        |
| **ado/ado-create-pull-request**   | stable   | Azure DevOps pull request creation with work item discovery, reviewer identification, and automated linking                                                                                                                                                 |
| **ado/ado-get-build-info**        | stable   | Azure DevOps build information: status, logs, and details from a PR, build ID, or branch name                                                                                                                                                               |
| **ado/ado-interaction-templates** | stable   | Work item description and comment templates for consistent Azure DevOps content formatting                                                                                                                                                                  |
| **ado/ado-update-wit-items**      | stable   | Work item creation and update protocol using MCP ADO tools with handoff tracking                                                                                                                                                                            |
| **ado/ado-wit-discovery**         | stable   | Azure DevOps work item discovery via user assignment or artifact analysis with planning file output                                                                                                                                                         |
| **ado/ado-wit-planning**          | stable   | Azure DevOps work item planning files, templates, field definitions, and search protocols                                                                                                                                                                   |
| **shared/hve-core-location**      | stable   | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

### Skills

| Name                  | Maturity | Description                                                                                                                                                                                                                                                                                      |
|-----------------------|----------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **pr-reference**      | stable   | Generates PR reference XML with commit history and unified diffs between branches, with extension and path filtering. Use when creating pull request descriptions, preparing code reviews, analyzing branch changes, discovering work items from diffs, or generating structured diff summaries. |
| **rpi-plan**          | stable   | Create evidence-based RPI plans and phase details from supplied context, research, drafts, and decisions. Use when implementation planning is needed.                                                                                                                                            |
| **rpi-plan-critique** | stable   | Independently critique an RPI plan and phase details against supplied evidence without editing plan sources. Use when planning credibility needs a read-only assessment.                                                                                                                         |
| **rpi-research**      | stable   | Research-only RPI playbook that gathers task evidence, writes dated research artifacts under .copilot-tracking/research/, and hands off planning-ready findings. Use when the user needs evidence, alternatives, or task framing first.                                                          |

<!-- END AUTO-GENERATED ARTIFACTS -->

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
