---
title: HVE Core Documentation
description: Documentation index for HVE Core Copilot customizations
author: Microsoft
ms.date: 2026-01-22
ms.topic: overview
---

HVE Core is an enterprise-ready prompt engineering framework for GitHub Copilot. It provides specialized agents, reusable prompts, instruction sets, and a validation pipeline with JSON schema enforcement. The framework separates AI concerns into distinct artifact types with clear boundaries, preventing runaway behavior through constraint-based design.

## Audience

| Role                   | Goal                        | Start Here                                          | Key Resources                   |
|------------------------|-----------------------------|-----------------------------------------------------|---------------------------------|
| **Developers**         | Use agents to ship features | [First Workflow](getting-started/first-workflow.md) | RPI agents, prompt patterns     |
| **TPMs & Leads**       | Coordinate AI-assisted work | [Why RPI?](rpi/why-rpi.md)                          | Methodology, team adoption      |
| **Platform Engineers** | Maintain prompt libraries   | [Build Workflows](architecture/workflows.md)        | Validation pipeline, schemas    |
| **Contributors**       | Create new artifacts        | [AI Artifacts](contributing/ai-artifacts-common.md) | Authoring patterns, conventions |

## Getting Started

**Time to complete**: 15-30 minutes

The Getting Started guide walks through installation, configuration, and running your first Copilot workflow.

* [Installation Methods](getting-started/install.md) - Seven setup options from VSCode extension to submodule
* [MCP Configuration](getting-started/mcp-configuration.md) - Model Context Protocol server setup
* [First Workflow](getting-started/first-workflow.md) - End-to-end example with RPI agents

**[Getting Started Guide →](getting-started/README.md)**

## Agent Systems

**Time to complete**: 10-15 minutes

hve-core provides specialized agents organized into functional groups. Each group combines agents, prompts, and instruction files into cohesive workflows for specific engineering tasks.

* [RPI Orchestration](rpi/README.md) separates complex tasks into research, planning, implementation, and review phases
* [GitHub Backlog Manager](agents/github-backlog/README.md) automates issue discovery, triage, sprint planning, and execution across GitHub repositories
* Additional systems documented in the [Agent Catalog](agents/README.md)

**[Browse the Agent Catalog →](agents/README.md)**

## RPI Methodology

**Time to complete**: 20-40 minutes

Research, Plan, Implement (RPI) is a structured methodology for complex AI-assisted engineering tasks. It separates concerns into three specialized agents that work together.

* [Why RPI?](rpi/why-rpi.md) - Problem statement and design rationale
* [Task Researcher](rpi/task-researcher.md) - Discovery and context gathering
* [Task Planner](rpi/task-planner.md) - Structured task planning
* [Task Implementor](rpi/task-implementor.md) - Execution with tracking
* [Using Together](rpi/using-together.md) - Agent coordination patterns

**[RPI Documentation →](rpi/README.md)**

## Prompt Engineering

**Time to complete**: 15-25 minutes

HVE Core provides a structured approach to building AI artifacts with protocol patterns, input variables, and maturity lifecycle management.

* [Prompt Builder Agent](../.github/agents/prompt-builder.agent.md) - Interactive artifact creation with sandbox testing
* [AI Artifacts Overview](contributing/ai-artifacts-common.md) - Common patterns across artifact types
* [Activation Context](architecture/ai-artifacts.md#activation-context) - When artifacts activate within workflows

Key differentiators:

| Capability              | Description                                               |
|-------------------------|-----------------------------------------------------------|
| Constraint-based design | Agents know their boundaries, preventing runaway behavior |
| Subagent delegation     | First-class pattern for decomposing complex tasks         |
| Maturity lifecycle      | Four-stage model from experimental to deprecated          |
| Schema validation       | JSON schema enforcement for all artifact types            |

## Contributing

**Time to complete**: 10-20 minutes

Learn how to create and maintain AI artifacts including agents, prompts, instructions, and skills.

* [Instructions](contributing/instructions.md) - Passive reference guidance
* [Prompts](contributing/prompts.md) - Task-specific procedures
* [Agents](contributing/custom-agents.md) - Custom personas and modes
* [Skills](contributing/skills.md) - Executable utilities with documentation

**[Contributing Guide →](contributing/README.md)**

## Architecture

Technical documentation for system design, component relationships, and build pipelines.

* [Component Overview](architecture/README.md) - System components and interactions
* [AI Artifacts](architecture/ai-artifacts.md) - Four-tier artifact delegation model
* [Build Workflows](architecture/workflows.md) - GitHub Actions CI/CD architecture
* [Testing](architecture/testing.md) - PowerShell Pester test infrastructure

**[Architecture Overview →](architecture/README.md)**

## Templates

Pre-built templates for common engineering documents:

* [ADR Template](templates/adr-template-solutions.md) - Architecture Decision Records
* [BRD Template](templates/brd-template.md) - Business Requirements Documents
* [Security Plan Template](templates/security-plan-template.md) - Security planning

**[Browse Templates →](templates/)**

## Quick Links

| Resource                                   | Description                        |
|--------------------------------------------|------------------------------------|
| [CHANGELOG](../CHANGELOG.md)               | Release history and version notes  |
| [CONTRIBUTING](../CONTRIBUTING.md)         | Repository contribution guidelines |
| [Scripts README](../scripts/README.md)     | Automation script reference        |
| [Extension README](../extension/README.md) | VS Code extension documentation    |

🤖 *Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
