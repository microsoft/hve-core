---
title: HVE Core Documentation
description: Documentation index for HVE Core Copilot customizations
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

| Role                     | Description                                                    | Start Here                                                        |
|--------------------------|----------------------------------------------------------------|-------------------------------------------------------------------|
| Engineer                 | Write code, implement features, fix bugs                       | [Engineer Guide](hve-guide/roles/engineer.md)                     |
| TPM                      | Plan projects, manage requirements, track work                 | [TPM Guide](hve-guide/roles/tpm.md)                               |
| Tech Lead / Architect    | Design architecture, review code, set standards                | [Tech Lead Guide](hve-guide/roles/tech-lead.md)                   |
| Security Architect       | Assess security, create threat models                          | [Security Architect Guide](hve-guide/roles/security-architect.md) |
| Data Scientist           | Analyze data, build notebooks, create dashboards               | [Data Scientist Guide](hve-guide/roles/data-scientist.md)         |
| SRE / Operations         | Manage infrastructure, handle incidents, deploy                | [SRE Guide](hve-guide/roles/sre-operations.md)                    |
| Business Program Manager | Define business outcomes, manage stakeholders                  | [BPM Guide](hve-guide/roles/business-program-manager.md)          |
| New Contributor          | Get started contributing to the project                        | [New Contributor Guide](hve-guide/roles/new-contributor.md)       |
| UX Designer              | Design Thinking coaching, user research, prototyping workflows | [UX Designer Guide](hve-guide/roles/ux-designer.md)               |
| All Roles                | Cross-cutting utility tools                                    | [Utility Guide](hve-guide/roles/utility.md)                       |

**[Browse All Role Guides →](hve-guide/roles/README.md)**

## AI-Assisted Project Lifecycle

HVE Core supports a 9-stage project lifecycle from initial setup through ongoing operations, with AI-assisted tooling at each stage. The project lifecycle guides walk through each stage, covering available tools, role-specific guidance, and starter prompts.

* [Stage Overview](hve-guide/lifecycle/README.md) - Full lifecycle map with Mermaid flowchart
* [Stage 6: Implementation](hve-guide/lifecycle/implementation.md) - Highest-density stage with 30 assets
* [Stage 2: Discovery](hve-guide/lifecycle/discovery.md) - Research, requirements, and BRD creation

**[AI-Assisted Project Lifecycle Overview →](hve-guide/lifecycle/README.md)**

## Role Guides

Find your role-specific guide for AI-assisted engineering. Each guide maps the agents, prompts, and collections relevant to your responsibilities.

* [Engineer](hve-guide/roles/engineer.md) - RPI workflow, coding standards, implementation
* [TPM](hve-guide/roles/tpm.md) - Requirements, backlog management, sprint planning
* [New Contributor](hve-guide/roles/new-contributor.md) - Guided onboarding with progression milestones

**[Browse All Role Guides →](hve-guide/roles/README.md)**

## Getting Started

The Getting Started guide walks through installation, configuration, and running your first Copilot workflow.

* [Installation Methods](getting-started/install.md) - Seven setup options from VSCode extension to submodule
* [MCP Configuration](getting-started/mcp-configuration.md) - Model Context Protocol server setup
* [First Workflow](getting-started/first-workflow.md) - End-to-end example with RPI agents

**[Getting Started Guide →](getting-started/README.md)**

## Agent Systems

hve-core provides specialized agents organized into functional groups. Each group combines agents, prompts, and instruction files into cohesive workflows for specific engineering tasks.

* [RPI Orchestration](rpi/README.md) separates complex tasks into research, planning, implementation, and review phases
* [GitHub Backlog Manager](agents/github-backlog/README.md) automates issue discovery, triage, sprint planning, and execution across GitHub repositories
* Additional systems documented in the [Agent Catalog](agents/README.md)

**[Browse the Agent Catalog →](agents/README.md)**

## Design Thinking

AI-assisted Design Thinking uses the dt-coach agent to guide teams through nine methods across three spaces.

* [Design Thinking Guide](design-thinking/README.md) — Overview and method catalog
* [Why Design Thinking?](design-thinking/why-design-thinking.md) — When to use DT
* [Using the DT Coach](design-thinking/dt-coach.md) — Agent usage guide
* [Browse all Design Thinking docs →](design-thinking/)

## RPI Methodology

Research, Plan, Implement (RPI) is a structured methodology for complex AI-assisted engineering tasks. It separates concerns into three specialized agents that work together.

* [Why RPI?](rpi/why-rpi.md) - Problem statement and design rationale
* [Task Researcher](rpi/task-researcher.md) - Discovery and context gathering
* [Task Planner](rpi/task-planner.md) - Structured task planning
* [Task Implementor](rpi/task-implementor.md) - Execution with tracking
* [Using Together](rpi/using-together.md) - Agent coordination patterns

**[RPI Documentation →](rpi/README.md)**

## Prompt Engineering

HVE Core provides a structured approach to building AI artifacts with protocol patterns, input variables, and maturity lifecycle management.

* [Prompt Builder Agent](../.github/agents/hve-core/prompt-builder.agent.md) - Interactive artifact creation with sandbox testing
* [AI Artifacts Overview](contributing/ai-artifacts-common.md) - Common patterns across artifact types
* [Activation Context](architecture/ai-artifacts.md#activation-context) - When artifacts activate within workflows

### Key Differentiators

| Capability              | Description                                               |
|-------------------------|-----------------------------------------------------------|
| Constraint-based design | Agents know their boundaries, preventing runaway behavior |
| Subagent delegation     | First-class pattern for decomposing complex tasks         |
| Maturity lifecycle      | Four-stage model from experimental to deprecated          |
| Schema validation       | JSON schema enforcement for all artifact types            |

## Customization

Adapt HVE Core to your team's workflow with these guides, from lightweight instruction files to full fork-and-extend workflows.

* [Customization Overview](customization/README.md) - Spectrum of customization options and role-based entry points
* [Instructions](customization/instructions.md) - Repository-level and file-pattern-scoped coding guidance
* [Agents](customization/agents.md) - Custom agent architecture, subagent patterns, and tool restrictions
* [Prompts](customization/prompts.md) - Task-specific prompt files with variables and agent delegation
* [Skills](customization/skills.md) - Self-contained skill packages with scripts and references
* [Collections](customization/collections.md) - Bundle and distribute sets of agents, prompts, instructions, and skills
* [Build System](customization/build-system.md) - Plugin generation, schema validation, and CI pipeline integration
* [Forking](customization/forking.md) - Fork setup, customization areas, and upstream synchronization
* [Environment](customization/environment.md) - DevContainer, VS Code settings, and MCP server configuration
* [Team Adoption](customization/team-adoption.md) - Governance, naming conventions, onboarding, and change management

**[Customization Guide →](customization/README.md)**

## Contributing

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
| [Customization Guide](customization/)      | Adapt HVE Core to your workflow    |
| [CHANGELOG](../CHANGELOG.md)               | Release history and version notes  |
| [CONTRIBUTING](../CONTRIBUTING.md)         | Repository contribution guidelines |
| [Scripts README](../scripts/README.md)     | Automation script reference        |
| [Extension README](../extension/README.md) | VS Code extension documentation    |

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
