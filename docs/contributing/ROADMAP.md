---
title: Roadmap
description: Project direction and priorities for HVE Core over the next 12-18 months
sidebar_position: 10
author: HVE Core Team
ms.date: 2026-01-21
ms.topic: reference
keywords:
  - roadmap
  - project direction
  - priorities
  - AI coding agents
  - github copilot
estimated_reading_time: 8
---

## Overview

HVE Core intends to accelerate Azure solution development over the next 12-18 months by providing optimized GitHub Copilot customizations (agents, instructions, and prompts) that transform AI coding assistants from suggestion engines into reliable engineering partners. The RPI (Research, Plan, Implement) framework remains central to this vision, ensuring AI produces verified, context-aware code rather than plausible-looking hallucinations.

Actual delivery may vary based on contributor availability, community feedback, and evolving AI capabilities.

## Current State (January 2026)

HVE Core v1.1.0 provides:

* Task researcher, planner, and implementor agents for structured AI workflows (RPI Framework)
* Marketplace distribution via VS Code extension for zero-configuration setup
* 15+ specialized agents for BRD building, architecture diagrams, issue management, and more
* 20+ instruction files covering C#, Terraform, Bicep, Python, bash, and prompt engineering
* Git workflow prompts, ADR planning, risk registers, and PR creation templates
* Frontmatter validation, markdown linting, security scanning, and dependency pinning tooling
* Pre-configured DevContainer with all required development tools

## Priorities for 2026-2027

### Agent Framework Evolution

**Will Do:**

* Expand MCP (Model Context Protocol) integration for standardized tool connections
* Develop multi-agent coordination patterns for complex enterprise scenarios
* Create specialized agents for Azure service categories (compute, data, AI/ML, security)
* Build agent composition patterns allowing agents to delegate to specialized sub-agents
* Add agent metrics and observability for understanding AI decision patterns
* Implement agent memory and context management capabilities

**Won't Do:**

* Build a custom orchestration runtime; use LangGraph or similar established frameworks instead
* Create proprietary tool protocols that compete with MCP
* Develop agents for non-Azure cloud providers (AWS, GCP) in this repository

### Instructions Expansion

**Will Do:**

* Add instructions for emerging Azure services (Azure AI Foundry, Azure Container Apps)
* Create security-focused instructions for threat modeling and secure coding patterns
* Develop instructions for infrastructure-as-code testing (Terratest, Bicep testing)
* Build instructions for observability implementation (Azure Monitor, Application Insights)
* Enhance existing C# instructions with .NET 9+ patterns and minimal API guidance
* Add instructions for GitHub Actions workflow authoring

**Won't Do:**

* Create instructions for out-of-market Azure services
* Maintain instructions for non-Microsoft technology stacks unless directly relevant to Azure integration
* Build framework-specific instructions for every JavaScript/Python framework

### Prompt Engineering

**Will Do:**

* Develop prompt templates for common Azure architecture patterns (hub-spoke, landing zones)
* Create code review prompts that understand Azure Well-Architected & Cloud-Adoption Framework principles
* Add incident response prompts for Azure operations scenarios
* Develop security audit prompts for Azure resource configurations

**Won't Do:**

* Create prompts for general-purpose coding tasks without Azure context
* Build prompts that duplicate functionality available in GitHub Copilot's native capabilities

### Enterprise Readiness

**Will Do:**

* Document governance patterns for organization-wide Hypervelocity Engineering adoption
* Create compliance mapping for Azure Policy and Defender for Cloud alignment
* Build audit logging recommendations for AI-assisted code changes
* Develop approval workflow patterns for high-risk AI operations
* Add data classification guidance for sensitive context handling

**Won't Do:**

* Build enterprise licensing or access control systems
* Create centralized management infrastructure; organizations should use existing policy mechanisms

### Documentation and Learning

**Will Do:**

* Create video tutorials demonstrating RPI workflow with real Azure projects
* Develop scenario-based guides (greenfield, modernization, migration)
* Build troubleshooting guides for common AI coding assistant issues
* Add architecture decision records (ADRs) explaining design choices
* Create certification-style learning paths for HVE Core proficiency

**Won't Do:**

* Duplicate Azure documentation: link to authoritative sources instead
* Create marketing materials or promotional content

### Community and Ecosystem

**Will Do:**

* Establish contribution guidelines for new agents and instructions
* Create agent and instruction quality criteria for inclusion
* Build automated testing for agent and instruction effectiveness
* Develop community showcase for organization-specific customizations
* Add integration guides for popular Azure development tools

**Won't Do:**

* Accept agents or instructions that don't align with project scope
* Maintain community contributions without active maintainers
* Build a separate community platform; use GitHub Discussions and Issues

## Out of Scope

The following areas are explicitly out of scope for HVE Core:

* Non-Azure cloud providers (AWS, GCP customizations belong in separate projects)
* General-purpose coding assistance (use GitHub Copilot's native capabilities for non-Azure-specific tasks)
* Model training or fine-tuning (HVE Core uses prompt engineering, not model customization)
* IDE plugins beyond VS Code (the VS Code extension is the primary distribution mechanism)
* Proprietary or closed-source components (all HVE Core code remains MIT-licensed open source)
* Runtime infrastructure (no backend services, APIs, or hosted components)
* Language model hosting (HVE Core works with existing Copilot infrastructure)

## Success Metrics

Progress is measured by:

| Metric                     | Target                                 | Rationale                                     |
|----------------------------|----------------------------------------|-----------------------------------------------|
| Agent coverage             | 25+ agents                             | Cover common Azure development scenarios      |
| Instruction coverage       | 35+ instructions                       | Address major Azure technologies and patterns |
| VS Code extension installs | 10,000+                                | Validate community adoption                   |
| GitHub stars               | 500+                                   | Measure community interest                    |
| Active contributors        | 10+                                    | Ensure project sustainability                 |
| Issue response time        | < 7 days                               | Maintain community engagement                 |
| Documentation completeness | 100% of agents/instructions documented | Enable self-service adoption                  |

## Timeline Overview

```text
Q1 2026 (Current)
├── MCP integration groundwork
├── Agent metrics foundation
└── Security-focused instructions

Q2 2026
├── Multi-agent coordination patterns
├── Azure AI Foundry agents
└── Video tutorial series launch

Q3 2026
├── Enterprise governance documentation
├── Migration prompt templates
└── Community contribution framework

Q4 2026
├── Agent composition patterns
├── Certification learning paths
└── Automated effectiveness testing

Q1 2027
├── Agent memory capabilities
├── Architecture pattern prompts
└── Compliance mapping documentation
```

## How to Influence the Roadmap

The roadmap evolves based on community input:

* Open a [GitHub Issue](https://github.com/microsoft/hve-core/issues) with the `enhancement` label for feature requests
* Join [GitHub Discussions](https://github.com/microsoft/hve-core/discussions) to propose and debate priorities
* Submit PRs for items on the roadmap; early contributors shape implementation direction
* Use agents and instructions in real projects and report what works and what doesn't

## Version History

| Version | Date       | Changes                     |
|---------|------------|-----------------------------|
| 1.0     | 2026-01-21 | Initial roadmap publication |

*This roadmap satisfies OpenSSF Best Practices Badge Silver criterion `documentation_roadmap`.*

🤖 *Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
