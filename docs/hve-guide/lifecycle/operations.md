---
title: "Stage 9: Operations"
description: Monitor production systems, respond to incidents, and maintain documentation post-delivery
sidebar_position: 10
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

| Tool           | Type  | How to Invoke                   | Purpose                                 |
|----------------|-------|---------------------------------|-----------------------------------------|
| doc-ops        | Agent | Select **doc-ops** agent        | Update and maintain documentation       |
| prompt-builder | Agent | Select **prompt-builder** agent | Refine and optimize operational prompts |

### Prompts

| Tool              | Type   | How to Invoke        | Purpose                                     |
|-------------------|--------|----------------------|---------------------------------------------|
| doc-ops-update    | Prompt | `/doc-ops-update`    | Update documentation for the latest release |
| incident-response | Prompt | `/incident-response` | Document and triage incidents               |
| prompt-analyze    | Prompt | `/prompt-analyze`    | Evaluate prompt effectiveness               |
| prompt-refactor   | Prompt | `/prompt-refactor`   | Refactor and improve existing prompts       |
| checkpoint        | Prompt | `/checkpoint`        | Save operational state for continuity       |

### Auto-Activated Instructions

| Instruction    | Activates On | Purpose                             |
|----------------|--------------|-------------------------------------|
| writing-style  | `**/*.md`    | Enforces voice and tone conventions |
| markdown       | `**/*.md`    | Enforces Markdown formatting rules  |
| prompt-builder | AI artifacts | Enforces authoring standards        |

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

Use the `/doc-ops-update` prompt to target a specific scope and focus area:

```text
/doc-ops-update scope=docs focus=accuracy
```

For ad-hoc documentation work outside the predefined scopes, select the agent directly.

Select **doc-ops** agent:

```text
Scan docs/getting-started/ for accuracy against current scripts/ and
.github/ artifacts. Several install scripts changed in the v3.2 release
and the setup guides may reference outdated flags or file paths.
```

### Prompt Refinement

```text
/prompt-analyze .github/prompts/rpi/task-research.prompt.md
```

After analysis, apply the suggested improvements:

```text
/prompt-refactor .github/prompts/rpi/task-research.prompt.md Remove
duplicate input declarations and consolidate the research scope section
into a single structured list.
```

To create a new prompt from an existing implementation file, select **prompt-builder** agent:

```text
Create a prompt from src/api/handlers/search.py that generates search
handler implementations following the same query parsing, pagination,
and response envelope patterns.
```

### Operational Continuity

Save conversation state before ending a session:

```text
/checkpoint mode=save description=incident-response-playbook-updates
```

Resume a previous session:

```text
/checkpoint mode=continue description=incident-response
```

## Stage Outputs and Next Stage

Operations produces updated documentation, incident reports, refined prompts, and maintenance artifacts. When a hotfix is needed, transition back to [Stage 6: Implementation](implementation.md) to address the issue through the standard implementation workflow.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
