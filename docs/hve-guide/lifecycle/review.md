---
title: "Stage 7: Review"
description: Validate implementations through code review, PR management, and quality assessment
sidebar_position: 8
author: Microsoft
ms.date: 2026-07-15
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

Review validates that implementations meet acceptance criteria and quality standards before delivery. RPI review reconciles the plan, phase details, critique dispositions, amendments, changes, and validation evidence before routing open work. This stage also covers code review, pull request creation, dashboard testing, and prompt evaluation.

## When You Enter This Stage

You enter Review after completing implementation work in [Stage 6: Implementation](implementation).

> [!NOTE]
> Prerequisites: In-scope implementation is reviewable, with the plan, phase details, changes, and validation evidence available. Commit after the review outcome is conformant or explicitly accepted. Use `/clear` to reset context when a fresh conversation will improve evidence reconciliation.

## Available Tools

### Primary Agents

| Tool                     | Type  | How to Invoke                             | Purpose                                  |
|--------------------------|-------|-------------------------------------------|------------------------------------------|
| code-review              | Agent | Select **code-review** agent              | Multi-perspective review of code changes |
| test-streamlit-dashboard | Agent | Select **test-streamlit-dashboard** agent | Test Streamlit dashboard implementations |

### Review Skills

| Tool        | How to Invoke     | Purpose                                                      |
|-------------|-------------------|--------------------------------------------------------------|
| rpi-review  | `/rpi-review`     | Review implementation evidence against the approved RPI plan |
| hve-builder | Use `hve-builder` | Review or validate prompts, instructions, agents, and skills |

### Prompts and Instructions

| Tool                    | Type        | How to Invoke                  | Purpose                                          |
|-------------------------|-------------|--------------------------------|--------------------------------------------------|
| pr-review               | Prompt      | `/pr-review`                   | Run a multi-perspective review of a pull request |
| pull-request            | Prompt      | `/pull-request`                | Create a pull request for current changes        |
| ado-create-pull-request | Prompt      | `/ado-create-pull-request`     | Create an ADO-linked pull request                |
| documentation           | Agent       | Select **documentation** agent | Audit, drift, author, and validate documentation |
| commit-message          | Instruction | Auto-activated                 | Enforces commit message conventions              |
| community-interaction   | Instruction | Auto-activated                 | Enforces community communication standards       |

## Role-Specific Guidance

Engineers submit work for review and participate as peer reviewers. Tech Leads serve as primary reviewers, evaluating architecture alignment and code quality. Data Scientists review notebooks and dashboard outputs. Security Architects validate implementation against security requirements and compliance standards.

* [Engineer Guide](../roles/engineer)
* [Tech Lead Guide](../roles/tech-lead)
* [Data Scientist Guide](../roles/data-scientist)
* [Security Architect Guide](../roles/security-architect)

## Starter Prompts

### Implementation Review

```text
/rpi-review Review today's changes to the authentication service against
.copilot-tracking/plans/2025-01-15/auth-refactor-plan.md and
.copilot-tracking/details/2025-01-15/auth-refactor-phase-details.md. Reconcile
the `Pxx` and `Pxx-Txx` completion evidence and check for missing input
validation on the new endpoints.
```

```text
/rpi-review plan=.copilot-tracking/plans/2025-01-15/pagination-plan.md details=.copilot-tracking/details/2025-01-15/pagination-phase-details.md critique=.copilot-tracking/reviews/plans/2025-01-15/pagination-plan-critique.md changes=.copilot-tracking/changes/2025-01-15/pagination-changes.md research=.copilot-tracking/research/2025-01-15/pagination-research.md
```

### Pull Request Workflow

```text
/pull-request branch=origin/main excludeMarkdown=true
```

```text
/ado-create-pull-request adoProject=hve-core baseBranch=origin/main isDraft=true workItemIds=54321,54322
```

```text
/pr-review
```

Select **code-review** agent:

```text
Review the open PR for the payment processing refactor, focusing on breaking changes to the /api/payments endpoint and any exposed credentials in configuration files
```

### Dashboard Testing

Select **test-streamlit-dashboard** agent:

```text
Test the sensor monitoring dashboard at src/dashboards/sensor_monitor.py, verifying that temperature readings render within the 15-45°C expected range and all navigation links resolve correctly
```

### RPI Evidence Reconciliation

```text
/rpi-review Review the API redesign evidence set:
- Plan: .copilot-tracking/plans/2025-01-15/api-redesign-plan.md
- Phase details: .copilot-tracking/details/2025-01-15/api-redesign-phase-details.md
- Plan critique: .copilot-tracking/reviews/plans/2025-01-15/api-redesign-plan-critique.md
- Changes: .copilot-tracking/changes/2025-01-15/api-redesign-changes.md

Reconcile requirements, `Pxx` and `Pxx-Txx` completion evidence, amendments, divergences, and validation. Record severity-graded `RV-xxx` findings and route each open item.
```

Use `hve-builder` review mode for an AI artifact:

```text
Use hve-builder with mode=review and
targets=.github/prompts/hve-core/rpi.prompt.md. Evaluate activation,
lifecycle routing, behavior-test requirements, and host compatibility.
```

### Documentation Review

```text
Select documentation agent in validate mode. Scope docs/hve-guide/lifecycle, validation-only, focus accuracy.
```

## Stage Outputs and Next Stage

Review produces reviewed pull requests with feedback, validation reports, and approval decisions. Transition to [Stage 8: Delivery](delivery) when the PR is approved. Return to [Stage 6: Implementation](implementation) when rework is needed.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
