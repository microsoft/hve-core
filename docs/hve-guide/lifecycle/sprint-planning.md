---
title: "Stage 5: Sprint Planning"
description: Organize work items into sprints and manage backlog priorities with AI-assisted planning
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

| Tool                     | Type        | How to Invoke              | Purpose                                          |
|--------------------------|-------------|----------------------------|--------------------------------------------------|
| github-backlog-manager   | Agent       | `@github-backlog-manager`  | Manage GitHub issue backlog end-to-end            |
| agile-coach              | Agent       | `@agile-coach`             | Get agile methodology guidance and sprint advice  |
| github-discover-issues   | Prompt      | `/github-discover-issues`  | Find open issues for sprint planning              |
| github-triage-issues     | Prompt      | `/github-triage-issues`    | Triage and label unprocessed issues               |
| github-sprint-plan       | Prompt      | `/github-sprint-plan`      | Create a sprint plan from backlog priorities      |
| github-execute-backlog   | Prompt      | `/github-execute-backlog`  | Execute planned backlog operations                |
| github-add-issue         | Prompt      | `/github-add-issue`        | Add new issues to the backlog                     |
| github-backlog-planning  | Instruction | Auto-activated on issues   | Enforces backlog planning conventions             |
| github-backlog-triage    | Instruction | Auto-activated on triage   | Enforces triage workflow standards                |

## Role-Specific Guidance

TPMs lead Sprint Planning, balancing priorities across the backlog and coordinating with Tech Leads on technical sequencing. Tech Leads contribute capacity estimates and identify dependency chains.

* [TPM Guide](../roles/tpm.md)
* [Tech Lead Guide](../roles/tech-lead.md)

## Starter Prompts

```text
/github-discover-issues Find open issues for sprint planning
```

```text
/github-triage-issues Triage and label unprocessed issues
```

```text
@agile-coach Help plan the next sprint with backlog priorities
```

## Stage Outputs and Next Stage

Sprint Planning produces a scoped sprint with prioritized issues, assigned owners, and milestone targets. Transition to [Stage 6: Implementation](implementation.md) when the sprint is planned and work items are assigned.

## Coverage Notes

> [!NOTE]
> GAP-10: Good-First-Issue discovery for new contributors is not yet available. GAP-19: No sprint retrospective tooling exists for end-of-sprint reflection. Sprint Planning currently has no skills or templates.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
