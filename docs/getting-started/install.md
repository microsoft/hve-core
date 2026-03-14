---
title: Installing HVE-Core
description: Choose the right installation method for your environment
sidebar_position: 2
author: Microsoft
ms.date: 2026-03-10
ms.topic: how-to
keywords:
  - installation
  - setup
  - github copilot
  - devcontainer
  - codespaces
estimated_reading_time: 5
---

HVE-Core provides GitHub Copilot customizations (custom agents, instructions, and prompts) that enhance your development workflow. This guide helps you choose the right installation method for your environment.

Before installing, you can browse all available collections here:

[View Extension Collections](./collections.md)

## Recommended: VS Code Extension ⭐

**For most users**, the simplest method is to install directly from the VS Code Marketplace:

```text
VS Code → Extensions → Search "HVE Core" → Install
```

**Or visit:** [HVE Core on Marketplace](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core)

### Why choose the extension

* ✅ Zero configuration required
* ✅ Automatic updates via VS Code
* ✅ Works everywhere (local, devcontainers, Codespaces)
* ✅ No project files needed
* ✅ Instant availability

### When to use alternatives

* ❌ Team needs version control → Use [Submodule](methods/submodule.md)
* ❌ Contributing to HVE-Core → Use [Peer Clone](methods/peer-clone.md)
* 🤔 Not sure which method fits? → The [HVE Core Installer](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-installer) skill guides you through the choice

See [Extension Installation Guide](methods/extension.md) for complete documentation.

## Custom Installation Methods

If you need customization or version control of HVE-Core, choose from the methods below. The [HVE Core Installer](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-installer) skill is the recommended way to evaluate these options: it walks you through your environment, team size, and update preferences to recommend the best method, then configures it for you.

## Quick Start

> **Recommended:** Install the [HVE Core extension](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core) for the flagship RPI workflow and core artifacts with zero configuration (~30 seconds). For the complete artifact library across all collections, use the [HVE Core - All extension](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core-all).
>
> **Need guided setup?** Install the [HVE Core Installer](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-installer) extension, which provides the installer skill. Ask any agent: "help me customize hve-core installation". The installer skill walks you through choosing an installation method (peer clone, submodule, git-ignored, and others), configures MCP servers, and supports agent bundle selection by collection.

For clone-based customization, answer the questions below to find the best method for your environment.

## Help Me Choose

> [!TIP]
> The [HVE Core Installer](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-installer) skill asks these same questions interactively and configures the recommended method for you. Install the extension and ask any agent "help me customize hve-core installation".

Answer these questions to find your recommended installation method:

1. What's your development environment?
   * Local VS Code (no devcontainer)
   * Local devcontainer (Docker Desktop)
   * GitHub Codespaces
   * Both local and Codespaces

2. Solo or team development?
   * Solo: Just you, no version control of HVE-Core needed
   * Team: Multiple people, need reproducible setup

3. Update preference?
   * Auto: Always get latest HVE-Core
   * Controlled: Pin to specific version, update explicitly

### Decision Matrix

| Environment               | Team | Updates    | Recommended Method                            |
|---------------------------|------|------------|-----------------------------------------------|
| **Any** (simplest)        | Any  | Auto       | [VS Code Extension](methods/extension.md) ⭐   |
| Local (no container)      | Solo | Manual     | [Peer Directory Clone](methods/peer-clone.md) |
| Local (no container)      | Team | Controlled | [Submodule](methods/submodule.md)             |
| Local devcontainer        | Solo | Auto       | [Git-Ignored Folder](methods/git-ignored.md)  |
| Local devcontainer        | Team | Controlled | [Submodule](methods/submodule.md)             |
| Codespaces only           | Solo | Auto       | [GitHub Codespaces](methods/codespaces.md)    |
| Codespaces only           | Team | Controlled | [Submodule](methods/submodule.md)             |
| Both local + Codespaces   | Any  | Any        | [Multi-Root Workspace](methods/multi-root.md) |
| Advanced (shared install) | Solo | Auto       | [Mounted Directory](methods/mounted.md)       |
| Any (CLI preferred)       | Any  | Manual     | [CLI Plugins](methods/cli-plugins.md)         |

⭐ **VS Code Extension** is the recommended method for most users who don't need customization.

## Collection Packages

HVE-Core organizes artifacts into role-based collections. The VS Code extension installs the **HVE Core Workflow** collection (flagship RPI workflow and core artifacts). For the complete set across all collections, use the `hve-core-all` CLI plugin or installer skill. Clone-based methods also support filtering which agents to copy by collection bundle.

| Collection        | Collection ID      | Maturity     | Description                                                       |
|-------------------|--------------------|--------------|-------------------------------------------------------------------|
| **Full** ⭐        | `hve-core-all`     | Stable       | All stable artifacts (recommended for most)                       |
| HVE Core Workflow | `hve-core`         | Stable       | RPI workflow with Git commit, merge, and pull request prompts     |
| Azure DevOps      | `ado`              | Stable       | Work item management, build monitoring, and PR creation           |
| Coding Standards  | `coding-standards` | Stable       | Language-specific instructions for bash, Bicep, C#, Python, etc.  |
| Data Science      | `data-science`     | Stable       | Data specs, Jupyter notebooks, and Streamlit dashboards           |
| Design Thinking   | `design-thinking`  | Preview      | AI-enhanced Design Thinking coaching across nine methods          |
| GitHub Backlog    | `github`           | Stable       | Issue discovery, triage, sprint planning, and backlog execution   |
| Installer         | `installer`        | Stable       | Interactive installer skill for workspace configuration           |
| Project Planning  | `project-planning` | Stable       | PRDs, BRDs, ADRs, and architecture diagrams                       |
| Security          | `security`         | Experimental | Security review, planning, incident response, and risk assessment |
| Experimental      | `experimental`     | Experimental | Artifacts not yet promoted to stable collections                  |

### Extension Installation (Flagship Collection)

The VS Code Marketplace extension installs the **HVE Core Workflow** collection: the flagship set of RPI agents, prompts, and instructions. This is the recommended starting point for most users. For every stable artifact across all collections, use the `hve-core-all` Extension or plugin.

### Clone Methods (Agent Bundle Selection)

Clone-based installation methods support agent bundle selection through the HVE Core installer skill:

1. Install the [HVE Core Installer](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-installer) extension to get the installer skill
2. Ask any agent: "help me customize hve-core installation"
3. Choose an agent bundle by collection or copy all agents

The installer skill reads collection assignments from `collections/*.collection.yml` and copies only the agents from your selected bundles to `.github/agents/`.

> [!IMPORTANT]
> Agent bundle selection copies agents only. Prompts, instructions, and skills are not filtered by collection. Copying of additional artifact types is planned for a future release.

### Quick Decision Tree

```text
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  Want the simplest setup?                                       │
│  └─ Yes ──────────────────────────────► VS Code Extension ⭐   │
│                                                                 │
│  Need to customize HVE-Core?                                    │
│  ├─ Local VS Code only ──────────────► Peer Directory Clone    │
│  ├─ Local devcontainer only ─────────► Git-Ignored Folder      │
│  ├─ Codespaces only ─────────────────► GitHub Codespaces       │
│  └─ Both local + Codespaces ─────────► Multi-Root Workspace    │
│                                                                 │
│  Working in a team?                                             │
│  └─ Yes, need version control ───────► Submodule               │
│                                                                 │
│  Prefer terminal/CLI workflows?                                 │
│  └─ Yes ──────────────────────────────► CLI Plugins            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Installation Methods

### Simplest Method (Recommended for Most Users)

| Method                                      | Best For                         | Complexity |
|---------------------------------------------|----------------------------------|------------|
| [VS Code Extension](methods/extension.md) ⭐ | Anyone wanting zero-config setup | Minimal    |

### Consumer Methods (Customization + Version Control)

These methods are for projects that want to use and potentially customize HVE-Core's components:

| Method                                        | Best For                      | Complexity |
|-----------------------------------------------|-------------------------------|------------|
| [Multi-Root Workspace](methods/multi-root.md) | Any environment, portable     | Low        |
| [Submodule](methods/submodule.md)             | Teams needing version control | Medium     |

### Developer Methods

These methods are for HVE-Core contributors or advanced scenarios:

| Method                                        | Best For                      | Complexity |
|-----------------------------------------------|-------------------------------|------------|
| [Peer Directory Clone](methods/peer-clone.md) | Local VS Code, solo           | Low        |
| [Git-Ignored Folder](methods/git-ignored.md)  | Local devcontainer, solo      | Low        |
| [Mounted Directory](methods/mounted.md)       | Advanced devcontainer sharing | High       |
| [GitHub Codespaces](methods/codespaces.md)    | Codespaces-only projects      | Medium     |
| [CLI Plugins](methods/cli-plugins.md)         | Terminal-based CLI workflows  | Low        |

## Validation

After installation, verify everything works:

1. Open GitHub Copilot Chat (`Ctrl+Alt+I`)
2. Click the agent picker dropdown
3. Verify HVE-Core agents appear (task-planner, task-researcher, prompt-builder)
4. Select an agent and submit a test prompt

## Post-Installation: Update Your .gitignore

HVE-Core agents create ephemeral workflow artifacts in a `.copilot-tracking/` folder within your project. These files include research documents, implementation plans, PR review tracking, and other machine-generated content that should typically not be committed to version control.

### Add this line to your project's `.gitignore`

```text
.copilot-tracking/
```

> [!IMPORTANT]
> This applies to all installation methods (extension, submodule, peer clone, etc.). The `.copilot-tracking/` folder is created in your project directory, not in HVE-Core itself.

### What gets stored there

* Research documents from `task-researcher`
* Implementation plans from `task-planner`
* PR review artifacts from `pr-review`
* Work item planning files for ADO workflows
* Temporary prompt files used by agents

These artifacts are useful during your workflow session but are ephemeral by design. They help agents maintain context across sessions without polluting your repository history.

## MCP Server Configuration (Optional)

Some HVE-Core agents use MCP (Model Context Protocol) servers to integrate with Azure DevOps, GitHub, or documentation services. These are optional enhancements; agents work without MCP configuration.

If you use agents like `ado-prd-to-wit` or `github-backlog-manager`, see [MCP Server Configuration](mcp-configuration.md) for setup instructions. That guide includes:

* Which agents require which MCP servers
* Complete configuration templates
* Method-specific placement notes (extension, submodule, Codespaces, etc.)
* Troubleshooting for common issues

## Next Steps

* [Your First Workflow](first-workflow.md) - Try HVE-Core with a real task
* [RPI Workflow](../rpi/) - Research, Plan, Implement methodology
* [Contributing](../contributing/) - Contribute to HVE-Core

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
