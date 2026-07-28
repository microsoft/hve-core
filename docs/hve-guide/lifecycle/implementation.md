---
title: "Stage 6: Implementation"
description: Build features, write code, and create content with the full suite of AI-assisted development tools
sidebar_position: 7
author: Microsoft
ms.date: 2026-07-15
ms.topic: how-to
keywords:
  - ai-assisted project lifecycle
  - implementation
  - coding
  - RPI
  - development
estimated_reading_time: 8
---

## Overview

Implementation has the broadest tooling surface in the project lifecycle. This stage covers coding, content creation, prompt engineering, data analysis, and infrastructure work. The RPI lifecycle keeps Research, Plan, Implement, Review, and Follow-up distinct while providing structured execution guidance for complex tasks.

## When You Enter This Stage

You enter Implementation after completing [Stage 5: Sprint Planning](sprint-planning) with assigned work items. You also re-enter this stage from [Stage 7: Review](review) when rework is needed, from [Stage 8: Delivery](delivery) at the start of each new sprint, or from [Stage 9: Operations](operations) for hotfixes.

> [!NOTE]
> Prerequisites: Sprint planned with assigned work items. Development environment configured from [Stage 1: Setup](setup).

## Available Tools

### Primary Agents

| Tool                    | Type  | How to Invoke                            | Purpose                                    |
|-------------------------|-------|------------------------------------------|--------------------------------------------|
| RPI Agent               | Agent | Select **RPI Agent**                     | Coordinate the applicable RPI phase skills |
| gen-jupyter-notebook    | Agent | Select **gen-jupyter-notebook** agent    | Create data analysis notebooks             |
| gen-streamlit-dashboard | Agent | Select **gen-streamlit-dashboard** agent | Generate Streamlit dashboards              |

### Prompts

| Tool               | Type   | How to Invoke         | Purpose                                      |
|--------------------|--------|-----------------------|----------------------------------------------|
| rpi                | Prompt | `/rpi`                | Coordinate the full RPI lifecycle            |
| git-commit         | Prompt | `/git-commit`         | Stage and commit changes                     |
| git-commit-message | Prompt | `/git-commit-message` | Generate a commit message for staged changes |

### Auto-Activated Instructions

All coding standard instructions activate automatically based on file type:

| Instruction       | Activates On              | Purpose                                |
|-------------------|---------------------------|----------------------------------------|
| csharp            | `**/*.cs`                 | C# coding standards                    |
| python-script     | `**/*.py`                 | Python scripting standards             |
| bash              | `**/*.sh`                 | Bash script standards                  |
| bicep             | `**/bicep/**`             | Bicep infrastructure standards         |
| terraform         | `**/*.tf`                 | Terraform infrastructure standards     |
| workflows         | `.github/workflows/*.yml` | GitHub Actions workflow standards      |
| markdown          | `**/*.md`                 | Markdown formatting rules              |
| writing-style     | `**/*.md`                 | Voice and tone conventions             |
| hve-builder       | AI artifacts              | Prompt engineering authoring standards |
| hve-core-location | `**`                      | Reference resolution for hve-core      |

### Skills

| Tool          | How to Invoke      | Purpose                                                    |
|---------------|--------------------|------------------------------------------------------------|
| rpi-research  | `/rpi-research`    | Close a demonstrated evidence gap                          |
| rpi-plan      | `/rpi-plan`        | Create a plan, phase details, and independent critique     |
| rpi-implement | `/rpi-implement`   | Execute approved work and record change evidence           |
| rpi-review    | `/rpi-review`      | Reconcile implementation evidence and route follow-up      |
| hve-builder   | Use `hve-builder`  | Author or review prompts, instructions, agents, and skills |
| video-to-gif  | Use `video-to-gif` | Convert video to optimized GIFs                            |

## Role-Specific Guidance

Engineers are the primary users of Implementation, spending the majority of their engagement time here. Tech Leads contribute architecture-sensitive implementations. Data Scientists use notebook and dashboard generators. SREs handle infrastructure code. New Contributors start with guided tasks.

* [Engineer Guide](../roles/engineer)
* [Tech Lead Guide](../roles/tech-lead)
* [Data Scientist Guide](../roles/data-scientist)
* [SRE/Operations Guide](../roles/sre-operations)
* [New Contributor Guide](../roles/new-contributor)

## Starter Prompts

### Full RPI Workflow

```text
/rpi task="Implement the pagination logic for the /api/v2/search endpoint.
Add cursor-based pagination with a default page size of 50 and a maximum
of 200 results per request. Follow the existing pagination pattern in
src/api/handlers/list-resources.py."
```

### Step-by-Step RPI Skills

Use the matching phase skills when you want more control over each phase.

```text
/rpi-research Investigate how the existing list-resources handler in
src/api/handlers/list-resources.py implements pagination. Identify the
cursor encoding strategy, default and maximum page sizes, and response
envelope structure.
```

After research completes, plan the implementation:

```text
/rpi-plan Create an implementation plan for adding cursor-based pagination
to the /api/v2/search endpoint following the patterns documented in the
research output.
```

Execute the plan:

```text
/rpi-implement Build the webhook delivery system following the plan in
.copilot-tracking/plans/2026-07-13/webhook-delivery-plan.md and phase details in
.copilot-tracking/details/2026-07-13/webhook-delivery-phase-details.md. Start
with the event dispatcher component and implement the retry queue second.
```

Select **gen-jupyter-notebook** agent:

```text
Create a data analysis notebook for the Q4 sales transactions dataset in
data/sales-q4-2025.parquet. Include data quality assessment, revenue trend
analysis by product category and region, and customer cohort segmentation
using RFM scoring with matplotlib visualizations.
```

After implementation, validate the changes:

```text
/rpi-review Validate the pagination implementation against the plan.
Check cursor encoding, page size limits, response envelope consistency,
and error handling for invalid cursor values.
```

## Stage Outputs and Next Stage

Implementation produces source code, documentation, notebooks, dashboards, prompt artifacts, and infrastructure definitions. Transition to [Stage 7: Review](review) when implementation is complete. Use `/clear` to reset context before starting the review cycle.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
