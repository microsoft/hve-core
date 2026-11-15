---
title: Git-Ignored Folder Installation
description: Install HVE Core in a git-ignored folder for devcontainer environments
sidebar_position: 3
author: Microsoft
ms.date: 2026-11-10
ms.topic: how-to
keywords:
  - git-ignored
  - installation
  - github copilot
  - devcontainer
estimated_reading_time: 7
---

Git-Ignored Folder installation places HVE Core inside your project in a `.hve-core/` folder that's excluded from version control. This is ideal for solo developers using devcontainers who want a self-contained setup.

## When to Use This Method

✅ **Use this when:**

* You use local devcontainers (Docker Desktop)
* You're working solo
* You want HVE Core auto-updated with container rebuilds
* You want a self-contained project (no external dependencies)

❌ **Consider alternatives when:**

* Your team needs version control → [Submodule](submodule.md)
* You use Codespaces → [GitHub Codespaces](codespaces.md)
* You want to share HVE Core across projects → [Mounted Directory](mounted.md)
* You need paths that work everywhere → [Multi-Root Workspace](multi-root.md)

## How It Works

HVE Core is cloned into a `.hve-core/` folder inside your project. The folder is added to `.gitignore` so it doesn't pollute your repository. Copilot can use the copy in two ways: install the folder as a plugin from source (Option A), or, because the folder sits inside your checkout, declare its folders in `.github/copilot/settings.json` (Option B).

```text
my-project/
├── .devcontainer/
│   └── devcontainer.json    # postCreateCommand clones HVE Core
├── .github/
│   └── copilot/
│       └── settings.json    # Option B only: declares the .hve-core folders
├── .hve-core/               # Git-ignored, contains HVE Core
│   ├── .github/
│   │   ├── agents/
│   │   ├── instructions/
│   │   └── skills/
│   └── plugin.json          # Plugin manifest used by Option A
├── .gitignore               # Includes .hve-core/
└── src/
```

## Quick Start

To use HVE Core without keeping a clone, install the `hve-core` plugin as described in [Install the Plugin](../install#install-the-plugin). For guided installation-method selection, MCP configuration, or copying HVE Core into your project, ask an agent to use the included `hve-core-installer` skill. Use the manual steps below to install from a git-ignored folder.

## Manual Setup

### Step 1: Update .gitignore

Add the HVE Core folder to your `.gitignore`:

```text
# HVE Core installation (local only)
.hve-core/
```

### Step 2: Clone HVE Core

#### PowerShell

```powershell
# Create folder and clone
$hveCoreFolder = ".hve-core"
if (-not (Test-Path $hveCoreFolder)) {
    git clone https://github.com/microsoft/hve-core.git $hveCoreFolder
    Write-Host "✅ Cloned HVE Core to $hveCoreFolder"
}
```

#### Bash

```bash
HVE_CORE_FOLDER=".hve-core"

if [ ! -d "$HVE_CORE_FOLDER" ]; then
    git clone https://github.com/microsoft/hve-core.git "$HVE_CORE_FOLDER"
    echo "✅ Cloned HVE Core to $HVE_CORE_FOLDER"
fi
```

### Step 3: Connect the Copy to Copilot

Use one route at a time: pick one of the two options below, and don't also install the VS Code extension or the marketplace plugin. Copilot doesn't remove copies that arrive by different routes, so a second route lists agents more than once in the subagent list.

> [!NOTE]
> If you set `chat.agentFilesLocations`, `chat.instructionsFilesLocations`, or `chat.agentSkillsLocations` for HVE Core in `.vscode/settings.json` or your devcontainer settings, remove those entries. Copilot doesn't need them. Switch to the Copilot harness and confirm HVE Core loads there before you remove them, as [Use One Route at a Time](../install#use-one-route-at-a-time) describes.

#### Option A: Install the Folder as a Plugin

A plugin installed from the `.hve-core` folder carries the full set: agents, skills, and path-specific instructions. HVE Core keeps `plugin.json` at its repository root, so `.hve-core` is the plugin folder.

1. Run **Chat: Open Customizations** from the Command Palette to open the Agent Customizations editor, and select **Plugins**.
2. Select the add (`+`) button next to **User** or **Workspace**.
3. Enter the local path to your project's `.hve-core` folder.

**Chat: Install Plugin from Source** in the Command Palette does the same. This option works wherever the VS Code host can read the folder. Inside a devcontainer, confirm that `hve-core` appears on the **Plugins** page before you rely on the install.

#### Option B: Declare the Folders in Repository Settings

Create `.github/copilot/settings.json` at your project root:

```json
{
  "agentDirectories": [".hve-core/.github/agents"],
  "skillDirectories": [".hve-core/.github/skills"],
  "instructionDirectories": [".hve-core/.github/instructions"]
}
```

These limits apply:

* Paths must be literal folders inside the checkout. Copilot rejects absolute paths, `~`, environment variables, globs, and paths that leave the checkout.
* The folders load only when the workspace folder is trusted.
* Copilot finds agents and skills nested by package under each folder, so you don't list package folders one by one.
* Copilot inlines instructions that have no `applyTo`. Whether path-specific instructions (those with `applyTo`) load from these folders isn't confirmed yet, so use Option A when you need them.

A committed settings file applies to everyone who opens the repository, while the `.hve-core` folder exists only on your machine. If you work solo and don't want to commit the settings file, use Option A.

### Step 4: Automate with Devcontainer

Add to `.devcontainer/devcontainer.json` so HVE Core is cloned on container creation:

```jsonc
{
  // ... existing configuration ...

  "postCreateCommand": "[ -d .hve-core ] || git clone --depth 1 https://github.com/microsoft/hve-core.git .hve-core"
}
```

### Step 5: Validate Installation

1. Rebuild your devcontainer (`Ctrl+Shift+P` → "Dev Containers: Rebuild Container").
2. For Option B, make sure the workspace folder is trusted.
3. Open GitHub Copilot Chat (`Ctrl+Alt+I`) in a session that uses the Copilot harness, which is the default.
4. Open the agent picker and confirm `RPI Agent` is listed.
5. Type `/` and confirm HVE Core skills appear. With Option A, skills carry the plugin name as a prefix, such as `/hve-core:rpi-research`. With Option B, look for skills such as `/rpi-research` or `/hve-core:rpi-research`.

## Complete Devcontainer Example

```jsonc
{
  "name": "My Project with HVE Core",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",

  "postCreateCommand": "[ -d .hve-core ] || git clone --depth 1 https://github.com/microsoft/hve-core.git .hve-core"
}
```

The devcontainer needs no VS Code settings for HVE Core. Connect the copy with Option A or Option B from [Step 3](#step-3-connect-the-copy-to-copilot).

## Updating HVE Core

### Manual update

```bash
cd .hve-core
git pull
```

After the pull, run **Developer: Reload Window** from the Command Palette so new chat sessions pick up the change. With Option A, if the change still doesn't show up, select **Check for and Apply Updates** on the **Plugins** page.

### Auto-update on container rebuild

The `postCreateCommand` re-clones on each container creation. To update, rebuild the container.

### Auto-update with version check

```jsonc
{
  "postCreateCommand": {
    "clone-or-update": "[ -d .hve-core ] && (cd .hve-core && git pull) || git clone --depth 1 https://github.com/microsoft/hve-core.git .hve-core"
  }
}
```

## Troubleshooting

### Agents Not Appearing

#### Check the folder exists

```bash
ls .hve-core/.github/agents
```

#### Check the plugin or settings file

* For Option A, confirm `hve-core` appears on the **Plugins** page of the Agent Customizations editor
* For Option B, confirm the paths in `.github/copilot/settings.json` start with `.hve-core/.github/` and that the workspace folder is trusted
* Run **Developer: Reload Window** from the Command Palette, then start a new chat session

### Agents Appear More Than Once

HVE Core is arriving through more than one route, and Copilot doesn't remove copies that arrive by different routes. Keep Option A or Option B and remove the other. If you also installed the VS Code extension or the `hve-core` plugin from the marketplace, remove that too.

### Folder Not Ignored by Git

Check your `.gitignore` includes `.hve-core/`:

```bash
cat .gitignore | grep hve-core
```

If missing, add it:

```bash
echo ".hve-core/" >> .gitignore
```

### Clone Fails in Devcontainer

If `postCreateCommand` fails, check:

1. Network connectivity in the container
2. Git is available (`git --version`)
3. GitHub is accessible (`curl -I https://github.com`)

### Container Rebuild Doesn't Update

The clone only happens if the folder doesn't exist. To force update:

```jsonc
{
  "postCreateCommand": "rm -rf .hve-core && git clone --depth 1 https://github.com/microsoft/hve-core.git .hve-core"
}
```

**Warning:** This deletes any local changes to HVE Core on every rebuild.

## Limitations

| Aspect                     | Status                                                             |
|----------------------------|--------------------------------------------------------------------|
| Devcontainers              | ✅  Designed for this                                              |
| Codespaces                 | ⚠️  Works but not optimal (use [Codespaces method](codespaces.md)) |
| Team sharing               | ⚠️  Each developer clones separately                               |
| Portable paths             | ✅  Option B uses relative paths inside the checkout               |
| Path-specific instructions | ⚠️  Load with Option A; not confirmed with Option B                |
| Workspace trust            | ⚠️  Option B folders load only in a trusted workspace folder       |
| Version pinning            | ⚠️  Manual (modify clone command)                                  |
| Disk usage                 | ⚠️  Per-project copy                                               |
| Setup complexity           | ✅  Simple                                                         |

## Next Steps

* [Your First Workflow](../first-workflow.md) - Try HVE Core with a real task
* [Multi-Root Workspace](multi-root.md) - Share across local + Codespaces
* [Submodule](submodule.md) - Add version control for teams

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
