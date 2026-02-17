<!-- markdownlint-disable-file -->
# Data Science

Data specification generation, Jupyter notebooks, and Streamlit dashboards

## Install

```bash
copilot plugin install data-science@hve-core
```

## Agents

| Agent                    | Description                                                                                                                                                                                     |
|--------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| gen-data-spec            | Generate comprehensive data dictionaries, machine-readable data profiles, and objective summaries for downstream analysis (EDA notebooks, dashboards) through guided discovery                  |
| gen-jupyter-notebook     | Create structured exploratory data analysis Jupyter notebooks from available data sources and generated data dictionaries                                                                       |
| gen-streamlit-dashboard  | Develop a multi-page Streamlit dashboard                                                                                                                                                        |
| test-streamlit-dashboard | Automated testing for Streamlit dashboards using Playwright with issue tracking and reporting                                                                                                   |
| rpi-agent                | Autonomous RPI orchestrator running specialized subagents through Research → Plan → Implement → Review → Discover phases - Brought to you by microsoft/hve-core                                 |
| task-researcher          | Task research specialist for comprehensive project analysis - Brought to you by microsoft/hve-core                                                                                              |
| task-planner             | Implementation planner for creating actionable implementation plans - Brought to you by microsoft/hve-core                                                                                      |
| task-implementor         | Executes implementation plans from .copilot-tracking/plans with progressive tracking and change records - Brought to you by microsoft/hve-core                                                  |
| task-reviewer            | Reviews completed implementation work for accuracy, completeness, and convention compliance - Brought to you by microsoft/hve-core                                                              |
| memory                   | Conversation memory persistence for session continuity - Brought to you by microsoft/hve-core                                                                                                   |
| pr-review                | Comprehensive Pull Request review assistant ensuring code quality, security, and convention compliance - Brought to you by microsoft/hve-core                                                   |
| prompt-builder           | Prompt engineering assistant with phase-based workflow for creating and validating prompts, agents, and instructions files - Brought to you by microsoft/hve-core                               |
| rpi-validator            | Validates a Changes Log against the Implementation Plan, Planning Log, and Research Documents for a specific plan phase - Brought to you by microsoft/hve-core                                  |
| implementation-validator | Validates implementation quality against architectural requirements, design principles, and code standards with severity-graded findings - Brought to you by microsoft/hve-core                 |
| plan-validator           | Validates implementation plans against research documents, updating the Planning Log Discrepancy Log section with severity-graded findings - Brought to you by microsoft/hve-core               |
| researcher-subagent      | Research subagent using search tools, read tools, fetch web page, github repo, and mcp tools                                                                                                    |
| phase-implementor        | Executes a single implementation phase from a plan with full codebase access and change tracking - Brought to you by microsoft/hve-core                                                         |
| prompt-evaluator         | Evaluates prompt execution results against Prompt Quality Criteria with severity-graded findings and categorized remediation guidance                                                           |
| prompt-tester            | Tests prompt files by following them literally in a sandbox environment when creating or improving prompts, instructions, agents, or skills without improving or interpreting beyond face value |
| prompt-updater           | Modifies or creates prompts, instructions or rules, agents, skills following prompt engineering conventions and standards based on prompt evaluation and research                               |

## Commands

| Command            | Description                                                                                                                  |
|--------------------|------------------------------------------------------------------------------------------------------------------------------|
| rpi                | Autonomous Research-Plan-Implement-Review-Discover workflow for completing tasks - Brought to you by microsoft/hve-core      |
| task-research      | Initiates research for implementation planning based on user requirements - Brought to you by microsoft/hve-core             |
| task-plan          | Initiates implementation planning based on user context or research documents - Brought to you by microsoft/hve-core         |
| task-implement     | Locates and executes implementation plans using task-implementor - Brought to you by microsoft/hve-core                      |
| task-review        | Initiates implementation review based on user context or automatic artifact discovery - Brought to you by microsoft/hve-core |
| checkpoint         | Save or restore conversation context using memory files - Brought to you by microsoft/hve-core                               |
| git-commit-message | Generates a commit message following the commit-message.instructions.md rules based on all changes in the branch             |
| git-commit         | Stages all changes, generates a conventional commit message, shows it to the user, and commits using only git add/commit     |
| git-merge          | Coordinate Git merge, rebase, and rebase --onto workflows with consistent conflict handling.                                 |
| git-setup          | Interactive, verification-first Git configuration assistant (non-destructive)                                                |
| pull-request       | Provides prompt instructions for pull request (PR) generation - Brought to you by microsoft/edge-ai                          |
| prompt-analyze     | Evaluates prompt engineering artifacts against quality criteria and reports findings - Brought to you by microsoft/hve-core  |
| prompt-build       | Build or improve prompt engineering artifacts following quality criteria - Brought to you by microsoft/hve-core              |
| prompt-refactor    | Refactors and cleans up prompt engineering artifacts through iterative improvement - Brought to you by microsoft/hve-core    |

## Instructions

| Instruction    | Description                                                                                                    |
|----------------|----------------------------------------------------------------------------------------------------------------|
| writing-style  | Required writing style conventions for voice, tone, and language in all markdown content                       |
| markdown       | Required instructions for creating or editing any Markdown (.md) files                                         |
| commit-message | Required instructions for creating all commit messages - Brought to you by microsoft/hve-core                  |
| prompt-builder | Authoring standards for prompt engineering artifacts including prompts, agents, instructions, and skills       |
| git-merge      | Required protocol for Git merge, rebase, and rebase --onto workflows with conflict handling and stop controls. |
| python-script  | Instructions for Python scripting implementation - Brought to you by microsoft/hve-core                        |
| uv-projects    | Create and manage Python virtual environments using uv commands                                                |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

