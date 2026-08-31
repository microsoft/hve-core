---
title: "Stage 5: Sprint Planning"
description: Organize work items into sprints and manage backlog priorities with AI-assisted planning
sidebar_position: 5
author: Microsoft
ms.date: 2026-08-06
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

Sprint Planning organizes decomposed work items into actionable sprints. This stage covers backlog triage, work discovery, priority assignment, and sprint scoping using tracker-agnostic backlog management tools.

## When You Enter This Stage

You enter Sprint Planning after completing [Stage 4: Decomposition](decomposition.md) with work items created and ready for prioritization.

> [!NOTE]
> Prerequisites: Work items exist in GitHub Issues or ADO. Repository has labels and milestones configured for sprint tracking.

## Available Tools

| Tool                  | Type  | How to Invoke                      | Purpose                                                          |
|-----------------------|-------|------------------------------------|------------------------------------------------------------------|
| backlog-manager       | Agent | Select **backlog-manager** agent   | Manage the backlog end-to-end across ADO, GitHub, and Jira       |
| backlog-plan discover | Skill | `/backlog-plan discover`           | Find candidate work items for sprint planning, read-only         |
| backlog-plan triage   | Skill | `/backlog-plan triage`             | Classify and label unprocessed items, read-only                  |
| backlog-plan sprint   | Skill | `/backlog-plan sprint`             | Create a sprint plan from backlog priorities, read-only          |
| backlog-execute run   | Skill | `/backlog-execute run`             | Apply a reviewed handoff to the tracker                          |
| backlog-execute add   | Skill | `/backlog-execute add`             | Add a single new item to the backlog                             |
| backlog-management    | Skill | Auto-loaded by the Backlog Manager | Supplies backlog planning, triage, and story quality conventions |

## Role-Specific Guidance

TPMs lead Sprint Planning, balancing priorities across the backlog and coordinating with Tech Leads on technical sequencing. Tech Leads contribute capacity estimates and identify dependency chains.

* [TPM Guide](../roles/tpm.md)
* [Tech Lead Guide](../roles/tech-lead.md)

## Starter Prompts

### Issue Discovery

Survey the backlog for candidate work. Discovery is read-only and writes an analysis file you review before continuing:

```text
/backlog-plan discover
```

The workflow resolves your tracker, runs its preflight, and asks which discovery path fits. Supply search terms such as `authentication` and a target iteration such as `v2.4.0` when prompted, or point it at a requirements document such as `docs/architecture/prd-notifications.md`.

### Backlog Triage

Classify untriaged items with label suggestions, iteration assignment, and duplicate detection:

```text
/backlog-plan triage
```

Triage is read-only. It writes a triage plan with its recommendations, and a separate execution pass applies them.

### Sprint Planning

Build a prioritized sprint plan from a target iteration with capacity constraints and a sprint goal:

```text
/backlog-plan sprint
```

### Backlog Execution

Dry-run a reviewed handoff to preview item operations before committing changes:

```text
/backlog-execute run --dry-run
```

When the preview matches your intent, apply it:

```text
/backlog-execute run
```

Create a single new item conversationally, using repository templates where they exist:

```text
/backlog-execute add
```

### User Story Coaching

Select **backlog-manager** agent to create a new story from a rough idea. The agent applies the story quality guidance in the `backlog-management` skill's story-quality reference:

```text
I need a story for adding webhook notifications when deployment status changes. The platform team needs real-time alerts in their monitoring dashboard.
```

Select **backlog-manager** agent to refine a vague existing story:

```text
Help me refine this story: Title: Improve error handling, Description: Handle errors better, AC: Errors are handled
```

### Full Backlog Orchestration

Select **backlog-manager** agent to coordinate triage and sprint planning end-to-end:

```text
Prepare the v2.4.0 milestone for sprint planning. Triage any needs-triage issues first, then build a prioritized sprint plan with a 15-issue capacity.
```

## Stage Outputs and Next Stage

Sprint Planning produces a scoped sprint with prioritized issues, assigned owners, and milestone targets. Transition to [Stage 6: Implementation](implementation.md) when the sprint is planned and work items are assigned.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
