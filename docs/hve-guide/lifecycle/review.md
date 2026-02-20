---
title: "Stage 7: Review"
description: Validate implementations through code review, PR management, and quality assessment
author: Microsoft
ms.date: 2026-02-18
ms.topic: how-to
keywords:
  - ai-assisted project lifecycle
  - review
  - pull request
  - code review
  - quality
estimated_reading_time: 6
---

## Overview

Review validates that implementations meet acceptance criteria and quality standards before delivery. This stage covers code review, pull request creation, dashboard testing, prompt evaluation, and implementation validation against plans.

## When You Enter This Stage

You enter Review after completing implementation work in [Stage 6: Implementation](implementation.md).

> [!NOTE]
> Prerequisites: Implementation complete with all changes committed. Use `/clear` to reset context before starting review.

## Available Tools

### Primary Agents

| Tool                     | Type  | How to Invoke                             | Purpose                                  |
|--------------------------|-------|-------------------------------------------|------------------------------------------|
| task-reviewer            | Agent | Select **task-reviewer** agent            | Review implementation against the plan   |
| pr-review                | Agent | Select **pr-review** agent                | Evaluate pull requests for quality       |
| test-streamlit-dashboard | Agent | Select **test-streamlit-dashboard** agent | Test Streamlit dashboard implementations |

### Supporting Agents

| Tool                     | Type  | How to Invoke                             | Purpose                                     |
|--------------------------|-------|-------------------------------------------|---------------------------------------------|
| rpi-validator            | Agent | Select **rpi-validator** agent            | Validate RPI workflow compliance            |
| implementation-validator | Agent | Select **implementation-validator** agent | Check implementation against specifications |
| prompt-tester            | Agent | Select **prompt-tester** agent            | Test prompt engineering artifacts           |
| prompt-evaluator         | Agent | Select **prompt-evaluator** agent         | Evaluate prompt quality and effectiveness   |

### Prompts and Instructions

| Tool                    | Type        | How to Invoke              | Purpose                                     |
|-------------------------|-------------|----------------------------|---------------------------------------------|
| task-review             | Prompt      | `/task-review`             | Start a structured task review              |
| pull-request            | Prompt      | `/pull-request`            | Create a pull request for current changes   |
| ado-create-pull-request | Prompt      | `/ado-create-pull-request` | Create an ADO-linked pull request           |
| doc-ops-update          | Prompt      | `/doc-ops-update`          | Update documentation alongside code changes |
| commit-message          | Instruction | Auto-activated             | Enforces commit message conventions         |
| community-interaction   | Instruction | Auto-activated             | Enforces community communication standards  |

## Role-Specific Guidance

Engineers submit work for review and participate as peer reviewers. Tech Leads serve as primary reviewers, evaluating architecture alignment and code quality. Data Scientists review notebooks and dashboard outputs. Security Architects validate implementation against security requirements and compliance standards.

* [Engineer Guide](../roles/engineer.md)
* [Tech Lead Guide](../roles/tech-lead.md)
* [Data Scientist Guide](../roles/data-scientist.md)
* [Security Architect Guide](../roles/security-architect.md)

## Starter Prompts

### Implementation Review

Select **task-reviewer** agent:

```text
Review today's changes to the authentication service against .copilot-tracking/plans/2025-01-15/auth-refactor-plan.instructions.md and check for missing input validation on the new endpoints
```

```text
/task-review scope=today
```

```text
/task-review plan=.copilot-tracking/plans/2025-01-15/pagination-plan.instructions.md changes=.copilot-tracking/changes/2025-01-15/pagination-changes.md research=.copilot-tracking/research/2025-01-15/pagination-research.md
```

### Pull Request Workflow

```text
/pull-request branch=origin/main excludeMarkdown=true
```

```text
/ado-create-pull-request adoProject=hve-core baseBranch=origin/main isDraft=true workItemIds=54321,54322
```

Select **pr-review** agent:

```text
Review the open PR for the payment processing refactor, focusing on breaking changes to the /api/payments endpoint and any exposed credentials in configuration files
```

### Dashboard Testing

Select **test-streamlit-dashboard** agent:

```text
Test the sensor monitoring dashboard at src/dashboards/sensor_monitor.py, verifying that temperature readings render within the 15-45°C expected range and all navigation links resolve correctly
```

### Quality Validation

Select **rpi-validator** agent:

```text
Validate phase 2 of .copilot-tracking/plans/2025-01-15/api-redesign-plan.instructions.md against .copilot-tracking/changes/2025-01-15/api-redesign-changes.md
```

Select **implementation-validator** agent:

```text
Run full-quality validation on the files changed in src/services/auth/ against the architecture requirements in docs/architecture/auth-design.md
```

Select **prompt-tester** agent:

```text
Execute .github/prompts/rpi/task-review.prompt.md literally in a sandbox to verify the review workflow produces expected validation outputs
```

Select **prompt-evaluator** agent:

```text
Evaluate the execution log from .copilot-tracking/sandbox/2025-01-15-task-review-001/execution-log.md against the prompt quality criteria in .github/instructions/rpi/prompt-builder.instructions.md
```

### Documentation Review

```text
/doc-ops-update scope=docs/hve-guide/lifecycle validateOnly=true focus=accuracy
```

## Stage Outputs and Next Stage

Review produces reviewed pull requests with feedback, validation reports, and approval decisions. Transition to [Stage 8: Delivery](delivery.md) when the PR is approved. Return to [Stage 6: Implementation](implementation.md) when rework is needed.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
