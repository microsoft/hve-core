<!-- markdownlint-disable-file -->
# Coding Standards

Language-specific coding instructions and pre-PR code review agents for bash, Bicep, C#, PowerShell, Python, Rust, and Terraform projects

## Overview

Enforce language-specific coding conventions and best practices across your projects, with pre-PR code review agents for catching functional defects early. This collection provides instructions for bash, Bicep, C#, PowerShell, Python, Rust, and Terraform that are automatically applied based on file patterns, plus agents that review branch diffs before opening pull requests.

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Chat Agents

| Name                       | Description                                                                                          |
|----------------------------|------------------------------------------------------------------------------------------------------|
| **code-review-functional** | Pre-PR branch diff reviewer for functional correctness, error handling, edge cases, and testing gaps |

### Prompts

| Name                       | Description                                                                                        |
|----------------------------|----------------------------------------------------------------------------------------------------|
| **code-review-functional** | Pre-PR branch diff review for functional correctness, error handling, edge cases, and testing gaps |

### Instructions

| Name                                       | Description                                                                                                                                                                                                                                                 |
|--------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **coding-standards/bash/bash**             | Instructions for bash script implementation                                                                                                                                                                                                                 |
| **coding-standards/bicep/bicep**           | Instructions for Bicep infrastructure as code implementation                                                                                                                                                                                                |
| **coding-standards/csharp/csharp**         | Required instructions for C# (CSharp) research, planning, implementation, editing, or creating                                                                                                                                                              |
| **coding-standards/csharp/csharp-tests**   | Required instructions for C# (CSharp) test code research, planning, implementation, editing, or creating                                                                                                                                                    |
| **coding-standards/powershell/pester**     | Instructions for Pester testing conventions                                                                                                                                                                                                                 |
| **coding-standards/powershell/powershell** | Instructions for PowerShell scripting implementation                                                                                                                                                                                                        |
| **coding-standards/python-script**         | Instructions for Python scripting implementation                                                                                                                                                                                                            |
| **coding-standards/python-tests**          | Required instructions for Python test code research, planning, implementation, editing, or creating                                                                                                                                                         |
| **coding-standards/rust/rust**             | Required instructions for Rust research, planning, implementation, editing, or creating                                                                                                                                                                     |
| **coding-standards/rust/rust-tests**       | Required instructions for Rust test code research, planning, implementation, editing, or creating                                                                                                                                                           |
| **coding-standards/terraform/terraform**   | Instructions for Terraform infrastructure as code implementation                                                                                                                                                                                            |
| **coding-standards/uv-projects**           | Create and manage Python virtual environments using uv commands                                                                                                                                                                                             |
| **shared/hve-core-location**               | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

### Skills

| Name             | Description                                                                                                                                                                                                                                                                                                                                                                  |
|------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **pr-reference** | Generates PR reference XML containing commit history and unified diffs between branches with extension and path filtering. Includes utilities to list changed files by type and read diff chunks. Use when creating pull request descriptions, preparing code reviews, analyzing branch changes, discovering work items from diffs, or generating structured diff summaries. |

<!-- END AUTO-GENERATED ARTIFACTS -->

## Install

```bash
copilot plugin install coding-standards@hve-core
```

## Agents

| Agent                  | Description                                                                                                                                                      |
|------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| code-review-full       | Orchestrator that runs functional and standards code reviews via subagents and produces a merged report - Brought to you by microsoft/hve-core                   |
| code-review-functional | Pre-PR branch diff reviewer for functional correctness, error handling, edge cases, and testing gaps - Brought to you by microsoft/hve-core                      |
| code-review-standards  | Skills-based code reviewer for local changes and PRs - applies project-defined coding standards via dynamic skill loading - Brought to you by microsoft/hve-core |

## Commands

| Command                | Description                                                                                                                               |
|------------------------|-------------------------------------------------------------------------------------------------------------------------------------------|
| code-review-functional | Pre-PR branch diff review for functional correctness, error handling, edge cases, and testing gaps - Brought to you by microsoft/hve-core |
| code-review-full       | Run both functional and standards code reviews on the current branch in a single pass - Brought to you by microsoft/hve-core              |

## Instructions

| Instruction                    | Description                                                                                                                                                                                                                                                 |
|--------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| diff-computation.instructions  | Shared diff computation protocol for code review agents - branch detection, scope locking, large diff handling, and non-source artifact filtering - Brought to you by microsoft/hve-core                                                                    |
| review-artifacts.instructions  | Shared review artifact persistence protocol for code review agents - folder structure, metadata schema, verdict normalization, and writing rules - Brought to you by microsoft/hve-core                                                                     |
| bash.instructions              | Instructions for bash script implementation - Brought to you by microsoft/hve-core                                                                                                                                                                          |
| bicep.instructions             | Instructions for Bicep infrastructure as code implementation - Brought to you by microsoft/hve-core                                                                                                                                                         |
| csharp.instructions            | Required instructions for C# (CSharp) research, planning, implementation, editing, or creating - Brought to you by microsoft/hve-core                                                                                                                       |
| csharp-tests.instructions      | Required instructions for C# (CSharp) test code research, planning, implementation, editing, or creating - Brought to you by microsoft/hve-core                                                                                                             |
| pester.instructions            | Instructions for Pester testing conventions - Brought to you by microsoft/hve-core                                                                                                                                                                          |
| powershell.instructions        | Instructions for PowerShell scripting implementation - Brought to you by microsoft/hve-core                                                                                                                                                                 |
| rust.instructions              | Required instructions for Rust research, planning, implementation, editing, or creating - Brought to you by microsoft/hve-core                                                                                                                              |
| rust-tests.instructions        | Required instructions for Rust test code research, planning, implementation, editing, or creating - Brought to you by microsoft/hve-core                                                                                                                    |
| python-script.instructions     | Instructions for Python scripting implementation - Brought to you by microsoft/hve-core                                                                                                                                                                     |
| python-tests.instructions      | Required instructions for Python test code research, planning, implementation, editing, or creating - Brought to you by microsoft/hve-core                                                                                                                  |
| terraform.instructions         | Instructions for Terraform infrastructure as code implementation - Brought to you by microsoft/hve-core                                                                                                                                                     |
| uv-projects.instructions       | Create and manage Python virtual environments using uv commands                                                                                                                                                                                             |
| hve-core-location.instructions | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

## Skills

| Skill               | Description                                                                                                                                                                                                                                                                                                                                                                                                         |
|---------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| python-foundational | Foundational Python best practices, idioms, and code quality fundamentals - Brought to you by microsoft/hve-core                                                                                                                                                                                                                                                                                                    |
| pr-reference        | Generates PR reference XML containing commit history and unified diffs between branches with extension and path filtering. Includes utilities to list changed files by type and read diff chunks. Use when creating pull request descriptions, preparing code reviews, analyzing branch changes, discovering work items from diffs, or generating structured diff summaries. - Brought to you by microsoft/hve-core |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

