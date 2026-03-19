---
title: "Stage 4: Decomposition"
description: Break product requirements into actionable work items and task hierarchies
sidebar_position: 6
author: Microsoft
ms.date: 2026-02-19
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

| Tool                      | Type        | How to Invoke                           | Purpose                                                |
|---------------------------|-------------|-----------------------------------------|--------------------------------------------------------|
| ado-prd-to-wit            | Agent       | Select **ado-prd-to-wit** agent         | Convert PRDs into ADO work items automatically         |
| github-backlog-manager    | Agent       | Select **github-backlog-manager** agent | GitHub issue discovery, triage, and backlog management |
| ado-get-my-work-items     | Prompt      | `/ado-get-my-work-items`                | Retrieve your assigned work items                      |
| ado-process-my-work-items | Prompt      | `/ado-process-my-work-items`            | Process and prioritize existing work items             |
| ado-wit-planning          | Instruction | Auto-activated on workitems             | Enforces work item planning conventions                |

## Role-Specific Guidance

TPMs own Decomposition, creating work item hierarchies that engineers pick up during Sprint Planning. The quality of decomposition directly affects implementation velocity.

* [TPM Guide](../roles/tpm.md)

## Starter Prompts

### ADO Work Items

Select **ado-prd-to-wit** agent:

```text
Convert the PRD at docs/prds/customer-onboarding-v2.md to Azure DevOps
work items. Create epics for each major feature area, user stories for
individual capabilities, and tasks for implementation steps. Tag all
items with "onboarding-v2".
```

```text
/ado-get-my-work-items Show my assigned work items
```

```text
/ado-process-my-work-items Process and prioritize my work items
```

### GitHub Issues via RPI Workflow

Select **github-backlog-manager** agent:

```text
Convert the PRD at docs/prds/customer-onboarding-v2.md into GitHub
issues. Create tracking issues for each major feature area, task issues
for implementation steps, and apply the "onboarding-v2" label to all
items.
```

After creating issues, add them to a GitHub Project for tracking:

```text
Add all issues labeled "onboarding-v2" to the "Onboarding v2" GitHub
Project. Use the gh CLI to list matching issues and add each one to
the project board.
```

## Stage Outputs and Next Stage

Decomposition produces work item hierarchies in ADO or GitHub Issues, with acceptance criteria traced to PRD requirements. Transition to [Stage 5: Sprint Planning](sprint-planning.md) when work items are created and prioritized.

## Coverage Notes

> [!NOTE]
> Teams that use GitHub Issues instead of ADO can use the RPI workflow with the **github-backlog-manager** agent for decomposition. Decomposition currently has no skills or templates.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
