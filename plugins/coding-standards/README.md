<!-- markdownlint-disable-file -->
# Coding Standards

Language-specific coding instructions and pre-PR code review agents for bash, Bicep, C#, PowerShell, Python, Rust, and Terraform projects

## Overview

Enforce language-specific coding conventions and best practices across your projects, with pre-PR code review agents for catching functional defects early. This collection provides instructions for bash, Bicep, C#, PowerShell, Python, Rust, and Terraform that are automatically applied based on file patterns, plus agents that review branch diffs before opening pull requests.

This collection includes:

- **Functional Code Review** — Pre-PR branch diff reviewer for functional correctness, error handling, edge cases, and testing gaps

Instructions for:

- **Bash** — Shell scripting conventions and best practices
- **Bicep** — Infrastructure as code implementation standards
- **C#** — Code and test conventions including nullable reference types, async patterns, and xUnit testing
- **PowerShell** — Script and module conventions including comment-based help, CmdletBinding, PSScriptAnalyzer compliance, and copyright headers
- **Python** — Scripting implementation with type hints, docstrings, and uv project management
- **Rust** — Rust development conventions targeting the 2021 edition
- **Terraform** — Infrastructure as code with provider configuration and module structure

## Install

```bash
copilot plugin install coding-standards@hve-core
```

## Agents

| Agent                  | Description                                                                                                                                 |
|------------------------|---------------------------------------------------------------------------------------------------------------------------------------------|
| functional-code-review | Pre-PR branch diff reviewer for functional correctness, error handling, edge cases, and testing gaps - Brought to you by microsoft/hve-core |

## Commands

| Command                | Description                                                                                                                               |
|------------------------|-------------------------------------------------------------------------------------------------------------------------------------------|
| functional-code-review | Pre-PR branch diff review for functional correctness, error handling, edge cases, and testing gaps - Brought to you by microsoft/hve-core |

## Instructions

| Instruction                    | Description                                                                                                                                                                                                                                                 |
|--------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| bash.instructions              | Instructions for bash script implementation - Brought to you by microsoft/hve-core                                                                                                                                                                          |
| bicep.instructions             | Instructions for Bicep infrastructure as code implementation - Brought to you by microsoft/hve-core                                                                                                                                                         |
| csharp.instructions            | Required instructions for C# (CSharp) research, planning, implementation, editing, or creating - Brought to you by microsoft/hve-core                                                                                                                       |
| csharp-tests.instructions      | Required instructions for C# (CSharp) test code research, planning, implementation, editing, or creating - Brought to you by microsoft/hve-core                                                                                                             |
| pester.instructions            | Instructions for Pester testing conventions - Brought to you by microsoft/hve-core                                                                                                                                                                          |
| powershell.instructions        | Instructions for PowerShell scripting implementation - Brought to you by microsoft/hve-core                                                                                                                                                                 |
| rust.instructions              | Required instructions for Rust research, planning, implementation, editing, or creating - Brought to you by microsoft/hve-core                                                                                                                              |
| rust-tests.instructions        | Required instructions for Rust test code research, planning, implementation, editing, or creating - Brought to you by microsoft/hve-core                                                                                                                    |
| python-script.instructions     | Instructions for Python scripting implementation - Brought to you by microsoft/hve-core                                                                                                                                                                     |
| terraform.instructions         | Instructions for Terraform infrastructure as code implementation - Brought to you by microsoft/hve-core                                                                                                                                                     |
| uv-projects.instructions       | Create and manage Python virtual environments using uv commands                                                                                                                                                                                             |
| hve-core-location.instructions | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

