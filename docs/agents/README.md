---
title: Agent Systems Catalog
description: Overview of all hve-core agent systems with workflow documentation and quick links
sidebar_position: 1
author: Microsoft
ms.date: 2026-06-25
ms.topic: overview
keywords:
  - github copilot
  - agents
  - agent catalog
estimated_reading_time: 5
---

hve-core organizes specialized agents into functional groups. Each group combines agents, prompts, and instruction files into cohesive workflows for specific engineering tasks.

| Group                                   | Agents   | Complexity  | Documentation                                                                                                                                                      |
|-----------------------------------------|----------|-------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| RPI Orchestration                       | 6        | High        | [RPI Documentation](../rpi/README.md)                                                                                                                              |
| [Code Review](#code-review)             | 3        | Medium      | [Code Review](code-review/README.md)                                                                                                                               |
| [PR Walkthrough](#pr-walkthrough)       | 1        | Medium      | [PR Walkthrough](pr-walkthrough/README.md)                                                                                                                         |
| GitHub Backlog Management               | 1 active | Very High   | [Backlog Manager](github-backlog/README.md)                                                                                                                        |
| ADO Backlog Management                  | 2 active | Very High   | [Backlog Manager](ado-backlog/README.md)                                                                                                                           |
| Jira Backlog Management                 | 2 active | Very High   | Backlog Manager                                                                                                                                                    |
| [Project Planning](#project-planning)   | 10       | Medium-High | [Project Planning](project-planning/README.md)                                                                                                                     |
| [Security Planning](#security-planning) | 3 active | Very High   | [Security Planner](security/README.md), [SSSC Planner](sssc-planning/README.md)                                                                                    |
| [RAI Planning](#rai-planning)           | 1 active | Very High   | [RAI Planner](rai-planning/README.md)                                                                                                                              |
| [Data Science](#data-science)           | 5        | Medium      | Data Science                                                                                                                                                       |
| Experimental                            | 2        | Medium      | Experiment Designer                                                                                                                                                |
| DevOps Quality                          | 1        | High        | Planned                                                                                                                                                            |
| Meta/Engineering                        | 2        | High        | [Prompt Builder](../contributing/instructions.md), [Documentation](https://github.com/microsoft/hve-core/blob/main/.github/agents/hve-core/documentation.agent.md) |
| Infrastructure                          | 1        | Very High   | Planned                                                                                                                                                            |
| Utility                                 | 1        | Low-Medium  | [Memory Agent](github-backlog/using-together.md#session-persistence)                                                                                               |
| [Design Thinking](#design-thinking)     | 2        | High        | Active                                                                                                                                                             |

## RPI Orchestration

The Research, Plan, Implement methodology separates complex tasks into specialized phases. Six agents (task-researcher, task-planner, task-implementor, task-reviewer, task-challenger, and the RPI orchestrator) coordinate through planning files to deliver structured engineering workflows. See the [RPI Documentation](../rpi/) for the full guide.

## Code Review

Three agents provide pre-PR code review on local branches. Code Review Functional catches logic errors, edge cases, and error handling gaps across five focus areas. Code Review Standards enforces project-defined conventions through dynamically loaded language skills. Code Review Full orchestrates both in a single pass and produces a merged, deduplicated report. See the [Code Review Documentation](code-review/) for usage guides and skill authoring.

## PR Walkthrough

A narrative orientation agent that builds a reviewer's mental model before they open the diff. Produces a flowing essay structured around decisions and design forks rather than a file-by-file summary. Useful for large PRs, cross-cutting refactors, and onboarding reviewers who lack context. Marked experimental. See the [PR Walkthrough Documentation](pr-walkthrough/) for usage.

## GitHub Backlog Management

Automates issue discovery, triage, sprint planning, and execution across GitHub repositories. The backlog manager agent orchestrates five distinct workflows with three-tier autonomy control. See the [Backlog Manager Documentation](github-backlog/) for workflow guides.

## ADO Backlog Management

Automates work item discovery, triage, sprint planning, execution, PR creation, build monitoring, and task planning across Azure DevOps projects. The ADO Backlog Manager agent orchestrates nine distinct workflows with three-tier autonomy control. The PRD-to-WIT agent translates product requirements into structured work items. See the [Backlog Manager Documentation](ado-backlog/README.md) for workflow guides.

## Jira Backlog Management

Automates issue discovery, triage, execution, and PRD-to-issue translation across Jira projects. The Jira Backlog Manager agent orchestrates workflows with three-tier autonomy control, mirroring the GitHub and ADO backlog management patterns.

## Project Planning

Ten specialized agents for project planning activities. Includes builders for Business Requirements Documents, Product Requirements Documents, Architecture Decision Records, architecture diagrams, agile coaching, meeting analysis, network ISA-95 planning, product manager advising, system architecture review, and UX/UI design. See the [Project Planning Agents](project-planning/README.md) for detailed documentation.

## Data Science

Five agents handle evaluation dataset creation, data specification generation, Jupyter notebook generation, and Streamlit dashboard generation and testing.

## Experimental

Exploratory agents for emerging workflows. Includes the Experiment Designer for minimum viable experiment (MVE) coaching and the PowerPoint Builder for YAML-driven slide deck generation.

## DevOps Quality

Agents focused on deployment reliability and build pipeline analysis.

## Meta/Engineering

The prompt builder agent creates and validates prompt engineering artifacts. Supports interactive authoring with sandbox testing for prompts, instructions, agents, and skills. The documentation agent coordinates documentation audit, drift, authoring, and validation across the repository through its four modes.

## Infrastructure

Manages cloud infrastructure provisioning and configuration. Handles Bicep and Terraform deployments with validation and drift detection.

## Utility

General-purpose agents for cross-cutting concerns such as session persistence and context management across workflows.

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

> Brought to you by microsoft/hve-core

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
