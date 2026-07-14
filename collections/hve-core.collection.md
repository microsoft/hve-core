# HVE Core Workflow

HVE Core provides the flagship RPI (Research, Plan, Implement, Review, Follow-up) workflow for completing complex tasks through an evidence-led lifecycle. The RPI workflow coordinates skills and bounded delegation to deliver researched, planned, implemented, reviewed, and routed outcomes. This collection also includes Git workflow prompts for commit messages, merge operations, repository setup, and pull request management.

## Included Artifacts

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Chat Agents

| Name                          | Description                                                                                                                                                                               |
|-------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **code-review**               | Human-gated code review orchestrator that bootstraps change context, scopes hotspots, picks perspectives and depth, and merges skill-backed perspective findings into one report          |
| **code-review-accessibility** | Thin skill-backed perspective subagent that reviews a precomputed diff for accessibility conformance and writes structured findings                                                       |
| **code-review-explainer**     | Thin skill-backed Register 1 explainer subagent that answers factual symbol or function questions and persists an explanation artifact                                                    |
| **code-review-functional**    | Thin skill-backed perspective subagent that reviews a precomputed diff for functional correctness and writes structured findings                                                          |
| **code-review-pr**            | Thin skill-backed orientation detailer that turns a precomputed diff into a factual Register 1 walkthrough plus dispatch-board appendices within the orientation-first review workflow    |
| **code-review-readiness**     | Thin skill-backed perspective subagent that reviews PR deliverable readiness and changed non-code documentation against a precomputed diff and PR context, and writes structured findings |
| **code-review-security**      | Thin skill-backed perspective subagent that reviews a precomputed diff for security issues and writes structured findings                                                                 |
| **code-review-standards**     | Thin skill-backed perspective subagent that reviews a precomputed diff against project coding standards and writes structured findings                                                    |
| **code-review-walkback**      | Thin wrapper subagent that dispatches deep Register 2 questions to the generic Researcher Subagent and anchors the output to a board item                                                 |
| **documentation**             | Orchestrates documentation audit, drift, authoring, and validation work through the documentation skill                                                                                   |
| **hve-artifact-tester**       | Performs contained literal conformance simulation of an HVE artifact and records simulated, emulated, and observed behavior. Dispatched by hve-builder-tester.                            |
| **memory**                    | Conversation memory persistence for session continuity                                                                                                                                    |
| **prompt-builder**            | Compatibility entry point that routes legacy prompt-build, prompt-refactor, and prompt-analyze requests through the hve-builder lifecycle.                                                |
| **researcher-subagent**       | Research subagent using search, read, web-fetch, GitHub repo, and MCP tools                                                                                                               |
| **rpi-agent**                 | User-selected RPI workflow wrapper for Research, Plan, Implement, Review, and Follow-up. Use when one task needs lifecycle coordination.                                                  |
| **rpi-planner**               | Revise one assigned RPI plan phase and matching phase details within a shared planning artifact. Use when a parent needs bounded phase authoring.                                         |
| **rpi-researcher**            | Executes one delegated internal, external, or hybrid RPI research lane and progressively writes owned evidence. Use for independent research threads.                                     |
| **task-challenger**           | Adversarial questioning agent that interrogates implementations with What/Why/How questions: no suggestions, no hints, no leading                                                         |
| **task-implementor**          | User-selected wrapper for executing an approved RPI plan with evidence-led change and divergence tracking. Use when planned work is ready to implement.                                   |
| **task-planner**              | User-selected wrapper for evidence-based RPI planning and plan critique. Use when a task needs an implementation-ready plan.                                                              |
| **task-researcher**           | Task research specialist for comprehensive project analysis                                                                                                                               |
| **task-reviewer**             | User-selected wrapper for reviewing RPI plan and implementation evidence with explicit outcome routing. Use when implementation acceptance needs assessment.                              |

### Prompts

| Name                   | Description                                                                                       |
|------------------------|---------------------------------------------------------------------------------------------------|
| **checkpoint**         | Save or restore conversation context using memory files                                           |
| **git-commit**         | Stage all changes, generate a conventional commit message, and commit                             |
| **git-commit-message** | Generate a conventional commit message from all branch changes                                    |
| **git-merge**          | Coordinate Git merge, rebase, and rebase --onto workflows with conflict handling                  |
| **git-setup**          | Interactive, verification-first Git configuration assistant (non-destructive)                     |
| **pr-review**          | Review a pull request or local change set by routing to the consolidated Code Review agent        |
| **prompt-analyze**     | Review prompt-engineering artifacts without source edits through HVE Builder review mode          |
| **prompt-build**       | Create or improve prompt-engineering artifacts through the HVE Builder lifecycle                  |
| **prompt-refactor**    | Refactor prompt-engineering artifacts while preserving behavior through HVE Builder refactor mode |
| **pull-request**       | Generate pull request descriptions from branch diffs                                              |
| **rpi**                | Coordinate one task through the Research, Plan, Implement, Review, and Follow-up RPI workflow     |
| **task-challenge**     | Adversarial What/Why/How interrogation of completed implementation artifacts                      |
| **task-implement**     | Execute an approved marker-based RPI plan using Task Implementor                                  |
| **task-plan**          | Initiate evidence-based RPI planning from supplied task context, research, drafts, and decisions  |
| **task-research**      | Initiate research for implementation planning from user requirements                              |
| **task-review**        | Initiate RPI acceptance review from plan, detail, critique, amendment, and change evidence        |

### Instructions

| Name                                              | Description                                                                                                                                                                                                                                                 |
|---------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **coding-standards/code-review/diff-computation** | Code review diff computation: branch detection, scope locking, large-diff handling, and non-source filtering                                                                                                                                                |
| **coding-standards/code-review/review-artifacts** | Code review artifact persistence: folder structure, metadata schema, verdict normalization, and writing rules                                                                                                                                               |
| **experimental/mural/mural-bootstrap**            | Fresh-session Mural bootstrap requirements for doctor checks, credential backend selection, and safe escalation before Mural tool use.                                                                                                                      |
| **experimental/mural/mural-destinations**         | Open destination registry for Mural extractor writeback: registered adapters, intent axis, and per-destination loop-closure metrics.                                                                                                                        |
| **experimental/mural/mural-human-record**         | Mural is the durable record of human conversation; AI never silently authors decisions and AI contribution must remain visible somewhere durable.                                                                                                           |
| **experimental/mural/mural-log-hygiene**          | Operator log-hygiene contract for Mural customizations: never echo raw URLs, Azure SAS query strings, OAuth tokens, or Authorization headers; the skill _redact() is a defense-in-depth backstop, not a license to log.                                     |
| **experimental/mural/mural-seeding-patterns**     | Cross-cutting Mural seeding conventions: duplicate-then-populate, source-artifact-to-area binding, anchor inheritance, probe-before-bulk, z-order visibility (detection-only), layout primitives applied across DT, RAI, and UX/UI workflows.               |
| **experimental/mural/mural-writeback-hygiene**    | Writeback hygiene rules for Mural: tags, hyperlinks, and parentId are the only stable channels; reserved tags are protected; tag manifests are re-applied defensively.                                                                                      |
| **experimental/mural/mural-writing-style**        | Asymmetric writing style for Mural: outbound (writing into Mural) is sticky-concise; inbound (extracting from Mural) is context-hydrated.                                                                                                                   |
| **hve-core/commit-message**                       | Commit message format and conventions                                                                                                                                                                                                                       |
| **hve-core/copilot-tracking**                     | Shared .copilot-tracking conventions for RPI, HVE Builder, and compatibility workflow evidence                                                                                                                                                              |
| **hve-core/git-merge**                            | Git merge, rebase, and rebase --onto workflows with conflict handling and stop controls                                                                                                                                                                     |
| **hve-core/hve-builder**                          | Authoring standards for prompts, agents, subagents, instructions, and skills, grounded in the frontier-LLM instruction-quality research                                                                                                                     |
| **hve-core/licensing-posture**                    | Repository posture for licensing, reproduction, and attribution of third-party standards in skills and tracking artifacts                                                                                                                                   |
| **hve-core/markdown**                             | Markdown authoring conventions for all .md files                                                                                                                                                                                                            |
| **hve-core/prompt-builder**                       | Legacy Prompt Builder instruction alias that points matching AI artifacts to the canonical HVE Builder standard                                                                                                                                             |
| **hve-core/pull-request**                         | Pull request description generation and creation via diff analysis, subagent review, and MCP tools                                                                                                                                                          |
| **hve-core/writing-style**                        | Writing style conventions for voice, tone, and language in markdown content                                                                                                                                                                                 |
| **shared/content-policy-citation**                | Content-policy and terms-of-service guardrails for public output and eval stimuli                                                                                                                                                                           |
| **shared/hve-core-location**                      | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |
| **shared/telemetry-overlay**                      | Shared telemetry overlay applying telemetry-foundations vocabulary across planner, ADR, PRD, accessibility, code-review, and implementation artifacts                                                                                                       |

### Skills

| Name                      | Description                                                                                                                                                                                                                                                                                      |
|---------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **code-review**           | Review code changes from multiple perspectives with context bootstrap, depth-tier rigor, and structured findings output.                                                                                                                                                                         |
| **documentation**         | Canonical documentation capability for audit, drift, validate, and author modes in hve-core.                                                                                                                                                                                                     |
| **hve-builder**           | Author, review, or validate Copilot prompt-engineering artifacts through independent review, behavior testing, and host checks.                                                                                                                                                                  |
| **hve-builder-tester**    | Test HVE artifact behavior with black-box scenarios, contained simulation or approved native execution, independent grading, and evidence reports.                                                                                                                                               |
| **mural**                 | Mural workspace, room, mural, and widget workflows via the Mural REST API exposed through a Python CLI. Use when you need to read or write Mural content or automate widget creation.                                                                                                            |
| **pr-reference**          | Generates PR reference XML with commit history and unified diffs between branches, with extension and path filtering. Use when creating pull request descriptions, preparing code reviews, analyzing branch changes, discovering work items from diffs, or generating structured diff summaries. |
| **prompt-analyze**        | Compatibility alias for read-only prompt artifact review. Routes static and behavior analysis to hve-builder review mode.                                                                                                                                                                        |
| **prompt-builder**        | Compatibility alias for legacy prompt-building requests. Routes creation and improvement to the hve-builder skill.                                                                                                                                                                               |
| **prompt-refactor**       | Compatibility alias for behavior-preserving prompt artifact cleanup. Routes refactoring to hve-builder refactor mode.                                                                                                                                                                            |
| **rpi-implement**         | Execute an approved RPI plan, preserve amendments, and record evidence-led changes. Use when implementation is ready to begin or resume.                                                                                                                                                         |
| **rpi-plan**              | Create evidence-based RPI plans and phase details from supplied context, research, drafts, and decisions. Use when implementation planning is needed.                                                                                                                                            |
| **rpi-plan-critique**     | Independently critique an RPI plan and phase details against supplied evidence without editing plan sources. Use when planning credibility needs a read-only assessment.                                                                                                                         |
| **rpi-quick**             | Sequence Research, Plan, Implement, Review, and Follow-up for an RPI task. Use when one workflow should coordinate the full delivery lifecycle.                                                                                                                                                  |
| **rpi-research**          | Research-only RPI playbook that gathers task evidence, writes dated research artifacts under .copilot-tracking/research/, and hands off planning-ready findings. Use when the user needs evidence, alternatives, or task framing first.                                                          |
| **rpi-review**            | Compare RPI planning and implementation evidence, record review findings, and route follow-up work. Use when an implementation needs acceptance review.                                                                                                                                          |
| **telemetry-foundations** | Declarative OpenTelemetry-aligned telemetry vocabulary and instrumentation conventions for traces, metrics, logs, and PII handling                                                                                                                                                               |

### Hooks

| Name          | Description                                                                |
|---------------|----------------------------------------------------------------------------|
| **telemetry** | Records Copilot session lifecycle events to local telemetry for reporting. |

<!-- END AUTO-GENERATED ARTIFACTS -->
