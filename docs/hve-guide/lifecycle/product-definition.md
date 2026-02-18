---
title: "Stage 3: Product Definition"
description: Transform business requirements into product specifications and architecture decisions
author: Microsoft
ms.date: 2026-02-18
ms.topic: how-to
keywords:
  - ai-assisted project lifecycle
  - product definition
  - PRD
  - ADR
  - architecture
estimated_reading_time: 6
---

## Overview

Product Definition transforms Discovery outputs into actionable specifications. This stage focuses on creating product requirements documents, formalizing architecture decisions, and validating that product direction aligns with business needs.

## When You Enter This Stage

You enter Product Definition after completing [Stage 2: Discovery](discovery.md) with a finalized BRD.

> [!NOTE]
> Prerequisites: BRD complete and available at `docs/brds/`. Architecture options explored during Discovery.

## Available Tools

| Tool                    | Type  | How to Invoke              | Purpose                                         |
|-------------------------|-------|----------------------------|-------------------------------------------------|
| prd-builder             | Agent | `@prd-builder`             | Create product requirements documents from BRDs |
| product-manager-advisor | Agent | `@product-manager-advisor` | Get product management guidance and feedback    |
| adr-creation            | Agent | `@adr-creation`            | Document architecture decisions formally        |
| arch-diagram-builder    | Agent | `@arch-diagram-builder`    | Generate architecture diagrams for PRDs         |
| security-plan-creator   | Agent | `@security-plan-creator`   | Validate security requirements in product specs |

## Role-Specific Guidance

TPMs own Product Definition, translating BRDs into PRDs with clear acceptance criteria. Tech Leads contribute architecture decisions and validate technical feasibility of proposed requirements.

* [TPM Guide](../roles/tpm.md)
* [Tech Lead Guide](../roles/tech-lead.md)

## Starter Prompts

```text
@prd-builder Create a PRD from our BRD at docs/brds/{name}.md
```

```text
@adr-creation Document the architecture decision for {topic}
```

```text
@arch-diagram-builder Generate an architecture diagram for {system}
```

## Stage Outputs and Next Stage

Product Definition produces PRDs, ADRs, and architecture diagrams. Transition to [Stage 4: Decomposition](decomposition.md) when PRDs and ADRs are finalized.

## Coverage Notes

> [!NOTE]
> GAP-15a: BRD-to-PRD traceability is not automated. Requirements from the BRD must be manually tracked through to PRD acceptance criteria. GAP-15b: Agent schema alignment between `@brd-builder` and `@prd-builder` has not been standardized.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
