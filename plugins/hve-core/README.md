<!-- markdownlint-disable-file -->
# HVE Core Workflow

HVE Core RPI (Research, Plan, Implement, Review) workflow with Git commit, merge, setup, and pull request prompts

## Overview

HVE Core provides the flagship RPI (Research, Plan, Implement, Review) workflow for completing complex tasks through a structured four-phase process. The RPI workflow dispatches specialized agents that collaborate autonomously to deliver well-researched, planned, and validated implementations. This collection also includes Git workflow prompts for commit messages, merge operations, repository setup, and pull request management.

This collection includes agents for:

- **RPI Agent** — Autonomous orchestrator that drives the full four-phase workflow
- **Task Researcher** — Gathers context, discovers patterns, and produces research documents
- **Task Planner** — Creates detailed implementation plans from research findings
- **Task Implementor** — Executes plans with progressive tracking and change records
- **Task Reviewer** — Validates implementations against plans and project conventions
- **PR Review** — Comprehensive pull request review ensuring code quality and convention compliance

Git workflow prompts for:

- **Commit Messages** — Generate conventional commit messages following project standards
- **Merge Operations** — Handle merges, rebases, and conflict resolution workflows
- **Repository Setup** — Initialize repositories with recommended configuration
- **Pull Requests** — Create and manage pull requests with linked context

Supporting subagents included:

- **Codebase Researcher** — Searches workspace for code patterns, conventions, and implementations
- **External Researcher** — Retrieves external documentation, SDK references, and code samples
- **Phase Implementor** — Executes single implementation phases with change tracking
- **Artifact Validator** — Validates implementation work against plans and conventions
- **Prompt Tester** — Tests prompt files by following them literally in a sandbox
- **Prompt Evaluator** — Evaluates prompt execution results against quality criteria

Skills included:

- **PR Reference** — Generates PR reference XML files with commit history and diffs for pull request workflows

## Install

```bash
copilot plugin install hve-core@hve-core
```

## Agents

| Agent                          | Description                                                                                                                                                                                       |
|--------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| rpi-agent.agent                | Autonomous RPI orchestrator running Research → Plan → Implement → Review → Discover phases, using specialized subagents when task difficulty warrants them - Brought to you by microsoft/hve-core |
| task-planner.agent             | Implementation planner for creating actionable implementation plans - Brought to you by microsoft/hve-core                                                                                        |
| memory.agent                   | Conversation memory persistence for session continuity - Brought to you by microsoft/hve-core                                                                                                     |
| doc-ops.agent                  | Autonomous documentation operations agent for pattern compliance, accuracy verification, and gap detection - Brought to you by microsoft/hve-core                                                 |
| prompt-builder.agent           | Prompt engineering assistant with phase-based workflow for creating and validating prompts, agents, and instructions files - Brought to you by microsoft/hve-core                                 |
| task-researcher.agent          | Task research specialist for comprehensive project analysis - Brought to you by microsoft/hve-core                                                                                                |
| task-implementor.agent         | Executes implementation plans from .copilot-tracking/plans with progressive tracking and change records - Brought to you by microsoft/hve-core                                                    |
| task-reviewer.agent            | Reviews completed implementation work for accuracy, completeness, and convention compliance - Brought to you by microsoft/hve-core                                                                |
| pr-review.agent                | Comprehensive Pull Request review assistant ensuring code quality, security, and convention compliance - Brought to you by microsoft/hve-core                                                     |
| rpi-validator.agent            | Validates a Changes Log against the Implementation Plan, Planning Log, and Research Documents for a specific plan phase - Brought to you by microsoft/hve-core                                    |
| implementation-validator.agent | Validates implementation quality against architectural requirements, design principles, and code standards with severity-graded findings - Brought to you by microsoft/hve-core                   |
| plan-validator.agent           | Validates implementation plans against research documents, updating the Planning Log Discrepancy Log section with severity-graded findings - Brought to you by microsoft/hve-core                 |
| phase-implementor.agent        | Executes a single implementation phase from a plan with full codebase access and change tracking - Brought to you by microsoft/hve-core                                                           |
| prompt-evaluator.agent         | Evaluates prompt execution results against Prompt Quality Criteria with severity-graded findings and categorized remediation guidance                                                             |
| prompt-tester.agent            | Tests prompt files by following them literally in a sandbox environment when creating or improving prompts, instructions, agents, or skills without improving or interpreting beyond face value   |
| prompt-updater.agent           | Modifies or creates prompts, instructions or rules, agents, skills following prompt engineering conventions and standards based on prompt evaluation and research                                 |
| researcher-subagent.agent      | Research subagent using search tools, read tools, fetch web page, github repo, and mcp tools                                                                                                      |

## Commands

| Command                   | Description                                                                                                                  |
|---------------------------|------------------------------------------------------------------------------------------------------------------------------|
| rpi.prompt                | Autonomous Research-Plan-Implement-Review-Discover workflow for completing tasks - Brought to you by microsoft/hve-core      |
| task-research.prompt      | Initiates research for implementation planning based on user requirements - Brought to you by microsoft/hve-core             |
| task-plan.prompt          | Initiates implementation planning based on user context or research documents - Brought to you by microsoft/hve-core         |
| task-implement.prompt     | Locates and executes implementation plans using Task Implementor - Brought to you by microsoft/hve-core                      |
| task-review.prompt        | Initiates implementation review based on user context or automatic artifact discovery - Brought to you by microsoft/hve-core |
| checkpoint.prompt         | Save or restore conversation context using memory files - Brought to you by microsoft/hve-core                               |
| doc-ops-update.prompt     | Invoke doc-ops agent for documentation quality assurance and updates                                                         |
| git-commit-message.prompt | Generates a commit message following the commit-message.instructions.md rules based on all changes in the branch             |
| git-commit.prompt         | Stages all changes, generates a conventional commit message, shows it to the user, and commits using only git add/commit     |
| git-merge.prompt          | Coordinate Git merge, rebase, and rebase --onto workflows with consistent conflict handling.                                 |
| git-setup.prompt          | Interactive, verification-first Git configuration assistant (non-destructive)                                                |
| pull-request.prompt       | Generates pull request descriptions from branch diffs - Brought to you by microsoft/hve-core                                 |
| prompt-analyze.prompt     | Evaluates prompt engineering artifacts against quality criteria and reports findings - Brought to you by microsoft/hve-core  |
| prompt-build.prompt       | Build or improve prompt engineering artifacts following quality criteria - Brought to you by microsoft/hve-core              |
| prompt-refactor.prompt    | Refactors and cleans up prompt engineering artifacts through iterative improvement - Brought to you by microsoft/hve-core    |

## Instructions

| Instruction                    | Description                                                                                                                                                                                                                                                 |
|--------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| writing-style.instructions     | Required writing style conventions for voice, tone, and language in all markdown content                                                                                                                                                                    |
| markdown.instructions          | Required instructions for creating or editing any Markdown (.md) files                                                                                                                                                                                      |
| commit-message.instructions    | Required instructions for creating all commit messages - Brought to you by microsoft/hve-core                                                                                                                                                               |
| prompt-builder.instructions    | Authoring standards for prompt engineering artifacts including prompts, agents, instructions, and skills                                                                                                                                                    |
| git-merge.instructions         | Required protocol for Git merge, rebase, and rebase --onto workflows with conflict handling and stop controls.                                                                                                                                              |
| pull-request.instructions      | Required instructions for pull request description generation and optional PR creation using diff analysis, subagent review, and MCP tools - Brought to you by microsoft/hve-core                                                                           |
| hve-core-location.instructions | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

## Skills

| Skill        | Description                                                                                                                                                                                                                                                                                                                                                                                                         |
|--------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| pr-reference | Generates PR reference XML containing commit history and unified diffs between branches with extension and path filtering. Includes utilities to list changed files by type and read diff chunks. Use when creating pull request descriptions, preparing code reviews, analyzing branch changes, discovering work items from diffs, or generating structured diff summaries. - Brought to you by microsoft/hve-core |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

