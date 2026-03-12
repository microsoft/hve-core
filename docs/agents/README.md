---
title: Agent Systems Catalog
description: Overview of all hve-core agent systems with workflow documentation and quick links
sidebar_position: 1
author: Microsoft
ms.date: 2026-02-12
ms.topic: overview
keywords:
  - github copilot
  - agents
  - agent catalog
estimated_reading_time: 5
---

hve-core organizes specialized agents into functional groups. Each group combines agents, prompts, and instruction files into cohesive workflows for specific engineering tasks.

| Group                                   | Agents   | Complexity  | Documentation                                                        |
|-----------------------------------------|----------|-------------|----------------------------------------------------------------------|
| RPI Orchestration                       | 5        | High        | [RPI Documentation](../rpi/README.md)                                |
| GitHub Backlog Management               | 1 active | Very High   | [Backlog Manager](github-backlog/README.md)                          |
| ADO Backlog Management                  | 1 active | Very High   | [Backlog Manager](ado-backlog/README.md)                             |
| Project Planning                        | 5        | Medium-High | [Project Planning](project-planning/README.md)                       |
| [Security Planning](#security-planning) | 1 active | Very High   | [Security Planner](security-planning/README.md)                      |
| [RAI Planning](#rai-planning)           | 1 active | Very High   | [RAI Planner](rai-planning/README.md)                                |
| Document Builders                       | 4        | Medium-High | Planned                                                              |
| Data Pipeline                           | 4        | Medium      | Planned                                                              |
| DevOps Quality                          | 2        | High        | Planned                                                              |
| Meta/Engineering                        | 1        | High        | Planned                                                              |
| Infrastructure                          | 1        | Very High   | Planned                                                              |
| Utility                                 | 1        | Low-Medium  | [Memory Agent](github-backlog/using-together.md#session-persistence) |
| [Design Thinking](#design-thinking)     | 2        | High        | Active                                                               |

## RPI Orchestration

The Research, Plan, Implement methodology separates complex tasks into specialized phases. Five agents (task-researcher, task-planner, task-implementor, task-reviewer, and the RPI orchestrator) coordinate through planning files to deliver structured engineering workflows. See the [RPI Documentation](../rpi/) for the full guide.

## GitHub Backlog Management

Automates issue discovery, triage, sprint planning, and execution across GitHub repositories. The backlog manager agent orchestrates five distinct workflows with three-tier autonomy control. See the [Backlog Manager Documentation](github-backlog/) for workflow guides.

## ADO Backlog Management

Automates work item discovery, triage, sprint planning, execution, PR creation, build monitoring, and task planning across Azure DevOps projects. The ADO Backlog Manager agent orchestrates nine distinct workflows with three-tier autonomy control. See the [Backlog Manager Documentation](ado-backlog/README.md) for workflow guides.

## Project Planning

Five specialized agents for project planning activities. Includes builders for Business Requirements Documents, Product Requirements Documents, Architecture Decision Records, architecture diagrams, and security plans. See the [Project Planning Agents](project-planning/README.md) for detailed documentation.

## Data Pipeline

Processes and transforms data across formats and systems. Four agents handle data extraction, transformation, validation, and loading workflows.

## DevOps Quality

Two agents focused on code quality and deployment reliability. Covers PR review automation and build pipeline analysis.

## Meta/Engineering

The prompt builder agent creates and validates prompt engineering artifacts. Supports interactive authoring with sandbox testing for prompts, instructions, agents, and skills.

## Infrastructure

Manages cloud infrastructure provisioning and configuration. Handles Bicep and Terraform deployments with validation and drift detection.

## Utility

General-purpose agents for cross-cutting concerns such as session persistence and context management across workflows.

## Security Planning

Guides teams through a six-phase security assessment covering system scoping, operational bucketing, standards mapping, security model analysis, impact assessment, and backlog handoff. The security planner agent conducts interactive sessions with structured state tracking and produces dual-platform work items for ADO and GitHub. See the [Security Planner Documentation](security-planning/) for phase details and entry modes.

## RAI Planning

Guides teams through a six-phase responsible AI assessment covering AI system scoping, sensitive uses screening, RAI standards mapping, security model analysis, impact assessment, and review with backlog handoff. The RAI planner agent builds on security plan outputs when available and produces scored assessments with dual-platform work items. See the [RAI Planner Documentation](rai-planning/) for phase details and entry modes.

## Design Thinking

The Design Thinking agents provide AI-assisted coaching through a nine-method, three-space framework for human-centered design.

| Agent               | Purpose                                                      |
|---------------------|--------------------------------------------------------------|
| `dt-coach`          | Coaches teams through all 9 DT methods with session tracking |
| `dt-learning-tutor` | Teaches DT curriculum with exercises and assessments         |

> Brought to you by microsoft/hve-core

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
