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

| Tool                     | Type  | How to Invoke               | Purpose                                  |
|--------------------------|-------|-----------------------------|------------------------------------------|
| task-reviewer            | Agent | `@task-reviewer`            | Review implementation against the plan   |
| pr-review                | Agent | `@pr-review`                | Evaluate pull requests for quality       |
| test-streamlit-dashboard | Agent | `@test-streamlit-dashboard` | Test Streamlit dashboard implementations |

### Supporting Agents

| Tool                     | Type  | How to Invoke               | Purpose                                     |
|--------------------------|-------|-----------------------------|---------------------------------------------|
| rpi-validator            | Agent | `@rpi-validator`            | Validate RPI workflow compliance            |
| implementation-validator | Agent | `@implementation-validator` | Check implementation against specifications |
| prompt-tester            | Agent | `@prompt-tester`            | Test prompt engineering artifacts           |
| prompt-evaluator         | Agent | `@prompt-evaluator`         | Evaluate prompt quality and effectiveness   |

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

```text
@task-reviewer Review the implementation against the plan
```

```text
/pull-request Create a PR for the current changes
```

```text
@pr-review Evaluate the open pull request for quality and completeness
```

## Stage Outputs and Next Stage

Review produces reviewed pull requests with feedback, validation reports, and approval decisions. Transition to [Stage 8: Delivery](delivery.md) when the PR is approved. Return to [Stage 6: Implementation](implementation.md) when rework is needed.

## Coverage Notes

> [!NOTE]
> GAP-03: CI failure diagnosis tooling is not available. GAP-06: A review feedback assistant to help authors address reviewer comments does not exist. GAP-18: Security review at the delivery boundary is not yet integrated into the review workflow.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
