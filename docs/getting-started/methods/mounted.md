---
title: Mounted Directory Installation
description: Advanced devcontainer setup mounting HVE Core from host filesystem
sidebar_position: 5
author: Microsoft
ms.date: 2026-10-31
ms.topic: how-to
keywords:
  - mounted directory
  - installation
  - github copilot
  - devcontainer
  - advanced
  - copilot settings
estimated_reading_time: 7
---

Mounted Directory installation shares one HVE Core clone on your host across several devcontainer projects. Each project mounts the clone into a git-ignored folder inside its workspace folder and declares the mounted folders in `.github/copilot/settings.json`. This is an **advanced method** requiring container rebuilds.

## When to Use This Method

✅ **Use this when:**

* You have multiple devcontainer projects needing HVE Core
* You want a single shared installation (one update applies everywhere)
* You're comfortable with devcontainer configuration
* You're using local devcontainers only (not Codespaces)

❌ **Consider alternatives when:**

* You don't need a shared clone → the `hve-core` plugin ([Quick Start](#quick-start))
* You use Codespaces → [GitHub Codespaces](codespaces.md) (mounts don't work)
* You want simpler setup → [Git-Ignored Folder](git-ignored.md)
* Your team needs version control → [Submodule](submodule.md)
* You need paths that work everywhere → [Multi-Root Workspace](multi-root.md)

## ⚠️ Important Limitations

**This method does NOT work in GitHub Codespaces.** Codespaces doesn't support `${localWorkspaceFolder}` or bind mounts to host filesystem.

**Requires container rebuild.** After adding the mount, you must rebuild the devcontainer before HVE Core becomes accessible.

**Mount inside the workspace folder.** The settings file can declare only folders inside your project's checkout, so a mount target outside the workspace folder, such as `/workspaces/hve-core`, cannot be declared.

## How It Works

HVE Core is cloned on your **host machine** as a sibling to your project. The devcontainer mounts that clone at `.hve-core/` inside the project's workspace folder, and the project's `.github/copilot/settings.json` declares the mounted `agents`, `skills`, and `instructions` folders.

```text
Host File System:
projects/
├── my-project/                    # Your project (workspace)
│   ├── .devcontainer/
│   │   └── devcontainer.json      # Contains mount configuration
│   ├── .github/
│   │   └── copilot/
│   │       └── settings.json      # Declares the mounted folders
│   └── .gitignore                 # Lists .hve-core/
│
└── hve-core/                      # Peer directory on HOST
    └── .github/
        ├── agents/
        ├── instructions/
        └── skills/

Inside Container (after rebuild):
/workspaces/
└── my-project/                    # Mounted workspace
    └── .hve-core/                 # Mounted peer directory (git-ignored)
```

## Installation Workflow

This method requires a multi-phase workflow:

```text
┌─────────────────────────────────────────────────────────────┐
│ Phase 1: Clone HVE Core on HOST                             │
│          ↓                                                  │
│ Phase 2: Add mount to devcontainer.json                     │
│          ↓                                                  │
│ Phase 3: Rebuild container (1-3 minutes)                    │
│          ↓                                                  │
│ Phase 4: Declare folders in .github/copilot/settings.json   │
│          ↓                                                  │
│ Phase 5: Validate installation                              │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

If you don't need one clone shared across projects, install the `hve-core` plugin instead, as described in [Install the Plugin](../install#install-the-plugin). To offer the plugin to everyone who opens your repository, commit the defaults described in [Offer the Plugin to Your Team](../install#offer-the-plugin-to-your-team).

To copy selected components into your repository's own `.github` folders, ask an agent to use the included `hve-core-installer` skill. Use the manual steps below for the mounted setup.

## Manual Setup

Use one install route at a time: when HVE Core arrives by more than one route, for example the plugin and the VS Code extension, or the plugin and a declared clone, Copilot lists its agents more than once in the subagent list.

> [!NOTE]
> If you added `chat.*Locations` settings for HVE Core, such as `chat.agentFilesLocations`, `chat.instructionsFilesLocations`, or `chat.agentSkillsLocations`, remove them from `.vscode/settings.json` and from `customizations.vscode.settings` in `devcontainer.json`. Copilot does not need them, and VS Code still forwards files from those locations, which adds a second route.

### Phase 1: Clone HVE Core on Host

**Important:** Clone on your **host machine**, not inside the container.

Open a terminal on your host (not in VS Code's container terminal):

```bash
# Navigate to parent of your project
cd /path/to/projects

# Clone HVE Core as a sibling
git clone https://github.com/microsoft/hve-core.git
```

Verify structure:

```text
projects/
├── my-project/
└── hve-core/        # ← Must exist on HOST before rebuild
```

### Phase 2: Add Mount to devcontainer.json

Mount the host clone at `.hve-core` inside the container's workspace folder. Update `.devcontainer/devcontainer.json`:

```jsonc
{
  // ... existing configuration ...

  "mounts": [
    "source=${localWorkspaceFolder}/../hve-core,target=${containerWorkspaceFolder}/.hve-core,type=bind,readonly=true,consistency=cached"
  ]
}
```

#### Alternative object format

```jsonc
{
  "mounts": [
    {
      "type": "bind",
      "source": "${localWorkspaceFolder}/../hve-core",
      "target": "${containerWorkspaceFolder}/.hve-core"
    }
  ]
}
```

#### Ignore the mount folder

Add the mount folder to your project's `.gitignore` so Git does not pick up the mounted copy:

```text
# Shared HVE Core mount (local only)
.hve-core/
```

### Phase 3: Rebuild Container

⚠️ **Container rebuild is required** to apply the mount.

1. Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on macOS)
2. Type "Dev Containers: Rebuild Container"
3. Press Enter and wait for rebuild (1-3 minutes)

#### What happens during rebuild

* Current container stops
* New container builds with mount configuration
* Extensions reinstall
* Lifecycle scripts re-run

### Phase 4: Declare the Mounted Folders

After the rebuild, create `.github/copilot/settings.json` in your project, or add these keys to the existing file:

```json
{
  "agentDirectories": [".hve-core/.github/agents"],
  "skillDirectories": [".hve-core/.github/skills"],
  "instructionDirectories": [".hve-core/.github/instructions"]
}
```

The settings file has these limits:

* Paths must be literal folders inside the checkout. Absolute paths, `~`, environment variables, globs, and paths that leave the checkout are rejected.
* The folders load only when the workspace folder is trusted.
* Copilot finds agents and skills nested by package under each folder, and inlines instructions that have no `applyTo`.
* Whether path-specific instructions (those with `applyTo`) load from these folders is not confirmed yet. Use the plugin when you need them.

#### Install the mount as a plugin instead

HVE Core keeps `plugin.json` at its repository root, so the mounted folder is also a plugin folder. Instead of declaring its folders, you can install it as a plugin from source. Run **Chat: Open Customizations** to open the Agent Customizations editor, select **Plugins**, select the add (`+`) button next to **User** or **Workspace**, and enter the mount path, such as `/workspaces/my-project/.hve-core`. **Chat: Install Plugin from Source** in the Command Palette does the same.

How this route behaves inside a container is not confirmed, so check that `hve-core` appears on the **Plugins** page before you rely on it. If you use this route, skip the settings file.

### Phase 5: Validate Installation

1. Open GitHub Copilot Chat (`Ctrl+Alt+I`) with the Copilot agent harness, which is the default.
2. Open the agent picker and confirm `RPI Agent` is listed.
3. Type `/` and confirm skills such as `/rpi-research` or `/hve-core:rpi-research` appear. If you installed the mount as a plugin, skills carry the plugin prefix, as in `/hve-core:rpi-research`.

#### Verify mount from container terminal

```bash
# From the project folder
ls .hve-core/.github/agents
```

## Complete Devcontainer Example

```jsonc
{
  "name": "My Project with Mounted HVE Core",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",

  "mounts": [
    "source=${localWorkspaceFolder}/../hve-core,target=${containerWorkspaceFolder}/.hve-core,type=bind,readonly=true,consistency=cached"
  ]
}
```

Pair it with the `.hve-core/` entry in `.gitignore` and the `.github/copilot/settings.json` file from Phase 4.

## Updating HVE Core

Update on your host machine:

```bash
cd /path/to/projects/hve-core
git pull
```

Every container that uses the mount sees the new files without a rebuild. Run **Developer: Reload Window** in each open VS Code window so new chat sessions pick up the change.

## Troubleshooting

### Mount Point Empty After Rebuild

**Cause:** HVE Core wasn't cloned on the host, or was cloned in the wrong location.

#### Fix

1. Exit the container
2. Clone HVE Core on your host machine (see Phase 1)
3. Verify the path matches the mount source
4. Rebuild the container

#### Check from host terminal

```bash
# On host, not in container
ls /path/to/projects/hve-core/.github
```

### Container Fails to Start

**Cause:** Mount source path doesn't exist.

#### Fix

1. Check `devcontainer.json` mount path
2. Ensure HVE Core exists at `${localWorkspaceFolder}/../hve-core`
3. Remove the mount temporarily to start the container
4. Clone HVE Core, then add mount back and rebuild

### Agents Not Appearing

#### Check mount is working

```bash
# Inside container, from the project folder
ls .hve-core/.github/agents
```

#### Check the settings file

Declared paths must be relative folders inside the checkout, such as `.hve-core/.github/agents`. Absolute container paths such as `/workspaces/hve-core/.github/agents` are rejected. The workspace folder must also be trusted.

### Path-Specific Instructions Not Applied

Copilot inlines instructions without `applyTo` from declared folders, but whether it loads path-specific instructions from them is not confirmed. If you need them, use the `hve-core` plugin from the [Quick Start](#quick-start).

### Agents Appear More Than Once

HVE Core is arriving by more than one route. Look for the VS Code extension, for a plugin install alongside the declared folders, and for the old editor settings described in the note under [Manual Setup](#manual-setup), then remove all but one.

### Doesn't Work in Codespaces

This is expected. Codespaces doesn't support `${localWorkspaceFolder}` or host bind mounts.

**Solution:** For Codespaces, follow [GitHub Codespaces](codespaces.md), which commits plugin defaults to the repository. For dual-environment support, see [Multi-Root Workspace](multi-root.md).

## Limitations

| Aspect                     | Status                                                  |
|----------------------------|---------------------------------------------------------|
| Devcontainers              | ✅  Full support                                         |
| Codespaces                 | ❌  Not supported (no host access)                       |
| Team sharing               | ⚠️  Each developer clones on their host                 |
| Portable paths             | ✅  Relative paths inside the checkout                   |
| Path-specific instructions | ⚠️  Not confirmed from declared folders; use the plugin |
| Version pinning            | ⚠️  Manual (use git checkout on host)                   |
| Shared installation        | ✅  One clone serves all projects                        |
| Setup complexity           | ⚠️  High (multi-phase, requires rebuild)                |
| Update process             | ✅  git pull on host, then reload the window             |

## Next Steps

* [Your First Workflow](../first-workflow.md) - Try HVE Core with a real task
* [Multi-Root Workspace](multi-root.md) - Simpler portable solution
* [GitHub Codespaces](codespaces.md) - If you also need Codespaces support

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
