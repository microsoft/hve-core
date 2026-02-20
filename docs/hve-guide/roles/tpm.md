---
title: TPM Guide
description: HVE Core support for technical program managers driving requirements, backlog management, and delivery coordination
author: Microsoft
ms.date: 2026-02-19
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
> Install the [HVE Core extension](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core) from the VS Code Marketplace to get all stable artifacts with zero configuration.
>
> Your primary collections are `project-planning` (BRD/PRD builders, agile coaching, and work item management), `ado` (Azure DevOps integration), and `github` (issue discovery and backlog automation). For clone-based setups, use the **hve-core-installer** agent with `install project-planning ado github`.

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

1. Stage 2: Discovery. Run the **task-researcher** agent for technical investigation and `/github-discover-issues` to find and categorize existing issues across repositories.
2. Stage 3: Product Definition. Use the **brd-builder** agent to create business requirements, then the **prd-builder** agent to generate a product specification from the BRD.
3. Stage 4: Decomposition. Convert PRD requirements to Azure DevOps work items with the **ado-prd-to-wit** agent, creating proper parent-child hierarchies.
4. Stage 5: Sprint Planning. Triage discovered issues with `/github-triage-issues` and plan sprints using the **agile-coach** agent for priority-based selection.
5. Stage 8: Delivery. Update work items as features ship, close completed milestones, and track delivery metrics.

## Starter Prompts

Select **brd-builder** agent:

```text
Create a business requirements document for the customer onboarding portal.
Target enterprise customers with 500+ seats, with the objective of reducing
onboarding time from 2 weeks to 3 days. Include integration requirements
for existing SSO and billing systems and SOC 2 Type II compliance constraints.
```

Select **prd-builder** agent:

```text
Generate a PRD from the BRD at docs/brds/customer-onboarding-v2.md.
Focus on the self-service registration flow with acceptance criteria for
each user story, non-functional requirements for sub-200ms API responses,
and a data migration plan from the legacy system.
```

```text
/github-discover-issues Find and categorize open issues
```

Select **agile-coach** agent:

```text
Refine the user story for the notification preferences feature. The current
story says "users can manage notifications" but lacks specifics. Target
mobile and web channels, support per-category opt-in/opt-out, and ensure
GDPR consent tracking. Help me write acceptance criteria that are binary
and testable.
```

Select **ado-prd-to-wit** agent:

```text
Convert the PRD at docs/prds/notification-service-v3.md to Azure DevOps
work items. Map each functional requirement to a user story and each
non-functional requirement to a task under the "Platform Quality" epic.
Set iteration path to Sprint 24.
```

## Key Agents and Workflows

| Agent                       | Purpose                                       | Docs                                            |
|-----------------------------|-----------------------------------------------|-------------------------------------------------|
| **brd-builder**             | Business requirements document creation       | Agent file                                      |
| **prd-builder**             | Product requirements document generation      | Agent file                                      |
| **agile-coach**             | Sprint planning and agile methodology         | Agent file                                      |
| **ado-prd-to-wit**          | PRD to Azure DevOps work item conversion      | Agent file                                      |
| **github-backlog-manager**  | GitHub issue discovery and backlog automation | [GitHub Backlog](../../agents/github-backlog/)  |
| **product-manager-advisor** | Product strategy and prioritization guidance  | Agent file                                      |
| **ux-ui-designer**          | UX/UI design guidance and review              | Agent file                                      |
| **task-researcher**         | Deep technical and requirement research       | [Task Researcher](../../rpi/task-researcher.md) |
| **rpi-agent**               | RPI workflow orchestration                    | [RPI docs](../../rpi/README.md)                 |
| **memory**                  | Session context and preference persistence    | Agent file                                      |

## Tips

| Do                                                            | Don't                                                     |
|---------------------------------------------------------------|-----------------------------------------------------------|
| Start with a BRD before jumping to work item creation         | Create work items without documented requirements         |
| Use `/github-discover-issues` before manual issue searches    | Manually scan repositories for open issues                |
| Let the **agile-coach** agent suggest sprint priorities       | Assign sprint items without capacity or priority analysis |
| Triage issues with labels and milestones systematically       | Leave discovered issues uncategorized                     |
| Use the **github-backlog-manager** agent for issue management | Manage issues manually without backlog automation         |

## Related Roles

* TPM + Security Architect: Secure product launches require requirements gathering paired with threat modeling and compliance verification. Security plans integrate into the BRD/PRD workflow. See the [Security Architect Guide](security-architect.md).
* TPM + Engineer: TPMs define requirements and manage backlogs while engineers implement. Work item decomposition flows directly into RPI planning. See the [Engineer Guide](engineer.md).

## Next Steps

> [!TIP]
> Explore GitHub Backlog automation: [GitHub Backlog Manager](../../agents/github-backlog/)
> Understand the full project lifecycle: [AI-Assisted Project Lifecycle](../lifecycle/)
> Review collaboration with Security: [Security Architect Guide](security-architect.md)

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
