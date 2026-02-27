---
title: HVE Core Documentation
description: Documentation index for HVE Core Copilot customizations
sidebar_position: 1
author: Microsoft
ms.date: 2026-02-18
ms.topic: overview
keywords:
  - hve core
  - documentation
  - copilot customizations
estimated_reading_time: 3
---

HVE Core is a prompt engineering framework for GitHub Copilot designed for team-scale adoption. It provides specialized agents, reusable prompts, instruction sets, and a validation pipeline with JSON schema enforcement. The framework separates AI concerns into distinct artifact types with clear boundaries, preventing runaway behavior through constraint-based design.

## Audience

| Role                     | Description                                      | Start Here                                                        |
|--------------------------|--------------------------------------------------|-------------------------------------------------------------------|
| Engineer                 | Write code, implement features, fix bugs         | [Engineer Guide](hve-guide/roles/engineer)                     |
| TPM                      | Plan projects, manage requirements, track work   | [TPM Guide](hve-guide/roles/tpm)                               |
| Tech Lead / Architect    | Design architecture, review code, set standards  | [Tech Lead Guide](hve-guide/roles/tech-lead)                   |
| Security Architect       | Assess security, create threat models            | [Security Architect Guide](hve-guide/roles/security-architect) |
| Data Scientist           | Analyze data, build notebooks, create dashboards | [Data Scientist Guide](hve-guide/roles/data-scientist)         |
| SRE / Operations         | Manage infrastructure, handle incidents, deploy  | [SRE Guide](hve-guide/roles/sre-operations)                    |
| Business Program Manager | Define business outcomes, manage stakeholders    | [BPM Guide](hve-guide/roles/business-program-manager)          |
| New Contributor          | Get started contributing to the project          | [New Contributor Guide](hve-guide/roles/new-contributor)       |
| All Roles                | Cross-cutting utility tools                      | [Utility Guide](hve-guide/roles/utility)                       |

**[Browse All Role Guides →](hve-guide/roles/)**

## AI-Assisted Project Lifecycle

HVE Core supports a 9-stage project lifecycle from initial setup through ongoing operations, with AI-assisted tooling at each stage. The project lifecycle guides walk through each stage, covering available tools, role-specific guidance, and starter prompts.

* [Stage Overview](hve-guide/lifecycle/) - Full lifecycle map with Mermaid flowchart
* [Stage 6: Implementation](hve-guide/lifecycle/implementation) - Highest-density stage with 30 assets
* [Stage 2: Discovery](hve-guide/lifecycle/discovery) - Research, requirements, and BRD creation

**[AI-Assisted Project Lifecycle Overview →](hve-guide/lifecycle/)**

## Role Guides

Find your role-specific guide for AI-assisted engineering. Each guide maps the agents, prompts, and collections relevant to your responsibilities.

* [Engineer](hve-guide/roles/engineer) - RPI workflow, coding standards, implementation
* [TPM](hve-guide/roles/tpm) - Requirements, backlog management, sprint planning
* [New Contributor](hve-guide/roles/new-contributor) - Guided onboarding with progression milestones

**[Browse All Role Guides →](hve-guide/roles/)**

## Getting Started

The Getting Started guide walks through installation, configuration, and running your first Copilot workflow.

* [Installation Methods](getting-started/install) - Seven setup options from VSCode extension to submodule
* [MCP Configuration](getting-started/mcp-configuration) - Model Context Protocol server setup
* [First Workflow](getting-started/first-workflow) - End-to-end example with RPI agents

**[Getting Started Guide →](getting-started/)**

## Agent Systems

hve-core provides specialized agents organized into functional groups. Each group combines agents, prompts, and instruction files into cohesive workflows for specific engineering tasks.

* [RPI Orchestration](rpi/) separates complex tasks into research, planning, implementation, and review phases
* [GitHub Backlog Manager](agents/github-backlog/) automates issue discovery, triage, sprint planning, and execution across GitHub repositories
* Additional systems documented in the [Agent Catalog](agents/)

**[Browse the Agent Catalog →](agents/)**

## RPI Methodology

Research, Plan, Implement (RPI) is a structured methodology for complex AI-assisted engineering tasks. It separates concerns into three specialized agents that work together.

* [Why RPI?](rpi/why-rpi) - Problem statement and design rationale
* [Task Researcher](rpi/task-researcher) - Discovery and context gathering
* [Task Planner](rpi/task-planner) - Structured task planning
* [Task Implementor](rpi/task-implementor) - Execution with tracking
* [Using Together](rpi/using-together) - Agent coordination patterns

**[RPI Documentation →](rpi/)**

## Prompt Engineering

HVE Core provides a structured approach to building AI artifacts with protocol patterns, input variables, and maturity lifecycle management.

* [Prompt Builder Agent](https://github.com/microsoft/hve-core/blob/main/.github/agents/hve-core/prompt-builder.agent.md) - Interactive artifact creation with sandbox testing
* [AI Artifacts Overview](contributing/ai-artifacts-common) - Common patterns across artifact types
* [Activation Context](architecture/ai-artifacts#activation-context) - When artifacts activate within workflows

### Key Differentiators

| Capability              | Description                                               |
|-------------------------|-----------------------------------------------------------|
| Constraint-based design | Agents know their boundaries, preventing runaway behavior |
| Subagent delegation     | First-class pattern for decomposing complex tasks         |
| Maturity lifecycle      | Four-stage model from experimental to deprecated          |
| Schema validation       | JSON schema enforcement for all artifact types            |

## Contributing

Learn how to create and maintain AI artifacts including agents, prompts, instructions, and skills.

* [Instructions](contributing/instructions) - Passive reference guidance
* [Prompts](contributing/prompts) - Task-specific procedures
* [Agents](contributing/custom-agents) - Custom personas and modes
* [Skills](contributing/skills) - Executable utilities with documentation

**[Contributing Guide →](contributing/)**

## Architecture

Technical documentation for system design, component relationships, and build pipelines.

* [Component Overview](architecture/) - System components and interactions
* [AI Artifacts](architecture/ai-artifacts) - Four-tier artifact delegation model
* [Build Workflows](architecture/workflows) - GitHub Actions CI/CD architecture
* [Testing](architecture/testing) - PowerShell Pester test infrastructure

**[Architecture Overview →](architecture/)**

## Templates

Pre-built templates for common engineering documents:

* [ADR Template](templates/adr-template-solutions) - Architecture Decision Records
* [BRD Template](templates/brd-template) - Business Requirements Documents
* [Security Plan Template](templates/security-plan-template) - Security planning

**[Browse Templates →](/docs/category/templates)**

## Quick Links

| Resource                                   | Description                        |
|--------------------------------------------|------------------------------------|
| [CHANGELOG](https://github.com/microsoft/hve-core/blob/main/CHANGELOG.md) | Release history and version notes |
| [CONTRIBUTING](https://github.com/microsoft/hve-core/blob/main/CONTRIBUTING.md) | Repository contribution guidelines |
| [Scripts README](https://github.com/microsoft/hve-core/blob/main/scripts/README.md) | Automation script reference |
| [Extension README](https://github.com/microsoft/hve-core/blob/main/extension/README.md) | VS Code extension documentation |

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
