---
title: Agent Systems Catalog
description: Overview of all hve-core agent systems with workflow documentation and quick links
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-06
ms.topic: overview
keywords:
  - github copilot
  - agents
  - agent catalog
estimated_reading_time: 5
---

hve-core organizes specialized agents into functional groups. Each group combines agents, prompts, and instruction files into cohesive workflows for specific engineering tasks.

| Group                                     | Agents   | Complexity  | Documentation                                                                                                                  |
|-------------------------------------------|----------|-------------|--------------------------------------------------------------------------------------------------------------------------------|
| RPI Orchestration                         | 1        | High        | [RPI Documentation](../rpi/README.md)                                                                                          |
| [Code Review](#code-review)               | 3        | Medium      | [Code Review](code-review/README.md)                                                                                           |
| [Backlog Management](#backlog-management) | 2 active | Very High   | [Backlog Management](backlog/README.md)                                                                                        |
| [Project Planning](#project-planning)     | 9        | Medium-High | [Project Planning](project-planning/README.md)                                                                                 |
| [Security Planning](#security-planning)   | 3 active | Very High   | [Security Planner](security/README.md), [SSSC Planner](sssc-planning/README.md)                                                |
| [RAI Planning](#rai-planning)             | 1 active | Very High   | [RAI Planner](rai-planning/README.md)                                                                                          |
| [Data Science](#data-science)             | 5        | Medium      | Data Science                                                                                                                   |
| Experimental                              | 2        | Medium      | Experiment Designer                                                                                                            |
| DevOps Quality                            | 1        | High        | Planned                                                                                                                        |
| Meta/Engineering                          | 1        | High        | `hve-builder`, [Documentation](https://github.com/microsoft/hve-core/blob/main/.github/agents/hve-core/documentation.agent.md) |
| Infrastructure                            | 1        | Very High   | Planned                                                                                                                        |
| [Design Thinking](#design-thinking)       | 2        | High        | Active                                                                                                                         |

## RPI Orchestration

The Research, Plan, Implement, Review methodology separates complex tasks into specialized phases. RPI Agent coordinates `rpi-research`, `rpi-plan`, `rpi-implement`, and `rpi-review` through durable artifacts. The self-contained `rpi-challenger` skill complements the lifecycle by challenging a confirmed subject through adaptive skeptical questions. See the [RPI Documentation](../rpi/) for the full guide.

## Code Review

A single human-gated Code Review agent provides pre-PR review on local branches. It confirms scope with you, then dispatches the perspectives you choose, functional, standards, accessibility, security, and PR, each to a thin skill-backed subagent, and merges them into one deduplicated report. A depth tier (basic, standard, or comprehensive) controls how deeply each perspective verifies the change. See the [Code Review Documentation](code-review/) for usage guides and skill authoring.

## Backlog Management

Automates work discovery, triage, sprint planning, task planning, and execution across Azure DevOps, GitHub, and Jira. One set of workflows serves all three: the commands resolve which tracker backs the workspace at runtime, so there is no per-platform variant to choose.

`backlog-plan` covers the read-only half and `backlog-execute` covers every tracker mutation, gated by three-tier autonomy, dry-run preview, and content sanitization. The Backlog Manager agent orchestrates both across a longer session, and the Functional Planner agent converts a PRD into a planned hierarchy. See the [Backlog Management Documentation](backlog/README.md) for workflow guides and per-platform differences.

### Azure DevOps Delivery Workflows

Three workflows have no cross-platform equivalent and remain Azure DevOps only:

| Workflow              | Documentation                                       |
|-----------------------|-----------------------------------------------------|
| Build monitoring      | [Build Monitoring](ado-backlog/build-monitoring.md) |
| Pull request creation | [Pull Request Creation](ado-backlog/pr-creation.md) |
| PRD planning          | [PRD Planning](ado-backlog/prd-planning.md)         |

## Project Planning

Specialized agents for project planning activities. Includes builders for Business Requirements Documents, Product Requirements Documents, and Architecture Decision Records, plus meeting analysis, network ISA-95 planning, system architecture review, and UX/UI design.

Agile story coaching now runs inside the backlog skill's work-item quality reference rather than as a separate agent, and architecture diagrams are delivered through the portable architecture-diagrams skill. See the [Project Planning Agents](project-planning/README.md).

## Data Science

Five agents handle evaluation dataset creation, data specification generation, Jupyter notebook generation, and Streamlit dashboard generation and testing.

## Experimental

Exploratory agents for emerging workflows. Includes the Experiment Designer for minimum viable experiment (MVE) coaching and the PowerPoint Builder for YAML-driven slide deck generation.

## DevOps Quality

Agents focused on deployment reliability and build pipeline analysis.

## Meta/Engineering

The `hve-builder` skill creates, improves, refactors, reviews, and validates prompt-engineering artifacts through independent quality gates. The Documentation agent coordinates documentation audit, drift, authoring, and validation across the repository through its four modes.

## Infrastructure

Manages cloud infrastructure provisioning and configuration. Handles Bicep and Terraform deployments with validation and drift detection.

## Security Planning

Guides teams through a six-phase security assessment covering system scoping, operational bucketing, standards mapping, security model analysis, impact assessment, and backlog handoff. The security planner agent conducts interactive sessions with structured state tracking and produces dual-platform work items for ADO and GitHub. The security reviewer agent performs automated security analysis of code changes. See the [Security Planner Documentation](security/) for phase details and entry modes.

The **SSSC Planner** guides teams through a structured six-phase supply chain security assessment. It inventories 27 supply chain capabilities, maps against OpenSSF Scorecard, SLSA, Sigstore, and SBOM standards, performs gap analysis with adoption categories, and generates priority-sorted backlog items. Supports four entry modes: capture, from-PRD, from-BRD, and from-security-plan. See [SSSC Planning](sssc-planning/README.md) for details.

## RAI Planning

Guides teams through a six-phase responsible AI assessment planning workflow covering AI system scoping, risk classification, RAI standards mapping, security model analysis, impact assessment, and review with backlog handoff. The RAI planner agent builds on security plan outputs when available and produces dual-platform work items for identified gaps. See the [RAI Planner Documentation](rai-planning/) for phase details and entry modes.

## Design Thinking

The Design Thinking agents provide AI-assisted coaching through a nine-method, three-space framework for human-centered design.

| Agent               | Purpose                                                      |
|---------------------|--------------------------------------------------------------|
| `dt-coach`          | Coaches teams through all 9 DT methods with session tracking |
| `dt-learning-tutor` | Teaches DT curriculum with exercises and assessments         |

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
