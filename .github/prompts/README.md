---
title: GitHub Copilot Prompts
description: Coaching and guidance prompts for specific development tasks that provide step-by-step assistance and context-aware support
author: Edge AI Team
ms.date: 2026-07-09
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

This directory contains **coaching and guidance prompts** designed to provide step-by-step assistance for specific development tasks. Unlike instructions that focus on systematic implementation, prompts offer educational guidance and context-aware coaching to help you learn and apply best practices. Prompts are organized by workflow focus area: planning and RPI, source control, pull requests and review, prompt engineering, Azure DevOps, GitHub, Jira, Design Thinking, Responsible AI, security, accessibility, data science, and experimental tools.

## How to Use Prompts

Prompts can be invoked in GitHub Copilot Chat using `/prompt-name` syntax (e.g., `/task-research`, `/git-commit`). They provide:

* **Educational Guidance**: Step-by-step coaching approach
* **Context-Aware Assistance**: Project-specific guidance and examples
* **Best Practices**: Established patterns and conventions
* **Interactive Support**: Conversational assistance for complex tasks

## Available Prompts

### Onboarding, Research & Planning

* **[Task Research](./hve-core/task-research.prompt.md)** - Initiates research for task implementation from user requirements (use `/task-research <topic>` to invoke)
* **[Task Plan](./hve-core/task-plan.prompt.md)** - Creates implementation plans from research documents (use `/task-plan` to invoke)
* **[Task Implement](./hve-core/task-implement.prompt.md)** - Executes implementation plans with tracking and stop controls (use `/task-implement` to invoke)
* **[Task Review](./hve-core/task-review.prompt.md)** - Initiates implementation review from context or artifact discovery
* **[Task Challenge](./hve-core/task-challenge.prompt.md)** - Adversarial What/Why/How interrogation of completed implementation artifacts
* **[RPI](./hve-core/rpi.prompt.md)** - Autonomous Research-Plan-Implement-Review-Discover workflow for completing tasks
* **[Checkpoint](./hve-core/checkpoint.prompt.md)** - Save or restore conversation context using memory files

### Source Control & Commit Quality

* **[Git Commit (Stage + Commit)](./hve-core/git-commit.prompt.md)** - Stages all changes and creates a Conventional Commit automatically
* **[Git Commit Message Generator](./hve-core/git-commit-message.prompt.md)** - Generates a compliant commit message for currently staged changes
* **[Git Merge](./hve-core/git-merge.prompt.md)** - Git merge, rebase, and rebase --onto workflows with conflict handling
* **[Git Setup](./hve-core/git-setup.prompt.md)** - Verification-first Git configuration assistant

### Pull Requests & Code Review

* **[Pull Request](./hve-core/pull-request.prompt.md)** - Generate pull request descriptions from branch diffs
* **[PR Review](./hve-core/pr-review.prompt.md)** - Review a pull request or local change set via the consolidated Code Review agent

### Prompt Engineering & Evaluation

* **[Prompt Build](./hve-core/prompt-build.prompt.md)** - Build or improve prompt engineering artifacts following quality criteria
* **[Prompt Analyze](./hve-core/prompt-analyze.prompt.md)** - Evaluate prompt engineering artifacts against quality criteria and report findings
* **[Prompt Refactor](./hve-core/prompt-refactor.prompt.md)** - Refactor and clean up prompt engineering artifacts through iterative improvement
* **[Vally Test Write](./hve-core/vally-test-write.prompt.md)** - Author Vally conformance test stimuli for an existing prompt, instructions, agent, or skill
* **[Evals Import](./hve-core/evals-import.prompt.md)** - Import a CSV or XLSX corpus into Vally eval suites with safety lint and dedupe

### Azure DevOps Integration

#### Work Item Management

* **[ADO Get My Work Items](./ado/ado-get-my-work-items.prompt.md)** - Retrieve your assigned work items into a planning file
* **[ADO Process My Work Items for Task Planning](./ado/ado-process-my-work-items-for-task-planning.prompt.md)** - Process retrieved work items and generate a task-planning handoff
* **[ADO Discover Work Items](./ado/ado-discover-work-items.prompt.md)** - Discover work items via user queries, artifact analysis, or search
* **[ADO Add Work Item](./ado/ado-add-work-item.prompt.md)** - Create a single work item with conversational field collection and parent validation
* **[ADO Update Work Items](./ado/ado-update-wit-items.prompt.md)** - Update work items from planning files
* **[ADO Triage Work Items](./ado/ado-triage-work-items.prompt.md)** - Triage untriaged work items with field classification, iteration assignment, and duplicate detection
* **[ADO Sprint Plan](./ado/ado-sprint-plan.prompt.md)** - Plan a sprint by analyzing iteration coverage, capacity, dependencies, and backlog gaps

> **Note:** For comprehensive work item task planning, use the two-step workflow: first run `ado-get-my-work-items`, then `ado-process-my-work-items-for-task-planning`.

#### Pull Requests & Builds

* **[ADO Create Pull Request](./ado/ado-create-pull-request.prompt.md)** - Create Azure DevOps PRs with generated description, linked work items, and reviewers
* **[ADO Get Build Info](./ado/ado-get-build-info.prompt.md)** - Retrieve build status and logs for a PR or build number

### GitHub Integration

* **[GitHub Add Issue](./github/github-add-issue.prompt.md)** - Create a GitHub issue using discovered repository templates and conversational field collection
* **[GitHub Discover Issues](./github/github-discover-issues.prompt.md)** - Discover issues via user queries, artifact analysis, or search and produce planning files
* **[GitHub Triage Issues](./github/github-triage-issues.prompt.md)** - Triage untriaged issues with label suggestions, milestone assignment, and duplicate detection
* **[GitHub Sprint Plan](./github/github-sprint-plan.prompt.md)** - Plan a milestone sprint by analyzing issue coverage, gaps, and prioritized backlog
* **[GitHub Execute Backlog](./github/github-execute-backlog.prompt.md)** - Execute a GitHub backlog plan from a handoff file
* **[GitHub Suggest](./github/github-suggest.prompt.md)** - Resume GitHub backlog management workflow after session restore

### Jira and GitLab Support

Jira workflow support is available through dedicated prompts in this directory. GitLab support is currently exposed through the local GitLab skill for merge request and pipeline workflows.

* **[Jira Discover Issues](./jira/jira-discover-issues.prompt.md)** - Discover Jira issues from documents, assigned work, or JQL searches and create planning files
* **[Jira Triage Issues](./jira/jira-triage-issues.prompt.md)** - Triage Jira issues with field recommendations, duplicate detection, and optional updates
* **[Jira Execute Backlog](./jira/jira-execute-backlog.prompt.md)** - Execute a reviewed Jira handoff by creating, updating, transitioning, and commenting on issues
* **[Jira PRD to WIT](./jira/jira-prd-to-wit.prompt.md)** - Analyze PRD artifacts and plan Jira issue hierarchies without mutating Jira
* **[Jira Setup](./jira/jira-setup.prompt.md)** - Interactive, verification-first Jira credential configuration assistant
* **[Jira Skill](../skills/jira/jira/SKILL.md)** - Configure local Jira access and use the CLI directly when prompt orchestration is not needed
* **[GitLab Skill](../skills/gitlab/gitlab/SKILL.md)** - Inspect merge requests, comments, pipelines, jobs, and logs for GitLab-hosted delivery workflows

### Design Thinking

* **[DT Start Project](./design-thinking/dt-start-project.prompt.md)** - Start a new Design Thinking coaching project with state initialization
* **[DT Resume Coaching](./design-thinking/dt-resume-coaching.prompt.md)** - Resume a coaching session by reading state and re-establishing context
* **[DT Method Next](./design-thinking/dt-method-next.prompt.md)** - Assess project state and recommend the next method with sequencing validation
* **[DT Canonical Deck](./design-thinking/dt-canonical-deck.prompt.md)** - Canonical deck workflow with snapshot generation and optional customer-card PowerPoint build
* **[DT Figma Export](./design-thinking/dt-figma-export.prompt.md)** - Export Design Thinking artifacts to a FigJam board or Figma Design file
* **[DT Handoff - Problem Space](./design-thinking/dt-handoff-problem-space.prompt.md)** - Compile Methods 1-3 outputs into an RPI-ready artifact targeting Task Researcher
* **[DT Handoff - Solution Space](./design-thinking/dt-handoff-solution-space.prompt.md)** - Compile Methods 4-6 outputs into an RPI-ready artifact targeting Task Researcher
* **[DT Handoff - Implementation Space](./design-thinking/dt-handoff-implementation-space.prompt.md)** - Compile Methods 7-9 outputs into an RPI-ready artifact targeting Task Researcher

> **Note:** The per-method coaching prompts (`dt-method-04-*`, `dt-method-05-*`, `dt-method-06-*`) are driven by the DT Coach agent mid-session and are not typically invoked directly.

### Responsible AI

* **[RAI Capture](./rai-planning/rai-capture.prompt.md)** - Start RAI assessment planning from existing knowledge (capture mode)
* **[RAI Plan from PRD](./rai-planning/rai-plan-from-prd.prompt.md)** - Start RAI assessment planning from PRD/BRD artifacts (from-prd mode)
* **[RAI Plan from Security Plan](./rai-planning/rai-plan-from-security-plan.prompt.md)** - Start RAI assessment planning from a completed Security Plan (recommended)

### Security

* **[Security Capture](./security/security-capture.prompt.md)** - Start security planning from existing notes (capture mode)
* **[Security Plan from PRD](./security/security-plan-from-prd.prompt.md)** - Start security planning from PRD/BRD artifacts (from-prd mode)
* **[Security Review](./security/security-review.prompt.md)** - OWASP vulnerability assessment against the current codebase with configurable mode, scope, and skill selection
* **[Security Review - Web](./security/security-review-web.prompt.md)** - OWASP Top 10 web vulnerability assessment without codebase profiling
* **[Security Review - LLM](./security/security-review-llm.prompt.md)** - OWASP LLM and Agentic vulnerability assessments with codebase profiling
* **[Security Review - Secure by Design](./security/security-review-sbd.prompt.md)** - Secure by Design principles assessment per UK and Australian government guidance
* **[SSSC Capture](./security/sssc-capture.prompt.md)** - Start supply chain security planning from existing knowledge (capture mode)
* **[SSSC from BRD](./security/sssc-from-brd.prompt.md)** - Start supply chain security planning from BRD artifacts
* **[SSSC from PRD](./security/sssc-from-prd.prompt.md)** - Start supply chain security planning from PRD artifacts
* **[SSSC from Security Plan](./security/sssc-from-security-plan.prompt.md)** - Extend a Security Planner assessment with supply chain coverage
* **[VEX Scan](./security/vex-scan.prompt.md)** - Full VEX pipeline: scan dependencies, enrich CVEs, analyze exploitability, and draft an OpenVEX document
* **[VEX Triage](./security/vex-triage.prompt.md)** - Triage CVEs from an existing scan report or SBOM and draft an OpenVEX document
* **[VEX Implement](./security/vex-implement.prompt.md)** - Plan the work to stand up VEX in a target project as a backlog for Task-* implementors
* **[Incident Response](./security/incident-response.prompt.md)** - Incident response workflow for Azure operations with triage, diagnostics, mitigation, and RCA phases
* **[Risk Register](./security/risk-register.prompt.md)** - Generate a qualitative risk assessment with a P×I matrix and mitigation plans

### Accessibility

* **[Accessibility Coverage Matrix](./accessibility/accessibility-coverage-matrix.prompt.md)** - Build, refresh, report, or probe an accessibility coverage matrix across criteria, surfaces, and methods

### Data Science

* **[Synthetic Data Generation](./data-science/synth-data-generate.prompt.md)** - Generate synthetic data for any subject with realistic patterns and relationships

### Experimental & Tools

* **[PowerPoint](./pptx.prompt.md)** - Create, update, or manage PowerPoint slide decks
* **[cspell Config](./experimental/cspell-config.prompt.md)** - Create or update the project cspell configuration with project words and ignores
* **[Graph Research](./experimental/graph-research.prompt.md)** - Research a codebase using an existing graphify knowledge graph with audit-tagged evidence

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
