---
title: Git Submodule Installation
description: Set up HVE Core as a git submodule for version-controlled team consumption
sidebar_position: 7
author: Microsoft
ms.date: 2026-11-02
ms.topic: how-to
keywords:
  - git submodule
  - installation
  - github copilot
  - version control
  - teams
estimated_reading_time: 8
---

A git submodule pins HVE Core to one commit for your whole team. Every team member gets the same version, and updates are explicit commits. A committed `.github/copilot/settings.json` file points Copilot at the agents, skills, and instructions inside the submodule.

## When to Use This Method

✅ **Use this when:**

* Your team needs reproducible setups (same version for everyone)
* You want to pin HVE Core to a specific version
* Updates should be deliberate, reviewed commits
* HVE Core dependency should be tracked in version control

❌ **Consider alternatives when:**

* Your team doesn't need a pinned version → [Plugin as a Team Default](#plugin-as-a-team-default)
* You want automatic updates → [Multi-Root Workspace](multi-root.md)
* You're a solo developer without version pinning needs → [Multi-Root Workspace](multi-root.md)

## How It Works

A git submodule embeds HVE Core as a nested repository within your project. The `.gitmodules` file tracks the repository URL, and your project's git history tracks the exact commit. Because the submodule sits inside your checkout, `.github/copilot/settings.json` can declare its folders with relative paths.

```text
your-project/
├── .github/
│   └── copilot/
│       └── settings.json  ← Declares the lib/hve-core folders
├── .gitmodules            ← Defines submodule URL
└── lib/
    └── hve-core/          ← Submodule (points to specific commit)
        └── .github/
            ├── agents/
            ├── instructions/
            └── skills/
```

## Quick Start

If your team doesn't need a pinned version, use the `hve-core` plugin instead: commit the [plugin defaults](#plugin-as-a-team-default), or have each person install it as described in [Install the Plugin](../install#install-the-plugin).

For guided installation-method selection, MCP configuration, or copying selected components into your project, ask an agent to use the included `hve-core-installer` skill. Use the manual steps below to set up the submodule.

## Manual Setup

### Step 1: Add the Submodule

```bash
# From your project root
git submodule add https://github.com/microsoft/hve-core.git lib/hve-core
git commit -m "Add HVE Core as submodule"
```

This creates a `.gitmodules` file:

```ini
[submodule "lib/hve-core"]
    path = lib/hve-core
    url = https://github.com/microsoft/hve-core.git
    branch = main
```

### Step 2: Declare the Submodule Folders

Create `.github/copilot/settings.json` at your project root and list the submodule's agent, skill, and instruction folders:

```json
{
  "agentDirectories": ["lib/hve-core/.github/agents"],
  "skillDirectories": ["lib/hve-core/.github/skills"],
  "instructionDirectories": ["lib/hve-core/.github/instructions"]
}
```

Commit the file so the settings apply to everyone who opens the repository. Your project's own `.github/agents`, `.github/skills`, and `.github/instructions` folders need no entries, because Copilot discovers them without settings.

> [!NOTE]
> If you set `chat.agentFilesLocations`, `chat.instructionsFilesLocations`, or `chat.agentSkillsLocations` for HVE Core in `.vscode/settings.json` or your devcontainer settings, remove those entries. Copilot doesn't need them. Switch to the Copilot harness and confirm HVE Core loads there before you remove them, as [Use One Route at a Time](../install#use-one-route-at-a-time) describes.

Keep these limits in mind:

* Paths must be literal folders inside the checkout. Copilot rejects absolute paths, `~`, environment variables, globs, and paths that leave the checkout.
* The folders load only when the workspace folder is trusted.
* Copilot finds agents and skills nested by package under each folder, so you don't list package folders one by one.
* Copilot inlines instructions that have no `applyTo`. Whether path-specific instructions (those with `applyTo`) load from these folders isn't confirmed yet. If your team needs them, skip this step and use the plugin instead: the [team default](#plugin-as-a-team-default), or a plugin each person installs from the `lib/hve-core` folder with **Chat: Install Plugin from Source**.

> [!IMPORTANT]
> Use one route at a time. If HVE Core also arrives through the `hve-core` plugin or the VS Code extension, Copilot lists each agent more than once in the subagent list, because it doesn't remove copies that arrive by different routes.

### Step 3: Configure Devcontainer (Codespaces)

Update `.devcontainer/devcontainer.json` to initialize submodules automatically:

```jsonc
{
  "name": "My Project with HVE Core",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",

  "onCreateCommand": "git submodule update --init --recursive",

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

## Team Member Onboarding

When team members clone your project, they need to initialize submodules. Until they do, the declared folders are empty. Copilot also loads those folders only when the workspace folder is trusted.

### Option A: Clone with submodules (recommended)

```bash
git clone --recurse-submodules https://github.com/your-org/your-project.git
```

### Option B: Initialize after clone

```bash
git clone https://github.com/your-org/your-project.git
cd your-project
git submodule update --init --recursive
```

### Option C: Configure git to auto-recurse

```bash
git config --global submodule.recurse true
# Now all git operations auto-update submodules
```

## Updating HVE Core

| Task                   | Command                                                               |
|------------------------|-----------------------------------------------------------------------|
| Check for updates      | `cd lib/hve-core && git fetch && git log HEAD..origin/main --oneline` |
| Update to latest       | `git submodule update --remote lib/hve-core`                          |
| Pin to specific commit | `cd lib/hve-core && git checkout <sha>`                               |
| Track different branch | `git config submodule.lib/hve-core.branch develop`                    |

### After updating, commit the change

```bash
git add lib/hve-core
git commit -m "Update HVE Core submodule to latest"
```

Then run **Developer: Reload Window** from the Command Palette so new chat sessions pick up the change. If you installed the `lib/hve-core` folder as a plugin and the change still doesn't show up, select **Check for and Apply Updates** on the **Plugins** page. Teammates who pull the commit update their submodule, automatically with `submodule.recurse` or by running `git submodule update --init --recursive`, and then reload their windows too.

### Auto-Update on Container Rebuild

To update HVE Core when rebuilding your devcontainer:

```jsonc
{
  "updateContentCommand": "git submodule update --remote lib/hve-core || true"
}
```

## Version Pinning

Submodules pin to a specific commit by default. To verify or change the pinned version:

### Check current version

```bash
cd lib/hve-core
git log -1 --oneline
```

### Pin to a specific tag or commit

```bash
cd lib/hve-core
git checkout v1.2.0  # or a specific commit SHA
cd ..
git add lib/hve-core
git commit -m "Pin HVE Core to v1.2.0"
```

## Verification

After setup, verify HVE Core is working:

1. Check that `lib/hve-core/` contains the HVE Core repository.
2. Make sure the workspace folder is trusted, then run **Developer: Reload Window** from the Command Palette.
3. Open Copilot Chat (`Ctrl+Alt+I`) in a session that uses the Copilot harness, which is the default.
4. Open the agent picker and confirm `RPI Agent` is listed.
5. Type `/` and confirm HVE Core skills appear, such as `/rpi-research` or `/hve-core:rpi-research`.

## Troubleshooting

### Submodule folder is empty

The submodule wasn't initialized:

```bash
git submodule update --init --recursive
```

### Agents not appearing

* Verify the paths in `.github/copilot/settings.json` match the submodule location and are literal relative paths inside the checkout
* Make sure the workspace folder is trusted, because declared folders load only in a trusted workspace folder
* Reload the window with `Ctrl+Shift+P` → "Developer: Reload Window"
* Confirm submodule content exists with `ls lib/hve-core/.github/agents/`

### Agents appear more than once

HVE Core is arriving through more than one route, and Copilot doesn't remove copies that arrive by different routes. Keep one route. If the team keeps the folder entries from Step 2, delete any plugin defaults from the same file, and have each person remove the `hve-core` plugin or the VS Code extension if they installed one.

### Path-specific instructions don't apply

Copilot inlines instructions without `applyTo` from declared folders, but loading of path-specific instructions from those folders isn't confirmed. When your team needs them, replace the Step 2 entries with the [plugin as a team default](#plugin-as-a-team-default) or a plugin installed from the `lib/hve-core` folder.

### "Detached HEAD" warning in submodule

This is normal for submodules. The submodule points to a specific commit, not a branch. To work on the submodule:

```bash
cd lib/hve-core
git checkout main
```

### Merge conflicts in submodule pointer

When multiple team members update the submodule:

```bash
git checkout --theirs lib/hve-core  # Accept their version
# OR
git checkout --ours lib/hve-core    # Keep your version
git add lib/hve-core
git commit
```

## Plugin as a Team Default

If your team doesn't need a pinned version, skip the submodule. Commit plugin defaults in `.github/copilot/settings.json` instead, and the Copilot harness offers the `hve-core` plugin to everyone who opens the repository:

```json
{
  "extraKnownMarketplaces": {
    "hve-core": {
      "source": {
        "source": "github",
        "repo": "microsoft/hve-core"
      }
    }
  },
  "enabledPlugins": {
    "hve-core@hve-core": true
  }
}
```

The plugin carries the full set, including path-specific instructions. Its registration tracks `main`, and each person applies updates with **Check for and Apply Updates** on the **Plugins** page, so you give up the shared pinned version a submodule provides. The marketplace key must match the marketplace name, `hve-core`. Each person can turn optional plugins off on the **Plugins** page, and enterprise-managed settings take precedence over these defaults.

Don't combine these keys with the folder entries from Step 2. With both in the file, HVE Core arrives through two routes, and Copilot lists each agent more than once.

To check the plugin, run **Developer: Reload Window**, confirm `RPI Agent` appears in the agent picker, and type `/` to find its skills. Plugin skills carry the plugin name as a prefix, so the Research skill appears as `/hve-core:rpi-research`.

## Comparison with Other Methods

| Aspect               | Submodule           | Multi-Root        | Clone         |
|----------------------|---------------------|-------------------|---------------|
| Version controlled   | ✅  Yes              | ⚠️  Partial       | ❌  No         |
| Team reproducibility | ✅  Same version     | ⚠️  May vary      | ⚠️  May vary  |
| Update control       | ✅  Explicit commits | ⚠️  Automatic     | ⚠️  Automatic |
| In workspace         | ✅  Subfolder        | ✅  Workspace root | ❌  External   |
| Initial setup        | 🟡  Medium          | 🟡  Medium        | 🟢  Easy      |

## Next Steps

* [Your First Workflow](../first-workflow.md) - Try HVE Core with a real task
* [RPI Workflow](../../rpi/) - Research, Plan, Implement, Review methodology
* [Back to Installation Guide](../install.md) - Compare other methods

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
