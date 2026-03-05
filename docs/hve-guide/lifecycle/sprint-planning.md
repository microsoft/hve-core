---
title: "Stage 5: Sprint Planning"
description: Organize work items into sprints and manage backlog priorities with AI-assisted planning
sidebar_position: 5
author: Microsoft
ms.date: 2026-02-18
ms.topic: how-to
keywords:
  - ai-assisted project lifecycle
  - sprint planning
  - backlog
  - triage
  - agile
estimated_reading_time: 6
---

## Overview

Sprint Planning organizes decomposed work items into actionable sprints. This stage covers backlog triage, issue discovery, priority assignment, and sprint scoping using GitHub-native backlog management tools.

## When You Enter This Stage

You enter Sprint Planning after completing [Stage 4: Decomposition](decomposition.md) with work items created and ready for prioritization.

> [!NOTE]
> Prerequisites: Work items exist in GitHub Issues or ADO. Repository has labels and milestones configured for sprint tracking.

## Available Tools

| Tool                    | Type        | How to Invoke                           | Purpose                                          |
|-------------------------|-------------|-----------------------------------------|--------------------------------------------------|
| github-backlog-manager  | Agent       | Select **github-backlog-manager** agent | Manage GitHub issue backlog end-to-end           |
| agile-coach             | Agent       | Select **agile-coach** agent            | Get agile methodology guidance and sprint advice |
| github-discover-issues  | Prompt      | `/github-discover-issues`               | Find open issues for sprint planning             |
| github-triage-issues    | Prompt      | `/github-triage-issues`                 | Triage and label unprocessed issues              |
| github-sprint-plan      | Prompt      | `/github-sprint-plan`                   | Create a sprint plan from backlog priorities     |
| github-execute-backlog  | Prompt      | `/github-execute-backlog`               | Execute planned backlog operations               |
| github-add-issue        | Prompt      | `/github-add-issue`                     | Add new issues to the backlog                    |
| github-backlog-planning | Instruction | Auto-activated on issues                | Enforces backlog planning conventions            |
| github-backlog-triage   | Instruction | Auto-activated on triage                | Enforces triage workflow standards               |

## Role-Specific Guidance

TPMs lead Sprint Planning, balancing priorities across the backlog and coordinating with Tech Leads on technical sequencing. Tech Leads contribute capacity estimates and identify dependency chains.

* [TPM Guide](../roles/tpm.md)
* [Tech Lead Guide](../roles/tech-lead.md)

## Starter Prompts

### Issue Discovery

Search for open issues by keyword to surface work items for the upcoming sprint:

```text
/github-discover-issues searchTerms=authentication milestone=v2.4.0
```

Extract issues from a requirements document and match them against the existing backlog:

```text
/github-discover-issues documents=docs/architecture/prd-notifications.md milestone=v2.4.0 autonomy=partial
```

### Backlog Triage

Triage untriaged issues with label suggestions, milestone assignment, and duplicate detection:

```text
/github-triage-issues milestone=v2.4.0 maxIssues=15
```

### Sprint Planning

Build a prioritized sprint plan from a milestone with capacity constraints and a sprint goal:

```text
/github-sprint-plan milestone=v2.4.0 sprintGoal=complete authentication module capacity=12
```

### Backlog Execution

Dry-run a handoff plan to preview issue operations before committing changes:

```text
/github-execute-backlog handoff=.copilot-tracking/github-issues/sprint/v2-4-0/handoff.md dryRun=true
```

Create a new issue using repository templates and conversational field collection:

```text
/github-add-issue title=feat(agents): add retry logic for rate-limited API calls labels=enhancement,agents
```

### User Story Coaching

Select **agile-coach** agent to create a new story from a rough idea:

```text
I need a story for adding webhook notifications when deployment status changes. The platform team needs real-time alerts in their monitoring dashboard.
```

Select **agile-coach** agent to refine a vague existing story:

```text
Help me refine this story: Title: Improve error handling, Description: Handle errors better, AC: Errors are handled
```

### Full Backlog Orchestration

Select **github-backlog-manager** agent to coordinate triage and sprint planning end-to-end:

```text
Prepare the v2.4.0 milestone for sprint planning. Triage any needs-triage issues first, then build a prioritized sprint plan with a 15-issue capacity.
```

## Stage Outputs and Next Stage

Sprint Planning produces a scoped sprint with prioritized issues, assigned owners, and milestone targets. Transition to [Stage 6: Implementation](implementation.md) when the sprint is planned and work items are assigned.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
