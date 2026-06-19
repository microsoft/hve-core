# HVE Core Workflow

HVE Core provides the flagship RPI (Research, Plan, Implement, Review) workflow for completing complex tasks through a structured four-phase process. The RPI workflow dispatches specialized agents that collaborate autonomously to deliver well-researched, planned, and validated implementations. This collection also includes Git workflow prompts for commit messages, merge operations, repository setup, and pull request management.

## Included Artifacts

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Chat Agents

| Name                         | Description                                                                                                                              |
|------------------------------|------------------------------------------------------------------------------------------------------------------------------------------|
| **doc-ops**                  | Documentation operations agent for pattern compliance, accuracy verification, and gap detection                                          |
| **implementation-validator** | Validates implementation quality against architectural requirements, design principles, and code standards with severity-graded findings |
| **memory**                   | Conversation memory persistence for session continuity                                                                                   |
| **phase-implementor**        | Executes a single implementation phase from a plan with full codebase access and change tracking                                         |
| **plan-validator**           | Validates implementation plans against research documents with severity-graded findings                                                  |
| **pr-review**                | Pull Request review assistant for code quality, security, and convention compliance                                                      |
| **pr-walkthrough**           | Narrative-driven PR orientation surfacing design forks, implicit bets, and architectural shape for reviewer judgment.                    |
| **prompt-builder**           | Prompt engineering assistant for creating and validating prompts, agents, and instructions                                               |
| **prompt-evaluator**         | Evaluates prompt execution results against Prompt Quality Criteria with severity-graded findings and remediation guidance                |
| **prompt-tester**            | Tests prompt files by following them literally in a sandbox, without interpreting beyond face value                                      |
| **prompt-updater**           | Creates and modifies prompts, instructions, agents, and skills following prompt engineering conventions                                  |
| **researcher-subagent**      | Research subagent using search, read, web-fetch, GitHub repo, and MCP tools                                                              |
| **rpi-agent**                | Autonomous RPI orchestrator running Research → Plan → Implement → Review → Discover phases with specialized subagents                    |
| **rpi-validator**            | Validates a Changes Log against the Implementation Plan, Planning Log, and Research Documents for a specific plan phase                  |
| **task-challenger**          | Adversarial questioning agent that interrogates implementations with What/Why/How questions: no suggestions, no hints, no leading        |
| **task-implementor**         | Executes implementation plans from .copilot-tracking/plans with progressive tracking and change records                                  |
| **task-planner**             | Implementation planner that creates actionable, step-by-step plans                                                                       |
| **task-researcher**          | Task research specialist for comprehensive project analysis                                                                              |
| **task-reviewer**            | Reviews completed implementation work for accuracy, completeness, and convention compliance                                              |

### Prompts

| Name                   | Description                                                                        |
|------------------------|------------------------------------------------------------------------------------|
| **checkpoint**         | Save or restore conversation context using memory files                            |
| **doc-ops-update**     | Run the doc-ops agent for documentation quality assurance and updates              |
| **git-commit**         | Stage all changes, generate a conventional commit message, and commit              |
| **git-commit-message** | Generate a conventional commit message from all branch changes                     |
| **git-merge**          | Coordinate Git merge, rebase, and rebase --onto workflows with conflict handling   |
| **git-setup**          | Interactive, verification-first Git configuration assistant (non-destructive)      |
| **prompt-analyze**     | Evaluate prompt engineering artifacts against quality criteria and report findings |
| **prompt-build**       | Build or improve prompt engineering artifacts following quality criteria           |
| **prompt-refactor**    | Refactor and clean up prompt engineering artifacts through iterative improvement   |
| **pull-request**       | Generate pull request descriptions from branch diffs                               |
| **rpi**                | Autonomous Research-Plan-Implement-Review-Discover workflow for completing tasks   |
| **task-challenge**     | Adversarial What/Why/How interrogation of completed implementation artifacts       |
| **task-implement**     | Locate and execute implementation plans using Task Implementor                     |
| **task-plan**          | Initiate implementation planning from user context or research documents           |
| **task-research**      | Initiate research for implementation planning from user requirements               |
| **task-review**        | Initiate implementation review from user context or artifact discovery             |

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
| **hve-core/commit-message**                    | Commit message format and conventions                                                                                                                                                                                                                       |
| **hve-core/git-merge**                         | Git merge, rebase, and rebase --onto workflows with conflict handling and stop controls                                                                                                                                                                     |
| **hve-core/licensing-posture**                 | Repository posture for licensing, reproduction, and attribution of third-party standards in skills and tracking artifacts                                                                                                                                   |
| **hve-core/markdown**                          | Markdown authoring conventions for all .md files                                                                                                                                                                                                            |
| **hve-core/prompt-builder**                    | Authoring standards for prompts, agents, instructions, and skills                                                                                                                                                                                           |
| **hve-core/pull-request**                      | Pull request description generation and creation via diff analysis, subagent review, and MCP tools                                                                                                                                                          |
| **hve-core/writing-style**                     | Writing style conventions for voice, tone, and language in markdown content                                                                                                                                                                                 |
| **shared/hve-core-location**                   | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |
| **shared/telemetry-overlay**                   | Shared telemetry overlay applying telemetry-foundations vocabulary across planner, ADR, PRD, accessibility, code-review, and implementation artifacts                                                                                                       |

### Skills

| Name                      | Description                                                                                                                                                                                                                                                                                      |
|---------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **mural**                 | Mural workspace, room, mural, and widget workflows via the Mural REST API exposed through a Python CLI. Use when you need to read or write Mural content or automate widget creation.                                                                                                            |
| **pr-reference**          | Generates PR reference XML with commit history and unified diffs between branches, with extension and path filtering. Use when creating pull request descriptions, preparing code reviews, analyzing branch changes, discovering work items from diffs, or generating structured diff summaries. |
| **telemetry-foundations** | Declarative OpenTelemetry-aligned telemetry vocabulary and instrumentation conventions for traces, metrics, logs, and PII handling                                                                                                                                                               |
| **vally-tests**           | Authors Vally conformance tests for prompts, instructions, agents, and skills, including refusals for jailbreak, prompt-injection, harmful-elicitation, TOS, CoC, and PII-extraction stimuli                                                                                                     |

<!-- END AUTO-GENERATED ARTIFACTS -->
