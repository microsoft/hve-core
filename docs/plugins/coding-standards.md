---
title: Coding Standards
description: Language-specific coding instructions and pre-PR code review agents for bash, Bicep, C#, PowerShell, Python, Rust, and Terraform projects
sidebar_position: 2
author: Microsoft
ms.date: 2026-08-03
ms.topic: reference
---

Choose this package for teams that want language-specific engineering guidance and pre-PR review support.

It covers Bash, Bicep, C#, PowerShell, Python, Rust, and Terraform, alongside code review, accessibility review, Python foundations, and shared telemetry guidance.

Lifecycle labels are disclosure metadata. In the channel model, Stable and PreRelease have equal active content, including components labeled stable, preview, and experimental; publication cadence and source ownership can differ.

## Included Artifacts

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Chat Agents

| Name                                 | Maturity     | Description                                                                                                                                                                               |
|--------------------------------------|--------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **accessibility-framework-assessor** | experimental | Assesses accessibility framework scopes through the consolidated Accessibility skill and returns structured findings                                                                      |
| **accessibility-reviewer**           | experimental | Accessibility skill assessment orchestrator for codebase profiling and accessibility findings reporting                                                                                   |
| **accessibility-surface-inventory**  | experimental | Discovers runtime surfaces and interaction states from a codebase profile, then emits an accessibility runtime config for the harness                                                     |
| **code-review**                      | experimental | Human-gated code review orchestrator that bootstraps change context, scopes hotspots, picks perspectives and depth, and merges skill-backed perspective findings into one report          |
| **code-review-accessibility**        | experimental | Thin skill-backed perspective subagent that reviews a precomputed diff for accessibility conformance and writes structured findings                                                       |
| **code-review-explainer**            | experimental | Thin skill-backed Register 1 explainer subagent that answers factual symbol or function questions and persists an explanation artifact                                                    |
| **code-review-functional**           | experimental | Thin skill-backed perspective subagent that reviews a precomputed diff for functional correctness and writes structured findings                                                          |
| **code-review-pr**                   | experimental | Thin skill-backed orientation detailer that turns a precomputed diff into a factual Register 1 walkthrough plus dispatch-board appendices within the orientation-first review workflow    |
| **code-review-readiness**            | experimental | Thin skill-backed perspective subagent that reviews PR deliverable readiness and changed non-code documentation against a precomputed diff and PR context, and writes structured findings |
| **code-review-security**             | experimental | Thin skill-backed perspective subagent that reviews a precomputed diff for security issues and writes structured findings                                                                 |
| **code-review-standards**            | experimental | Thin skill-backed perspective subagent that reviews a precomputed diff against project coding standards and writes structured findings                                                    |
| **code-review-walkback**             | experimental | Thin wrapper subagent that activates rpi-research for bounded Register 2 investigations and anchors results to a review board item                                                        |
| **rpi-researcher**                   | stable       | Executes one delegated internal, external, or hybrid RPI research lane and progressively writes owned evidence. Use for independent research threads.                                     |

### Instructions

| Name                                              | Maturity     | Description                                                                                                                                                                                                                                                 |
|---------------------------------------------------|--------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **coding-standards/bash/bash**                    | stable       | Bash script authoring conventions                                                                                                                                                                                                                           |
| **coding-standards/bicep/bicep**                  | stable       | Bicep infrastructure-as-code authoring conventions                                                                                                                                                                                                          |
| **coding-standards/code-review/diff-computation** | experimental | Code review diff computation: branch detection, scope locking, large-diff handling, and non-source filtering                                                                                                                                                |
| **coding-standards/code-review/review-artifacts** | experimental | Code review artifact persistence: folder structure, metadata schema, verdict normalization, and writing rules                                                                                                                                               |
| **coding-standards/csharp/csharp**                | stable       | C# (CSharp) code authoring conventions                                                                                                                                                                                                                      |
| **coding-standards/csharp/csharp-tests**          | stable       | C# (CSharp) test code authoring conventions                                                                                                                                                                                                                 |
| **coding-standards/powershell/pester**            | stable       | Instructions for Pester testing conventions                                                                                                                                                                                                                 |
| **coding-standards/powershell/powershell**        | stable       | PowerShell scripting conventions                                                                                                                                                                                                                            |
| **coding-standards/python-script**                | stable       | Python scripting conventions                                                                                                                                                                                                                                |
| **coding-standards/python-tests**                 | stable       | Python test code authoring conventions                                                                                                                                                                                                                      |
| **coding-standards/rust/rust**                    | stable       | Rust code authoring conventions                                                                                                                                                                                                                             |
| **coding-standards/rust/rust-tests**              | stable       | Rust test code authoring conventions                                                                                                                                                                                                                        |
| **coding-standards/terraform/terraform**          | stable       | Terraform infrastructure-as-code authoring conventions                                                                                                                                                                                                      |
| **coding-standards/uv-projects**                  | stable       | Create and manage Python virtual environments using uv commands                                                                                                                                                                                             |
| **shared/hve-core-location**                      | stable       | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |
| **shared/telemetry-overlay**                      | stable       | Shared telemetry overlay applying telemetry-foundations vocabulary across planner, ADR, PRD, accessibility, code-review, and implementation artifacts                                                                                                       |

### Skills

| Name                      | Maturity     | Description                                                                                                                                                                                                                                                                                      |
|---------------------------|--------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **code-review**           | experimental | Review code changes from multiple perspectives with context bootstrap, depth-tier rigor, and structured findings output.                                                                                                                                                                         |
| **pr-reference**          | stable       | Generates PR reference XML with commit history and unified diffs between branches, with extension and path filtering. Use when creating pull request descriptions, preparing code reviews, analyzing branch changes, discovering work items from diffs, or generating structured diff summaries. |
| **python-foundational**   | experimental | Foundational Python best practices, idioms, and code quality fundamentals                                                                                                                                                                                                                        |
| **rpi-research**          | stable       | Research-only RPI playbook that gathers task evidence, writes dated research artifacts under .copilot-tracking/research/, and hands off planning-ready findings. Use when the user needs evidence, alternatives, or task framing first.                                                          |
| **telemetry-foundations** | stable       | Declarative OpenTelemetry-aligned telemetry vocabulary and instrumentation conventions for traces, metrics, logs, and PII handling                                                                                                                                                               |

<!-- END AUTO-GENERATED ARTIFACTS -->

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
