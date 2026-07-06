---
title: Project Planning Agents
description: Agents for requirements gathering, architecture decisions, and security planning
sidebar_position: 1
author: Microsoft
ms.date: 2026-06-29
ms.topic: concept
---

Four agents and one portable skill support structured project planning across requirements, architecture, and security. Each agent follows a guided workflow to produce specific deliverables, from business requirements documents to security assessment plans.

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

| Agent                                     | Sub-Category | Workflow                    | Persistence | Key Output                     |
|-------------------------------------------|--------------|-----------------------------|-------------|--------------------------------|
| [BRD Builder](brd-prd-builders)           | Requirements | 3-phase Q&A                 | JSON state  | Business requirements document |
| [PRD Builder](brd-prd-builders)           | Requirements | 7-phase Q&A                 | JSON state  | Product requirements document  |
| [ADR Creator](adr-creation)               | Architecture | 3-phase Frame/Decide/Govern | JSON state  | Architecture decision record   |
| [Security Planner](../security/README.md) | Security     | 6-phase STRIDE              | JSON state  | Security model and backlog     |

## Requirements

The BRD Builder follows a three-phase lifecycle (Discover, Define, Govern) and the PRD Builder follows a seven-phase lifecycle (Assess, Discover, Create, Build, Integrate, Validate, Finalize), both driven by the `requirements-author` skill. Both agents persist session state as JSON files, supporting pause-and-resume workflows across conversations. Their twin architecture means most concepts transfer between them. Learn one, and the other follows naturally.

> [!NOTE]
> BRD and PRD builders share the same underlying workflow engine. Switching between them mid-project requires only a scope adjustment, not a restart.

See the [BRD & PRD Builders](brd-prd-builders) guide for the shared workflow, feature comparison, and invocation details.

## Architecture

Two agents address architecture documentation from different angles. The ADR Creator uses phase-gated, standards-aligned reasoning to guide users through technical decisions (Frame, Decide, Govern), producing architecture decision records. The [architecture-diagrams skill](pathname://../../../.github/skills/hve-core/architecture-diagrams/SKILL.md) analyzes infrastructure-as-code files and project structure to generate ASCII architecture diagrams directly in conversation.

> [!TIP]
> Pair the ADR Creator with the [architecture-diagrams skill](pathname://../../../.github/skills/hve-core/architecture-diagrams/SKILL.md): create an ADR for a design decision, then generate a diagram showing how the chosen approach fits the broader architecture.

* [ADR Creator](adr-creation): Guided decision reasoning and documentation
* [architecture-diagrams skill](pathname://../../../.github/skills/hve-core/architecture-diagrams/SKILL.md): Code-to-diagram generation from IaC analysis

## Security

The Security Planner applies STRIDE-based security model analysis across seven operational buckets to produce standards mappings and dual-format backlog handoff. It detects AI/ML components and recommends RAI Planner dispatch when AI elements are present. The agent uses a six-phase conversational workflow with JSON state persistence for tracking plan progress.

> [!IMPORTANT]
> Run security planning after architecture decisions stabilize. Changes to infrastructure or service boundaries may invalidate earlier security models.

See the [Security Planning](../security/README.md) guide for the workflow, operational buckets, and invocation details.

## Prerequisites

* VS Code with the GitHub Copilot Chat extension installed
* Agent definition files from the `project-planning` collection deployed to `.github/agents/`
* For Security Planner: agent definition files from the `security` collection
* For BRD/PRD builders: a writable `.copilot-tracking/` directory for session state persistence
* For diagram generation: the [architecture-diagrams skill](pathname://../../../.github/skills/hve-core/architecture-diagrams/SKILL.md) works with infrastructure-as-code files (Terraform, Bicep, ARM, Kubernetes YAML, or Docker Compose) in the repository

## Getting Started

Select any agent using the agent picker in the Copilot Chat pane. Each agent starts its guided workflow automatically.

| Scenario               | Agent                       | Purpose                                                                    |
|------------------------|-----------------------------|----------------------------------------------------------------------------|
| New project kickoff    | BRD Builder or PRD Builder  | Capture requirements before making architecture decisions                  |
| Architecture decisions | ADR Creator                 | Evaluate technology choices, design patterns, or infrastructure approaches |
| Visual documentation   | architecture-diagrams skill | Generate ASCII or Mermaid architecture diagrams for onboarding or reviews  |
| Security review        | Security Planner            | Assess threats and plan mitigations after architecture decisions stabilize |

### Recommended Sequencing

For greenfield projects, follow this order to build artifacts that feed into each subsequent step:

1. Start with the BRD Builder to capture business context, then the PRD Builder for product-level details.
2. Use the ADR Creator to document key design decisions, then the architecture-diagrams skill to visualize the resulting architecture.
3. Run the Security Planner once the architecture is stable to identify threats and plan mitigations.

## Related Documentation

* [RPI Documentation](../../rpi/README.md): Task research, planning, and implementation workflows
* [GitHub Backlog Manager](../github-backlog/README.md): Issue lifecycle management for GitHub repositories
* [ADO Backlog Manager](../ado-backlog/README.md): Work item management for Azure DevOps projects

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
