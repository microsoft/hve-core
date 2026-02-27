---
title: "Stage 2: Discovery"
description: Research requirements, gather context, and build foundational documents with AI-assisted exploration
author: Microsoft
ms.date: 2026-02-18
ms.topic: how-to
keywords:
  - ai-assisted project lifecycle
  - discovery
  - research
  - requirements
  - BRD
estimated_reading_time: 6
---

## Overview

Discovery is where engagements take shape. This stage supports requirement gathering, technical research, business requirements documentation, security planning, and architectural exploration. With 14 assets available, Discovery provides the broadest research toolset in the lifecycle.

## When You Enter This Stage

You enter Discovery after completing [Stage 1: Setup](setup.md) with a configured environment.

> [!NOTE]
> Prerequisites: HVE Core installation complete, project repository initialized.

## Available Tools

| Tool                   | Type   | How to Invoke                           | Purpose                                                                              |
|------------------------|--------|-----------------------------------------|--------------------------------------------------------------------------------------|
| task-researcher        | Agent  | Select **task-researcher** agent        | Research best practices and technical topics                                         |
| brd-builder            | Agent  | Select **brd-builder** agent            | Create business requirements documents                                               |
| security-plan-creator  | Agent  | Select **security-plan-creator** agent  | Generate security plans and threat models                                            |
| gen-data-spec          | Agent  | Select **gen-data-spec** agent          | Generate data specifications and schemas                                             |
| adr-creation           | Agent  | Select **adr-creation** agent           | Document architecture decisions                                                      |
| arch-diagram-builder   | Agent  | Select **arch-diagram-builder** agent   | Generate architecture diagrams                                                       |
| ux-ui-designer         | Agent  | Select **ux-ui-designer** agent         | Design user experience and interface concepts                                        |
| github-backlog-manager | Agent  | Select **github-backlog-manager** agent | Discover and triage existing GitHub issues                                           |
| memory                 | Agent  | Select **memory** agent                 | Store research findings for later reference                                          |
| risk-register          | Prompt | `/risk-register`                        | Identify and track project risks                                                     |
| task-research          | Prompt | `/task-research`                        | Quick research queries without full agent context                                    |
| dt-coach               | Agent  | Select **dt-coach** agent               | Guide teams through Design Thinking methods for user-centered requirements discovery |

## Design Thinking as Pre-Research Methodology

> [!NOTE]
> Teams can invoke **dt-coach** during Discovery to run scope conversations (Method 1) and design research (Method 2) before engaging the task-researcher agent. Design Thinking provides structured, empathy-driven research techniques that produce validated problem statements and stakeholder maps, strengthening the foundation for subsequent technical research.

## Role-Specific Guidance

TPMs lead Discovery, producing BRDs and coordinating research across disciplines. Engineers contribute technical feasibility research. Tech Leads evaluate architecture options. Security Architects drive threat modeling. Data Scientists define data requirements.

* [TPM Guide](../roles/tpm.md)
* [Engineer Guide](../roles/engineer.md)
* [Tech Lead Guide](../roles/tech-lead.md)
* [Security Architect Guide](../roles/security-architect.md)
* [Data Scientist Guide](../roles/data-scientist.md)
* [UX Designer Guide](../roles/ux-designer.md)

UX and UI designers use Discovery-stage tools alongside **dt-coach** for structured user research. The dt-coach agent provides nine Design Thinking methods, including interview planning, environmental observation, and input synthesis, that complement task-researcher workflows with empathy-driven requirements gathering. See the [Design Thinking documentation](../../design-thinking/README.md) for method details.

## Starter Prompts

Select **task-researcher** agent:

```text
Research best practices for container orchestration with Kubernetes,
focusing on namespace isolation for multi-tenant environments, resource
quota configuration, and secret management approaches like external
secrets operator vs sealed secrets.
```

Select **brd-builder** agent:

```text
Create a business requirements document for the customer onboarding portal.
Target enterprise customers with 500+ seats, with the objective of reducing
onboarding time from 2 weeks to 3 days. Include integration requirements
for existing SSO and billing systems and SOC 2 Type II compliance constraints.
```

Select **security-plan-creator** agent:

```text
Generate a security plan for the /api/payments endpoint in our
customer-facing REST API. Scope the plan to authentication via
OAuth 2.0 with Azure AD B2C, PCI DSS compliance for payment
tokenization, and a threat model covering injection and broken
access control. Exclude infrastructure and network-level controls.
```

## Stage Outputs and Next Stage

Discovery produces BRDs, research summaries, security plans, data specifications, and architecture decision records. Transition to [Stage 3: Product Definition](product-definition.md) when the BRD is complete (handoff at `docs/brds/`). TPMs who have a sufficient BRD can skip directly to [Stage 4: Decomposition](decomposition.md).

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
