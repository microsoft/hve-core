---
title: Installing HVE-Core
description: Three ways to install HVE-Core with marketplace extension, selective collections, or developer clone
sidebar_position: 2
author: Microsoft
ms.date: 2026-03-11
ms.topic: how-to
keywords:
  - installation
  - setup
  - github copilot
  - marketplace
  - collections
estimated_reading_time: 4
---

HVE-Core delivers GitHub Copilot customizations (agents, instructions, prompts, and skills) that accelerate your development workflow. Pick the installation path that fits your needs.

## Marketplace Install (Recommended)

Install the **HVE Core** extension for a zero-configuration experience that works across local VS Code, devcontainers, and GitHub Codespaces.

1. Open VS Code and go to the Extensions view (`Ctrl+Shift+X`).
2. Search for **HVE Core**.
3. Click **Install** on the extension published by `ise-hve-essentials`.
4. Reload VS Code when prompted.

**Or visit:** [HVE Core on VS Code Marketplace](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core)

The extension installs the `hve-core` (Flagship) collection containing 40 artifacts for the RPI workflow. Updates arrive automatically through VS Code.

See [Extension Installation Guide](methods/extension.md) for complete documentation.

> [!TIP]
> The marketplace extension is the fastest way to start. You can switch to a clone-based method later without losing any configuration.

## Selective Install

Teams that only need specific domains can use the **HVE Installer** extension to deploy individual [collections](collections.md) into a workspace.

1. Install the [HVE Installer extension](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-installer) from the VS Code Marketplace.
2. Open Copilot Chat and ask any agent: *"help me customize hve-core installation"*.
3. Choose the collections that match your team's workflow.

4. Update preference?
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
> Agent bundle selection currently applies to agents only. Support for prompts, instructions, and skills is planned for a future release.

## Developer Setup

Contributors and advanced users who need to modify HVE-Core source code should clone the repository directly.

1. Fork and clone the repository:

   ```bash
   git clone https://github.com/<your-fork>/hve-core.git
   ```

2. Install dependencies:

   ```bash
   cd hve-core && npm ci
   ```

3. Open the workspace in VS Code. A devcontainer configuration is included for containerized development.

Detailed instructions for each clone-based approach:

* [Peer Directory Clone](methods/peer-clone.md) for side-by-side local development
* [Git Submodule](methods/submodule.md) for team version control
* [Contributing Guide](../contributing/) for pull request and development conventions

## Choosing a Method

The three paths above cover the vast majority of scenarios. If your environment has specific constraints (Codespaces-only, mounted containers, multi-root workspaces), the [Comparing Setup Methods](methods/comparison.md) page has a detailed decision matrix and decision tree. The [Setup Methods Overview](methods/) lists every available approach.

## Validation

After installing, verify that HVE-Core is active:

1. Open Copilot Chat in VS Code.
2. Type `@` to see available agents.
3. Look for HVE-Core agents like `task-researcher`, `task-planner`, and `task-implementor`.

If you don't see the agents, check the [Troubleshooting](troubleshooting.md) page for common solutions.

## Post-Installation: Update Your .gitignore

Add this line to your project's `.gitignore`:

```text
.copilot-tracking/
```

> [!IMPORTANT]
> This applies to all installation methods. The `.copilot-tracking/` folder is created in your project directory, not in HVE-Core itself.

The folder stores ephemeral workflow artifacts (research documents, implementation plans, PR review notes, and work item planning files) that help agents maintain context across sessions. These files are useful during your workflow but should not be committed to your repository.

## MCP Server Configuration (Optional)

Some HVE-Core agents use MCP (Model Context Protocol) servers to integrate with Azure DevOps, GitHub, or documentation services. Agents work without MCP configuration; it is an optional enhancement.

See [MCP Server Configuration](mcp-configuration.md) for setup instructions covering server requirements, configuration templates, and troubleshooting.

## Next Steps

* [Your First Interaction](first-interaction.md) to confirm your setup works
* [Your First Workflow](first-workflow.md) to try HVE-Core with a real task
* [RPI Workflow](../rpi/) for the Research, Plan, Implement methodology

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
