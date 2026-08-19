---
title: Get Started with the HVE Partner Workshop
description: Start with the HVE partner workshop, then use the supporting setup, workflow, and role references
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-19
ms.topic: tutorial
keywords:
  - github copilot
  - multi-root workspace
  - setup
  - getting started
estimated_reading_time: 5
---

Start with the [HVE partner workshop](partner-workshop.md). It gives partners new to HVE a shared setup path, role-based exercises, an integrated solution, and publication follow-up.

## Workshop Goals
During the workshop, project and product managers, subject matter experts, designers, and technical participants work from one scenario to produce:

* Grounded business, user, domain, design, and technical context
* User and solution requirements with testable acceptance criteria
* Prioritized GitHub backlog draft
* Reviewed Azure architecture diagram
* Follow-up plans for an Azure Managed Application offer and Microsoft 365 Copilot Agent Store publication

## Workshop Prerequisites

Before joining the workshop, each participant should have the following:

* Mandatory: Product managers should pick a real customer scenario and log the customer opportunity in Partner Center, including the Partner Center referral ID for tracking and follow-up
* Product managers should bring a complete Marketplace Lean Canvas worksheet for the scenario they are shaping
* Product managers should have access to Microsoft Partner Center publisher settings or the appropriate publisher account needed for commercial publishing and validation
* Optional: Designers should have completed the AI Discovery Cards workshop with end users and be ready to share the prioritized use case with proposed Agentic AI capabilities
* Basic understanding that customer, production, or confidential data should not be entered into prompts or files during the workshop
* Laptop or desktop computer with a stable internet connection
* GitHub account that can access the workshop repository and has GitHub Copilot access enabled
* GitHub Copilot and GitHub Copilot Chat available in the environment, with the organization permitting the feature for users
* Access to Visual Studio Code, or the ability to use GitHub Codespaces in the browser
* Git installed locally if using a local VS Code setup
* Permission to install or use the Visual Studio Code extension for HVE Core All, or a facilitator-provided Codespace setup
* Shared GitHub repo and workspace folder such as `workshop-output` for the reviewed deliverables from each role track
* Technical participants should have a working understanding of Frontier Transformation, Microsoft IQ, Azure Databases, Fabric, Security, and GitHub Copilot
* Optional: Azure access or architecture context if the team plans to validate architecture decisions or deployment details during the later stages

## Workshop Agenda

| Step | Activity                                                                                         | Time   |
|------|--------------------------------------------------------------------------------------------------|--------|
| 1    | [Workshop Overview](partner-workshop.md)                                   | 30 min |
| 2    | [Set up Codespaces or local VS Code](partner-workshop-setup.md)                                  | 30 min |
| 3    | [Plan, Envision, Experience, Architecture Design, Backlog](partner-workshop-role-tracks.md)              | 90 min |
| 4    | [Validation & Solutioning](partner-workshop-solution.md)                | 30 min |
| 5    | [Microsoft Marketplace and Copilot Agent Store readiness](partner-workshop-publishing.md) | 60 min |
| 6    | [Handoff to Implementation & Commercialization](partner-workshop-implementation.md)                            | 30 min |

> [!NOTE]
> The workshop creates reviewed drafts and publication plans. Azure deployment,
> certification, tenant approval, and production implementation and publication continue after
> the session.

## Not sure which bundle of agents you need?

Visual Studio Marketplace packages are curated bundles of HVE capabilities that you can install into Copilot or VS Code so you get the right set of agents, prompts, instructions, and skills for your workflow. Browse the available [Visual Studio Marketplace Packages](packages.md) to compare curated HVE capabilities.

## Supporting References

Use the remaining Getting Started material as reference after the workshop.

| Reference                                                 | Use It To                                             |
|-----------------------------------------------------------|-------------------------------------------------------|
| [Installation Guide](install.md)                          | Compare installation methods and resolve setup issues |
| [VS Marketplace Packages](packages.md)                       | Choose a focused collection or HVE Core All           |
| [First Interaction](first-interaction.md)                 | Practice a one-minute agent interaction               |
| [First Research](first-research.md)                       | Learn the research phase on an existing codebase      |
| [First Full Workflow](first-workflow.md)                  | Run Research, Plan, Implement, and Review             |
| [Growing with HVE](../hve-guide/roles/new-contributor.md) | Progress toward independent HVE use                   |
| [Role Guides](../hve-guide/roles/)                        | Continue with role-specific workflows                 |
| [RPI Workflow](../rpi/)                                   | Understand HVE's core delivery methodology            |

## Troubleshooting

* Verify Git is installed: run `git --version` in terminal
* Check network connectivity to github.com
* See the [installation guide](install.md) for method-specific troubleshooting

## Optional Scripts

Copy the scripts you need to your project's `scripts/` directory and adjust paths, variables, or commands to fit your environment.

| Script                                             | Purpose                                            |
|----------------------------------------------------|----------------------------------------------------|
| `scripts/linting/Validate-MarkdownFrontmatter.ps1` | Validate markdown frontmatter against JSON schemas |
| `scripts/linting/Invoke-PSScriptAnalyzer.ps1`      | Run PSScriptAnalyzer with project settings         |
| `scripts/security/Test-DependencyPinning.ps1`      | Check GitHub Actions for pinned dependencies       |

Copy the scripts you need to your project's `scripts/` directory and adjust paths as needed.

## Design Thinking and Discovery

For projects requiring user-centered requirements discovery before implementation:

* [Design Thinking Guide](../design-thinking/): Start with the DT overview
* [Using the DT Coach](../design-thinking/dt-coach.md): Learn to use the DT Coach agent
* [DT to RPI Integration](../design-thinking/dt-rpi-integration.md): Transition from DT to implementation

## See Also

* [Available agents](https://github.com/microsoft/hve-core/blob/main/.github/CUSTOM-AGENTS.md)
* [MCP Configuration](mcp-configuration.md)

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
