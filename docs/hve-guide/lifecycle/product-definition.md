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

| Tool                    | Type  | How to Invoke                            | Purpose                                         |
|-------------------------|-------|------------------------------------------|-------------------------------------------------|
| prd-builder             | Agent | Select **prd-builder** agent             | Create product requirements documents from BRDs |
| product-manager-advisor | Agent | Select **product-manager-advisor** agent | Get product management guidance and feedback    |
| adr-creation            | Agent | Select **adr-creation** agent            | Document architecture decisions formally        |
| arch-diagram-builder    | Agent | Select **arch-diagram-builder** agent    | Generate architecture diagrams for PRDs         |
| security-plan-creator   | Agent | Select **security-plan-creator** agent   | Validate security requirements in product specs |

## Role-Specific Guidance

TPMs own Product Definition, translating BRDs into PRDs with clear acceptance criteria. Tech Leads contribute architecture decisions and validate technical feasibility of proposed requirements.

* [TPM Guide](../roles/tpm.md)
* [Tech Lead Guide](../roles/tech-lead.md)

## Starter Prompts

Select **prd-builder** agent:

```text
Create a PRD from the BRD at docs/brds/fleet-management-v1.md. Define
the vehicle tracking dashboard requirements with acceptance criteria for
real-time GPS updates, geofence alerting, and non-functional requirements
for sub-500ms map tile rendering at 10,000 concurrent sessions.
```

Select **adr-creation** agent:

```text
Document the architecture decision for choosing PostgreSQL over CosmosDB
for the order management service. Include decision drivers around query
complexity and transaction support, alternatives considered, and the
migration path from the existing MongoDB deployment.
```

Select **arch-diagram-builder** agent:

```text
Generate an architecture diagram for the event-driven order processing
pipeline. Show the message flow from API gateway through the event bus
to worker services, including the dead-letter queue and monitoring
integration. Use mermaid flowchart syntax.
```

## Stage Outputs and Next Stage

Product Definition produces PRDs, ADRs, and architecture diagrams. Transition to [Stage 4: Decomposition](decomposition.md) when PRDs and ADRs are finalized.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
