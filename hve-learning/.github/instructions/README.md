---
title: GitHub Copilot Instructions
description: Context-specific development instructions for systematic AI-assisted implementation
author: HVE Essentials Team
ms.date: 2025-01-11
ms.topic: reference
estimated_reading_time: 3
keywords:
  - github copilot
  - instructions
  - development standards
  - ai assistance
  - context-specific guidance
---

This directory contains context-specific instruction files designed to be used with GitHub Copilot's "Add Context > Instructions" feature for systematic AI-assisted development.

## Overview

Instructions provide focused guidance for specific development contexts, technologies, and workflows. They are applied directly to Copilot conversations to ensure consistent adherence to project standards and best practices.

## Available Instructions

### Azure DevOps Integration

#### [ADO Create Pull Request Instructions](ado-create-pull-request.instructions.md)

Required protocol for creating Azure DevOps pull requests with work item discovery, reviewer identification, and automated linking.

- **Context**: Pull request creation workflows in Azure DevOps
- **Scope**: PR creation, work item linking, reviewer assignment, automated tracking
- **Apply When**: Creating pull requests in `**/.copilot-tracking/pr/new/**` pattern

#### [ADO Get Build Info Instructions](ado-get-build-info.instructions.md)

Required instructions for retrieving Azure DevOps build information including status, logs, and details.

- **Context**: Azure DevOps pipeline monitoring and troubleshooting
- **Scope**: Build status checks, log retrieval, pipeline analysis
- **Apply When**: Working with `**/.copilot-tracking/pr/*-build-*.md` or investigating build issues

#### [ADO Update Work Items Instructions](ado-update-wit-items.instructions.md)

Required instructions for work item updating and creation leveraging MCP ADO tool calls.

- **Context**: Azure DevOps work item management and updates
- **Scope**: Work item creation, updates, state transitions, field modifications
- **Apply When**: Working with `**/.copilot-tracking/workitems/**/handoff-logs.md`

#### [ADO Work Item Discovery Instructions](ado-wit-discovery.instructions.md)

Required protocol for discovering, planning, and handing off Azure DevOps User Stories and Bugs.

- **Context**: Work item discovery and analysis workflows
- **Scope**: Work item queries, discovery, planning, handoff documentation
- **Apply When**: Working in `**/.copilot-tracking/workitems/discovery/**` pattern

#### [ADO Work Item Planning Instructions](ado-wit-planning.instructions.md)

Required instructions for work item planning and creation or updating leveraging MCP ADO tool calls.

- **Context**: Work item planning and structured task breakdown
- **Scope**: Sprint planning, task creation, dependency mapping, estimation
- **Apply When**: Working with `**/.copilot-tracking/workitems/**` pattern

### Development Workflows

#### [Git Merge Instructions](git-merge.instructions.md)

Required protocol for Git merge, rebase, and rebase --onto workflows with conflict handling and stop controls.

- **Context**: Git branch operations, conflict resolution, history management
- **Scope**: Merge strategies, rebase workflows, conflict resolution, history cleanup
- **Apply When**: Performing git merge, rebase, or complex branch operations

#### [Task Implementation Instructions](task-implementation.instructions.md)

Systematic process for implementing comprehensive task plans and tracking progress.

- **Context**: Task plan execution, implementation tracking
- **Scope**: Plan analysis, progressive implementation, change documentation
- **Apply When**: Following implementation plans from `**/.copilot-tracking/changes/*.md`

### Infrastructure as Code

#### [Bicep Instructions](bicep.instructions.md)

Infrastructure as Code implementation guidance for Azure Bicep development.

- **Context**: Azure infrastructure deployment, Bicep templates
- **Scope**: Bicep syntax, module organization, deployment patterns
- **Apply When**: Creating or modifying Bicep infrastructure code in `**/*.bicep` files

#### [Terraform Instructions](terraform.instructions.md)

Infrastructure as Code implementation guidance for HashiCorp Terraform development.

- **Context**: Multi-cloud infrastructure deployment, Terraform modules
- **Scope**: Terraform syntax, module design, provider configuration
- **Apply When**: Creating or modifying Terraform infrastructure in `**/*.{tf,hcl,tfvars}` files

#### [Terraform Variable Consistency Manager Instructions](tf-variable-consistency-manager.instructions.md)

Required instructions for Terraform variable consistency including canonical definitions, requirements, and detailed instructions.

- **Context**: Terraform variable validation and standardization
- **Scope**: Variable naming, type definitions, validation rules, documentation
- **Apply When**: Working with `.copilot-tracking/chore/tf-variable-check.md`

### Application Development

#### [Application Instructions](application.instructions.md)

Instructions for creating, importing, and managing edge applications.

- **Context**: Edge application development and deployment
- **Scope**: Application structure, deployment patterns, edge-specific requirements
- **Apply When**: Working in `**/src/500-application/**` pattern

#### [C# Instructions](csharp.instructions.md)

Development standards and practices for C# code implementation.

- **Context**: C# application development, .NET projects
- **Scope**: Code structure, naming conventions, best practices
- **Apply When**: Writing C# code in `**/*.cs` files

### Scripting and Automation

#### [Bash Instructions](bash.instructions.md)

Comprehensive guidance for bash script development and shell command execution.

- **Context**: Shell scripting, automation scripts, CI/CD workflows
- **Scope**: Bash syntax standards, error handling, script structure
- **Apply When**: Writing bash scripts in `**/src/**/*.sh` pattern

#### [Python Script Instructions](python-script.instructions.md)

Enhanced guidance for Python script development specifically targeting utility scripts.

- **Context**: Python automation scripts, build system utilities, deployment tools
- **Scope**: PEP 8 compliance, error handling, testing, documentation
- **Apply When**: Working with Python scripts in `**/scripts/**/*.py` pattern

#### [Shell Instructions](shell.instructions.md)

General shell environment and command-line interface guidance.

- **Context**: Shell operations, command-line tools, system interaction
- **Scope**: Shell usage patterns, command structure, environment setup
- **Apply When**: Working with shell files in `**/*.sh` pattern

### Documentation

#### [Commit Message Instructions](commit-message.instructions.md)

Standardized commit message formatting using Conventional Commit patterns.

- **Context**: Git commit message creation
- **Scope**: Message format, types, scopes, standardization
- **Apply When**: Creating commit messages in `**/` pattern

#### [Markdown Instructions](markdown.instructions.md)

Required instructions for creating or editing any Markdown files.

- **Context**: Documentation, README files, markdown content
- **Scope**: Markdown syntax, formatting standards, frontmatter, structure
- **Apply When**: Creating or editing `**/*.md` files

## Usage Guidelines

### Automatic Application

Instructions are automatically discovered and applied by GitHub Copilot based on file patterns and contexts defined in each instruction file's frontmatter or metadata. The system uses pattern matching to determine which instructions are relevant:

- **File Patterns**: Instructions apply to specific file glob patterns (e.g., `**/*.tf`, `**/*.md`)
- **Directory Contexts**: Instructions apply to specific directory structures (e.g., `.copilot-tracking/workitems/**`)
- **Workflow Contexts**: Instructions apply during specific operations (e.g., pull request creation, work item planning)

### Manual Application

To manually add instructions to a Copilot conversation:

1. Open GitHub Copilot Chat
2. Select **Add Context > Instructions**
3. Choose the relevant instruction file for your development context
4. Add additional context (files, folders) as needed
5. Provide your development prompt

### When to Manually Apply Instructions

While instructions are automatically applied, you may want to manually add them when:

- Working across multiple technology contexts simultaneously
- Ensuring compliance with specific workflows or protocols
- Providing explicit context for complex multi-step operations
- Overriding or emphasizing specific standards

### Pattern Matching Examples

The instruction system uses sophisticated pattern matching to automatically apply relevant guidance:

| Working On                                             | Auto-Applied Instructions                                 |
|--------------------------------------------------------|-----------------------------------------------------------|
| `src/000-cloud/010-security/terraform/main.tf`         | `terraform.instructions.md`                               |
| `blueprints/full-single-node-cluster/bicep/main.bicep` | `bicep.instructions.md`                                   |
| `scripts/deploy-infrastructure.py`                     | `python-script.instructions.md`                           |
| `.copilot-tracking/pr/new/feature-123.md`              | `ado-create-pull-request.instructions.md`                 |
| `src/500-application/501-rust-telemetry/README.md`     | `markdown.instructions.md`, `application.instructions.md` |

### Best Practices

- **Context Awareness**: Trust the automatic pattern matching to apply relevant instructions
- **Focused Work**: Instructions are designed to work together; multiple instructions may apply simultaneously
- **Progressive Application**: Task implementation and planning instructions guide multi-step workflows
- **Validation**: Instructions include validation steps and checklists to ensure compliance

## Related Resources

- **[Chat Modes](../chatmodes/README.md)**: Specialized AI coaching and workflow assistance
- **[Prompts](../prompts/README.md)**: Reusable prompts for specific development tasks
- **[AI-Assisted Engineering Guide](../../docs/contributing/ai-assisted-engineering.md)**: Comprehensive AI assistance documentation

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
