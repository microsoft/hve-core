<!-- markdownlint-disable-file -->
# GitHub Backlog Management

GitHub issue discovery, triage, sprint planning, and backlog execution agents and prompts

## Overview

Manage GitHub issue backlogs with agents for discovery, triage, sprint planning, and execution. This collection brings structured backlog management workflows directly into VS Code.

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Chat Agents

| Name                       | Description                                                                                                            |
|----------------------------|------------------------------------------------------------------------------------------------------------------------|
| **github-backlog-manager** | Orchestrator agent for GitHub backlog management workflows including triage, discovery, sprint planning, and execution |

### Prompts

| Name                       | Description                                                                                                                                      |
|----------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| **github-add-issue**       | Create a GitHub issue using discovered repository templates and conversational field collection                                                  |
| **github-discover-issues** | Discover GitHub issues through user-centric queries, artifact-driven analysis, or search-based exploration and produce planning files for review |
| **github-execute-backlog** | Execute a GitHub backlog plan by creating, updating, linking, closing, and commenting on issues from a handoff file                              |
| **github-sprint-plan**     | Plan a GitHub milestone sprint by analyzing issue coverage, identifying gaps, and organizing work into a prioritized sprint backlog              |
| **github-suggest**         | Resume GitHub backlog management workflow after session restore                                                                                  |
| **github-triage-issues**   | Triage GitHub issues not yet triaged with automated label suggestions, milestone assignment, and duplicate detection                             |

### Instructions

| Name                                | Description                                                                                                                                                                                                                                                 |
|-------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **github/community-interaction**    | Community interaction voice, tone, and response templates for GitHub-facing agents and prompts                                                                                                                                                              |
| **github/github-backlog-discovery** | Discovery protocol for GitHub backlog management - artifact-driven, user-centric, and search-based issue discovery                                                                                                                                          |
| **github/github-backlog-planning**  | Reference specification for GitHub backlog management tooling - planning files, search protocols, similarity assessment, and state persistence                                                                                                              |
| **github/github-backlog-triage**    | Triage workflow for GitHub issue backlog management - automated label suggestion, milestone assignment, and duplicate detection                                                                                                                             |
| **github/github-backlog-update**    | Execution workflow for GitHub issue backlog management - consumes planning handoffs and executes issue operations                                                                                                                                           |
| **shared/hve-core-location**        | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

### Skills

| Name                 | Description                                                                            |
|----------------------|----------------------------------------------------------------------------------------|
| **gh-code-scanning** | Retrieves and groups GitHub code scanning alerts by rule and severity using the gh CLI |

<!-- END AUTO-GENERATED ARTIFACTS -->

## Install

```bash
copilot plugin install github@hve-core
```

## Agents

| Agent                  | Description                                                                                                                                                   |
|------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------|
| github-backlog-manager | Orchestrator agent for GitHub backlog management workflows including triage, discovery, sprint planning, and execution - Brought to you by microsoft/hve-core |

## Commands

| Command                | Description                                                                                                                                      |
|------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| github-add-issue       | Create a GitHub issue using discovered repository templates and conversational field collection                                                  |
| github-discover-issues | Discover GitHub issues through user-centric queries, artifact-driven analysis, or search-based exploration and produce planning files for review |
| github-triage-issues   | Triage GitHub issues not yet triaged with automated label suggestions, milestone assignment, and duplicate detection                             |
| github-execute-backlog | Execute a GitHub backlog plan by creating, updating, linking, closing, and commenting on issues from a handoff file                              |
| github-sprint-plan     | Plan a GitHub milestone sprint by analyzing issue coverage, identifying gaps, and organizing work into a prioritized sprint backlog              |
| github-suggest         | Resume GitHub backlog management workflow after session restore - Brought to you by microsoft/hve-core                                           |

## Instructions

| Instruction                           | Description                                                                                                                                                                                                                                                 |
|---------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| github-backlog-discovery.instructions | Discovery protocol for GitHub backlog management - artifact-driven, user-centric, and search-based issue discovery                                                                                                                                          |
| github-backlog-planning.instructions  | Reference specification for GitHub backlog management tooling - planning files, search protocols, similarity assessment, and state persistence                                                                                                              |
| github-backlog-triage.instructions    | Triage workflow for GitHub issue backlog management - automated label suggestion, milestone assignment, and duplicate detection                                                                                                                             |
| github-backlog-update.instructions    | Execution workflow for GitHub issue backlog management - consumes planning handoffs and executes issue operations                                                                                                                                           |
| community-interaction.instructions    | Community interaction voice, tone, and response templates for GitHub-facing agents and prompts                                                                                                                                                              |
| hve-core-location.instructions        | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

## Skills

| Skill            | Description                                                                                                                   |
|------------------|-------------------------------------------------------------------------------------------------------------------------------|
| gh-code-scanning | Retrieves and groups GitHub code scanning alerts by rule and severity using the gh CLI - Brought to you by microsoft/hve-core |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

