---
title: "Stage 8: Delivery"
description: Merge approved changes, verify builds, and update tracking systems for release
author: Microsoft
ms.date: 2026-02-18
ms.topic: how-to
keywords:
  - ai-assisted project lifecycle
  - delivery
  - merge
  - release
  - deployment
estimated_reading_time: 6
---

## Overview

Delivery takes approved pull requests through merge, build verification, and work item updates. This stage closes the loop between implementation and tracking systems, ensuring that completed work is accurately reflected across all project management surfaces.

> [!IMPORTANT]
> Delivery is the only stage with zero agents. All operations at this stage are driven by prompts and auto-activated instructions. This reflects the procedural, checklist-oriented nature of delivery workflows.

## When You Enter This Stage

You enter Delivery after [Stage 7: Review](review.md) with an approved pull request.

> [!NOTE]
> Prerequisites: PR approved, CI checks passing, no merge conflicts.

## Available Tools

### Prompts

| Tool                   | Type   | How to Invoke             | Purpose                                   |
|------------------------|--------|---------------------------|-------------------------------------------|
| git-merge              | Prompt | `/git-merge`              | Merge approved PRs into the target branch |
| ado-get-build-info     | Prompt | `/ado-get-build-info`     | Check build status for the current branch |
| ado-update-wit-items   | Prompt | `/ado-update-wit-items`   | Update work items to reflect completion   |
| github-execute-backlog | Prompt | `/github-execute-backlog` | Execute planned backlog state changes     |

### Auto-Activated Instructions

| Instruction             | Activates On        | Purpose                                    |
|-------------------------|---------------------|--------------------------------------------|
| git-merge               | Merge operations    | Enforces merge, rebase, and conflict rules |
| ado-update-wit-items    | Work item updates   | Enforces ADO work item update conventions  |
| github-backlog-update   | Backlog operations  | Enforces GitHub backlog update standards   |
| community-interaction   | Public-facing comms | Enforces community communication standards |
| ado-create-pull-request | PR creation         | Enforces PR creation conventions           |

## Role-Specific Guidance

Engineers merge their approved PRs and verify builds. TPMs update work item status and close sprint tasks. SREs validate deployment pipelines and monitor post-merge build health. Data Scientists package notebooks, dashboards, and documentation for stakeholders.

* [Engineer Guide](../roles/engineer.md)
* [TPM Guide](../roles/tpm.md)
* [SRE/Operations Guide](../roles/sre-operations.md)
* [Data Scientist Guide](../roles/data-scientist.md)

## Starter Prompts

```text
/git-merge Merge the approved PR into main
```

```text
/ado-get-build-info Check build status for the current branch
```

```text
/ado-update-wit-items Update work items to reflect completion
```

## Stage Outputs and Next Stage

Delivery produces merged code on the target branch, updated work items, and verified build results. Transition to [Stage 6: Implementation](implementation.md) for the next sprint, or to [Stage 9: Operations](operations.md) when the final sprint is complete.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
