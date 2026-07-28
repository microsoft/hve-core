---
title: "Stage 9: Operations"
description: Monitor production systems, respond to incidents, and maintain documentation post-delivery
sidebar_position: 10
author: Microsoft
ms.date: 2026-07-15
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

| Tool          | Type  | How to Invoke                  | Purpose                                          |
|---------------|-------|--------------------------------|--------------------------------------------------|
| documentation | Agent | Select **documentation** agent | Audit, drift, author, and validate documentation |

### Prompts

| Tool              | Type   | How to Invoke        | Purpose                       |
|-------------------|--------|----------------------|-------------------------------|
| incident-response | Prompt | `/incident-response` | Document and triage incidents |

### Auto-Activated Instructions

| Instruction   | Activates On | Purpose                             |
|---------------|--------------|-------------------------------------|
| writing-style | `**/*.md`    | Enforces voice and tone conventions |
| markdown      | `**/*.md`    | Enforces Markdown formatting rules  |
| hve-builder   | AI artifacts | Enforces authoring standards        |

### Skills

| Skill        | Purpose                                                 |
|--------------|---------------------------------------------------------|
| hve-builder  | Review, refactor, or validate operational AI artifacts  |
| rpi-research | Investigate decision-critical operational evidence gaps |

### Templates

| Template          | Purpose                                        |
|-------------------|------------------------------------------------|
| incident-response | Structured template for incident documentation |

## Role-Specific Guidance

SREs lead Operations, handling incident response and system monitoring. Tech Leads contribute to architecture-level maintenance decisions. Engineers address hotfixes and ongoing code maintenance.

* [SRE/Operations Guide](../roles/sre-operations.md)
* [Tech Lead Guide](../roles/tech-lead.md)
* [Engineer Guide](../roles/engineer.md)

## Starter Prompts

### Incident Response

```text
/incident-response Users are reporting 504 Gateway Timeout errors on the
/api/v2/orders endpoint in East US 2. Errors started at 14:32 UTC after
the App Service scaled down during a scheduled maintenance window.
Severity 2. Phase is triage.
```

### Documentation Maintenance

Select the **documentation** agent and choose the validate or author mode to target a specific scope and focus area:

```text
Select documentation agent in validate mode. Scope docs, focus accuracy.
```

For ad-hoc documentation work, select the agent and describe the task directly.

Select **documentation** agent:

```text
Scan docs/getting-started/ for accuracy against current scripts/ and
.github/ artifacts. Several install scripts changed in the v3.2 release
and the setup guides may reference outdated flags or file paths.
```

### Prompt Refinement

```text
Use hve-builder with mode=review and
targets=.github/prompts/security/incident-response.prompt.md. Evaluate its
activation, operational safeguards, output contract, and host compatibility.
```

After review, use `hve-builder` improve or refactor mode only when source
changes are approved.

To create a new prompt from an existing implementation file, use
`hve-builder` create mode:

```text
Use hve-builder with mode=create. Create a prompt from
src/api/handlers/search.py that generates search
handler implementations following the same query parsing, pagination,
and response envelope patterns.
```

### Operational Continuity

Resume operational work from the artifacts owned by the active workflow. For
incident response, reopen the current incident report or runbook and continue
from its recorded status and next actions. For documentation work, resume from
the Documentation workflow's session record and target files. For HVE Builder,
resume from its author, review, behavior, and validation evidence.

## Stage Outputs and Next Stage

Operations produces updated documentation, incident reports, refined prompts, and maintenance artifacts. When a hotfix is needed, transition back to [Stage 6: Implementation](implementation.md) to address the issue through the standard implementation workflow.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
