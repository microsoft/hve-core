---
title: GitHub
description: GitHub issue discovery, triage, sprint planning, and backlog execution agents and prompts
sidebar_position: 6
author: Microsoft
ms.date: 2026-08-03
ms.topic: reference
keywords:
  - package
  - github
  - issues
---

Choose this package for teams that manage issue backlogs, sprint planning, and issue operations in GitHub.

It provides a GitHub backlog management agent, prompts for discovery through execution, community interaction guidance, and code-scanning support.

Lifecycle labels are disclosure metadata. In the channel model, Stable and PreRelease have equal active content, including components labeled stable, preview, and experimental; publication cadence and source ownership can differ.

## Included Artifacts

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Chat Agents

| Name                       | Maturity | Description                                                                       |
|----------------------------|----------|-----------------------------------------------------------------------------------|
| **github-backlog-manager** | stable   | GitHub backlog orchestrator for triage, discovery, sprint planning, and execution |

### Prompts

| Name                       | Maturity | Description                                                                                                         |
|----------------------------|----------|---------------------------------------------------------------------------------------------------------------------|
| **github-add-issue**       | stable   | Create a GitHub issue using discovered repository templates and conversational field collection                     |
| **github-discover-issues** | stable   | Discover GitHub issues via user queries, artifact analysis, or search and produce planning files                    |
| **github-execute-backlog** | stable   | Execute a GitHub backlog plan by creating, updating, linking, closing, and commenting on issues from a handoff file |
| **github-sprint-plan**     | stable   | Plan a GitHub milestone sprint by analyzing issue coverage, gaps, and prioritized backlog                           |
| **github-suggest**         | stable   | Resume GitHub backlog management from its durable planning artifacts                                                |
| **github-triage-issues**   | stable   | Triage untriaged GitHub issues with label suggestions, milestone assignment, and duplicate detection                |

### Instructions

| Name                                | Maturity | Description                                                                                                                                                                                                                                                 |
|-------------------------------------|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **github/community-interaction**    | stable   | Community interaction voice, tone, and response templates for GitHub-facing agents and prompts                                                                                                                                                              |
| **github/github-backlog-discovery** | stable   | GitHub issue backlog discovery: artifact-driven, user-centric, search-based                                                                                                                                                                                 |
| **github/github-backlog-planning**  | stable   | GitHub backlog management: planning files, search protocols, similarity assessment, and state persistence                                                                                                                                                   |
| **github/github-backlog-triage**    | stable   | GitHub issue backlog triage: label suggestion, milestone assignment, and duplicate detection                                                                                                                                                                |
| **github/github-backlog-update**    | stable   | GitHub issue backlog execution: consumes planning handoffs and runs issue operations                                                                                                                                                                        |
| **shared/content-policy-citation**  | stable   | Content-policy and terms-of-service guardrails for public output and eval stimuli                                                                                                                                                                           |
| **shared/hve-core-location**        | stable   | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

### Skills

| Name                 | Maturity     | Description                                                                            |
|----------------------|--------------|----------------------------------------------------------------------------------------|
| **gh-code-scanning** | experimental | Retrieves and groups GitHub code scanning alerts by rule and severity using the gh CLI |

<!-- END AUTO-GENERATED ARTIFACTS -->

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
