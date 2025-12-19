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

### Source Control & Commit Quality

- **[Git Commit (Stage + Commit)](./git-commit.prompt.md)** - Stages all changes and creates a Conventional Commit automatically
- **[Git Commit Message Generator](./git-commit-message.prompt.md)** - Generates a compliant commit message for currently staged changes
- **[Git Merge](./git-merge.prompt.md)** - Git merge, rebase, and rebase --onto workflows with conflict handling
- **[Git Setup](./git-setup.prompt.md)** - Verification-first Git configuration assistant

### Azure DevOps Integration

#### Work Item Management

- **[ADO Get My Work Items](./ado-get-my-work-items.prompt.md)** - Retrieves user's work items and organizes into planning files
- **[ADO Process My Work Items for Task Planning](./ado-process-my-work-items-for-task-planning.prompt.md)** - Processes planning files for task planning with repository context enrichment

> **Note:** For comprehensive work item task planning, use the two-step workflow: First run `ado-get-my-work-items` to retrieve and organize work items into planning files, then `ado-process-my-work-items-for-task-planning` to enrich with repository context and generate task planning handoffs.

#### Pull Requests & Builds

- **[ADO Create Pull Request](./ado-create-pull-request.prompt.md)** - Creates Azure DevOps PRs with work item discovery and reviewer identification
- **[ADO Get Build Info](./ado-get-build-info.prompt.md)** - Retrieves Azure DevOps build information for PRs or specific builds

### GitHub Integration

- **[GitHub Add Issue](./github-add-issue.prompt.md)** - Create GitHub issues with proper formatting and labels

### Documentation & Process

- **[Pull Request](./pull-request.prompt.md)** - PR description and review assistance

## Prompts vs Instructions vs Chat Modes

- **Prompts** (this directory): Coaching and educational guidance for learning
- **[Instructions](../instructions/README.md)**: Systematic implementation and automation
- **[Chat Modes](../chatmodes/README.md)**: Specialized AI assistance with enhanced capabilities

## Quick Start

1. **Committing changes?** Use [Git Commit Message Generator](./git-commit-message.prompt.md) or [Git Commit](./git-commit.prompt.md)
2. **Handling merge conflicts?** Use [Git Merge](./git-merge.prompt.md)
3. **Setting up Git?** Use [Git Setup](./git-setup.prompt.md)
4. **Tracking your work?** Run [ADO Get My Work Items](./ado-get-my-work-items.prompt.md) then [ADO Process My Work Items for Task Planning](./ado-process-my-work-items-for-task-planning.prompt.md)
5. **Creating Azure DevOps PRs?** Use [ADO Create Pull Request](./ado-create-pull-request.prompt.md)
6. **Checking build status?** Use [ADO Get Build Info](./ado-get-build-info.prompt.md)
7. **Creating GitHub issues?** Use [GitHub Add Issue](./github-add-issue.prompt.md)
8. **Working on PRs?** Use [Pull Request](./pull-request.prompt.md)

## Related Resources

- **[Contributing Guide](../../CONTRIBUTING.md)** - Complete guide to contributing to the project
- **[Instructions](../instructions/README.md)** - Comprehensive guidance files for development standards
- **[Chat Modes](../chatmodes/README.md)** - Specialized AI assistance with enhanced capabilities

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
