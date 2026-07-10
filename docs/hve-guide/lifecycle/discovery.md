---
title: "Stage 2: Discovery"
description: Research requirements, gather context, and build foundational documents with AI-assisted exploration
sidebar_position: 2
author: Microsoft
ms.date: 2026-07-09
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

| Tool                   | Type   | How to Invoke                           | Purpose                                                                                    |
|------------------------|--------|-----------------------------------------|--------------------------------------------------------------------------------------------|
| Task Researcher        | Agent  | Select **Task Researcher** agent        | Research best practices and technical topics                                               |
| BRD Builder            | Agent  | Select **BRD Builder** agent            | Create business requirements documents                                                     |
| Security Planner       | Agent  | Select **Security Planner** agent       | Generate security plans and security models                                                |
| SSSC Planner           | Agent  | Select **SSSC Planner** agent           | Assess supply chain security posture against OpenSSF standards                             |
| RAI Planner            | Agent  | Select **RAI Planner** agent            | Assess responsible AI risks and generate RAI plans                                         |
| DS Gen Data Spec       | Agent  | Select **DS Gen Data Spec** agent       | Generate data specifications and schemas                                                   |
| ADR Creator            | Agent  | Select **ADR Creator** agent            | Document architecture decisions                                                            |
| architecture-diagrams  | Skill  | Use the **architecture-diagrams** skill | Generate architecture diagrams                                                             |
| UX UI Designer         | Agent  | Select **UX UI Designer** agent         | Design user experience and interface concepts                                              |
| GitHub Backlog Manager | Agent  | Select **GitHub Backlog Manager** agent | Discover and triage existing GitHub issues                                                 |
| Memory                 | Agent  | Select **Memory** agent                 | Store research findings for later reference                                                |
| risk-register          | Prompt | `/risk-register`                        | Identify and track project risks                                                           |
| task-research          | Prompt | `/task-research`                        | Quick research queries without full agent context                                          |
| DT Coach               | Agent  | Select **DT Coach** agent               | Guide teams through Design Thinking methods for user-centered requirements discovery       |
| Experiment Designer    | Agent  | Select **Experiment Designer** agent    | Design Minimum Viable Experiments to validate unknowns before committing to implementation |

## Design Thinking as Pre-Research Methodology

> [!NOTE]
> Teams can invoke **DT Coach** during Discovery to run scope conversations (Method 1) and design research (Method 2) before engaging Task Researcher. Design Thinking provides structured, empathy-driven research techniques that produce validated problem statements and stakeholder maps, strengthening the foundation for subsequent technical research.

## Validating Unknowns with Minimum Viable Experiments

> [!NOTE]
> When Discovery surfaces unknowns across data, technology, or use cases, invoke **Experiment Designer** to design a Minimum Viable Experiment (MVE) before committing to full implementation. The agent guides you through problem discovery, hypothesis formation, vetting criteria, and experiment planning. MVEs resolve uncertainty early (whether hypotheses are validated or invalidated) the results inform your go/no-go decisions and reduce downstream risk.

## Role-Specific Guidance

TPMs lead Discovery, producing BRDs and coordinating research across disciplines. Engineers contribute technical feasibility research. Tech Leads evaluate architecture options. Security Architects drive security model analysis. Data Scientists define data requirements.

* [TPM Guide](../roles/tpm.md)
* [Engineer Guide](../roles/engineer.md)
* [Tech Lead Guide](../roles/tech-lead.md)
* [Security Architect Guide](../roles/security-architect.md)
* [Data Scientist Guide](../roles/data-scientist.md)
* [UX Designer Guide](../roles/ux-designer.md)

UX and UI designers use Discovery-stage tools alongside **DT Coach** for structured user research. The DT Coach agent provides nine Design Thinking methods, including interview planning, environmental observation, and input synthesis, that complement Task Researcher workflows with empathy-driven requirements gathering. See the [Design Thinking documentation](../../design-thinking/) for method details.

## Starter Prompts

Select **Task Researcher** agent:

```text
Research best practices for container orchestration with Kubernetes,
focusing on namespace isolation for multi-tenant environments, resource
quota configuration, and secret management approaches like external
secrets operator vs sealed secrets.
```

Select **BRD Builder** agent:

```text
Create a business requirements document for the customer onboarding portal.
Target enterprise customers with 500+ seats, with the objective of reducing
onboarding time from 2 weeks to 3 days. Include integration requirements
for existing SSO and billing systems and SOC 2 Type II compliance constraints.
```

Select **Security Planner** agent:

```text
Generate a security plan for the /api/payments endpoint in our
customer-facing REST API. Scope the plan to authentication via
OAuth 2.0 with Azure AD B2C, PCI DSS compliance for payment
tokenization, and a security model covering injection and broken
access control. Exclude infrastructure and network-level controls.
```

Select **SSSC Planner** agent:

```text
Assess this repository's supply chain security posture against the OpenSSF Scorecard
```

Select **RAI Planner** agent:

```text
Assess the responsible AI risks for this project based on the security plan
```

## Stage Outputs and Next Stage

Discovery produces BRDs, research summaries, security plans, data specifications, architecture decision records, supply chain security assessments, and RAI assessments. Transition to [Stage 3: Product Definition](product-definition.md) when the BRD is complete (handoff at `docs/project-planning/`). TPMs who have a sufficient BRD can skip directly to [Stage 4: Decomposition](decomposition.md).

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
