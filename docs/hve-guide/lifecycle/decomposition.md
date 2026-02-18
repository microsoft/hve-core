---
title: "Stage 4: Decomposition"
description: Break product requirements into actionable work items and task hierarchies
author: Microsoft
ms.date: 2026-02-18
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

| Tool                      | Type        | How to Invoke                | Purpose                                        |
|---------------------------|-------------|------------------------------|------------------------------------------------|
| ado-prd-to-wit            | Agent       | `@ado-prd-to-wit`            | Convert PRDs into ADO work items automatically |
| github-issue-manager      | Agent       | `@github-issue-manager`      | Manage GitHub issues (deprecated)              |
| ado-get-my-work-items     | Prompt      | `/ado-get-my-work-items`     | Retrieve your assigned work items              |
| ado-process-my-work-items | Prompt      | `/ado-process-my-work-items` | Process and prioritize existing work items     |
| ado-wit-planning          | Instruction | Auto-activated on workitems  | Enforces work item planning conventions        |

## Role-Specific Guidance

TPMs own Decomposition, creating work item hierarchies that engineers pick up during Sprint Planning. The quality of decomposition directly affects implementation velocity.

* [TPM Guide](../roles/tpm.md)

## Starter Prompts

```text
@ado-prd-to-wit Convert PRD to work items
```

```text
/ado-get-my-work-items Show my assigned work items
```

```text
/ado-process-my-work-items Process and prioritize my work items
```

## Stage Outputs and Next Stage

Decomposition produces work item hierarchies in ADO or GitHub Issues, with acceptance criteria traced to PRD requirements. Transition to [Stage 5: Sprint Planning](sprint-planning.md) when work items are created and prioritized.

## Coverage Notes

> [!NOTE]
> GAP-16: A PRD-to-GitHub-Issues agent is missing for teams that use GitHub Issues instead of ADO. Decomposition currently has no skills or templates.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
