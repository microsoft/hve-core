---
title: GitHub Copilot Prompts
description: Coaching and guidance prompts for specific development tasks that provide step-by-step assistance and context-aware support
author: Edge AI Team
ms.date: 2026-03-11
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

Prompts can be invoked in GitHub Copilot Chat using `/prompt-name` syntax (e.g., `/task-research`, `/git-commit`). They provide:

* **Educational Guidance**: Step-by-step coaching approach
* **Context-Aware Assistance**: Project-specific guidance and examples
* **Best Practices**: Established patterns and conventions
* **Interactive Support**: Conversational assistance for complex tasks

## Available Prompts

### Onboarding & Planning

* **[Task Research](./hve-core/task-research.prompt.md)** - Initiates research for task implementation based on user requirements and conversation context (use `/task-research <topic>` to invoke)
* **[Task Plan](./hve-core/task-plan.prompt.md)** - Creates implementation plans from research documents (use `/task-plan` to invoke)
* **[Task Implement](./hve-core/task-implement.prompt.md)** - Executes implementation plans with tracking and stop controls (use `/task-implement` to invoke)

### Source Control & Commit Quality

* **[Git Commit (Stage + Commit)](./hve-core/git-commit.prompt.md)** - Stages all changes and creates a Conventional Commit automatically
* **[Git Commit Message Generator](./hve-core/git-commit-message.prompt.md)** - Generates a compliant commit message for currently staged changes
* **[Git Merge](./hve-core/git-merge.prompt.md)** - Git merge, rebase, and rebase --onto workflows with conflict handling
* **[Git Setup](./hve-core/git-setup.prompt.md)** - Verification-first Git configuration assistant

### Azure DevOps Integration

#### Work Item Management

* **[ADO Get My Work Items](./ado/ado-get-my-work-items.prompt.md)** - Retrieves user's work items and organizes into planning files
* **[ADO Process My Work Items for Task Planning](./ado/ado-process-my-work-items-for-task-planning.prompt.md)** - Processes planning files for task planning with repository context enrichment

> **Note:** For comprehensive work item task planning, use the two-step workflow: First run `ado-get-my-work-items` to retrieve and organize work items into planning files, then `ado-process-my-work-items-for-task-planning` to enrich with repository context and generate task planning handoffs.

#### Pull Requests & Builds

* **[ADO Create Pull Request](./ado/ado-create-pull-request.prompt.md)** - Creates Azure DevOps PRs with work item discovery and reviewer identification
* **[ADO Get Build Info](./ado/ado-get-build-info.prompt.md)** - Retrieves Azure DevOps build information for PRs or specific builds

### GitHub Integration

* **[GitHub Add Issue](./github/github-add-issue.prompt.md)** - Create GitHub issues with proper formatting and labels

### Jira and GitLab Support

Jira workflow support is available through dedicated prompts in this directory. GitLab support is currently exposed through the local GitLab skill for merge request and pipeline workflows.

* **[Jira Discover Issues](./jira/jira-discover-issues.prompt.md)** - Discover Jira issues from documents, assigned work, or JQL searches and create planning files when needed
* **[Jira Triage Issues](./jira/jira-triage-issues.prompt.md)** - Triage Jira issues with bounded JQL, duplicate checks, and controlled execution
* **[Jira Execute Backlog](./jira/jira-execute-backlog.prompt.md)** - Execute a reviewed Jira handoff by creating, updating, transitioning, and commenting on issues
* **[Jira Skill](../skills/jira/jira/SKILL.md)** - Configure local Jira access and use the underlying CLI commands directly when prompt orchestration is not needed
* **[GitLab Skill](../skills/gitlab/gitlab/SKILL.md)** - Inspect merge requests, comments, pipelines, jobs, and logs for GitLab-hosted delivery workflows

### Security

* **[Security Review](./security/security-review.prompt.md)** - OWASP vulnerability assessment against the current codebase with configurable mode, scope, and skill selection
* **[Security Review - Web](./security/security-review-web.prompt.md)** - OWASP Top 10 web vulnerability assessment without codebase profiling (target-skill fast-path)
* **[Security Review - LLM](./security/security-review-llm.prompt.md)** - OWASP LLM and Agentic vulnerability assessments with codebase profiling for context
* **[Security Review - Secure by Design](./security/security-review-sbd.prompt.md)** - Secure by Design principles assessment based on UK and Australian government guidance (target-skill fast-path)
* **[Incident Response](./security/incident-response.prompt.md)** - Incident response workflow for Azure operations with triage, diagnostics, mitigation, and RCA phases
* **[Risk Register](./security/risk-register.prompt.md)** - Generate qualitative risk assessment with P×I matrix and mitigation plans

### Documentation & Process

* **[Pull Request](./hve-core/pull-request.prompt.md)** - PR description and review assistance

## Prompts vs Instructions vs Custom Agents

* **Prompts** (this directory): Coaching and educational guidance for learning
* **[Instructions](../instructions/README.md)**: Systematic implementation and automation
* **[Agents](../../docs/contributing/custom-agents.md)**: Specialized AI assistance with enhanced capabilities

## Quick Start

1. **Researching a complex task?** Use `/task-research <topic>` to investigate with [Task Research](./hve-core/task-research.prompt.md)
2. **Planning implementation?** Use `/task-plan` with a research file to create actionable plans with [Task Plan](./hve-core/task-plan.prompt.md)
3. **Executing a plan?** Use `/task-implement` to execute plans with [Task Implement](./hve-core/task-implement.prompt.md)
4. **Committing changes?** Use [Git Commit Message Generator](./hve-core/git-commit-message.prompt.md) or [Git Commit](./hve-core/git-commit.prompt.md)
5. **Handling merge conflicts?** Use [Git Merge](./hve-core/git-merge.prompt.md)
6. **Setting up Git?** Use [Git Setup](./hve-core/git-setup.prompt.md)
7. **Tracking your work?** Run [ADO Get My Work Items](./ado/ado-get-my-work-items.prompt.md) then [ADO Process My Work Items for Task Planning](./ado/ado-process-my-work-items-for-task-planning.prompt.md)
8. **Creating Azure DevOps PRs?** Use [ADO Create Pull Request](./ado/ado-create-pull-request.prompt.md)
9. **Checking build status?** Use [ADO Get Build Info](./ado/ado-get-build-info.prompt.md)
10. **Creating GitHub issues?** Use [GitHub Add Issue](./github/github-add-issue.prompt.md)
11. **Working on PRs?** Use [Pull Request](./hve-core/pull-request.prompt.md)
12. **Responding to Azure incidents?** Use [Incident Response](./security/incident-response.prompt.md)
13. **Managing Jira work?** Use [Jira Discover Issues](./jira/jira-discover-issues.prompt.md), [Jira Triage Issues](./jira/jira-triage-issues.prompt.md), or [Jira Execute Backlog](./jira/jira-execute-backlog.prompt.md)
14. **Need GitLab delivery context?** Review the [GitLab Skill](../skills/gitlab/gitlab/SKILL.md) for setup and command guidance
15. **Running a security review?** Use [Security Review](./security/security-review.prompt.md) for full OWASP assessment

## Related Resources

* **[Contributing Guide](../../CONTRIBUTING.md)** - Complete guide to contributing to the project
* **[Instructions](../instructions/README.md)** - Comprehensive guidance files for development standards
* **[Agents](../../docs/contributing/custom-agents.md)** - Specialized AI assistance with enhanced capabilities

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
