---
title: Getting Started with HVE Core
description: Quick setup guide for using HVE Core Copilot customizations in your projects
author: Microsoft
ms.date: 2026-02-18
ms.topic: tutorial
keywords:
  - github copilot
  - multi-root workspace
  - setup
  - getting started
estimated_reading_time: 5
---

You've installed HVE Core. What now?

The honest answer: you can start using agents immediately, and some of them
will produce good results right away. But the real power of HVE Core is a
methodology called RPI (Research, Plan, Implement) that changes how you
collaborate with AI. Instead of asking AI to "write the code," you ask it to
research first, plan second, and implement third. The constraint changes
everything.

This guide walks you through four steps, each building on the last:

| Step                                                      | What You Do                                             | Time    |
|-----------------------------------------------------------|---------------------------------------------------------|---------|
| [First Interaction](first-interaction.md)                 | Talk to an agent, see it respond                        | 1 min   |
| [First Research](first-research.md)                       | Use task-researcher on your own codebase                | 5 min   |
| [First Full Workflow](first-workflow.md)                  | Run a complete Research, Plan, Implement cycle          | 15 min  |
| [Growing with HVE](../hve-guide/roles/new-contributor.md) | Progress through four milestones toward independent use | Ongoing |

> [!TIP]
> Already comfortable with AI-assisted development? Skip to
> [First Full Workflow](first-workflow.md) or try the
> [rpi-agent](../../.github/CUSTOM-AGENTS.md#rpi-agent) for autonomous
> single-session workflows.

Need installation help? See the [Installation Guide](install.md) for all
methods, or install the
[VS Code extension](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core)
for the quickest path.

## Troubleshooting

### Installation Issues

#### Agent not available

* Ensure GitHub Copilot extension is installed and active
* Reload VS Code window: `Ctrl+Shift+P` → "Developer: Reload Window"
* Check that hve-core is accessible (cloned or configured correctly)

#### Copilot not discovering customizations

* For Multi-Root: Ensure you opened the `.code-workspace` file, not just the folder
* Verify `chat.agentFilesLocations` points to the correct path
* Check the window title shows the workspace name

#### Git or clone errors

* Verify Git is installed: run `git --version` in terminal
* Check network connectivity to github.com
* See the [installation guide](install.md) for method-specific troubleshooting

## Optional Scripts

HVE Core includes utility scripts you may want to copy into your project:

| Script                                             | Purpose                                            |
|----------------------------------------------------|----------------------------------------------------|
| `scripts/linting/Validate-MarkdownFrontmatter.ps1` | Validate markdown frontmatter against JSON schemas |
| `scripts/linting/Invoke-PSScriptAnalyzer.ps1`      | Run PSScriptAnalyzer with project settings         |
| `scripts/security/Test-DependencyPinning.ps1`      | Check GitHub Actions for pinned dependencies       |

Copy the scripts you need to your project's `scripts/` directory and adjust paths as needed.

## Next Steps

* Start the journey: [Your First Interaction](first-interaction.md)
* Learn the [RPI Workflow](../rpi/README.md) for complex tasks
* Browse [available agents](../../.github/CUSTOM-AGENTS.md) for the full catalog

## See Also

* [Installation Guide](install.md) - Full decision matrix for all installation methods
* [MCP Configuration](mcp-configuration.md) - Configure Model Context Protocol servers
* [Role Guides](../hve-guide/roles/README.md) - Find your role-specific guide

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
