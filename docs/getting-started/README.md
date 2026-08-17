---
title: Get Started with the HVE Partner Workshop
description: Start with the HVE partner workshop, then use the supporting setup, workflow, and role references
author: Microsoft
ms.date: 2026-08-17
ms.topic: tutorial
keywords:
  - github copilot
  - multi-root workspace
  - setup
  - getting started
estimated_reading_time: 5
---

## HVE Partner Workshop

Start with the [HVE partner workshop](partner-workshop.md). It gives partners new to HVE a shared setup path, role-based exercises, an integrated solution, and publication follow-up.

During the workshop, project and product managers, subject matter experts, designers, and technical participants work from one scenario to produce:

* grounded business, user, domain, design, and technical context
* user and solution requirements with testable acceptance criteria
* a prioritized GitHub backlog draft
* a reviewed Azure architecture diagram
* follow-up plans for an Azure Managed Application offer and Microsoft 365 Copilot Agent Store publication

## Start The Workshop

| Step | Activity | Time |
|------|----------|------|
| 1 | [Review the workshop overview and agenda](partner-workshop.md) | 30 min |
| 2 | [Set up Codespaces or local VS Code](partner-workshop-setup.md) | 30 min |
| 3 | [Complete the PM, SME, Design, or Technical track](partner-workshop-role-tracks.md) | 60 min |
| 4 | [Integrate requirements, backlog, and architecture](partner-workshop-solution.md) | 60 min |
| 5 | [Assess Microsoft Marketplace and Copilot Agent Store readiness](partner-workshop-publishing.md) | 30 min |

> [!NOTE]
> The workshop creates reviewed drafts and publication plans. Azure deployment,
> certification, tenant approval, and production publication continue after
> the session.

## Not sure which bundle of agents you need?

Marketplace packages are curated bundles of HVE capabilities that you can install into Copilot or VS Code so you get the right set of agents, prompts, instructions, and skills for your workflow. Browse the available [Marketplace Packages](packages.md) to compare curated HVE capabilities.

## Supporting References

Use the remaining Getting Started material as reference after the workshop.

| Reference | Use It To |
|-----------|-----------|
| [Installation Guide](install.md) | Compare installation methods and resolve setup issues |
| [Marketplace Packages](packages.md) | Choose a focused collection or HVE Core All |
| [First Interaction](first-interaction.md) | Practice a one-minute agent interaction |
| [First Research](first-research.md) | Learn the research phase on an existing codebase |
| [First Full Workflow](first-workflow.md) | Run Research, Plan, Implement, and Review |
| [Growing with HVE](../hve-guide/roles/new-contributor.md) | Progress toward independent HVE use |
| [Role Guides](../hve-guide/roles/) | Continue with role-specific workflows |
| [RPI Workflow](../rpi/) | Understand HVE's core delivery methodology |

## Troubleshooting

* Verify Git is installed: run `git --version` in terminal
* Check network connectivity to github.com
* See the [installation guide](install.md) for method-specific troubleshooting

## Optional Scripts

Copy the scripts you need to your project's `scripts/` directory and adjust paths, variables, or commands to fit your environment.

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
