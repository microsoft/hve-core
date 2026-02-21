---
title: "Stage 6: Implementation"
description: Build features, write code, and create content with the full suite of AI-assisted development tools
author: Microsoft
ms.date: 2026-02-18
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

Implementation is the highest-density stage in the project lifecycle, with 30 assets spanning agents, prompts, instructions, and skills. This stage covers coding, content creation, prompt engineering, data analysis, and infrastructure work. The RPI (Research, Plan, Implement) methodology provides structured execution guidance for complex tasks.

## When You Enter This Stage

You enter Implementation after completing [Stage 5: Sprint Planning](sprint-planning.md) with assigned work items. You also re-enter this stage from [Stage 7: Review](review.md) when rework is needed, from [Stage 8: Delivery](delivery.md) at the start of each new sprint, or from [Stage 9: Operations](operations.md) for hotfixes.

> [!NOTE]
> Prerequisites: Sprint planned with assigned work items. Development environment configured from [Stage 1: Setup](setup.md).

## Available Tools

### Primary Agents

| Tool                    | Type  | How to Invoke                            | Purpose                                               |
|-------------------------|-------|------------------------------------------|-------------------------------------------------------|
| rpi-agent               | Agent | Select **rpi-agent** agent               | Orchestrate the full research-plan-implement workflow |
| task-researcher         | Agent | Select **task-researcher** agent         | Research requirements and gather codebase evidence    |
| task-planner            | Agent | Select **task-planner** agent            | Create implementation plans from research findings    |
| task-implementor        | Agent | Select **task-implementor** agent        | Build components following plans                      |
| task-reviewer           | Agent | Select **task-reviewer** agent           | Validate implementation against plan and research     |
| gen-jupyter-notebook    | Agent | Select **gen-jupyter-notebook** agent    | Create data analysis notebooks                        |
| gen-streamlit-dashboard | Agent | Select **gen-streamlit-dashboard** agent | Generate Streamlit dashboards                         |
| prompt-builder          | Agent | Select **prompt-builder** agent          | Create and refine prompt engineering artifacts        |

### Supporting Agents

| Tool                | Type  | How to Invoke                        | Purpose                                  |
|---------------------|-------|--------------------------------------|------------------------------------------|
| phase-implementor   | Agent | Select **phase-implementor** agent   | Execute individual implementation phases |
| prompt-updater      | Agent | Select **prompt-updater** agent      | Update existing prompts and instructions |
| researcher-subagent | Agent | Select **researcher-subagent** agent | Conduct focused research within tasks    |

### Prompts

| Tool               | Type   | How to Invoke         | Purpose                                      |
|--------------------|--------|-----------------------|----------------------------------------------|
| rpi                | Prompt | `/rpi`                | Start the full RPI workflow                  |
| task-research      | Prompt | `/task-research`      | Research requirements for a task             |
| task-plan          | Prompt | `/task-plan`          | Create an implementation plan from research  |
| task-implement     | Prompt | `/task-implement`     | Begin implementation of a specific task      |
| task-review        | Prompt | `/task-review`        | Review implementation against the plan       |
| prompt-build       | Prompt | `/prompt-build`       | Create a new prompt engineering artifact     |
| prompt-analyze     | Prompt | `/prompt-analyze`     | Analyze prompt quality and effectiveness     |
| prompt-refactor    | Prompt | `/prompt-refactor`    | Refactor and improve existing prompts        |
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
| prompt-builder    | AI artifacts              | Prompt engineering authoring standards |
| hve-core-location | `**`                      | Reference resolution for hve-core      |

### Skills

| Tool         | Type  | How to Invoke      | Purpose                         |
|--------------|-------|--------------------|---------------------------------|
| video-to-gif | Skill | Referenced in chat | Convert video to optimized GIFs |

## Role-Specific Guidance

Engineers are the primary users of Implementation, spending the majority of their engagement time here. Tech Leads contribute architecture-sensitive implementations. Data Scientists use notebook and dashboard generators. SREs handle infrastructure code. New Contributors start with guided tasks.

* [Engineer Guide](../roles/engineer.md)
* [Tech Lead Guide](../roles/tech-lead.md)
* [Data Scientist Guide](../roles/data-scientist.md)
* [SRE/Operations Guide](../roles/sre-operations.md)
* [New Contributor Guide](../roles/new-contributor.md)

## Starter Prompts

### Full RPI Workflow

```text
/rpi Implement the pagination logic for the /api/v2/search endpoint.
Add cursor-based pagination with a default page size of 50 and a maximum
of 200 results per request. Follow the existing pagination pattern in
src/api/handlers/list-resources.py.
```

### Step-by-Step RPI Agents

Use individual task agents when you want more control over each phase.

```text
/task-research Investigate how the existing list-resources handler in
src/api/handlers/list-resources.py implements pagination. Identify the
cursor encoding strategy, default and maximum page sizes, and response
envelope structure.
```

After research completes, plan the implementation:

```text
/task-plan Create an implementation plan for adding cursor-based pagination
to the /api/v2/search endpoint following the patterns documented in the
research output.
```

Execute the plan:

Select **task-implementor** agent:

```text
Build the webhook delivery system following the plan in
.copilot-tracking/plans/webhook-delivery-plan.md. Start with the event
dispatcher component and implement the retry queue second.
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
/task-review Validate the pagination implementation against the plan.
Check cursor encoding, page size limits, response envelope consistency,
and error handling for invalid cursor values.
```

## Stage Outputs and Next Stage

Implementation produces source code, documentation, notebooks, dashboards, prompt artifacts, and infrastructure definitions. Transition to [Stage 7: Review](review.md) when implementation is complete. Use `/clear` to reset context before starting the review cycle.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
