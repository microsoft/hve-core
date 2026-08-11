---
title: HVE Core
description: Opinionated, rapidly evolving agentic SDLC patterns for RPI workflows, HVE Builder, and Git operations
sidebar_position: 8
author: Microsoft
ms.date: 2026-08-08
ms.topic: reference
---

Choose HVE Core when you want an opinionated working set focused on RPI, HVE Builder, Git, and code review.

It combines lifecycle coordination, prompt-engineering authoring and validation, documentation, Git and pull request workflows, and code review. It also includes the shared telemetry hook.

> [!CAUTION]
> Do not install `hve-core` and `hve-core-all` together. Both include shared content and the telemetry hook, so install one package based on the scope you need.

Stable and PreRelease contain the same active components. Both include components labeled `stable`, `preview`, and `experimental`; components labeled `deprecated` or `removed` are excluded. These lifecycle labels disclose support posture and inform governance. They do not filter channel content, and they are separate from maturity classifications used in Responsible AI assessments.

The channels differ in cadence, version, and source ownership. `main` provides
ref-less development-tip delivery and is not a release registration.
PreRelease follows a reviewed promotion from `main` to `release/prerelease`.
Stable follows a reviewed promotion from `release/prerelease` to
`release/stable`.

The moving consumer registrations are
`microsoft/hve-core#release/prerelease` and
`microsoft/hve-core#release/stable`. For reproducible source selection, use
the immutable exact tags `prerelease-v<version>` and `v<version>`. Release
workflows package the selected exact tag and bind the result to its source SHA,
with SBOM, provenance, and attestation produced where applicable.

These repository release checks do not verify hosted Marketplace behavior or
installed-client behavior.

> [!CAUTION]
> HVE Core is a highly opinionated, rapidly evolving agentic SDLC framework. It is best treated as a source of patterns and learning rather than a stable platform, foundation, or production dependency.
> Workflows, interfaces, architecture, and recommended practices may change substantially, including in ways that are not backward compatible, as the technology landscape evolves. Evaluate all materials for your own requirements and risk tolerance.
> The HVE Builder skill (use with `/hve-builder`) and GitHub Copilot can help you adapt or copy relevant patterns into an agentic SDLC that you own and maintain independently.
> To build an independent implementation, start with [Forking and Extending HVE Core](https://microsoft.github.io/hve-core/docs/customization/forking/) and review the [HVE Core documentation](https://microsoft.github.io/hve-core/) before adopting any component.

## Included Artifacts

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Chat Agents

| Name                          | Maturity     | Description                                                                                                                                                                                                                                                                                                                     |
|-------------------------------|--------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **code-review**               | experimental | Human-gated code review orchestrator that bootstraps change context, scopes hotspots, picks perspectives and depth, and merges skill-backed perspective findings into one report                                                                                                                                                |
| **code-review-accessibility** | experimental | Thin skill-backed perspective subagent that reviews a precomputed diff for accessibility conformance and writes structured findings                                                                                                                                                                                             |
| **code-review-explainer**     | experimental | Thin skill-backed Register 1 explainer subagent that answers factual symbol or function questions and persists an explanation artifact                                                                                                                                                                                          |
| **code-review-functional**    | experimental | Thin skill-backed perspective subagent that reviews a precomputed diff for functional correctness and writes structured findings                                                                                                                                                                                                |
| **code-review-pr**            | experimental | Thin skill-backed orientation detailer that turns a precomputed diff into a factual Register 1 walkthrough plus dispatch-board appendices within the orientation-first review workflow                                                                                                                                          |
| **code-review-readiness**     | experimental | Thin skill-backed perspective subagent that reviews PR deliverable readiness and changed non-code documentation against a precomputed diff and PR context, and writes structured findings                                                                                                                                       |
| **code-review-security**      | experimental | Thin skill-backed perspective subagent that reviews a precomputed diff for security issues and writes structured findings                                                                                                                                                                                                       |
| **code-review-standards**     | experimental | Thin skill-backed perspective subagent that reviews a precomputed diff against project coding standards and writes structured findings                                                                                                                                                                                          |
| **code-review-walkback**      | experimental | Thin wrapper subagent that activates rpi-research for bounded Register 2 investigations and anchors results to a review board item                                                                                                                                                                                              |
| **documentation**             | stable       | Orchestrates documentation audit, drift, authoring, and validation work through the documentation skill                                                                                                                                                                                                                         |
| **hve-artifact-tester**       | stable       | Performs contained literal conformance simulation of an HVE artifact and records simulated, emulated, and observed behavior. Dispatched by hve-builder-tester.                                                                                                                                                                  |
| **rpi-agent**                 | stable       | User-selected RPI workflow wrapper for Research, Plan, Implement, Review, and Follow-up. Use when one task needs lifecycle coordination.                                                                                                                                                                                        |
| **rpi-planner**               | stable       | Revise one assigned RPI plan phase and matching phase details within a shared planning artifact. Use when a parent needs bounded phase authoring.                                                                                                                                                                               |
| **rpi-researcher**            | stable       | Executes one delegated internal, external, or hybrid RPI research lane and progressively writes owned evidence. Use for independent research threads.                                                                                                                                                                           |
| **vally-test-author**         | experimental | Authors Vally conformance test stimuli in two modes: from-artifact (read a prompt, instructions, agent, or skill file and draft a stimulus block) and corpus-import (turn a CSV or XLSX corpus into stimulus blocks), with safety-lint refusal enforcement and SHA-256 dedupe before append-only writes to the routed eval file |

### Prompts

| Name                   | Maturity     | Description                                                                                           |
|------------------------|--------------|-------------------------------------------------------------------------------------------------------|
| **evals-import**       | experimental | Imports a CSV or XLSX corpus into Vally eval suites with safety lint and dedupe                       |
| **git-commit**         | stable       | Stage all changes, generate a conventional commit message, and commit                                 |
| **git-commit-message** | stable       | Generate a conventional commit message from all branch changes                                        |
| **git-merge**          | stable       | Coordinate Git merge, rebase, and rebase --onto workflows with conflict handling                      |
| **git-setup**          | stable       | Interactive, verification-first Git configuration assistant (non-destructive)                         |
| **pr-review**          | experimental | Review a pull request or local change set by routing to the consolidated Code Review agent            |
| **pull-request**       | stable       | Generate pull request descriptions from branch diffs                                                  |
| **rpi**                | stable       | Coordinate one task through the Research, Plan, Implement, Review, and Follow-up RPI workflow         |
| **vally-test-write**   | experimental | Authors Vally conformance test stimuli for an existing prompt, instructions, agent, or skill artifact |

### Instructions

| Name                                              | Maturity     | Description                                                                                                                                                                                                                                                 |
|---------------------------------------------------|--------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **coding-standards/code-review/diff-computation** | experimental | Code review diff computation: branch detection, scope locking, large-diff handling, and non-source filtering                                                                                                                                                |
| **coding-standards/code-review/review-artifacts** | experimental | Code review artifact persistence: folder structure, metadata schema, verdict normalization, and writing rules                                                                                                                                               |
| **experimental/mural/mural-bootstrap**            | experimental | Fresh-session Mural bootstrap requirements for doctor checks, credential backend selection, and safe escalation before Mural tool use.                                                                                                                      |
| **experimental/mural/mural-destinations**         | experimental | Open destination registry for Mural extractor writeback: registered adapters, intent axis, and per-destination loop-closure metrics.                                                                                                                        |
| **experimental/mural/mural-human-record**         | experimental | Mural is the durable record of human conversation; AI never silently authors decisions and AI contribution must remain visible somewhere durable.                                                                                                           |
| **experimental/mural/mural-log-hygiene**          | experimental | Operator log-hygiene contract for Mural customizations: never echo raw URLs, Azure SAS query strings, OAuth tokens, or Authorization headers; the skill _redact() is a defense-in-depth backstop, not a license to log.                                     |
| **experimental/mural/mural-seeding-patterns**     | experimental | Cross-cutting Mural seeding conventions: duplicate-then-populate, source-artifact-to-area binding, anchor inheritance, probe-before-bulk, z-order visibility (detection-only), layout primitives applied across DT, RAI, and UX/UI workflows.               |
| **experimental/mural/mural-writeback-hygiene**    | experimental | Writeback hygiene rules for Mural: tags, hyperlinks, and parentId are the only stable channels; reserved tags are protected; tag manifests are re-applied defensively.                                                                                      |
| **experimental/mural/mural-writing-style**        | experimental | Asymmetric writing style for Mural: outbound (writing into Mural) is sticky-concise; inbound (extracting from Mural) is context-hydrated.                                                                                                                   |
| **hve-core/commit-message**                       | stable       | Commit message format and conventions                                                                                                                                                                                                                       |
| **hve-core/copilot-tracking**                     | stable       | Shared .copilot-tracking conventions for RPI, HVE Builder, and compatibility workflow evidence                                                                                                                                                              |
| **hve-core/git-merge**                            | stable       | Git merge, rebase, and rebase --onto workflows with conflict handling and stop controls                                                                                                                                                                     |
| **hve-core/hve-builder**                          | stable       | Authoring standards for prompts, agents, subagents, instructions, and skills, grounded in the frontier-LLM instruction-quality research                                                                                                                     |
| **hve-core/licensing-posture**                    | stable       | Repository posture for licensing, reproduction, and attribution of third-party standards in skills and tracking artifacts                                                                                                                                   |
| **hve-core/markdown**                             | stable       | Markdown authoring conventions for all .md files                                                                                                                                                                                                            |
| **hve-core/pull-request**                         | stable       | Pull request description generation and creation via diff analysis, subagent review, and MCP tools                                                                                                                                                          |
| **hve-core/writing-style**                        | stable       | Writing style conventions for voice, tone, and language in markdown content                                                                                                                                                                                 |
| **shared/content-policy-citation**                | stable       | Content-policy and terms-of-service guardrails for public output and eval stimuli                                                                                                                                                                           |
| **shared/hve-core-location**                      | stable       | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |
| **shared/telemetry-overlay**                      | stable       | Shared telemetry overlay applying telemetry-foundations vocabulary across planner, ADR, PRD, accessibility, code-review, and implementation artifacts                                                                                                       |

### Skills

| Name                      | Maturity     | Description                                                                                                                                                                                                                                                                                      |
|---------------------------|--------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **code-review**           | experimental | Review code changes from multiple perspectives with context bootstrap, depth-tier rigor, and structured findings output.                                                                                                                                                                         |
| **documentation**         | stable       | Canonical documentation capability for audit, drift, validate, and author modes in hve-core.                                                                                                                                                                                                     |
| **hve-builder**           | stable       | Author, review, or validate Copilot prompt-engineering artifacts through independent review, behavior testing, and host checks.                                                                                                                                                                  |
| **hve-builder-tester**    | stable       | Test HVE artifact behavior with black-box scenarios, contained simulation or approved native execution, independent grading, and evidence reports.                                                                                                                                               |
| **mural**                 | experimental | Mural workspace, room, mural, and widget workflows via the Mural REST API exposed through a Python CLI. Use when you need to read or write Mural content or automate widget creation.                                                                                                            |
| **pr-reference**          | stable       | Generates PR reference XML with commit history and unified diffs between branches, with extension and path filtering. Use when creating pull request descriptions, preparing code reviews, analyzing branch changes, discovering work items from diffs, or generating structured diff summaries. |
| **prompt-analyze**        | stable       | Compatibility alias for read-only prompt artifact review. Routes static and behavior analysis to hve-builder review mode.                                                                                                                                                                        |
| **prompt-builder**        | stable       | Compatibility alias for legacy prompt-building requests. Routes creation and improvement to the hve-builder skill.                                                                                                                                                                               |
| **prompt-refactor**       | stable       | Compatibility alias for behavior-preserving prompt artifact cleanup. Routes refactoring to hve-builder refactor mode.                                                                                                                                                                            |
| **rpi-challenger**        | stable       | Challenge a confirmed task, decision, plan, or artifact through adaptive skeptical questions. Use when you need to expose assumptions before acting.                                                                                                                                             |
| **rpi-implement**         | stable       | Execute an approved RPI plan, maintain current planning state, and record implementation evidence. Use when implementation is ready to begin or resume.                                                                                                                                          |
| **rpi-plan**              | stable       | Create evidence-based RPI plans and phase details from supplied context, research, drafts, and decisions. Use when implementation planning is needed.                                                                                                                                            |
| **rpi-plan-critique**     | stable       | Independently critique an RPI plan and phase details against supplied evidence without editing plan sources. Use when planning credibility needs a read-only assessment.                                                                                                                         |
| **rpi-quick**             | stable       | Sequence Research, Plan, Implement, Review, and Follow-up for an RPI task. Use when one workflow should coordinate the full delivery lifecycle.                                                                                                                                                  |
| **rpi-research**          | stable       | Research-only RPI playbook that gathers task evidence, writes dated research artifacts under .copilot-tracking/research/, and hands off planning-ready findings. Use when the user needs evidence, alternatives, or task framing first.                                                          |
| **rpi-review**            | stable       | Compare RPI planning and implementation evidence, record review findings, and route follow-up work. Use when an implementation needs acceptance review.                                                                                                                                          |
| **rpi-walkthrough**       | stable       | Guided, conversational walkthrough that explains code, UI, UX, features, or .copilot-tracking artifacts with navigable evidence links, deep subagent review, and a reconciled decisions-and-changes ledger. Use when the user wants to understand how something works or why it was changed.     |
| **telemetry-foundations** | stable       | Declarative OpenTelemetry-aligned telemetry vocabulary and instrumentation conventions for traces, metrics, logs, and PII handling                                                                                                                                                               |
| **vally-tests**           | experimental | Authors Vally conformance tests for prompts, instructions, agents, and skills, including refusals for jailbreak, prompt-injection, harmful-elicitation, TOS, CoC, and PII-extraction stimuli                                                                                                     |

### Hooks

| Name          | Maturity     | Description                                                                |
|---------------|--------------|----------------------------------------------------------------------------|
| **telemetry** | experimental | Records Copilot session lifecycle events to local telemetry for reporting. |

<!-- END AUTO-GENERATED ARTIFACTS -->

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
