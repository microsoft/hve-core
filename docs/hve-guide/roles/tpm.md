---
title: TPM Guide
description: HVE Core support for technical program managers driving requirements, backlog management, and delivery coordination
author: Microsoft
ms.date: 2026-02-18
ms.topic: how-to
keywords:
  - TPM
  - project management
  - requirements
  - backlog
estimated_reading_time: 10
---

This guide is for you if you drive project planning, manage requirements, coordinate sprints, triage backlogs, or bridge business needs to technical delivery. TPMs have the widest tooling surface in HVE Core, with 32+ addressable assets spanning discovery, product definition, decomposition, sprint planning, and delivery.

## Recommended Collections

> [!TIP]
> Install the collections that match your workflow:
>
> ```text
> Minimum: @hve-core-installer install project-planning
> Full:    @hve-core-installer install project-planning ado github
> ```
>
> The `project-planning` collection provides BRD/PRD builders, agile coaching, and work item management. Adding `ado` enables Azure DevOps integration, and `github` adds issue discovery and backlog automation.

## What HVE Core Does for You

1. Generates business requirements documents (BRDs) from stakeholder conversations
2. Transforms BRDs into product requirements documents (PRDs) with traceability
3. Decomposes PRDs into Azure DevOps work items with proper hierarchy
4. Discovers, categorizes, and triages GitHub issues across repositories
5. Plans sprints with priority-based issue selection and capacity considerations
6. Provides agile coaching and product management advisory guidance
7. Tracks backlog health and identifies stale or duplicate issues

## Your Lifecycle Stages

> [!NOTE]
> TPMs primarily operate in these lifecycle stages:
>
> [Stage 2: Discovery](../lifecycle/discovery.md): Research requirements, gather context, discover existing issues
> [Stage 3: Product Definition](../lifecycle/product-definition.md): Create BRDs and PRDs, define product specifications
> [Stage 4: Decomposition](../lifecycle/decomposition.md): Break down requirements into work items and tasks
> [Stage 5: Sprint Planning](../lifecycle/sprint-planning.md): Triage issues, plan sprints, manage backlog
> [Stage 8: Delivery](../lifecycle/delivery.md): Track delivery, update work items, close milestones

## Stage Walkthrough

1. Stage 2: Discovery. Run `@task-researcher` for technical investigation and `/github-discover-issues` to find and categorize existing issues across repositories.
2. Stage 3: Product Definition. Use `@brd-builder` to create business requirements, then `@prd-builder` to generate a product specification from the BRD.
3. Stage 4: Decomposition. Convert PRD requirements to Azure DevOps work items with `@ado-prd-to-wit`, creating proper parent-child hierarchies.
4. Stage 5: Sprint Planning. Triage discovered issues with `/github-triage-issues` and plan sprints using `@agile-coach` for priority-based selection.
5. Stage 8: Delivery. Update work items as features ship, close completed milestones, and track delivery metrics.

## Starter Prompts

```text
@brd-builder Create a BRD for {project}
```

```text
@prd-builder Generate a PRD from the BRD at docs/brds/{name}.md
```

```text
/github-discover-issues Find and categorize open issues
```

```text
@agile-coach Help plan the sprint with current priorities
```

```text
@ado-prd-to-wit Convert PRD requirements to Azure DevOps work items
```

## Key Agents and Workflows

| Agent                  | Purpose                                       | Invoke                    | Docs                                                           |
|------------------------|-----------------------------------------------|---------------------------|----------------------------------------------------------------|
| brd-builder            | Business requirements document creation       | `@brd-builder`            | Agent file                                                     |
| prd-builder            | Product requirements document generation      | `@prd-builder`            | Agent file                                                     |
| agile-coach            | Sprint planning and agile methodology         | `@agile-coach`            | Agent file                                                     |
| ado-prd-to-wit         | PRD to Azure DevOps work item conversion      | `@ado-prd-to-wit`         | Agent file                                                     |
| github-backlog-manager | GitHub issue discovery and backlog automation  | `@github-backlog-manager` | [GitHub Backlog](../agents/github-backlog/)                    |
| github-issue-manager   | Single-issue operations (deprecated)          | `@github-issue-manager`   | Agent file                                                     |
| product-manager-advisor | Product strategy and prioritization guidance  | `@product-manager-advisor`| Agent file                                                     |
| ux-ui-designer         | UX/UI design guidance and review              | `@ux-ui-designer`         | Agent file                                                     |
| task-researcher        | Deep technical and requirement research       | `@task-researcher`        | [Task Researcher](../rpi/task-researcher.md)                   |
| rpi-agent              | RPI workflow orchestration                    | `@rpi-agent`              | [RPI docs](../rpi/README.md)                                   |
| memory                 | Session context and preference persistence    | `@memory`                 | Agent file                                                     |

## Tips

| Do                                                          | Don't                                                         |
|-------------------------------------------------------------|---------------------------------------------------------------|
| Start with a BRD before jumping to work item creation       | Create work items without documented requirements             |
| Use `/github-discover-issues` before manual issue searches  | Manually scan repositories for open issues                    |
| Let `@agile-coach` suggest sprint priorities                | Assign sprint items without capacity or priority analysis     |
| Triage issues with labels and milestones systematically     | Leave discovered issues uncategorized                         |
| Use `@github-backlog-manager` over `@github-issue-manager`  | Use the deprecated single-issue manager for bulk operations   |

## Related Roles

* TPM + Security Architect: Secure product launches require requirements gathering paired with threat modeling and compliance verification. Security plans integrate into the BRD/PRD workflow. See the [Security Architect Guide](security-architect.md).
* TPM + Engineer: TPMs define requirements and manage backlogs while engineers implement. Work item decomposition flows directly into RPI planning. See the [Engineer Guide](engineer.md).

## Next Steps

> [!TIP]
> Explore GitHub Backlog automation: [GitHub Backlog Manager](../agents/github-backlog/)
> Understand the full project lifecycle: [AI-Assisted Project Lifecycle](../lifecycle/)
> Review collaboration with Security: [Security Architect Guide](security-architect.md)

---

> [!NOTE]
> BRD-to-PRD traceability (GAP-15a), agent schema alignment (GAP-15b), and PRD-to-GitHub-Issues conversion (GAP-16) are planned improvements.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
