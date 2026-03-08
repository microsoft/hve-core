---
title: Project Planning Agents
description: Agents for requirements gathering, architecture decisions, and security planning
sidebar_position: 1
author: Microsoft
ms.date: 2026-03-07
ms.topic: concept
---

Five agents support structured project planning across requirements, architecture, and security. Each agent follows a guided workflow to produce specific deliverables, from business requirements documents to security assessment plans.

## Why Use Project Planning Agents

These agents bring structure and consistency to activities that teams often handle ad-hoc:

* Guided workflows walk users through each planning activity step by step, reducing ramp-up time and removing guesswork from unfamiliar processes.
* Every output follows a repeatable template, making documents easier to review, compare, and maintain across projects.
* Architecture decision records and security plans are generated alongside the reasoning that produced them, preserving institutional knowledge.
* Requirements agents persist session state, so multi-day planning efforts pick up where they left off.
* Business analysts, architects, and security engineers share a common toolchain, reducing handoff friction between planning stages.

> [!TIP]
> Project planning agents work best when invoked early in a project lifecycle. Start with requirements gathering, then move to architecture decisions and security planning as the design matures.

## Agent Overview

| Agent                                             | Sub-Category | Workflow          | Persistence    | Key Output                     |
|---------------------------------------------------|--------------|-------------------|----------------|--------------------------------|
| [BRD Builder](brd-prd-builders.md)                | Requirements | 7-phase Q&A       | JSON state     | Business requirements document |
| [PRD Builder](brd-prd-builders.md)                | Requirements | 7-phase Q&A       | JSON state     | Product requirements document  |
| [ADR Creation Coach](adr-creation.md)             | Architecture | 4-phase Socratic  | Markdown draft | Architecture decision record   |
| [Arch Diagram Builder](arch-diagram-builder.md)   | Architecture | 4-stage analysis  | None           | ASCII architecture diagram     |
| [Security Plan Creator](security-plan-creator.md) | Security     | 5-phase blueprint | Markdown plan  | Security assessment plan       |

## Requirements

The BRD Builder and PRD Builder share a 7-phase workflow that guides users through structured question-and-answer sessions to produce comprehensive requirements documents. Both agents persist session state as JSON files, supporting pause-and-resume workflows across conversations. Their twin architecture means 80% of concepts transfer between them. Learn one, and the other follows naturally.

> [!NOTE]
> BRD and PRD builders share the same underlying workflow engine. Switching between them mid-project requires only a scope adjustment, not a restart.

See the [BRD & PRD Builders](brd-prd-builders.md) guide for the shared workflow, feature comparison, and invocation details.

## Architecture

Two agents address architecture documentation from different angles. The ADR Creation Coach uses Socratic questioning to guide users through structured reasoning about technical decisions, producing architecture decision records. The Arch Diagram Builder analyzes infrastructure-as-code files and project structure to generate ASCII architecture diagrams directly in conversation.

> [!TIP]
> Pair the ADR Creation Coach with the Arch Diagram Builder: create an ADR for a design decision, then generate a diagram showing how the chosen approach fits the broader architecture.

* [ADR Creation Coach](adr-creation.md): Guided decision reasoning and documentation
* [Arch Diagram Builder](arch-diagram-builder.md): Code-to-diagram generation from IaC analysis

## Security

The Security Plan Creator applies an 8-category threat analysis framework to generate security assessment plans. It walks through scope definition, threat analysis, risk assessment, mitigation planning, and plan generation. The agent uses a template-guided approach with structured persistence for tracking plan progress.

> [!IMPORTANT]
> Run security planning after architecture decisions stabilize. Changes to infrastructure or service boundaries may invalidate earlier threat assessments.

See the [Security Plan Creator](security-plan-creator.md) guide for the workflow, threat categories, and invocation details.

## Prerequisites

* VS Code with the GitHub Copilot Chat extension installed
* Agent definition files from the `project-planning` collection deployed to `.github/agents/`
* For BRD/PRD builders: a writable `.copilot-tracking/` directory for session state persistence
* For Arch Diagram Builder: infrastructure-as-code files (Terraform, Bicep, ARM, Kubernetes YAML, or Docker Compose) in the repository

## Getting Started

Invoke any agent by mentioning it in Copilot Chat. Each agent starts its guided workflow automatically.

| Scenario               | Agent                            | Purpose                                                                    |
|------------------------|----------------------------------|----------------------------------------------------------------------------|
| New project kickoff    | `@brd-builder` or `@prd-builder` | Capture requirements before making architecture decisions                  |
| Architecture decisions | `@adr-creation`                  | Evaluate technology choices, design patterns, or infrastructure approaches |
| Visual documentation   | `@arch-diagram-builder`          | Generate architecture diagrams for onboarding or reviews                   |
| Security review        | `@security-plan-creator`         | Assess threats and plan mitigations after architecture decisions stabilize |

### Recommended Sequencing

For greenfield projects, follow this order to build artifacts that feed into each subsequent step:

1. Start with `@brd-builder` to capture business context, then `@prd-builder` for product-level details.
2. Use `@adr-creation` to document key design decisions, then `@arch-diagram-builder` to visualize the resulting architecture.
3. Run `@security-plan-creator` once the architecture is stable to identify threats and plan mitigations.

## Related Documentation

* [RPI Documentation](../../rpi/README.md): Task research, planning, and implementation workflows
* [GitHub Backlog Manager](../github-backlog/README.md): Issue lifecycle management for GitHub repositories
* [ADO Backlog Manager](../ado-backlog/README.md): Work item management for Azure DevOps projects

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
