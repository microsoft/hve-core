<!-- markdownlint-disable-file -->
# GitHub Backlog Management

GitHub issue discovery, triage, sprint planning, and backlog execution agents and prompts

## Overview

Manage GitHub issue backlogs with agents for discovery, triage, sprint planning, and execution. This collection brings structured backlog management workflows directly into VS Code.

## Included Artifacts

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Chat Agents

| Name                       | Description                                                                       |
|----------------------------|-----------------------------------------------------------------------------------|
| **github-backlog-manager** | GitHub backlog orchestrator for triage, discovery, sprint planning, and execution |

### Prompts

| Name                       | Description                                                                                                         |
|----------------------------|---------------------------------------------------------------------------------------------------------------------|
| **github-add-issue**       | Create a GitHub issue using discovered repository templates and conversational field collection                     |
| **github-discover-issues** | Discover GitHub issues via user queries, artifact analysis, or search and produce planning files                    |
| **github-execute-backlog** | Execute a GitHub backlog plan by creating, updating, linking, closing, and commenting on issues from a handoff file |
| **github-sprint-plan**     | Plan a GitHub milestone sprint by analyzing issue coverage, gaps, and prioritized backlog                           |
| **github-suggest**         | Resume GitHub backlog management workflow after session restore                                                     |
| **github-triage-issues**   | Triage untriaged GitHub issues with label suggestions, milestone assignment, and duplicate detection                |

### Instructions

| Name                                | Description                                                                                                                                                                                                                                                 |
|-------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **github/community-interaction**    | Community interaction voice, tone, and response templates for GitHub-facing agents and prompts                                                                                                                                                              |
| **github/github-backlog-discovery** | GitHub issue backlog discovery: artifact-driven, user-centric, search-based                                                                                                                                                                                 |
| **github/github-backlog-planning**  | GitHub backlog management: planning files, search protocols, similarity assessment, and state persistence                                                                                                                                                   |
| **github/github-backlog-triage**    | GitHub issue backlog triage: label suggestion, milestone assignment, and duplicate detection                                                                                                                                                                |
| **github/github-backlog-update**    | GitHub issue backlog execution: consumes planning handoffs and runs issue operations                                                                                                                                                                        |
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

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

