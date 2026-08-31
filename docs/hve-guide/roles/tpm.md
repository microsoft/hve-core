---
title: TPM Guide
description: HVE Core support for technical program managers driving requirements, backlog management, and delivery coordination
sidebar_position: 5
author: Microsoft
ms.date: 2026-08-12
ms.topic: how-to
keywords:
  - TPM
  - project management
  - requirements
  - backlog
estimated_reading_time: 10
---

This guide is for you if you drive project planning, manage requirements, coordinate sprints, triage backlogs, or bridge business needs to technical delivery. TPMs have the widest tooling surface in HVE Core, with 32+ addressable assets spanning discovery, product definition, decomposition, sprint planning, and delivery.

## Capability Groups

> [!TIP]
> Install the [HVE Core extension](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core) from the VS Code Marketplace for the complete active component set with zero configuration.
>
> For selective clone adoption, choose requirements, agile coaching, backlog-management, and delivery-planning components that match your program. Backlog management is not split by tracker: one set of components resolves Azure DevOps, GitHub, or Jira at runtime. Capability groups help you discover related components; they are not independently installable products. See the [Installation Guide](../../getting-started/install.md).

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

1. Stage 2: Discovery. Run `/rpi-research` for technical investigation and `/backlog-plan discover` to find and categorize existing work items across trackers.
2. Stage 3: Product Definition. Use the **brd-builder** agent to create business requirements, then the **prd-builder** agent to generate a product specification from the BRD.
3. Stage 4: Decomposition. Plan a work item hierarchy from PRD requirements with the read-only **functional-planner** agent, then apply its reviewed handoff with `/backlog-execute run`.
4. Stage 5: Sprint Planning. Triage discovered items with `/backlog-plan triage`, then build the sprint with `/backlog-plan sprint`. Both are read-only and produce plans that a separate `/backlog-execute run` pass applies.
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
Generate a PRD from the BRD at docs/project-planning/customer-onboarding-v2.md.
Focus on the self-service registration flow with acceptance criteria for
each user story, non-functional requirements for sub-200ms API responses,
and a data migration plan from the legacy system.
```

When coordinating an RFI, RFP, tender, bid, or questionnaire, either builder can run the full `analyze`, `contribute`, `draft` sequence, with the domain binding applying to contributions only. Use `proposal-response` directly when you want the skill outside a builder session. Human owners retain disclosure, commitment, approval, submission, and release decisions. See the [proposal response workflow](../../agents/project-planning/brd-prd-builders#proposal-response-workflow).

```text
/backlog-plan discover
```

Select **backlog-manager** agent:

```text
Refine the user story for the notification preferences feature. The current
story says "users can manage notifications" but lacks specifics. Target
mobile and web channels, support per-category opt-in/opt-out, and ensure
GDPR consent tracking. Help me write acceptance criteria that are binary
and testable.
```

Select **functional-planner** agent:

```text
Convert the PRD at docs/project-planning/notification-service-v3.md into an Azure
DevOps work item hierarchy plan. Map each functional requirement to a user story
and each non-functional requirement to a task under the "Platform Quality" epic.
Set iteration path to Sprint 24.
```

Review the resulting handoff, then apply it:

```text
/backlog-execute run
```

## Key Agents and Workflows

| Agent or skill         | Purpose                                                                    | Docs                                        |
|------------------------|----------------------------------------------------------------------------|---------------------------------------------|
| **brd-builder**        | Business requirements document creation                                    | Agent file                                  |
| **prd-builder**        | Product requirements document generation                                   | Agent file                                  |
| **functional-planner** | PRD to work item hierarchy planning, read-only                             | Agent file                                  |
| **backlog-manager**    | Work discovery, triage, sprint planning, and execution across trackers     | [Backlog Management](../../agents/backlog/) |
| **ux-ui-designer**     | UX/UI design guidance and review                                           | Agent file                                  |
| **rpi-research**       | Deep technical and requirement research                                    | [RPI docs](../../rpi/)                      |
| **RPI Agent**          | RPI lifecycle coordination                                                 | [RPI docs](../../rpi/)                      |
| **dt-coach**           | Design Thinking coaching for stakeholder alignment and scope conversations | [Design Thinking](../../design-thinking/)   |

TPMs benefit from **dt-coach** when stakeholder alignment requires structured scope conversations (Method 1) or when requirements gathering needs empathy-driven research techniques. Design Thinking methods produce validated problem statements and stakeholder maps that strengthen BRD creation.

## Tips

| Do                                                       | Don't                                                     |
|----------------------------------------------------------|-----------------------------------------------------------|
| Start with a BRD before jumping to work item creation    | Create work items without documented requirements         |
| Use `/backlog-plan discover` before manual searches      | Manually scan repositories for open issues                |
| Let `/backlog-plan sprint` propose sprint priorities     | Assign sprint items without capacity or priority analysis |
| Triage issues with labels and milestones systematically  | Leave discovered issues uncategorized                     |
| Use the **backlog-manager** agent for backlog operations | Manage issues manually without backlog automation         |

## Related Roles

* TPM + Security Architect: Secure product launches require requirements gathering paired with security model analysis and compliance verification. Security plans integrate into the BRD/PRD workflow. See the [Security Architect Guide](security-architect.md).
* TPM + Engineer: TPMs define requirements and manage backlogs while engineers implement. Work item decomposition flows directly into RPI planning. See the [Engineer Guide](engineer.md).

## Next Steps

> [!TIP]
> Explore backlog automation across trackers: [Backlog Management](../../agents/backlog/)
> Understand the full project lifecycle: [AI-Assisted Project Lifecycle](../lifecycle/)
> Review collaboration with Security: [Security Architect Guide](security-architect.md)

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
