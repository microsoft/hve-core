---
title: "Stage 9: Operations"
description: Monitor production systems, respond to incidents, and maintain documentation post-delivery
author: Microsoft
ms.date: 2026-02-18
ms.topic: how-to
keywords:
  - ai-assisted project lifecycle
  - operations
  - monitoring
  - incidents
  - maintenance
estimated_reading_time: 6
---

## Overview

Operations covers the ongoing lifecycle after delivery, including incident response, documentation maintenance, prompt refinement, and system monitoring. This stage provides tooling for keeping production systems healthy and documentation current.

## When You Enter This Stage

You enter Operations after completing the final sprint delivery in [Stage 8: Delivery](delivery.md).

> [!NOTE]
> Prerequisites: Production deployment complete. Monitoring and alerting configured.

## Available Tools

### Primary Agents

| Tool           | Type  | How to Invoke     | Purpose                                       |
|----------------|-------|-------------------|------------------------------------------------|
| doc-ops        | Agent | `@doc-ops`        | Update and maintain documentation               |
| prompt-builder | Agent | `@prompt-builder` | Refine and optimize operational prompts         |

### Prompts

| Tool             | Type   | How to Invoke       | Purpose                                        |
|------------------|--------|---------------------|-------------------------------------------------|
| doc-ops-update   | Prompt | `/doc-ops-update`   | Update documentation for the latest release     |
| incident-response| Prompt | `/incident-response`| Document and triage incidents                   |
| prompt-analyze   | Prompt | `/prompt-analyze`   | Evaluate prompt effectiveness                   |
| prompt-refactor  | Prompt | `/prompt-refactor`  | Refactor and improve existing prompts           |
| checkpoint       | Prompt | `/checkpoint`       | Save operational state for continuity           |

### Auto-Activated Instructions

| Instruction    | Activates On    | Purpose                            |
|----------------|-----------------|-------------------------------------|
| writing-style  | `**/*.md`       | Enforces voice and tone conventions |
| markdown       | `**/*.md`       | Enforces Markdown formatting rules  |
| prompt-builder | AI artifacts    | Enforces authoring standards        |

### Templates

| Template          | Purpose                                     |
|-------------------|----------------------------------------------|
| incident-response | Structured template for incident documentation |

## Role-Specific Guidance

SREs lead Operations, handling incident response and system monitoring. Tech Leads contribute to architecture-level maintenance decisions. Engineers address hotfixes and ongoing code maintenance.

* [SRE/Operations Guide](../roles/sre-operations.md)
* [Tech Lead Guide](../roles/tech-lead.md)
* [Engineer Guide](../roles/engineer.md)

## Starter Prompts

```text
/incident-response Document and triage the current incident
```

```text
@doc-ops Update documentation for the latest release
```

```text
/prompt-analyze Evaluate prompt effectiveness and suggest improvements
```

## Stage Outputs and Next Stage

Operations produces updated documentation, incident reports, refined prompts, and maintenance artifacts. When a hotfix is needed, transition back to [Stage 6: Implementation](implementation.md) to address the issue through the standard implementation workflow.

## Coverage Notes

> [!NOTE]
> GAP-17: The incident lifecycle agent needs an upgrade for full incident management. GAP-21: An engagement wrap-up agent for closing out completed engagements is missing. GAP-19: Sprint retrospective tooling does not exist for end-of-engagement reflection.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
