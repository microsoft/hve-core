<!-- markdownlint-disable-file -->
# RPI Workflow

Research, Plan, Implement, Review workflow agents and prompts for task-driven development

## Install

```bash
copilot plugin install rpi@hve-core
```

## Agents

| Agent            | Description                                                                                                                                                       |
|------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| rpi-agent        | Autonomous RPI orchestrator dispatching task-* agents through Research → Plan → Implement → Review → Discover phases - Brought to you by microsoft/hve-core       |
| task-researcher  | Task research specialist for comprehensive project analysis - Brought to you by microsoft/hve-core                                                                |
| task-planner     | Implementation planner for creating actionable implementation plans - Brought to you by microsoft/hve-core                                                        |
| task-implementor | Executes implementation plans from .copilot-tracking/plans with progressive tracking and change records                                                           |
| task-reviewer    | Reviews completed implementation work for accuracy, completeness, and convention compliance - Brought to you by microsoft/hve-core                                |
| memory           | Conversation memory persistence for session continuity - Brought to you by microsoft/hve-core                                                                     |
| prompt-builder   | Prompt engineering assistant with phase-based workflow for creating and validating prompts, agents, and instructions files - Brought to you by microsoft/hve-core |

## Commands

| Command         | Description                                                                                                                  |
|-----------------|------------------------------------------------------------------------------------------------------------------------------|
| rpi             | Autonomous Research-Plan-Implement-Review-Discover workflow for completing tasks - Brought to you by microsoft/hve-core      |
| task-research   | Initiates research for implementation planning based on user requirements - Brought to you by microsoft/hve-core             |
| task-plan       | Initiates implementation planning based on user context or research documents - Brought to you by microsoft/hve-core         |
| task-implement  | Locates and executes implementation plans using task-implementor mode - Brought to you by microsoft/hve-core                 |
| task-review     | Initiates implementation review based on user context or automatic artifact discovery - Brought to you by microsoft/hve-core |
| checkpoint      | Save or restore conversation context using memory files - Brought to you by microsoft/hve-core                               |
| prompt-analyze  | Evaluates prompt engineering artifacts against quality criteria and reports findings - Brought to you by microsoft/hve-core  |
| prompt-build    | Build or improve prompt engineering artifacts following quality criteria - Brought to you by microsoft/hve-core              |
| prompt-refactor | Refactors and cleans up prompt engineering artifacts through iterative improvement - Brought to you by microsoft/hve-core    |

## Instructions

| Instruction    | Description                                                                                                                                                              |
|----------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| writing-style  | Required writing style conventions for voice, tone, and language in all markdown content                                                                                 |
| markdown       | Required instructions for creating or editing any Markdown (.md) files                                                                                                   |
| commit-message | Required instructions for creating all commit messages - Brought to you by microsoft/hve-core                                                                            |
| prompt-builder | Authoring standards for prompt engineering artifacts including file types, protocol patterns, writing style, and quality criteria - Brought to you by microsoft/hve-core |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

