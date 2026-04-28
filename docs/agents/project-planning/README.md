---
title: Project Planning Agents
description: Agents for requirements gathering, architecture decisions, and security planning
sidebar_position: 1
author: Microsoft
ms.date: 2026-04-23
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

| Agent                                           | Sub-Category | Workflow         | Persistence    | Key Output                            |
|-------------------------------------------------|--------------|------------------|----------------|---------------------------------------|
| [Requirements Builder](requirements-builder.md) | Requirements | 6-phase FSI      | JSON state     | PRDs, BRDs, and future MRDs/FRDs/SRSs |
| [ADR Creation Coach](adr-creation.md)           | Architecture | 4-phase Socratic | Markdown draft | Architecture decision record          |
| [Arch Diagram Builder](arch-diagram-builder.md) | Architecture | 4-stage analysis | None           | ASCII architecture diagram            |
| [Security Planner](../security/README.md)       | Security     | 6-phase STRIDE   | JSON state     | Security model and backlog            |

> [!NOTE]
> The legacy `brd-builder` and `prd-builder` agents are deprecated and now stub-redirect to Requirements Builder. Existing sessions under `.copilot-tracking/prd-sessions/` and `.copilot-tracking/brd-sessions/` remain readable; new work writes to `.copilot-tracking/requirements-sessions/`.

## Requirements

The [Requirements Builder](requirements-builder.md) is a single, unified agent for authoring PRDs, BRDs, and future requirements documents (MRD, FRD, SRS, custom org templates).
It runs a six-phase pipeline (identity → intake → template-selection → drafting → review → handoff) and loads document styles as [Framework Skill Interface (FSI)](../../announcements/framework-skill-interfaces.md) framework skills under `.github/skills/requirements/`. Pick one or more document styles at the framework gate and draft them in a single session.

> [!TIP]
> To add a new document style (MRD, FRD, internal template), author a new FSI framework skill rather than modifying the agent. See [Authoring Framework Skills with Prompt Builder](../../customization/authoring-framework-skills.md).

See the [Requirements Builder](requirements-builder.md) guide for the six-phase workflow, framework gate, entry modes, and invocation details.

## Architecture

Two agents address architecture documentation from different angles. The ADR Creation Coach uses Socratic questioning to guide users through structured reasoning about technical decisions, producing architecture decision records. The Arch Diagram Builder analyzes infrastructure-as-code files and project structure to generate ASCII architecture diagrams directly in conversation.

> [!TIP]
> Pair the ADR Creation Coach with the Arch Diagram Builder: create an ADR for a design decision, then generate a diagram showing how the chosen approach fits the broader architecture.

* [ADR Creation Coach](adr-creation.md): Guided decision reasoning and documentation
* [Arch Diagram Builder](arch-diagram-builder.md): Code-to-diagram generation from IaC analysis

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
* For Arch Diagram Builder: infrastructure-as-code files (Terraform, Bicep, ARM, Kubernetes YAML, or Docker Compose) in the repository

## Getting Started

Select any agent using the agent picker in the Copilot Chat pane. Each agent starts its guided workflow automatically.

| Scenario               | Agent                | Purpose                                                                    |
|------------------------|----------------------|----------------------------------------------------------------------------|
| New project kickoff    | Requirements Builder | Capture business and/or product requirements before architecture decisions |
| Architecture decisions | ADR Creation Coach   | Evaluate technology choices, design patterns, or infrastructure approaches |
| Visual documentation   | Arch Diagram Builder | Generate architecture diagrams for onboarding or reviews                   |
| Security review        | Security Planner     | Assess threats and plan mitigations after architecture decisions stabilize |

### Recommended Sequencing

For greenfield projects, follow this order to build artifacts that feed into each subsequent step:

1. Start with the Requirements Builder; select `requirements-brd` for business context and `requirements-prd` for product-level details (single session or sequential).
2. Use the ADR Creation Coach to document key design decisions, then the Arch Diagram Builder to visualize the resulting architecture.
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
