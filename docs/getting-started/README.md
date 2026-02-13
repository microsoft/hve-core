---
title: Getting Started with HVE Core
description: Quick setup guide for using HVE Core Copilot customizations in your projects
author: Microsoft
ms.date: 2025-12-02
ms.topic: tutorial
keywords:
  - github copilot
  - multi-root workspace
  - setup
  - getting started
estimated_reading_time: 5
---

HVE Core provides GitHub Copilot customizations (custom agents, instructions, and prompts) that enhance your development workflow. This guide helps you get started quickly.

## Installation

### Quick Install: VS Code Extension ⭐

**Simplest method:** Install directly from VS Code Marketplace:

1. Open VS Code Extensions view (`Ctrl+Shift+X`)
2. Search for "HVE Core"
3. Click **Install**

Or visit: [HVE Core on Marketplace](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core)

**Pros:** Zero configuration, automatic updates, works everywhere
**Cons:** Cannot customize components

See [Extension Installation Guide](methods/extension.md) for full details.

### Custom Installation

For customization or version control, see [Installing HVE-Core](install.md) to choose from six installation methods.

> **Contributing to HVE-Core?** See the [Contributing Guide](../contributing/README.md) for development setup and contribution guidelines.

**Quick start:** Use the `hve-core-installer` agent:

1. Open GitHub Copilot Chat (`Ctrl+Alt+I`)
2. Select `hve-core-installer` from the agent picker
3. Follow the guided installation

### Installation Methods

HVE-Core supports eight installation methods. See the [installation guide](install.md) for a decision matrix to help you choose:

| Method                                        | Best For                      |
|-----------------------------------------------|-------------------------------|
| [VS Code Extension](methods/extension.md) ⭐   | Simplest, no config needed    |
| [Multi-Root Workspace](methods/multi-root.md) | Any environment, portable     |
| [Submodule](methods/submodule.md)             | Teams needing version control |
| [Peer Directory Clone](methods/peer-clone.md) | Local VS Code, solo           |
| [Git-Ignored Folder](methods/git-ignored.md)  | Local devcontainer, solo      |
| [Mounted Directory](methods/mounted.md)       | Advanced devcontainer sharing |
| [GitHub Codespaces](methods/codespaces.md)    | Codespaces-only projects      |
| [Copilot CLI Plugins](methods/cli-plugins.md) | Terminal-based CLI workflows  |

## Verifying Setup

After installation, verify everything works:

1. Open GitHub Copilot Chat (`Ctrl+Alt+I`)
2. Click the **agent picker dropdown**
3. Verify HVE-Core agents appear:
   - task-planner
   - task-researcher
   - prompt-builder
   - pr-review
4. Select an agent and submit a test prompt

## Troubleshooting

### Installation Issues

#### Agent not available

- Ensure GitHub Copilot extension is installed and active
- Reload VS Code window: `Ctrl+Shift+P` → "Developer: Reload Window"
- Check that hve-core is accessible (cloned or configured correctly)

#### Copilot not discovering customizations

- For Multi-Root: Ensure you opened the `.code-workspace` file, not just the folder
- Verify `chat.agentFilesLocations` points to the correct path
- Check the window title shows the workspace name

#### Git or clone errors

- Verify Git is installed: run `git --version` in terminal
- Check network connectivity to github.com
- See the [installation guide](install.md) for method-specific troubleshooting

## Optional Scripts

HVE Core includes utility scripts you may want to copy into your project:

| Script                                             | Purpose                                             |
|----------------------------------------------------|-----------------------------------------------------|
| `scripts/dev-tools/Generate-PrReference.ps1`       | Generate PR reference docs for handoff to reviewers |
| `scripts/linting/Validate-MarkdownFrontmatter.ps1` | Validate markdown frontmatter against JSON schemas  |
| `scripts/linting/Invoke-PSScriptAnalyzer.ps1`      | Run PSScriptAnalyzer with project settings          |
| `scripts/security/Test-DependencyPinning.ps1`      | Check GitHub Actions for pinned dependencies        |

Copy the scripts you need to your project's `scripts/` directory and adjust paths as needed.

## Next Steps

- Try [Your First Workflow](first-workflow.md) for a quick start
- Learn the [RPI Workflow](../rpi/README.md) for complex tasks
- Browse the [Agent Catalog](../agents/README.md) for all agent system documentation
- Explore [Agents](../../.github/CUSTOM-AGENTS.md) for available agents
- Review [Instructions](../../.github/instructions/README.md) for coding guidelines
- Check the [README](../../README.md) for feature overview

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
