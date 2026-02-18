---
title: Business Program Manager Guide
description: HVE Core support for business program managers driving stakeholder alignment, business outcomes, and program coordination
author: Microsoft
ms.date: 2026-02-18
ms.topic: how-to
keywords:
  - BPM
  - program management
  - business requirements
  - stakeholder alignment
estimated_reading_time: 10
---

> [!IMPORTANT]
> The BPM role guide is in beta. BPM-specific tooling is derived from TPM and project-planning assets. As dedicated BPM workflows mature, this guide will be updated with refined agent interactions and purpose-built prompts.

This guide is for you if you define business outcomes, manage stakeholder alignment, coordinate cross-team programs, or bridge business strategy to technical delivery. Business program managers share many tools with TPMs but focus on business-level requirements, stakeholder communication, and outcome tracking rather than technical implementation detail.

## Recommended Collections

> [!TIP]
> Install the collection that matches your workflow:
>
> ```text
> @hve-core-installer install project-planning
> ```
>
> The `project-planning` collection provides BRD creation, product management guidance, and agile coaching. These assets support business requirement gathering and stakeholder alignment workflows.

## What HVE Core Does for You

1. Generates business requirements documents (BRDs) from stakeholder conversations and strategy inputs
2. Provides product management advisory guidance for prioritization and go-to-market decisions
3. Offers agile coaching for program-level sprint and milestone planning
4. Supports research workflows for competitive analysis, market investigation, and business case development

## BPM vs TPM

The BPM and TPM roles share tooling but apply it differently:

| Aspect            | BPM Focus                                                               | TPM Focus                                                 |
|-------------------|-------------------------------------------------------------------------|-----------------------------------------------------------|
| Primary artifacts | Business requirements, outcome definitions                              | Technical requirements, work item hierarchies             |
| Stakeholder scope | Business leaders, customers, cross-org partners                         | Engineering teams, technical stakeholders                 |
| Measurement       | Business outcomes, ROI, customer impact                                 | Sprint velocity, delivery milestones, technical quality   |
| Lifecycle stages  | Stage 2: Discovery, Stage 3: Product Definition, Stage 4: Decomposition | Stage 2 through Stage 8 with deeper technical involvement |

For technical backlog management, Azure DevOps integration, or GitHub issue workflows, see the [TPM Guide](tpm.md).

## Your Lifecycle Stages

> [!NOTE]
> BPMs primarily operate in these lifecycle stages:
>
> [Stage 2: Discovery](../lifecycle/discovery.md): Research business requirements, competitive landscape, market context
> [Stage 3: Product Definition](../lifecycle/product-definition.md): Define business requirements and outcome specifications
> [Stage 4: Decomposition](../lifecycle/decomposition.md): Break down business objectives into program milestones
> [Stage 5: Sprint Planning](../lifecycle/sprint-planning.md): Coordinate cross-team planning and milestone alignment

## Stage Walkthrough

1. Stage 2: Discovery. Use `@task-researcher` to investigate business context, competitive landscape, and stakeholder needs.
2. Stage 3: Product Definition. Run `@brd-builder` to create business requirements documents from stakeholder conversations and strategy inputs.
3. Stage 3: Advisory. Consult `@product-manager-advisor` for prioritization guidance, go-to-market strategy, and product positioning.
4. Stage 4: Decomposition. Break business objectives into program milestones and coordinate cross-team dependencies.
5. Stage 5: Planning. Coordinate program milestones with `@agile-coach` for cross-team sprint alignment and capacity planning.

## Starter Prompts

```text
@brd-builder Create a BRD for {business initiative}
```

```text
@product-manager-advisor Advise on prioritization for {product area}
```

```text
@agile-coach Help plan cross-team milestones for {program}
```

```text
@task-researcher Research the competitive landscape for {market}
```

## Key Agents and Workflows

| Agent                   | Purpose                                         | Invoke                     | Docs       |
|-------------------------|-------------------------------------------------|----------------------------|------------|
| brd-builder             | Business requirements document creation         | `@brd-builder`             | Agent file |
| product-manager-advisor | Product strategy and prioritization guidance    | `@product-manager-advisor` | Agent file |
| agile-coach             | Program-level sprint and milestone planning     | `@agile-coach`             | Agent file |
| task-researcher         | Business context and market research            | `@task-researcher`         | Agent file |
| ux-ui-designer          | UX/UI guidance for business-facing deliverables | `@ux-ui-designer`          | Agent file |
| memory                  | Session context and preference persistence      | `@memory`                  | Agent file |

## Tips

| Do                                                         | Don't                                                    |
|------------------------------------------------------------|----------------------------------------------------------|
| Start with `@brd-builder` for structured requirements      | Create informal requirements without BRD structure       |
| Use `@product-manager-advisor` for data-informed decisions | Make prioritization decisions without advisory input     |
| Focus on business outcomes and stakeholder alignment       | Dive into technical implementation details               |
| Coordinate with TPMs for technical decomposition           | Attempt Azure DevOps or GitHub issue management directly |
| Research market context before defining requirements       | Assume business context without investigation            |

## Related Roles

* BPM + TPM: BPMs define business requirements and outcomes; TPMs decompose them into technical specifications and work items. Strong collaboration between these roles ensures business intent carries through to implementation. See the [TPM Guide](tpm.md).
* BPM + Security Architect: Business requirements include compliance and security constraints. Security plans validate that business commitments are technically achievable. See the [Security Architect Guide](security-architect.md).

## Next Steps

> [!TIP]
> Explore project planning tools: [Project Planning Collection](../../collections/project-planning.collection.md)
> Understand the TPM workflow for technical handoff: [TPM Guide](tpm.md)
> See how program management fits the project lifecycle: [AI-Assisted Project Lifecycle](../lifecycle/)

---

> [!NOTE]
> Dedicated BPM workflow automation and business outcome tracking are planned improvements.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
