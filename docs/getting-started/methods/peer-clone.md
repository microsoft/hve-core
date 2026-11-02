---
title: Peer Directory Clone Installation
description: Clone HVE Core next to your project and install it in VS Code as a plugin from source
sidebar_position: 4
author: Microsoft
ms.date: 2026-11-02
ms.topic: how-to
keywords:
  - peer directory
  - installation
  - github copilot
  - local development
  - plugin from source
estimated_reading_time: 5
---

Peer Directory Clone keeps HVE Core in a sibling folder next to your project, and you install that folder in VS Code as a plugin from source. It is a simple setup for developers who use local VS Code without devcontainers.

## When to Use This Method

✅ **Use this when:**

* You're using local VS Code (no devcontainer)
* You're working solo on a project
* You want a copy of HVE Core on disk that you update or pin with Git
* You're developing or testing HVE Core itself

❌ **Consider alternatives when:**

* You use devcontainers → [Git-Ignored Folder](git-ignored.md) or [Mounted Directory](mounted.md)
* You use Codespaces → [GitHub Codespaces](codespaces.md)
* Your team needs version control → [Submodule](submodule.md)
* You maintain your organization's fork of HVE Core → [Multi-Root Workspace](multi-root.md)

## How It Works

HVE Core keeps `plugin.json` at its repository root, so the root folder of your clone is the plugin folder. After you install that folder as a plugin from source, Copilot gets the full set of HVE Core agents, skills, and path-specific instructions from it. Your project needs no HVE Core settings.

```text
projects/
├── my-project/              # Your project, with no HVE Core settings
│
└── hve-core/                # Sibling clone, installed as a plugin from source
    ├── plugin.json          # Plugin manifest at the repository root
    └── .github/
        ├── agents/
        ├── instructions/
        └── skills/
```

A project can also list customization folders in `.github/copilot/settings.json`, but only folders inside the project checkout. A sibling folder such as `../hve-core` is outside the checkout and cannot be listed there, so this method installs it as a plugin.

> [!NOTE]
> If an earlier setup added `chat.agentFilesLocations`, `chat.instructionsFilesLocations`, or `chat.agentSkillsLocations` entries for HVE Core to `.vscode/settings.json`, remove them. Copilot does not need them. Switch to the Copilot harness and confirm HVE Core loads there before you remove them, as [Use One Route at a Time](../install#use-one-route-at-a-time) describes.

## Quick Start

To use HVE Core without keeping a clone, install the `hve-core` plugin as described in [Install the Plugin](../install#install-the-plugin). For guided installation-method selection, MCP configuration, or copying selected components into your project, ask an agent to use the included `hve-core-installer` skill. Use the manual steps below to install from a peer clone.

## Manual Setup

### Step 1: Clone HVE Core

Open a terminal in your project's parent directory:

```bash
# Navigate to parent of your project
cd /path/to/projects

# Clone HVE Core as a sibling
git clone https://github.com/microsoft/hve-core.git
```

Your directory structure should now look like:

```text
projects/
├── my-project/
└── hve-core/
```

### Step 2: Install the Clone as a Plugin

Install the clone's root folder, the one that holds `plugin.json`, as a plugin from source:

1. Run **Chat: Open Customizations** from the Command Palette to open the Agent Customizations editor, and select **Plugins**.
2. Select the add (`+`) button next to **User**.
3. Enter the clone's local folder path, such as `/path/to/projects/hve-core`.

Running **Chat: Install Plugin from Source** from the Command Palette (`Ctrl+Shift+P`) does the same.

> [!IMPORTANT]
> Use one install route at a time. When the same content arrives through more than one route, for example this plugin and the HVE Core VS Code extension, Copilot lists agents more than once in the subagent list and does not remove the copies.

### Step 3: Validate Installation

1. Run **Developer: Reload Window** from the Command Palette so new chat sessions pick up the plugin.
2. Open Copilot Chat (`Ctrl+Alt+I`) with the Copilot harness, which is the VS Code default.
3. Open the agent picker and confirm `RPI Agent` is listed.
4. Type `/` and confirm skills such as `/hve-core:rpi-research` appear. VS Code prefixes a plugin's skills with the plugin name.

## Updating HVE Core

To get the latest version, pull in the clone:

```bash
cd ../hve-core
git pull
```

Then run **Developer: Reload Window** so new chat sessions pick up the change. If the change still does not show up, open the **Plugins** page in the Agent Customizations editor and select **Check for and Apply Updates** (the refresh icon), or run **Chat: Update Plugins**.

## Troubleshooting

### Agents Not Appearing

#### Check the clone

```bash
# From your project directory
ls ../hve-core/plugin.json
```

If the file is missing, verify:

1. HVE Core is cloned at the correct location
2. Your terminal is in your project directory

#### Check the plugin install

1. Open the Agent Customizations editor, select **Plugins**, and confirm `hve-core` is listed.
2. If it is missing, repeat Step 2 with the path of the folder that holds `plugin.json`.
3. Run **Developer: Reload Window** and start a new chat session.

### Doesn't Work in Devcontainer

Peer directory clone doesn't work in devcontainers because the container can't access files outside the mounted workspace.

#### Solutions

* Use [Git-Ignored Folder](git-ignored.md) for self-contained installation
* Use [Mounted Directory](mounted.md) to share HVE Core across projects

## Limitations

| Aspect           | Status                                            |
|------------------|---------------------------------------------------|
| Devcontainers    | ❌  Not supported                                  |
| Codespaces       | ❌  Not supported                                  |
| Team sharing     | ⚠️  Each developer clones and installs separately |
| Project settings | ✅  None needed                                    |
| Version pinning  | ⚠️  Manual (use git checkout)                     |
| Setup complexity | ✅  Simple (clone, then install from source)       |
| Update process   | ✅  git pull, then reload the window               |

## Next Steps

* [Your First Workflow](../first-workflow.md) - Try HVE Core with a real task
* [Multi-Root Workspace](multi-root.md) - Open your organization's fork next to your project
* [Submodule](submodule.md) - Add version control for teams

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
