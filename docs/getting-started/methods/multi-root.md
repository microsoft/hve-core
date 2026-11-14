---
title: Multi-Root Workspace Installation
description: Set up your enterprise fork of HVE Core using VS Code multi-root workspaces
sidebar_position: 6
author: Microsoft
ms.date: 2026-11-10
ms.topic: how-to
keywords:
  - multi-root workspace
  - installation
  - github copilot
  - codespaces
  - devcontainer
  - enterprise fork
  - plugin from source
estimated_reading_time: 7
---

Forking HVE Core lets your enterprise customize agents, instructions, and skills for your organization while staying connected to upstream improvements. A multi-root workspace opens that fork next to your project in one VS Code window, so you can read and edit both. Copilot loads the fork once you install its root folder as a plugin from source.

## When to Use This Method

✅ **Use this when:**

* Your enterprise maintains a fork of HVE Core with org-specific customizations
* You want the fork open beside your project while you work
* Teams share a common set of customized agents, skills, and instructions
* You want to pull upstream improvements on your own schedule

❌ **Consider alternatives when:**

* Your team needs version-pinned dependencies without a fork → [Submodule](submodule.md)
* You're contributing back to HVE Core itself → [Peer Clone](peer-clone.md)

## How It Works

Your enterprise forks the `microsoft/hve-core` repository and adds org-specific agents, skills, and instructions, as described in [Forking and Extending HVE Core](../../customization/forking.md). Developers clone the fork, and a `.code-workspace` file opens the clone as a second root folder next to the project.

The workspace file only arranges folders and holds no customization settings. The fork keeps `plugin.json` at its root, as HVE Core does, so you install the clone's root folder as a plugin from source and Copilot loads the fork from there.

```text
┌──────────────────────────────────────────────────┐
│           VS Code Multi-Root Workspace           │
├──────────────────────────────────────────────────┤
│  📁 My Project (primary)                         │
│     └── Your application code                    │
│  📁 HVE Core Fork (secondary)                    │
│     └── plugin.json (plugin manifest)            │
│     └── .github/agents, skills, instructions     │
│     └── Org-specific customizations              │
└──────────────────────────────────────────────────┘
         ↑
   .code-workspace file defines this

   microsoft/hve-core (upstream)
         ↓  sync on your schedule
   your-org/hve-core (fork)
         ↓  install the clone as a plugin from source
   Copilot loads the fork's agents, skills, and instructions
```

## Quick Start

If your organization does not need its own fork, install the `hve-core` plugin instead, as described in [Install the Plugin](../install#install-the-plugin). For guided installation-method selection, MCP configuration, or copying HVE Core into your project, ask an agent to use the included `hve-core-installer` skill. Use the manual steps below to set up the fork, the workspace, and the plugin install.

## Manual Setup

### Step 1: Fork and Clone

If your organization has not already forked HVE Core, create a fork of `microsoft/hve-core` under your org's GitHub account. Then clone your fork.

#### VS Code on Your Machine

```bash
# Clone your org's fork next to your project
cd /path/to/your-projects
git clone https://github.com/your-org/hve-core.git

# Add upstream for syncing improvements
cd hve-core
git remote add upstream https://github.com/microsoft/hve-core.git
```

In Codespaces or a devcontainer, Step 3 clones the fork for you.

### Step 2: Create the Workspace File

Create `.devcontainer/hve-core.code-workspace` in your project to list the two folders to open.

> [!NOTE]
> If an earlier setup added `chat.agentFilesLocations`, `chat.instructionsFilesLocations`, or `chat.agentSkillsLocations` entries for HVE Core to your workspace file or `.vscode/settings.json`, remove them. Copilot does not need them. Switch to the Copilot harness and confirm HVE Core loads there before you remove them, as [Use One Route at a Time](../install#use-one-route-at-a-time) describes.

#### Codespaces / Devcontainer

Use the absolute clone path:

```jsonc
{
  "folders": [
    {
      "name": "My Project",
      "path": ".."
    },
    {
      "name": "HVE Core Fork",
      "path": "/workspaces/hve-core"
    }
  ],
  "extensions": {
    "recommendations": [
      "github.copilot",
      "github.copilot-chat"
    ]
  }
}
```

#### VS Code on Your Machine

Use the relative clone path from the workspace file's directory:

```jsonc
{
  "folders": [
    {
      "name": "My Project",
      "path": ".."
    },
    {
      "name": "HVE Core Fork",
      "path": "../../hve-core"
    }
  ]
}
```

Adjust the relative path to match your clone location.

### Step 3: Configure Devcontainer (Codespaces)

Update `.devcontainer/devcontainer.json` to clone your org's fork:

```jsonc
{
  "name": "My Project + HVE Core",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",

  "onCreateCommand": "git clone --depth 1 https://github.com/your-org/hve-core.git /workspaces/hve-core 2>/dev/null || git -C /workspaces/hve-core pull --ff-only || true",

  "customizations": {
    "vscode": {
      "extensions": [
        "github.copilot",
        "github.copilot-chat"
      ]
    }
  }
}
```

### Step 4: Open the Workspace

> [!WARNING]
> You must open the `.code-workspace` file, not the folder.

* `File` → `Open Workspace from File...` → select `hve-core.code-workspace` (on your machine)
* Run `code .devcontainer/hve-core.code-workspace` in terminal (Codespaces)

> [!NOTE]
> The dev container spec has no `workspaceFile` property, so Codespaces and devcontainers always open in single-folder mode. You must manually switch to the workspace file after the container starts. For Codespaces without a fork, see the [Codespaces method](codespaces.md).

The VS Code title bar should show your workspace name, not just the folder name.

### Step 5: Install the Fork as a Plugin

The workspace puts the fork in the Explorer. To have Copilot load it, install the clone's root folder, the one that holds `plugin.json`, as a plugin from source:

1. Run **Chat: Open Customizations** from the Command Palette to open the Agent Customizations editor, and select **Plugins**.
2. Select the add (`+`) button next to **User**.
3. Enter the clone's folder path: `/path/to/your-projects/hve-core` on your machine, or `/workspaces/hve-core` in Codespaces or a devcontainer.

Running **Chat: Install Plugin from Source** from the Command Palette (`Ctrl+Shift+P`) does the same. In Codespaces or a devcontainer, confirm that `hve-core` appears on the **Plugins** page of the Agent Customizations editor before you rely on the install.

> [!IMPORTANT]
> Use one install route at a time. When the same content arrives through more than one route, for example this plugin and the HVE Core VS Code extension, Copilot lists agents more than once in the subagent list and does not remove the copies.

## Path Resolution

The `path` field of each folder entry tells VS Code where that folder is on disk. The `name` field is the label shown in the Explorer sidebar.

| Path Style    | Example                  | Recommended                     |
|---------------|--------------------------|---------------------------------|
| Absolute path | `"/workspaces/hve-core"` | ✅ Codespaces and devcontainers |
| Relative path | `"../../hve-core"`       | ✅ VS Code on your machine      |

A relative path resolves from the directory that holds the workspace file, so from `.devcontainer/` the value `../../hve-core` points at a sibling of your project. The plugin install in Step 5 takes the clone's folder path, not its `name`.

## Keeping Your Fork Updated

Sync your fork with upstream `microsoft/hve-core` to pick up new agents, skills, and improvements. Pull from your fork into workspaces on a schedule that suits your team.

### Syncing Upstream Changes into Your Fork

```bash
# From your fork's local clone
git fetch upstream
git merge upstream/main
# Resolve any conflicts with your org customizations, then push
git push origin main
```

### Pulling Fork Updates into Workspaces

| Strategy       | Configuration                                       | When Updates Apply |
|----------------|-----------------------------------------------------|--------------------|
| Manual         | Run `git -C /workspaces/hve-core pull` when desired | On demand          |
| On rebuild     | Add `updateContentCommand` to devcontainer.json     | Container rebuild  |
| On every start | Add `postStartCommand` to devcontainer.json         | Every startup      |

> [!TIP]
> Update on rebuild for stability:

```jsonc
{
  "updateContentCommand": "git -C /workspaces/hve-core pull --ff-only || true"
}
```

A pull updates the files on disk. Run **Developer: Reload Window** afterward so new chat sessions pick up the change. If the change still does not show up, open the **Plugins** page in the Agent Customizations editor and select **Check for and Apply Updates** (the refresh icon), or run **Chat: Update Plugins**.

## Verification

After setup, verify HVE Core is working:

1. Check that the Explorer sidebar shows both folders.
2. Confirm that `hve-core` appears on the **Plugins** page of the Agent Customizations editor.
3. Run **Developer: Reload Window**, then open Copilot Chat (`Ctrl+Alt+I`) with the Copilot harness, which is the VS Code default.
4. Open the agent picker and confirm `RPI Agent` is listed.
5. Type `/` and confirm skills such as `/hve-core:rpi-research` appear. VS Code prefixes a plugin's skills with the plugin name.

## Troubleshooting

### Agents Not Appearing

* Confirm that `hve-core` appears on the **Plugins** page. If it does not, repeat Step 5 with the path of the folder that holds `plugin.json`.
* Run **Developer: Reload Window** and start a new chat session.

### "Folder Not Found" Error

* Ensure `path` values in the workspace file point to the correct locations
* On your machine, verify HVE Core is cloned at the relative path specified
* For Codespaces, check that `onCreateCommand` ran successfully in creation logs

## Next Steps

* [Your First Workflow](../first-workflow.md) - Try HVE Core with a real task
* [RPI Workflow](../../rpi/) - Research, Plan, Implement, Review methodology
* [Back to Installation Guide](../install.md) - Compare other methods

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
