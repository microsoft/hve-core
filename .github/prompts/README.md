---
title: GitHub Copilot Prompts
description: Coaching and guidance prompts for specific development tasks that provide step-by-step assistance and context-aware support
author: Edge AI Team
ms.date: 08/22/2025
ms.topic: hub-page
estimated_reading_time: 3
keywords:
  - github copilot
  - prompts
  - ai assistance
  - coaching
  - guidance
  - development workflows
---

## GitHub Copilot Prompts

This directory contains **coaching and guidance prompts** designed to provide step-by-step assistance for specific development tasks. Unlike instructions that focus on systematic implementation, prompts offer educational guidance and context-aware coaching to help you learn and apply best practices. Prompts are organized by workflow focus areas: onboarding & planning, source control & commit quality, Azure DevOps integration, development tools, documentation & process, and prompt engineering.

## How to Use Prompts

Prompts can be invoked in GitHub Copilot Chat using `/prompt-name` syntax (e.g., `/getting-started`, `/deploy`). They provide:

- **Educational Guidance**: Step-by-step coaching approach
- **Context-Aware Assistance**: Project-specific guidance and examples
- **Best Practices**: Established patterns and conventions
- **Interactive Support**: Conversational assistance for complex tasks

## Available Prompts

### Onboarding & Planning

- **[Getting Started](./getting-started.prompt.md)** - Project onboarding and initial setup guidance
- **[Task Planner](./task-planner-plan.prompt.md)** - Creates implementation plans from research documents

### Source Control & Commit Quality

- **[Git Commit (Stage + Commit)](./git-commit.prompt.md)** - Stages all changes and creates a Conventional Commit automatically
- **[Git Commit Message Generator](./git-commit-message.prompt.md)** - Generates a compliant commit message for currently staged changes
- **[Git Merge](./git-merge.prompt.md)** - Git merge, rebase, and rebase --onto workflows with conflict handling
- **[Git Setup](./git-setup.prompt.md)** - Verification-first Git configuration assistant

### Azure DevOps Integration

#### Work Item Management

- **[ADO Work Item Discovery](./ado-wit-discovery.prompt.md)** - Discovers and plans Azure DevOps User Stories and Bugs from research or changes
- **[ADO Get My Work Items](./ado-get-my-work-items.prompt.md)** - Retrieves user's work items and organizes into planning files
- **[ADO Process My Work Items for Task Planning](./ado-process-my-work-items-for-task-planning.prompt.md)** - Processes planning files for task planning with repository context enrichment
- **[Get My Work Items](./get-my-work-items.prompt.md)** - Retrieves ordered @Me Azure DevOps work items and exports raw JSON
- **[Create Work Items Handoff](./create-my-work-items-handoff.prompt.md)** - Generates comprehensive work item handoff markdown with repo context enrichment
- **[ADO Update Work Items](./ado-update-wit-items.prompt.md)** - Updates work items based on planning files

> **Note:** For comprehensive work item task planning, use the two-step workflow: First run `ado-get-my-work-items` to retrieve and organize work items into planning files, then `ado-process-my-work-items-for-task-planning` to enrich with repository context and generate task planning handoffs.

#### Pull Requests & Builds

- **[ADO Create Pull Request](./ado-create-pull-request.prompt.md)** - Creates Azure DevOps PRs with work item discovery and reviewer identification
- **[ADO Get Build Info](./ado-get-build-info.prompt.md)** - Retrieves Azure DevOps build information for PRs or specific builds

### Python & Development Tools

- **[UV Project Manager](./uv-manage.prompt.md)** - Create and manage uv Python projects in workspace

### Documentation & Process

- **[ADR Creation](./adr-create.prompt.md)** - Architecture Decision Record creation guidance *(Migrated to [ADR Creation Chatmode](../chatmodes/adr-creation.chatmode.md) for enhanced capabilities)*
- **[Pull Request](./pull-request.prompt.md)** - PR description and review assistance

### Prompt Engineering

- **[Prompt Creation](./prompt-new.prompt.md)** - Creating new prompt files systematically
- **[Prompt Refactor](./prompt-refactor.prompt.md)** - Optimizing and improving existing prompts

## Prompts vs Instructions vs Chat Modes

- **Prompts** (this directory): Coaching and educational guidance for learning
- **[Instructions](../instructions/README.md)**: Systematic implementation and automation
- **[Chat Modes](../chatmodes/README.md)**: Specialized AI assistance with enhanced capabilities

## Quick Start

1. **New to the project?** Start with [Getting Started](./getting-started.prompt.md)
2. **Creating implementation plans?** Try [Task Planner](./task-planner-plan.prompt.md)
3. **Committing changes?** Use [Git Commit Message Generator](./git-commit-message.prompt.md) or [Git Commit](./git-commit.prompt.md)
4. **Handling merge conflicts?** Use [Git Merge](./git-merge.prompt.md)
5. **Tracking your work?** Run [ADO Get My Work Items](./ado-get-my-work-items.prompt.md) then [ADO Process My Work Items for Task Planning](./ado-process-my-work-items-for-task-planning.prompt.md)
6. **Creating Azure DevOps PRs?** Use [ADO Create Pull Request](./ado-create-pull-request.prompt.md)
7. **Checking build status?** Use [ADO Get Build Info](./ado-get-build-info.prompt.md)
8. **Managing Python projects?** Use [UV Project Manager](./uv-manage.prompt.md)
9. **Creating documentation?** Use [ADR Creation](./adr-create.prompt.md) or [Pull Request](./pull-request.prompt.md)

## Related Resources

- **[Contributing Guide](../../CONTRIBUTING.md)** - Complete guide to contributing to the project
- **[Instructions](../instructions/README.md)** - Comprehensive guidance files for development standards
- **[Chat Modes](../chatmodes/README.md)** - Specialized AI assistance with enhanced capabilities

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
