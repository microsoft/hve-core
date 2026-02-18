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

| Tool                  | Type   | How to Invoke            | Purpose                                           |
|-----------------------|--------|--------------------------|---------------------------------------------------|
| task-researcher       | Agent  | `@task-researcher`       | Research best practices and technical topics      |
| brd-builder           | Agent  | `@brd-builder`           | Create business requirements documents            |
| security-plan-creator | Agent  | `@security-plan-creator` | Generate security plans and threat models         |
| gen-data-spec         | Agent  | `@gen-data-spec`         | Generate data specifications and schemas          |
| adr-creation          | Agent  | `@adr-creation`          | Document architecture decisions                   |
| arch-diagram-builder  | Agent  | `@arch-diagram-builder`  | Generate architecture diagrams                    |
| ux-ui-designer        | Agent  | `@ux-ui-designer`        | Design user experience and interface concepts     |
| memory                | Agent  | `@memory`                | Store research findings for later reference       |
| risk-register         | Prompt | `/risk-register`         | Identify and track project risks                  |
| task-research         | Prompt | `/task-research`         | Quick research queries without full agent context |

## Role-Specific Guidance

TPMs lead Discovery, producing BRDs and coordinating research across disciplines. Engineers contribute technical feasibility research. Tech Leads evaluate architecture options. Security Architects drive threat modeling. Data Scientists define data requirements.

* [TPM Guide](../roles/tpm.md)
* [Engineer Guide](../roles/engineer.md)
* [Tech Lead Guide](../roles/tech-lead.md)
* [Security Architect Guide](../roles/security-architect.md)
* [Data Scientist Guide](../roles/data-scientist.md)

## Starter Prompts

```text
@task-researcher Research best practices for {topic}
```

```text
@brd-builder Create a business requirements document for {project}
```

```text
@security-plan-creator Generate a security plan for {system}
```

## Stage Outputs and Next Stage

Discovery produces BRDs, research summaries, security plans, data specifications, and architecture decision records. Transition to [Stage 3: Product Definition](product-definition.md) when the BRD is complete (handoff at `docs/brds/`). TPMs who have a sufficient BRD can skip directly to [Stage 4: Decomposition](decomposition.md).

## Coverage Notes

> [!NOTE]
> NEW-GAP-D: Six agents operate at Stage 2 without orchestration guidance connecting them into a coherent discovery workflow. GAP-14: A Project Envisioning agent for pre-Stage 2 ideation is not yet available.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
