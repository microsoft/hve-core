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

| Tool                    | Type  | How to Invoke             | Purpose                                        |
|-------------------------|-------|---------------------------|-------------------------------------------------|
| task-implementor        | Agent | `@task-implementor`       | Build components following plans                 |
| rpi-agent               | Agent | `@rpi-agent`              | Orchestrate research-plan-implement workflow     |
| gen-jupyter-notebook    | Agent | `@gen-jupyter-notebook`   | Create data analysis notebooks                   |
| gen-streamlit-dashboard | Agent | `@gen-streamlit-dashboard`| Generate Streamlit dashboards                    |
| prompt-builder          | Agent | `@prompt-builder`         | Create and refine prompt engineering artifacts   |

### Supporting Agents

| Tool                | Type  | How to Invoke          | Purpose                                    |
|---------------------|-------|------------------------|--------------------------------------------|
| phase-implementor   | Agent | `@phase-implementor`   | Execute individual implementation phases    |
| prompt-updater      | Agent | `@prompt-updater`      | Update existing prompts and instructions    |
| researcher-subagent | Agent | `@researcher-subagent` | Conduct focused research within tasks       |

### Prompts

| Tool               | Type   | How to Invoke        | Purpose                                       |
|---------------------|--------|----------------------|------------------------------------------------|
| rpi                 | Prompt | `/rpi`               | Start the full RPI workflow                    |
| task-implement      | Prompt | `/task-implement`    | Begin implementation of a specific task        |
| prompt-build        | Prompt | `/prompt-build`      | Create a new prompt engineering artifact       |
| prompt-analyze      | Prompt | `/prompt-analyze`    | Analyze prompt quality and effectiveness       |
| prompt-refactor     | Prompt | `/prompt-refactor`   | Refactor and improve existing prompts          |
| git-commit          | Prompt | `/git-commit`        | Stage and commit changes                       |
| git-commit-message  | Prompt | `/git-commit-message`| Generate a commit message for staged changes   |

### Auto-Activated Instructions

All coding standard instructions activate automatically based on file type:

| Instruction    | Activates On              | Purpose                              |
|----------------|---------------------------|--------------------------------------|
| csharp         | `**/*.cs`                 | C# coding standards                  |
| python-script  | `**/*.py`                 | Python scripting standards            |
| bash           | `**/*.sh`                 | Bash script standards                 |
| bicep          | `**/bicep/**`             | Bicep infrastructure standards        |
| terraform      | `**/*.tf`                 | Terraform infrastructure standards    |
| workflows      | `.github/workflows/*.yml` | GitHub Actions workflow standards     |
| markdown       | `**/*.md`                 | Markdown formatting rules             |
| writing-style  | `**/*.md`                 | Voice and tone conventions            |
| prompt-builder | AI artifacts              | Prompt engineering authoring standards |
| hve-core-location | `**`                   | Reference resolution for hve-core     |

### Skills

| Tool         | Type  | How to Invoke    | Purpose                           |
|--------------|-------|------------------|------------------------------------|
| video-to-gif | Skill | Referenced in chat | Convert video to optimized GIFs  |

## Role-Specific Guidance

Engineers are the primary users of Implementation, spending the majority of their engagement time here. Tech Leads contribute architecture-sensitive implementations. Data Scientists use notebook and dashboard generators. SREs handle infrastructure code. New Contributors start with guided tasks.

* [Engineer Guide](../roles/engineer.md)
* [Tech Lead Guide](../roles/tech-lead.md)
* [Data Scientist Guide](../roles/data-scientist.md)
* [SRE/Operations Guide](../roles/sre-operations.md)
* [New Contributor Guide](../roles/new-contributor.md)

## Starter Prompts

```text
/rpi Implement the feature described in work item #{id}
```

```text
@task-implementor Build the {component} following the plan in .copilot-tracking/plans/
```

```text
@gen-jupyter-notebook Create a data analysis notebook for {dataset}
```

## Stage Outputs and Next Stage

Implementation produces source code, documentation, notebooks, dashboards, prompt artifacts, and infrastructure definitions. Transition to [Stage 7: Review](review.md) when implementation is complete. Use `/clear` to reset context before starting the review cycle.

## Coverage Notes

> [!NOTE]
> GAP-02: Pre-submit validation is not automated. GAP-11: Rust language instructions are missing. GAP-12: GitHub Actions workflow instructions need expansion. GAP-04: An artifact type advisor to guide users toward the right artifact kind does not exist yet. GAP-05: Duplicate detection across prompt engineering artifacts is not available.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
