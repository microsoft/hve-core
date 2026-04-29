HVE Core provides the flagship RPI (Research, Plan, Implement, Review) workflow for completing complex tasks through a structured four-phase process. The RPI workflow dispatches specialized agents that collaborate autonomously to deliver well-researched, planned, and validated implementations. This collection also includes Git workflow prompts for commit messages, merge operations, repository setup, and pull request management.

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

| Name                                | Description                                                                                                                                                                                                                                                 |
|-------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **hve-core/commit-message**         | Required instructions for creating all commit messages                                                                                                                                                                                                      |
| **hve-core/git-merge**              | Required protocol for Git merge, rebase, and rebase --onto workflows with conflict handling and stop controls.                                                                                                                                              |
| **hve-core/markdown**               | Required instructions for creating or editing any Markdown (.md) files                                                                                                                                                                                      |
| **hve-core/prompt-builder**         | Authoring standards for prompt engineering artifacts including prompts, agents, instructions, and skills                                                                                                                                                    |
| **hve-core/pull-request**           | Required instructions for pull request description generation and optional PR creation using diff analysis, subagent review, and MCP tools                                                                                                                  |
| **hve-core/rpi-context-discipline** | Shared context-discipline rules for RPI parent agents — lean post-work turns, response mode selection, and subagent result handling                                                                                                                         |
| **hve-core/writing-style**          | Required writing style conventions for voice, tone, and language in all markdown content                                                                                                                                                                    |
| **shared/hve-core-location**        | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

### Skills

| Name             | Description                                                                                                                                                                                                                                                                                                                                                                  |
|------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **pr-reference** | Generates PR reference XML containing commit history and unified diffs between branches with extension and path filtering. Includes utilities to list changed files by type and read diff chunks. Use when creating pull request descriptions, preparing code reviews, analyzing branch changes, discovering work items from diffs, or generating structured diff summaries. |

<!-- END AUTO-GENERATED ARTIFACTS -->
