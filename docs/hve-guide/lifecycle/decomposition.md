---
title: "Stage 4: Decomposition"
description: Break product requirements into actionable work items and task hierarchies
sidebar_position: 6
author: Microsoft
ms.date: 2026-08-06
ms.topic: how-to
keywords:
  - ai-assisted project lifecycle
  - decomposition
  - work items
  - task breakdown
  - ADO
estimated_reading_time: 6
---

## Overview

Decomposition converts finalized product specifications into trackable work items. This stage bridges the gap between planning artifacts and execution by creating structured task hierarchies in Azure DevOps or GitHub Issues.

## When You Enter This Stage

You enter Decomposition after completing [Stage 3: Product Definition](product-definition.md) with finalized PRDs and ADRs. TPMs who skipped Product Definition enter directly from [Stage 2: Discovery](discovery.md) with a sufficient BRD.

> [!NOTE]
> Prerequisites: PRD or BRD finalized with clear acceptance criteria. Azure DevOps project configured (for ADO work items).

## Available Tools

| Tool                   | Type  | How to Invoke                       | Purpose                                                        |
|------------------------|-------|-------------------------------------|----------------------------------------------------------------|
| functional-planner     | Agent | Select **functional-planner** agent | Plan a work item hierarchy from a PRD, read-only               |
| backlog-manager        | Agent | Select **backlog-manager** agent    | Work discovery, triage, and backlog management across trackers |
| backlog-plan my-work   | Skill | `/backlog-plan my-work`             | Retrieve your assigned work items                              |
| backlog-plan task-plan | Skill | `/backlog-plan task-plan`           | Enrich assigned work into an implementation handoff            |
| backlog-execute run    | Skill | `/backlog-execute run`              | Apply a reviewed handoff to the tracker                        |
| backlog-management     | Skill | Auto-loaded by the Backlog Manager  | Supplies work item planning conventions                        |

## Role-Specific Guidance

TPMs own Decomposition, creating work item hierarchies that engineers pick up during Sprint Planning. The quality of decomposition directly affects implementation velocity.

* [TPM Guide](../roles/tpm.md)

## Starter Prompts

### ADO Work Items

Select **functional-planner** agent:

```text
Convert the PRD at docs/project-planning/customer-onboarding-v2.md into an Azure
DevOps work item hierarchy plan. Create epics for each major feature area, user
stories for individual capabilities, and tasks for implementation steps. Tag all
items with "onboarding-v2".
```

The Functional Planner is read-only. It emits a reviewed handoff that a separate execution pass applies to the tracker:

```text
/backlog-execute run
```

Retrieve the work already assigned to you:

```text
/backlog-plan my-work
```

Enrich that assigned work into an ordered implementation handoff:

```text
/backlog-plan task-plan
```

### GitHub Issues via RPI Workflow

Select **functional-planner** agent:

```text
Convert the PRD at docs/project-planning/customer-onboarding-v2.md into a GitHub
issue hierarchy. Create tracking issues for each major feature area, task issues
for implementation steps, and apply the "onboarding-v2" label to all
items.
```

Review the handoff, then create the issues with `/backlog-execute run`. After creating issues, add them to a GitHub Project for tracking:

```text
Add all issues labeled "onboarding-v2" to the "Onboarding v2" GitHub
Project. Use the gh CLI to list matching issues and add each one to
the project board.
```

## Stage Outputs and Next Stage

Decomposition produces work item hierarchies in ADO or GitHub Issues, with acceptance criteria traced to PRD requirements. Transition to [Stage 5: Sprint Planning](sprint-planning.md) when work items are created and prioritized.

## Coverage Notes

> [!NOTE]
> Teams that use GitHub Issues instead of ADO use the same tooling: the **backlog-manager** agent resolves the backing tracker at runtime. Decomposition is supported by the `functional-planner`, `backlog-plan`, and `backlog-execute` skills.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
