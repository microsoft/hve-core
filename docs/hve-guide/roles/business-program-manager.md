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
> Install the [HVE Core extension](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core) from the VS Code Marketplace to get all stable artifacts with zero configuration.
>
> Your primary collection is `project-planning` (BRD creation, product management guidance, and agile coaching for business requirement gathering and stakeholder alignment). For clone-based setups, use the **hve-core-installer** agent with `install project-planning`.

## What HVE Core Does for You

1. Generates business requirements documents (BRDs) from stakeholder conversations and strategy inputs
2. Provides product management advisory guidance for prioritization and go-to-market decisions
3. Coaches user story creation and refinement with testable acceptance criteria
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

1. Stage 2: Discovery. Use the **task-researcher** agent to investigate business context, competitive landscape, and stakeholder needs.
2. Stage 3: Product Definition. Run the **brd-builder** agent to create business requirements documents from stakeholder conversations and strategy inputs.
3. Stage 3: Advisory. Consult the **product-manager-advisor** agent for prioritization guidance, go-to-market strategy, and product positioning.
4. Stage 4: Decomposition. Break business objectives into program milestones and coordinate cross-team dependencies.
5. Stage 5: Planning. Use the **agile-coach** agent to create or refine user stories with clear acceptance criteria for program work items.

## Starter Prompts

### Business Requirements

Select **brd-builder** agent:

```text
Create a business requirements document for the customer onboarding portal.
Target enterprise customers with 500+ seats, with the objective of reducing
onboarding time from 2 weeks to 3 days. Include integration requirements
for existing SSO and billing systems and SOC 2 Type II compliance constraints.
```

To resume a previous session, select **brd-builder** agent:

```text
Continue my claims automation BRD. Pick up where we left off
and focus on completing the data and reporting requirements section.
```

### Product Requirements Discovery

Select **product-manager-advisor** agent:

```text
We're building a webhook notification system for our API platform. Walk me
through requirements discovery: identify who the target users are, what
pain points exist with the current polling approach, and what measurable
outcomes would indicate success. Three enterprise customers provided
interview feedback we can reference.
```

For feature prioritization, select **product-manager-advisor** agent:

```text
Advise on prioritization for the identity and access management product
area. We have 12 open feature requests and 5 bugs. Revenue impact and
customer escalation status should weigh highest. Budget constraints limit
us to 2 engineers for the next quarter.
```

### User Story Coaching

Select **agile-coach** agent to create a story from a rough idea:

```text
I need a user story for adding webhook retry logic to our event
notification service. Deliveries currently fail silently when endpoints
return 5xx errors, and customers are missing critical billing events.
```

Select **agile-coach** agent to refine a vague story:

```text
Help me refine this story. Title: Improve error handling. Description:
Make error handling better across the API. AC: Errors should be handled
properly. This is too vague and I need testable acceptance criteria
tied to specific API endpoints.
```

### Business Context Research

Select **task-researcher** agent:

```text
Research best practices for migrating from manual invoice approval workflows
to automated AP processing. Compare ERP-integrated solutions versus
standalone AP automation platforms across processing volume limits,
three-way matching accuracy, audit trail completeness, and average
reduction in days payable outstanding. Our finance team processes 8,000
invoices per month with a 12% exception rate we need to cut in half.
```

### UX Research

Select **ux-ui-designer** agent:

```text
Create a Jobs-to-be-Done analysis and user journey map for the first-time
developer onboarding flow. Target audience is enterprise developers with
3-5 years experience migrating from a competitor platform. Include
accessibility requirements for WCAG AA compliance and keyboard-only
navigation support.
```

## Key Agents and Workflows

| Agent                       | Purpose                                                   | Docs                                               |
|-----------------------------|-----------------------------------------------------------|----------------------------------------------------|
| **brd-builder**             | Business requirements document creation                   | Agent file                                         |
| **product-manager-advisor** | Product strategy and prioritization guidance              | Agent file                                         |
| **agile-coach**             | User story creation and refinement coaching               | Agent file                                         |
| **task-researcher**         | Business context and market research                      | Agent file                                         |
| **ux-ui-designer**          | UX/UI guidance for business-facing deliverables           | Agent file                                         |
| **memory**                  | Session context and preference persistence                | Agent file                                         |
| **dt-coach**                | Design Thinking coaching for user-centered program design | [Design Thinking](../../design-thinking/README.md) |

BPMs benefit from **dt-coach** when program design requires user-centered validation. Design Thinking scope conversations (Method 1) and user concepts (Method 5) help BPMs ground business requirements in validated user needs before formal BRD creation.

Prompts complement the agents for cross-cutting workflows:

| Prompt       | Purpose                                                       | Invoke          |
|--------------|---------------------------------------------------------------|-----------------|
| git-commit   | Stage and commit changes with conventional message formatting | `/git-commit`   |
| pull-request | Create a pull request with structured description             | `/pull-request` |

## Tips

| Do                                                                    | Don't                                                    |
|-----------------------------------------------------------------------|----------------------------------------------------------|
| Start with the **brd-builder** agent for structured requirements      | Create informal requirements without BRD structure       |
| Use the **product-manager-advisor** agent for data-informed decisions | Make prioritization decisions without advisory input     |
| Focus on business outcomes and stakeholder alignment                  | Dive into technical implementation details               |
| Coordinate with TPMs for technical decomposition                      | Attempt Azure DevOps or GitHub issue management directly |
| Research market context before defining requirements                  | Assume business context without investigation            |

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
