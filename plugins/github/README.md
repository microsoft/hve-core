<!-- markdownlint-disable-file -->
# GitHub Backlog Management

GitHub issue discovery, triage, sprint planning, and backlog execution agents and prompts

## Install

```bash
copilot plugin install github@hve-core
```

## Agents

| Agent                  | Description                                                                                                                                                       |
|------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| github-backlog-manager | Orchestrator agent for GitHub backlog management workflows including triage, discovery, sprint planning, and execution - Brought to you by microsoft/hve-core     |
| rpi-agent              | Autonomous RPI orchestrator dispatching task-* agents through Research → Plan → Implement → Review → Discover phases - Brought to you by microsoft/hve-core       |
| task-researcher        | Task research specialist for comprehensive project analysis - Brought to you by microsoft/hve-core                                                                |
| task-planner           | Implementation planner for creating actionable implementation plans - Brought to you by microsoft/hve-core                                                        |
| task-implementor       | Executes implementation plans from .copilot-tracking/plans with progressive tracking and change records                                                           |
| task-reviewer          | Reviews completed implementation work for accuracy, completeness, and convention compliance - Brought to you by microsoft/hve-core                                |
| memory                 | Conversation memory persistence for session continuity - Brought to you by microsoft/hve-core                                                                     |
| prompt-builder         | Prompt engineering assistant with phase-based workflow for creating and validating prompts, agents, and instructions files - Brought to you by microsoft/hve-core |

## Commands

| Command                | Description                                                                                                                                      |
|------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| github-add-issue       | Create a GitHub issue using discovered repository templates and conversational field collection                                                  |
| github-discover-issues | Discover GitHub issues through user-centric queries, artifact-driven analysis, or search-based exploration and produce planning files for review |
| github-triage-issues   | Triage GitHub issues not yet triaged with automated label suggestions, milestone assignment, and duplicate detection                             |
| github-execute-backlog | Execute a GitHub backlog plan by creating, updating, linking, closing, and commenting on issues from a handoff file                              |
| github-sprint-plan     | Plan a GitHub milestone sprint by analyzing issue coverage, identifying gaps, and organizing work into a prioritized sprint backlog              |
| rpi                    | Autonomous Research-Plan-Implement-Review-Discover workflow for completing tasks - Brought to you by microsoft/hve-core                          |
| task-research          | Initiates research for implementation planning based on user requirements - Brought to you by microsoft/hve-core                                 |
| task-plan              | Initiates implementation planning based on user context or research documents - Brought to you by microsoft/hve-core                             |
| task-implement         | Locates and executes implementation plans using task-implementor mode - Brought to you by microsoft/hve-core                                     |
| task-review            | Initiates implementation review based on user context or automatic artifact discovery - Brought to you by microsoft/hve-core                     |
| checkpoint             | Save or restore conversation context using memory files - Brought to you by microsoft/hve-core                                                   |
| prompt-analyze         | Evaluates prompt engineering artifacts against quality criteria and reports findings - Brought to you by microsoft/hve-core                      |
| prompt-build           | Build or improve prompt engineering artifacts following quality criteria - Brought to you by microsoft/hve-core                                  |
| prompt-refactor        | Refactors and cleans up prompt engineering artifacts through iterative improvement - Brought to you by microsoft/hve-core                        |

## Instructions

| Instruction              | Description                                                                                                                                                              |
|--------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| writing-style            | Required writing style conventions for voice, tone, and language in all markdown content                                                                                 |
| markdown                 | Required instructions for creating or editing any Markdown (.md) files                                                                                                   |
| commit-message           | Required instructions for creating all commit messages - Brought to you by microsoft/hve-core                                                                            |
| prompt-builder           | Authoring standards for prompt engineering artifacts including file types, protocol patterns, writing style, and quality criteria - Brought to you by microsoft/hve-core |
| github-backlog-discovery | Discovery protocol for GitHub backlog management - artifact-driven, user-centric, and search-based issue discovery                                                       |
| github-backlog-planning  | Reference specification for GitHub backlog management tooling - planning files, search protocols, similarity assessment, and state persistence                           |
| github-backlog-triage    | Triage workflow for GitHub issue backlog management - automated label suggestion, milestone assignment, and duplicate detection                                          |
| github-backlog-update    | Execution workflow for GitHub issue backlog management - consumes planning handoffs and executes issue operations                                                        |
| community-interaction    | Community interaction voice, tone, and response templates for GitHub-facing agents and prompts                                                                           |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

