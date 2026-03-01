---
title: Installing HVE-Core
description: Choose the right installation method for your environment
sidebar_position: 2
author: Microsoft
ms.date: 2025-12-02
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

## Recommended: VS Code Extension ⭐

**For most users**, the simplest method is to install directly from the VS Code Marketplace:

```text
VS Code → Extensions → Search "HVE Core" → Install
```

**Or visit:** [HVE Core on Marketplace](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core)

**Why choose the extension:**

* ✅ Zero configuration required
* ✅ Automatic updates via VS Code
* ✅ Works everywhere (local, devcontainers, Codespaces)
* ✅ No project files needed
* ✅ Instant availability

**When to use alternatives:**

* ❌ You need to customize components → Use custom installation methods below
* ❌ Team needs version control → Use [Submodule](methods/submodule.md)
* ❌ Contributing to HVE-Core → Use [Peer Clone](methods/peer-clone.md)

See [Extension Installation Guide](methods/extension.md) for complete documentation.

## Custom Installation Methods

If you need customization or version control of HVE-Core, choose from the methods below.

## Quick Start

> **Starter prompt:** "Help me choose how to install this library"

Open Copilot Chat, select the `hve-core-installer` agent, and use this prompt. The agent will ask three questions about your environment and recommend the best method.

## Help Me Choose

Answer these questions to find your recommended installation method:

1. **What's your development environment?**
   * Local VS Code (no devcontainer)
   * Local devcontainer (Docker Desktop)
   * GitHub Codespaces
   * Both local and Codespaces

2. **Solo or team development?**
   * Solo: Just you, no version control of HVE-Core needed
   * Team: Multiple people, need reproducible setup

3. **Update preference?**
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

⭐ **VS Code Extension** is the recommended method for most users who don't need customization.

## Collection Packages

HVE-Core supports role-based artifact collections tailored to specific roles:

| Collection    | Extension Name  | Collection ID  | Maturity     | Description                          |
|---------------|-----------------|----------------|--------------|--------------------------------------|
| **Full**      | `hve-core`      | `hve-core-all` | Stable       | All artifacts (recommended for most) |
| **Developer** | `hve-developer` | `developer`    | Experimental | Software engineering focus           |

> [!NOTE]
> Experimental collections are only available via PreRelease extension builds. The Stable channel includes the Full collection only.

### Extension Installation (Full Collection)

The VS Code Marketplace extension installs the **full collection** containing all stable artifacts. This is the recommended approach for most users.

### Clone Methods (Collection Filtering)

Clone-based installation methods support collection-based agent filtering through the installer agent:

1. Clone the repository using your preferred method
2. Run the `hve-core-installer` agent
3. In Phase 7 (Agent Customization), select your role-based collection or install all agents

The installer reads collection assignments from the collection manifests (`collections/*.collection.yml`) and copies only the agents assigned to your selected collection. Agents marked for all collections are always included.

> [!NOTE]
> Collection filtering applies to agents only. Copying of related prompts, instructions, and skills based on collection is planned for a future release.

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

## Using the Installer Agent

The `hve-core-installer` agent automates any installation method:

1. Open GitHub Copilot Chat in VS Code (`Ctrl+Alt+I`)
2. Select `hve-core-installer` from the agent picker
3. Answer the environment detection questions
4. The agent executes your chosen method

The agent handles:

* Environment detection (Local VS Code, Devcontainer, Codespaces)
* Repository cloning or configuration
* VS Code settings updates
* Devcontainer configuration
* Validation of the installation

## Validation

After installation, verify everything works:

1. Open GitHub Copilot Chat (`Ctrl+Alt+I`)
2. Click the agent picker dropdown
3. Verify HVE-Core agents appear (task-planner, task-researcher, prompt-builder)
4. Select an agent and submit a test prompt

Run the installer in validation mode:

> "Validate my HVE-Core installation"

## Post-Installation: Update Your .gitignore

HVE-Core agents create ephemeral workflow artifacts in a `.copilot-tracking/` folder within your project. These files include research documents, implementation plans, PR review tracking, and other machine-generated content that should typically not be committed to version control.

**Add this line to your project's `.gitignore`:**

```text
.copilot-tracking/
```

> [!IMPORTANT]
> This applies to all installation methods (extension, submodule, peer clone, etc.). The `.copilot-tracking/` folder is created in your project directory, not in HVE-Core itself.

**What gets stored there:**

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
