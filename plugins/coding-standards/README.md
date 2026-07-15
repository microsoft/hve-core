<!-- markdownlint-disable-file -->
# Coding Standards

Language-specific coding instructions and pre-PR code review agents for bash, Bicep, C#, PowerShell, Python, Rust, and Terraform projects

## Overview

Enforce language-specific coding conventions and best practices across your projects, with pre-PR code review agents for catching functional defects early. This collection provides instructions for bash, Bicep, C#, PowerShell, Python, Rust, and Terraform that are automatically applied based on file patterns, plus agents that review branch diffs before opening pull requests.

## Included Artifacts

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Chat Agents

| Name                                 | Description                                                                                                                                                                               |
|--------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **accessibility-framework-assessor** | Assesses accessibility framework scopes through the consolidated Accessibility skill and returns structured findings                                                                      |
| **accessibility-reviewer**           | Accessibility skill assessment orchestrator for codebase profiling and accessibility findings reporting                                                                                   |
| **accessibility-surface-inventory**  | Discovers runtime surfaces and interaction states from a codebase profile, then emits an accessibility runtime config for the harness                                                     |
| **code-review**                      | Human-gated code review orchestrator that bootstraps change context, scopes hotspots, picks perspectives and depth, and merges skill-backed perspective findings into one report          |
| **code-review-accessibility**        | Thin skill-backed perspective subagent that reviews a precomputed diff for accessibility conformance and writes structured findings                                                       |
| **code-review-explainer**            | Thin skill-backed Register 1 explainer subagent that answers factual symbol or function questions and persists an explanation artifact                                                    |
| **code-review-functional**           | Thin skill-backed perspective subagent that reviews a precomputed diff for functional correctness and writes structured findings                                                          |
| **code-review-pr**                   | Thin skill-backed orientation detailer that turns a precomputed diff into a factual Register 1 walkthrough plus dispatch-board appendices within the orientation-first review workflow    |
| **code-review-readiness**            | Thin skill-backed perspective subagent that reviews PR deliverable readiness and changed non-code documentation against a precomputed diff and PR context, and writes structured findings |
| **code-review-security**             | Thin skill-backed perspective subagent that reviews a precomputed diff for security issues and writes structured findings                                                                 |
| **code-review-standards**            | Thin skill-backed perspective subagent that reviews a precomputed diff against project coding standards and writes structured findings                                                    |
| **code-review-walkback**             | Thin wrapper subagent that dispatches deep Register 2 questions to the generic Researcher Subagent and anchors the output to a board item                                                 |
| **researcher-subagent**              | Research subagent using search, read, web-fetch, GitHub repo, and MCP tools                                                                                                               |

### Instructions

| Name                                              | Description                                                                                                                                                                                                                                                 |
|---------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **coding-standards/bash/bash**                    | Bash script authoring conventions                                                                                                                                                                                                                           |
| **coding-standards/bicep/bicep**                  | Bicep infrastructure-as-code authoring conventions                                                                                                                                                                                                          |
| **coding-standards/code-review/diff-computation** | Code review diff computation: branch detection, scope locking, large-diff handling, and non-source filtering                                                                                                                                                |
| **coding-standards/code-review/review-artifacts** | Code review artifact persistence: folder structure, metadata schema, verdict normalization, and writing rules                                                                                                                                               |
| **coding-standards/csharp/csharp**                | C# (CSharp) code authoring conventions                                                                                                                                                                                                                      |
| **coding-standards/csharp/csharp-tests**          | C# (CSharp) test code authoring conventions                                                                                                                                                                                                                 |
| **coding-standards/powershell/pester**            | Instructions for Pester testing conventions                                                                                                                                                                                                                 |
| **coding-standards/powershell/powershell**        | PowerShell scripting conventions                                                                                                                                                                                                                            |
| **coding-standards/python-script**                | Python scripting conventions                                                                                                                                                                                                                                |
| **coding-standards/python-tests**                 | Python test code authoring conventions                                                                                                                                                                                                                      |
| **coding-standards/rust/rust**                    | Rust code authoring conventions                                                                                                                                                                                                                             |
| **coding-standards/rust/rust-tests**              | Rust test code authoring conventions                                                                                                                                                                                                                        |
| **coding-standards/terraform/terraform**          | Terraform infrastructure-as-code authoring conventions                                                                                                                                                                                                      |
| **coding-standards/uv-projects**                  | Create and manage Python virtual environments using uv commands                                                                                                                                                                                             |
| **shared/hve-core-location**                      | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |
| **shared/telemetry-overlay**                      | Shared telemetry overlay applying telemetry-foundations vocabulary across planner, ADR, PRD, accessibility, code-review, and implementation artifacts                                                                                                       |

### Skills

| Name                      | Description                                                                                                                                                                                                                                                                                      |
|---------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **code-review**           | Review code changes from multiple perspectives with context bootstrap, depth-tier rigor, and structured findings output.                                                                                                                                                                         |
| **pr-reference**          | Generates PR reference XML with commit history and unified diffs between branches, with extension and path filtering. Use when creating pull request descriptions, preparing code reviews, analyzing branch changes, discovering work items from diffs, or generating structured diff summaries. |
| **python-foundational**   | Foundational Python best practices, idioms, and code quality fundamentals                                                                                                                                                                                                                        |
| **telemetry-foundations** | Declarative OpenTelemetry-aligned telemetry vocabulary and instrumentation conventions for traces, metrics, logs, and PII handling                                                                                                                                                               |

<!-- END AUTO-GENERATED ARTIFACTS -->

## Install

```bash
copilot plugin install coding-standards@hve-core
```

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

