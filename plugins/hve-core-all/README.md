<!-- markdownlint-disable-file -->
# HVE Core All

Full bundle of all stable HVE Core agents, prompts, instructions, and skills

## Install

```bash
copilot plugin install hve-core-all@hve-core
```

## Agents

| Agent                    | Description                                                                                                                                                                                                |
|--------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ado-prd-to-wit           | Product Manager expert for analyzing PRDs and planning Azure DevOps work item hierarchies                                                                                                                  |
| adr-creation             | Interactive AI coaching for collaborative architectural decision record creation with guided discovery, research integration, and progressive documentation building - Brought to you by microsoft/edge-ai |
| agile-coach              | Conversational agent that helps create or refine goal-oriented user stories with clear acceptance criteria for any tracking tool - Brought to you by microsoft/hve-core                                    |
| arch-diagram-builder     | Architecture diagram builder agent that builds high quality ASCII-art diagrams - Brought to you by microsoft/hve-core                                                                                      |
| brd-builder              | Business Requirements Document builder with guided Q&A and reference integration                                                                                                                           |
| doc-ops                  | Autonomous documentation operations agent for pattern compliance, accuracy verification, and gap detection - Brought to you by microsoft/hve-core                                                          |
| gen-data-spec            | Generate comprehensive data dictionaries, machine-readable data profiles, and objective summaries for downstream analysis (EDA notebooks, dashboards) through guided discovery                             |
| gen-jupyter-notebook     | Create structured exploratory data analysis Jupyter notebooks from available data sources and generated data dictionaries                                                                                  |
| gen-streamlit-dashboard  | Develop a multi-page Streamlit dashboard                                                                                                                                                                   |
| github-backlog-manager   | Orchestrator agent for GitHub backlog management workflows including triage, discovery, sprint planning, and execution - Brought to you by microsoft/hve-core                                              |
| github-issue-manager     | Deprecated: replaced by github-backlog-manager.agent.md for GitHub issue and backlog management                                                                                                            |
| hve-core-installer       | Decision-driven installer for HVE-Core with 6 installation methods for local, devcontainer, and Codespaces environments - Brought to you by microsoft/hve-core                                             |
| memory                   | Conversation memory persistence for session continuity - Brought to you by microsoft/hve-core                                                                                                              |
| pr-review                | Comprehensive Pull Request review assistant ensuring code quality, security, and convention compliance - Brought to you by microsoft/hve-core                                                              |
| prd-builder              | Product Requirements Document builder with guided Q&A and reference integration                                                                                                                            |
| prompt-builder           | Prompt engineering assistant with phase-based workflow for creating and validating prompts, agents, and instructions files - Brought to you by microsoft/hve-core                                          |
| rpi-agent                | Autonomous RPI orchestrator running specialized subagents through Research → Plan → Implement → Review → Discover phases - Brought to you by microsoft/hve-core                                            |
| security-plan-creator    | Expert security architect for creating comprehensive cloud security plans - Brought to you by microsoft/hve-core                                                                                           |
| implementation-validator | Validates implementation quality against architectural requirements, design principles, and code standards with severity-graded findings - Brought to you by microsoft/hve-core                            |
| phase-implementor        | Executes a single implementation phase from a plan with full codebase access and change tracking - Brought to you by microsoft/hve-core                                                                    |
| plan-validator           | Validates implementation plans against research documents, updating the Planning Log Discrepancy Log section with severity-graded findings - Brought to you by microsoft/hve-core                          |
| prompt-evaluator         | Evaluates prompt execution results against Prompt Quality Criteria with severity-graded findings and categorized remediation guidance                                                                      |
| prompt-tester            | Tests prompt files by following them literally in a sandbox environment when creating or improving prompts, instructions, agents, or skills without improving or interpreting beyond face value            |
| prompt-updater           | Modifies or creates prompts, instructions or rules, agents, skills following prompt engineering conventions and standards based on prompt evaluation and research                                          |
| researcher-subagent      | Research subagent using search tools, read tools, fetch web page, github repo, and mcp tools                                                                                                               |
| rpi-validator            | Validates a Changes Log against the Implementation Plan, Planning Log, and Research Documents for a specific plan phase - Brought to you by microsoft/hve-core                                             |
| task-implementor         | Executes implementation plans from .copilot-tracking/plans with progressive tracking and change records - Brought to you by microsoft/hve-core                                                             |
| task-planner             | Implementation planner for creating actionable implementation plans - Brought to you by microsoft/hve-core                                                                                                 |
| task-researcher          | Task research specialist for comprehensive project analysis - Brought to you by microsoft/hve-core                                                                                                         |
| task-reviewer            | Reviews completed implementation work for accuracy, completeness, and convention compliance - Brought to you by microsoft/hve-core                                                                         |
| test-streamlit-dashboard | Automated testing for Streamlit dashboards using Playwright with issue tracking and reporting                                                                                                              |

## Commands

| Command                                     | Description                                                                                                                                      |
|---------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| ado-create-pull-request                     | Generate pull request description, discover related work items, identify reviewers, and create Azure DevOps pull request with all linkages.      |
| ado-get-build-info                          | Retrieve Azure DevOps build information for a Pull Request or specific Build Number.                                                             |
| ado-get-my-work-items                       | Retrieve user's current Azure DevOps work items and organize them into planning file definitions                                                 |
| ado-process-my-work-items-for-task-planning | Process retrieved work items for task planning and generate task-planning-logs.md handoff file                                                   |
| ado-update-wit-items                        | Prompt to update work items based on planning files                                                                                              |
| checkpoint                                  | Save or restore conversation context using memory files - Brought to you by microsoft/hve-core                                                   |
| doc-ops-update                              | Invoke doc-ops agent for documentation quality assurance and updates                                                                             |
| git-commit-message                          | Generates a commit message following the commit-message.instructions.md rules based on all changes in the branch                                 |
| git-commit                                  | Stages all changes, generates a conventional commit message, shows it to the user, and commits using only git add/commit                         |
| git-merge                                   | Coordinate Git merge, rebase, and rebase --onto workflows with consistent conflict handling.                                                     |
| git-setup                                   | Interactive, verification-first Git configuration assistant (non-destructive)                                                                    |
| github-add-issue                            | Create a GitHub issue using discovered repository templates and conversational field collection                                                  |
| github-discover-issues                      | Discover GitHub issues through user-centric queries, artifact-driven analysis, or search-based exploration and produce planning files for review |
| github-execute-backlog                      | Execute a GitHub backlog plan by creating, updating, linking, closing, and commenting on issues from a handoff file                              |
| github-sprint-plan                          | Plan a GitHub milestone sprint by analyzing issue coverage, identifying gaps, and organizing work into a prioritized sprint backlog              |
| github-triage-issues                        | Triage GitHub issues not yet triaged with automated label suggestions, milestone assignment, and duplicate detection                             |
| incident-response                           | Incident response workflow for Azure operations scenarios - Brought to you by microsoft/hve-core                                                 |
| prompt-analyze                              | Evaluates prompt engineering artifacts against quality criteria and reports findings - Brought to you by microsoft/hve-core                      |
| prompt-build                                | Build or improve prompt engineering artifacts following quality criteria - Brought to you by microsoft/hve-core                                  |
| prompt-refactor                             | Refactors and cleans up prompt engineering artifacts through iterative improvement - Brought to you by microsoft/hve-core                        |
| pull-request                                | Provides prompt instructions for pull request (PR) generation - Brought to you by microsoft/edge-ai                                              |
| risk-register                               | Creates a concise and well-structured qualitative risk register using a Probability × Impact (P×I) risk matrix.                                  |
| rpi                                         | Autonomous Research-Plan-Implement-Review-Discover workflow for completing tasks - Brought to you by microsoft/hve-core                          |
| task-implement                              | Locates and executes implementation plans using task-implementor - Brought to you by microsoft/hve-core                                          |
| task-plan                                   | Initiates implementation planning based on user context or research documents - Brought to you by microsoft/hve-core                             |
| task-research                               | Initiates research for implementation planning based on user requirements - Brought to you by microsoft/hve-core                                 |
| task-review                                 | Initiates implementation review based on user context or automatic artifact discovery - Brought to you by microsoft/hve-core                     |

## Instructions

| Instruction              | Description                                                                                                                                                                                                                                                 |
|--------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ado-create-pull-request  | Required protocol for creating Azure DevOps pull requests with work item discovery, reviewer identification, and automated linking.                                                                                                                         |
| ado-get-build-info       | Required instructions for anything related to Azure Devops or ado build information including status, logs, or details from provided pullrequest (PR), build Id, or branch name.                                                                            |
| ado-update-wit-items     | Work item creation and update protocol using MCP ADO tools with handoff tracking                                                                                                                                                                            |
| ado-wit-discovery        | Protocol for discovering Azure DevOps work items via user assignment or artifact analysis with planning file output                                                                                                                                         |
| ado-wit-planning         | Reference specification for Azure DevOps work item planning files, templates, field definitions, and search protocols                                                                                                                                       |
| bash                     | Instructions for bash script implementation - Brought to you by microsoft/edge-ai                                                                                                                                                                           |
| bicep                    | Instructions for Bicep infrastructure as code implementation - Brought to you by microsoft/hve-core                                                                                                                                                         |
| commit-message           | Required instructions for creating all commit messages - Brought to you by microsoft/hve-core                                                                                                                                                               |
| community-interaction    | Community interaction voice, tone, and response templates for GitHub-facing agents and prompts                                                                                                                                                              |
| csharp-tests             | Required instructions for C# (CSharp) test code research, planning, implementation, editing, or creating - Brought to you by microsoft/hve-core                                                                                                             |
| csharp                   | Required instructions for C# (CSharp) research, planning, implementation, editing, or creating - Brought to you by microsoft/hve-core                                                                                                                       |
| git-merge                | Required protocol for Git merge, rebase, and rebase --onto workflows with conflict handling and stop controls.                                                                                                                                              |
| github-backlog-discovery | Discovery protocol for GitHub backlog management - artifact-driven, user-centric, and search-based issue discovery                                                                                                                                          |
| github-backlog-planning  | Reference specification for GitHub backlog management tooling - planning files, search protocols, similarity assessment, and state persistence                                                                                                              |
| github-backlog-triage    | Triage workflow for GitHub issue backlog management - automated label suggestion, milestone assignment, and duplicate detection                                                                                                                             |
| github-backlog-update    | Execution workflow for GitHub issue backlog management - consumes planning handoffs and executes issue operations                                                                                                                                           |
| hve-core-location        | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |
| markdown                 | Required instructions for creating or editing any Markdown (.md) files                                                                                                                                                                                      |
| prompt-builder           | Authoring standards for prompt engineering artifacts including prompts, agents, instructions, and skills                                                                                                                                                    |
| python-script            | Instructions for Python scripting implementation - Brought to you by microsoft/hve-core                                                                                                                                                                     |
| terraform                | Instructions for Terraform infrastructure as code implementation - Brought to you by microsoft/hve-core                                                                                                                                                     |
| uv-projects              | Create and manage Python virtual environments using uv commands                                                                                                                                                                                             |
| writing-style            | Required writing style conventions for voice, tone, and language in all markdown content                                                                                                                                                                    |

## Skills

| Skill        | Description  |
|--------------|--------------|
| video-to-gif | video-to-gif |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

