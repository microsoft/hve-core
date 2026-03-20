---
title: HVE Core Documentation
description: Documentation hub for HVE Core, a prompt engineering framework that brings AI-powered agents, prompts, instructions, and skills to your GitHub Copilot workflow
sidebar_position: 1
author: Microsoft
ms.date: 2026-03-11
ms.topic: overview
keywords:
  - hve core
  - documentation
  - copilot customizations
  - agents
  - prompt engineering
estimated_reading_time: 3
---

HVE Core gives your team production-ready agents, reusable prompts, coding instructions, and executable skills for GitHub Copilot. You get structured workflows (Research → Plan → Implement), schema-enforced quality gates, and role-specific tooling across 10 engineering disciplines. Install from the VS Code Marketplace and start shipping with AI-assisted engineering in minutes.

## Choose Your Extension

|              | HVE Core All                                                                                                | HVE Installer                                                                                                 |
|--------------|-------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------|
| What you get | Every agent, prompt, instruction, and skill in the framework                                                | Pick only the collections you need                                                                            |
| Best for     | Teams that want the full toolkit out of the box                                                             | Teams that prefer a curated, lightweight setup                                                                |
| Install      | [Install HVE Core All](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core-all) | [Install HVE Installer](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-installer) |

> Not sure which to choose? See the [installation methods comparison](getting-started/methods/comparison.md) for a detailed breakdown.

## Find Your Path

### New to HVE Core?

Get up and running with installation, configuration, and your first AI-assisted workflow.

* [Install HVE Core](getting-started/install.md) covers three setup paths from marketplace extension to developer clone
* [Run your first workflow](getting-started/first-workflow.md) walks through an end-to-end RPI example
* [Browse available collections](getting-started/collections.md) to see what each bundle includes

### Leading a Team?

Set up HVE Core for your team with governance, collections, and customization options.

* [Team adoption guide](customization/team-adoption.md) covers governance, naming conventions, and onboarding
* [Collections overview](getting-started/collections.md) explains how to bundle and distribute artifacts
* [Customization guide](customization/README.md) covers the full spectrum from lightweight instructions to fork-and-extend

### Contributing to HVE Core?

Create and maintain agents, prompts, instructions, and skills for the framework.

* [Contributing guide](contributing/) explains artifact authoring standards
* [Templates](templates/) provide starting points for ADRs, BRDs, and security plans
* [Architecture overview](architecture/) documents system design, components, and build pipelines

### Going Deeper?

Explore advanced capabilities including Design Thinking coaching, security planning, and methodology reference.

* [Design Thinking](design-thinking/README.md) guides teams through nine methods across three spaces
* [Project Planning](agents/project-planning/) covers ADR creation, BRD/PRD building, architecture diagrams, and security plan generation
* [Security documentation](security/README.md) covers threat modeling and security planning
* [RPI methodology](rpi/) explains the Research, Plan, Implement agent coordination pattern

## Roles

HVE Core provides dedicated tooling for 10 engineering roles, each with curated agents, prompts, and starter workflows. Find your role guide on the [Role Guides](hve-guide/roles/) page.

## AI-Assisted Project Lifecycle

HVE Core supports a 9-stage lifecycle from initial setup through ongoing operations. Each stage maps to specific agents, prompts, and role-specific guidance.

* [Stage overview](hve-guide/lifecycle/) provides a full lifecycle map
* [Implementation (Stage 6)](hve-guide/lifecycle/implementation.md) is the highest-density stage with 30+ assets
* [Discovery (Stage 2)](hve-guide/lifecycle/discovery.md) covers research, requirements, and BRD creation

**[Explore the full lifecycle →](hve-guide/lifecycle/)**

## Agent Systems

Specialized agents are organized into functional groups that combine agents, prompts, and instruction files into cohesive workflows.

* [RPI Orchestration](rpi/) separates complex tasks into research, planning, implementation, and review phases
* [Project Planning](agents/project-planning/) creates ADRs, BRDs, PRDs, architecture diagrams, and security plans through guided AI workflows
* [GitHub Backlog Manager](agents/github-backlog/) automates issue discovery, triage, sprint planning, and execution
* Additional systems are documented in the [Agent Catalog](agents/)

**[Browse the Agent Catalog →](agents/)**

## RPI Methodology

Research, Plan, Implement (RPI) decomposes complex engineering tasks into three specialized agents that collaborate through structured handoffs.

* [Why RPI?](rpi/why-rpi.md) explains the problem statement and design rationale
* [Task Researcher](rpi/task-researcher.md), [Task Planner](rpi/task-planner.md), and [Task Implementor](rpi/task-implementor.md) cover each agent
* [Using Together](rpi/using-together.md) describes agent coordination patterns

**[RPI Documentation →](rpi/)**

## Design Thinking

The dt-coach agent guides teams through nine Design Thinking methods across problem space, solution space, and validation.

* [Design Thinking Guide](design-thinking/README.md) provides the overview and method catalog
* [Why Design Thinking?](design-thinking/why-design-thinking.md) explains when to reach for DT
* [Using the DT Coach](design-thinking/dt-coach.md) covers agent usage

**[Browse all Design Thinking docs →](design-thinking/)**

## Prompt Engineering

HVE Core structures AI artifacts with protocol patterns, input variables, and a four-stage maturity lifecycle.

* [Prompt Builder Agent](https://github.com/microsoft/hve-core/blob/main/.github/agents/hve-core/prompt-builder.agent.md) provides interactive artifact creation with sandbox testing
* [AI Artifacts Overview](contributing/ai-artifacts-common.md) covers common patterns across artifact types
* [Activation Context](architecture/ai-artifacts.md#activation-context) explains when artifacts activate within workflows

## Quick Links

| Resource                                                                                | Description                        |
|-----------------------------------------------------------------------------------------|------------------------------------|
| [Customization Guide](customization/)                                                   | Adapt HVE Core to your workflow    |
| [CHANGELOG](https://github.com/microsoft/hve-core/blob/main/CHANGELOG.md)               | Release history and version notes  |
| [CONTRIBUTING](https://github.com/microsoft/hve-core/blob/main/CONTRIBUTING.md)         | Repository contribution guidelines |
| [Scripts README](https://github.com/microsoft/hve-core/blob/main/scripts/README.md)     | Automation script reference        |
| [Extension README](https://github.com/microsoft/hve-core/blob/main/extension/README.md) | VS Code extension documentation    |

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
