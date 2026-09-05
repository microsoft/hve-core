---
title: HVE Guide
description: Role-specific guides and the AI-assisted project lifecycle for engineering teams using HVE Core
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-20
ms.topic: overview
keywords:
  - hve guide
  - roles
  - ai-assisted project lifecycle
  - engineering guide
estimated_reading_time: 3
---

## Overview

The HVE Guide combines two complementary perspectives on AI-assisted engineering: the project lifecycle that defines *what* happens at each stage of delivery, and the role guides that define *how* each team member participates. Together, they provide a complete map of HVE Core tooling organized by both workflow stage and team responsibility.

## Sections

### AI-Assisted Project Lifecycle

A 9-stage lifecycle from initial setup through ongoing operations, with AI-assisted tooling at each stage. Every stage maps to specific agents, prompts, instructions, and skills that accelerate your work.

```mermaid
flowchart LR
  accTitle: AI-Assisted Project Lifecycle
  accDescr: Nine stages progress from setup through operations, with rework, next-sprint, hotfix, and next-iteration paths returning work to earlier stages.
    S1["1 · Setup"] --> S2["2 · Discovery"]
    S2 --> S3["3 · Product Definition"]
    S3 --> S4["4 · Decomposition"]
    S4 --> S5["5 · Sprint Planning"]
    S5 --> S6["6 · Implementation"]
    S6 --> S7["7 · Review"]
    S7 --> S8["8 · Delivery"]
    S8 --> S9["9 · Operations"]
    S7 -.->|"rework"| S6
    S8 -.->|"next sprint"| S6
    S9 -.->|"hotfix"| S6
    S9 -.->|"next iteration"| S2
```

> [!TIP]
> [Design Thinking](../design-thinking/using-together.md) can feed into this lifecycle at three exit points. See the [DT-RPI integration guide](../design-thinking/dt-rpi-integration.md) for details.

| Stage   | Name               | Key Tools                                                                                                                      |
|---------|--------------------|--------------------------------------------------------------------------------------------------------------------------------|
| Stage 1 | Setup              | hve-core-installer (skill), git-setup                                                                                          |
| Stage 2 | Discovery          | rpi-research, brd-builder, security-planner, dt-coach, sssc-planner, rai-planner                                               |
| Stage 3 | Product Definition | prd-builder, requirements-author skill, adr-creation, architecture-diagrams skill, security-planner, sssc-planner, rai-planner |
| Stage 4 | Decomposition      | functional-planner, backlog-manager                                                                                            |
| Stage 5 | Sprint Planning    | backlog-manager, backlog-management                                                                                            |
| Stage 6 | Implementation     | RPI Agent, rpi-plan, rpi-implement, hve-builder, coding-standards                                                              |
| Stage 7 | Review             | rpi-review, code-review, hve-builder                                                                                           |
| Stage 8 | Delivery           | pull-request, git-commit, git-merge, ado-get-build-info                                                                        |
| Stage 9 | Operations         | documentation, hve-builder, incident-response                                                                                  |

> Cross-cutting: each workflow persists its own durable state, evidence, and
> handoff artifacts when work must span conversations.

**[AI-Assisted Project Lifecycle Overview →](lifecycle/)**

### Role Guides

Nine role-specific guides covering recommended capabilities, stage walkthroughs, starter prompts, and collaboration patterns tailored to how you work.

| Role                     | Primary Stages                              | Guide                                                         |
|--------------------------|---------------------------------------------|---------------------------------------------------------------|
| Engineer                 | Stage 2, Stage 3, Stage 6, Stage 7, Stage 8 | [Engineer](roles/engineer.md)                                 |
| TPM                      | Stage 2, Stage 3, Stage 4, Stage 5, Stage 8 | [TPM](roles/tpm.md)                                           |
| Tech Lead / Architect    | Stage 2, Stage 3, Stage 6, Stage 7, Stage 9 | [Tech Lead](roles/tech-lead.md)                               |
| Security Architect       | Stage 2, Stage 3, Stage 7, Stage 9          | [Security Architect](roles/security-architect.md)             |
| Data Scientist           | Stage 2, Stage 3, Stage 6, Stage 7, Stage 8 | [Data Scientist](roles/data-scientist.md)                     |
| SRE / Operations         | Stage 1, Stage 3, Stage 6, Stage 8, Stage 9 | [SRE / Operations](roles/sre-operations.md)                   |
| Business Program Manager | Stage 2, Stage 3, Stage 4, Stage 5          | [Business Program Manager](roles/business-program-manager.md) |
| New Contributor          | Stage 1, Stage 2, Stage 6, Stage 7          | [New Contributor](roles/new-contributor.md)                   |
| UX Designer              | Stage 2, Stage 3, Stage 6, Stage 7          | [UX Designer](roles/ux-designer.md)                           |
| Utility                  | All                                         | [Utility](roles/utility.md)                                   |

**[Browse All Role Guides →](roles/)**

## Where to Start

```mermaid
flowchart TD
  accTitle: HVE Guide Navigation Entry Points
  accDescr: A starting decision routes readers to the lifecycle overview, stage navigator, role finder, or role capability reference according to their goal.
    START{Where to Start?} -->|Understand the workflow| LC[Lifecycle Overview]
    START -->|Find tools for my phase| SN[Stage Navigator]
    START -->|Get my role guide| RF[Role Finder]
    START -->|Find tools for my role| CQ[Role Capability Reference]
```

| I want to...                            | Go Here                                           |
|-----------------------------------------|---------------------------------------------------|
| Understand the full project workflow    | [Lifecycle Overview](lifecycle/)                  |
| Find tools for my current project phase | [Stage Navigator](lifecycle/#where-are-you)       |
| Get my role-specific guide              | [Role Finder](roles/#find-your-role)              |
| Find HVE Core tools for my role         | [Role Capability Reference](roles/#role-overview) |

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
