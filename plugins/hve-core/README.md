<!-- markdownlint-disable-file -->
# HVE Core Workflow

HVE Core RPI (Research, Plan, Implement, Review) workflow with Git commit, merge, setup, and pull request prompts

## Overview

HVE Core provides the flagship RPI (Research, Plan, Implement, Review) workflow for completing complex tasks through a structured four-phase process. The RPI workflow dispatches specialized agents that collaborate autonomously to deliver well-researched, planned, and validated implementations. This collection also includes Git workflow prompts for commit messages, merge operations, repository setup, and pull request management.

## Included Artifacts

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Chat Agents

| Name                         | Description                                                                                                                                                                                     |
|------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **doc-ops**                  | Autonomous documentation operations agent for pattern compliance, accuracy verification, and gap detection                                                                                      |
| **implementation-validator** | Validates implementation quality against architectural requirements, design principles, and code standards with severity-graded findings                                                        |
| **memory**                   | Conversation memory persistence for session continuity                                                                                                                                          |
| **phase-implementor**        | Executes a single implementation phase from a plan with full codebase access and change tracking                                                                                                |
| **plan-validator**           | Validates implementation plans against research documents, updating the Planning Log Discrepancy Log section with severity-graded findings                                                      |
| **pr-review**                | Comprehensive Pull Request review assistant ensuring code quality, security, and convention compliance                                                                                          |
| **prompt-builder**           | Prompt engineering assistant with phase-based workflow for creating and validating prompts, agents, and instructions files                                                                      |
| **prompt-evaluator**         | Evaluates prompt execution results against Prompt Quality Criteria with severity-graded findings and categorized remediation guidance                                                           |
| **prompt-tester**            | Tests prompt files by following them literally in a sandbox environment when creating or improving prompts, instructions, agents, or skills without improving or interpreting beyond face value |
| **prompt-updater**           | Modifies or creates prompts, instructions or rules, agents, skills following prompt engineering conventions and standards based on prompt evaluation and research                               |
| **researcher-subagent**      | Research subagent using search tools, read tools, fetch web page, github repo, and mcp tools                                                                                                    |
| **rpi-agent**                | Autonomous RPI orchestrator running Research → Plan → Implement → Review → Discover phases, using specialized subagents when task difficulty warrants them                                      |
| **rpi-validator**            | Validates a Changes Log against the Implementation Plan, Planning Log, and Research Documents for a specific plan phase                                                                         |
| **task-challenger**          | Adversarial questioning agent that interrogates implementations with What/Why/How questions: no suggestions, no hints, no leading                                                               |
| **task-implementor**         | Executes implementation plans from .copilot-tracking/plans with progressive tracking and change records                                                                                         |
| **task-planner**             | Implementation planner for creating actionable implementation plans                                                                                                                             |
| **task-researcher**          | Task research specialist for comprehensive project analysis                                                                                                                                     |
| **task-reviewer**            | Reviews completed implementation work for accuracy, completeness, and convention compliance                                                                                                     |

### Prompts

| Name                   | Description                                                                                                              |
|------------------------|--------------------------------------------------------------------------------------------------------------------------|
| **checkpoint**         | Save or restore conversation context using memory files                                                                  |
| **doc-ops-update**     | Invoke doc-ops agent for documentation quality assurance and updates                                                     |
| **git-commit**         | Stages all changes, generates a conventional commit message, shows it to the user, and commits using only git add/commit |
| **git-commit-message** | Generates a commit message following the commit-message.instructions.md rules based on all changes in the branch         |
| **git-merge**          | Coordinate Git merge, rebase, and rebase --onto workflows with consistent conflict handling.                             |
| **git-setup**          | Interactive, verification-first Git configuration assistant (non-destructive)                                            |
| **prompt-analyze**     | Evaluates prompt engineering artifacts against quality criteria and reports findings                                     |
| **prompt-build**       | Build or improve prompt engineering artifacts following quality criteria                                                 |
| **prompt-refactor**    | Refactors and cleans up prompt engineering artifacts through iterative improvement                                       |
| **pull-request**       | Generates pull request descriptions from branch diffs                                                                    |
| **rpi**                | Autonomous Research-Plan-Implement-Review-Discover workflow for completing tasks                                         |
| **task-challenge**     | Adversarial What/Why/How interrogation of completed implementation artifacts                                             |
| **task-implement**     | Locates and executes implementation plans using Task Implementor                                                         |
| **task-plan**          | Initiates implementation planning based on user context or research documents                                            |
| **task-research**      | Initiates research for implementation planning based on user requirements                                                |
| **task-review**        | Initiates implementation review based on user context or automatic artifact discovery                                    |

### Instructions

| Name                                           | Description                                                                                                                                                                                                                                                 |
|------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **experimental/mural/mural-bootstrap**         | Fresh-session Mural bootstrap requirements for doctor checks, credential backend selection, and safe escalation before Mural tool use.                                                                                                                      |
| **experimental/mural/mural-destinations**      | Open destination registry for Mural extractor writeback: registered adapters, intent axis, and per-destination loop-closure metrics.                                                                                                                        |
| **experimental/mural/mural-human-record**      | Mural is the durable record of human conversation; AI never silently authors decisions and AI contribution must remain visible somewhere durable.                                                                                                           |
| **experimental/mural/mural-log-hygiene**       | Operator log-hygiene contract for Mural customizations: never echo raw URLs, Azure SAS query strings, OAuth tokens, or Authorization headers; the skill _redact() is a defense-in-depth backstop, not a license to log.                                     |
| **experimental/mural/mural-seeding-patterns**  | Cross-cutting Mural seeding conventions: duplicate-then-populate, source-artifact-to-area binding, anchor inheritance, probe-before-bulk, z-order visibility (detection-only), layout primitives applied across DT, RAI, and UX/UI workflows.               |
| **experimental/mural/mural-writeback-hygiene** | Writeback hygiene rules for Mural: tags, hyperlinks, and parentId are the only stable channels; reserved tags are protected; tag manifests are re-applied defensively.                                                                                      |
| **experimental/mural/mural-writing-style**     | Asymmetric writing style for Mural: outbound (writing into Mural) is sticky-concise; inbound (extracting from Mural) is context-hydrated.                                                                                                                   |
| **hve-core/commit-message**                    | Required instructions for creating all commit messages                                                                                                                                                                                                      |
| **hve-core/git-merge**                         | Required protocol for Git merge, rebase, and rebase --onto workflows with conflict handling and stop controls.                                                                                                                                              |
| **hve-core/markdown**                          | Required instructions for creating or editing any Markdown (.md) files                                                                                                                                                                                      |
| **hve-core/prompt-builder**                    | Authoring standards for prompt engineering artifacts including prompts, agents, instructions, and skills                                                                                                                                                    |
| **hve-core/pull-request**                      | Required instructions for pull request description generation and optional PR creation using diff analysis, subagent review, and MCP tools                                                                                                                  |
| **hve-core/writing-style**                     | Required writing style conventions for voice, tone, and language in all markdown content                                                                                                                                                                    |
| **shared/hve-core-location**                   | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

### Skills

| Name             | Description                                                                                                                                                                                                                                                                                                                                                                  |
|------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **mural**        | Mural workspace, room, mural, and widget workflows via the Mural REST API exposed through a Python CLI. Use when you need to read or write Mural content or automate widget creation.                                                                                                                                                                                        |
| **pr-reference** | Generates PR reference XML containing commit history and unified diffs between branches with extension and path filtering. Includes utilities to list changed files by type and read diff chunks. Use when creating pull request descriptions, preparing code reviews, analyzing branch changes, discovering work items from diffs, or generating structured diff summaries. |

<!-- END AUTO-GENERATED ARTIFACTS -->

## Install

```bash
copilot plugin install hve-core@hve-core
```

## Agents

| Agent                    | Description                                                                                                                                                                                       |
|--------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| rpi-agent                | Autonomous RPI orchestrator running Research → Plan → Implement → Review → Discover phases, using specialized subagents when task difficulty warrants them - Brought to you by microsoft/hve-core |
| task-planner             | Implementation planner for creating actionable implementation plans - Brought to you by microsoft/hve-core                                                                                        |
| memory                   | Conversation memory persistence for session continuity - Brought to you by microsoft/hve-core                                                                                                     |
| doc-ops                  | Autonomous documentation operations agent for pattern compliance, accuracy verification, and gap detection - Brought to you by microsoft/hve-core                                                 |
| prompt-builder           | Prompt engineering assistant with phase-based workflow for creating and validating prompts, agents, and instructions files - Brought to you by microsoft/hve-core                                 |
| task-researcher          | Task research specialist for comprehensive project analysis - Brought to you by microsoft/hve-core                                                                                                |
| task-implementor         | Executes implementation plans from .copilot-tracking/plans with progressive tracking and change records - Brought to you by microsoft/hve-core                                                    |
| task-reviewer            | Reviews completed implementation work for accuracy, completeness, and convention compliance - Brought to you by microsoft/hve-core                                                                |
| task-challenger          | Adversarial questioning agent that interrogates implementations with What/Why/How questions: no suggestions, no hints, no leading - Brought to you by microsoft/hve-core                          |
| pr-review                | Comprehensive Pull Request review assistant ensuring code quality, security, and convention compliance - Brought to you by microsoft/hve-core                                                     |
| rpi-validator            | Validates a Changes Log against the Implementation Plan, Planning Log, and Research Documents for a specific plan phase - Brought to you by microsoft/hve-core                                    |
| implementation-validator | Validates implementation quality against architectural requirements, design principles, and code standards with severity-graded findings - Brought to you by microsoft/hve-core                   |
| plan-validator           | Validates implementation plans against research documents, updating the Planning Log Discrepancy Log section with severity-graded findings - Brought to you by microsoft/hve-core                 |
| phase-implementor        | Executes a single implementation phase from a plan with full codebase access and change tracking - Brought to you by microsoft/hve-core                                                           |
| prompt-evaluator         | Evaluates prompt execution results against Prompt Quality Criteria with severity-graded findings and categorized remediation guidance                                                             |
| prompt-tester            | Tests prompt files by following them literally in a sandbox environment when creating or improving prompts, instructions, agents, or skills without improving or interpreting beyond face value   |
| prompt-updater           | Modifies or creates prompts, instructions or rules, agents, skills following prompt engineering conventions and standards based on prompt evaluation and research                                 |
| researcher-subagent      | Research subagent using search tools, read tools, fetch web page, github repo, and mcp tools                                                                                                      |

## Commands

| Command            | Description                                                                                                                  |
|--------------------|------------------------------------------------------------------------------------------------------------------------------|
| rpi                | Autonomous Research-Plan-Implement-Review-Discover workflow for completing tasks - Brought to you by microsoft/hve-core      |
| task-research      | Initiates research for implementation planning based on user requirements - Brought to you by microsoft/hve-core             |
| task-plan          | Initiates implementation planning based on user context or research documents - Brought to you by microsoft/hve-core         |
| task-implement     | Locates and executes implementation plans using Task Implementor - Brought to you by microsoft/hve-core                      |
| task-review        | Initiates implementation review based on user context or automatic artifact discovery - Brought to you by microsoft/hve-core |
| task-challenge     | Adversarial What/Why/How interrogation of completed implementation artifacts - Brought to you by microsoft/hve-core          |
| checkpoint         | Save or restore conversation context using memory files - Brought to you by microsoft/hve-core                               |
| doc-ops-update     | Invoke doc-ops agent for documentation quality assurance and updates                                                         |
| git-commit-message | Generates a commit message following the commit-message.instructions.md rules based on all changes in the branch             |
| git-commit         | Stages all changes, generates a conventional commit message, shows it to the user, and commits using only git add/commit     |
| git-merge          | Coordinate Git merge, rebase, and rebase --onto workflows with consistent conflict handling.                                 |
| git-setup          | Interactive, verification-first Git configuration assistant (non-destructive)                                                |
| pull-request       | Generates pull request descriptions from branch diffs - Brought to you by microsoft/hve-core                                 |
| prompt-analyze     | Evaluates prompt engineering artifacts against quality criteria and reports findings - Brought to you by microsoft/hve-core  |
| prompt-build       | Build or improve prompt engineering artifacts following quality criteria - Brought to you by microsoft/hve-core              |
| prompt-refactor    | Refactors and cleans up prompt engineering artifacts through iterative improvement - Brought to you by microsoft/hve-core    |

## Instructions

| Instruction                          | Description                                                                                                                                                                                                                                                 |
|--------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| writing-style.instructions           | Required writing style conventions for voice, tone, and language in all markdown content                                                                                                                                                                    |
| markdown.instructions                | Required instructions for creating or editing any Markdown (.md) files                                                                                                                                                                                      |
| commit-message.instructions          | Required instructions for creating all commit messages - Brought to you by microsoft/hve-core                                                                                                                                                               |
| prompt-builder.instructions          | Authoring standards for prompt engineering artifacts including prompts, agents, instructions, and skills                                                                                                                                                    |
| git-merge.instructions               | Required protocol for Git merge, rebase, and rebase --onto workflows with conflict handling and stop controls.                                                                                                                                              |
| pull-request.instructions            | Required instructions for pull request description generation and optional PR creation using diff analysis, subagent review, and MCP tools - Brought to you by microsoft/hve-core                                                                           |
| mural-bootstrap.instructions         | Fresh-session Mural bootstrap requirements for doctor checks, credential backend selection, and safe escalation before Mural tool use.                                                                                                                      |
| mural-destinations.instructions      | Open destination registry for Mural extractor writeback: registered adapters, intent axis, and per-destination loop-closure metrics.                                                                                                                        |
| mural-human-record.instructions      | Mural is the durable record of human conversation; AI never silently authors decisions and AI contribution must remain visible somewhere durable.                                                                                                           |
| mural-log-hygiene.instructions       | Operator log-hygiene contract for Mural customizations: never echo raw URLs, Azure SAS query strings, OAuth tokens, or Authorization headers; the skill _redact() is a defense-in-depth backstop, not a license to log.                                     |
| mural-seeding-patterns.instructions  | Cross-cutting Mural seeding conventions: duplicate-then-populate, source-artifact-to-area binding, anchor inheritance, probe-before-bulk, z-order visibility (detection-only), layout primitives applied across DT, RAI, and UX/UI workflows.               |
| mural-writeback-hygiene.instructions | Writeback hygiene rules for Mural: tags, hyperlinks, and parentId are the only stable channels; reserved tags are protected; tag manifests are re-applied defensively.                                                                                      |
| mural-writing-style.instructions     | Asymmetric writing style for Mural: outbound (writing into Mural) is sticky-concise; inbound (extracting from Mural) is context-hydrated.                                                                                                                   |
| hve-core-location.instructions       | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

## Skills

| Skill        | Description                                                                                                                                                                                                                                                                                                                                                                                                         |
|--------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| pr-reference | Generates PR reference XML containing commit history and unified diffs between branches with extension and path filtering. Includes utilities to list changed files by type and read diff chunks. Use when creating pull request descriptions, preparing code reviews, analyzing branch changes, discovering work items from diffs, or generating structured diff summaries. - Brought to you by microsoft/hve-core |
| mural        | Mural workspace, room, mural, and widget workflows via the Mural REST API exposed through a Python CLI. Use when you need to read or write Mural content or automate widget creation. - Brought to you by microsoft/hve-core                                                                                                                                                                                        |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

