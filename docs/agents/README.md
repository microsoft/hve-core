---
title: Agent Systems Catalog
description: Overview of all hve-core agent systems with workflow documentation and quick links
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

| Group                     | Agents   | Complexity  | Documentation                               |
|---------------------------|----------|-------------|---------------------------------------------|
| RPI Orchestration         | 5        | High        | [RPI Documentation](../rpi/README.md)       |
| GitHub Backlog Management | 1 active | Very High   | [Backlog Manager](github-backlog/README.md) |
| ADO Integration           | 1        | Medium-High | Planned                                     |
| Document Builders         | 4        | Medium-High | Planned                                     |
| Data Pipeline             | 4        | Medium      | Planned                                     |
| DevOps Quality            | 2        | High        | Planned                                     |
| Meta/Engineering          | 1        | High        | Planned                                     |
| Infrastructure            | 1        | Very High   | Planned                                     |
| Utility                   | 1        | Low-Medium  | Planned                                     |

## RPI Orchestration

The Research, Plan, Implement methodology separates complex tasks into specialized phases. Five agents (task-researcher, task-planner, task-implementor, task-reviewer, and the RPI orchestrator) coordinate through planning files to deliver structured engineering workflows. See the [RPI Documentation](../rpi/README.md) for the full guide.

## GitHub Backlog Management

Automates issue discovery, triage, sprint planning, and execution across GitHub repositories. The backlog manager agent orchestrates five distinct workflows with three-tier autonomy control. See the [Backlog Manager Documentation](github-backlog/README.md) for workflow guides.

## ADO Integration

Bridges Azure DevOps work items with local Copilot workflows. The ADO integration agent handles work item discovery, planning file creation, pull request generation, and build status monitoring.

## Document Builders

Four specialized agents for creating structured documents. Includes builders for Architecture Decision Records, Business Requirements Documents, Product Requirements Documents, and security plans.

## Data Pipeline

Processes and transforms data across formats and systems. Four agents handle data extraction, transformation, validation, and loading workflows.

## DevOps Quality

Two agents focused on code quality and deployment reliability. Covers PR review automation and build pipeline analysis.

## Meta/Engineering

The prompt builder agent creates and validates prompt engineering artifacts. Supports interactive authoring with sandbox testing for prompts, instructions, agents, and skills.

## Infrastructure

Manages cloud infrastructure provisioning and configuration. Handles Bicep and Terraform deployments with validation and drift detection.

## Utility

General-purpose agents for common development tasks such as file organization, content transformation, and small automation helpers.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
