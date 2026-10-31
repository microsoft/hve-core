---
title: GitHub Codespaces Installation
description: Set up HVE Core in GitHub Codespaces with committed plugin defaults or a cloned copy
sidebar_position: 8
author: Microsoft
ms.date: 2026-10-31
ms.topic: how-to
keywords:
  - codespaces
  - installation
  - github copilot
  - postCreateCommand
  - cloud development
  - copilot settings
  - plugins
estimated_reading_time: 8
---

GitHub Codespaces runs your repository in a cloud container with no access to your local file system, so setups that depend on a peer directory or a host bind mount don't work there. Start by committing `.github/copilot/settings.json` with the HVE Core plugin defaults. That needs no clone, and Copilot offers HVE Core to everyone who opens the repository in a codespace. If you need a pinned or customized copy, use the [clone option](#clone-option) instead.

## When to Use This Method

✅ **Use this when:**

* Your project runs in GitHub Codespaces
* You want the repository to offer HVE Core to every contributor
* You want onboarding without a clone or per-user settings
* You need a pinned or customized copy inside the codespace (clone option)

❌ **Consider alternatives when:**

* You also need local devcontainer support → [Multi-Root Workspace](multi-root.md)
* Your team needs version control → [Submodule](submodule.md)
* You're using local VS Code only → [Peer Clone](peer-clone.md)

## Why Other Methods Don't Work in Codespaces

| Feature                   | Local Devcontainer | GitHub Codespaces  |
|---------------------------|--------------------|--------------------|
| `${localWorkspaceFolder}` | ✅ Resolves to host | ❌ Not available    |
| Bind mounts to host       | ✅ Full support     | ❌ No host access   |
| Persistent storage        | Host filesystem    | `/workspaces` only |

## How It Works

In the Copilot harness, `.github/copilot/settings.json` supplies plugin and marketplace defaults for the repository. With the HVE Core plugin keys in that file, `devcontainer.json` needs no HVE Core changes.

The clone option keeps a copy of HVE Core in the codespace instead. Where that copy lives depends on the Codespaces storage model:

```text
/
├── workspaces/                    # ✅ PERSISTENT - survives stops/restarts
│   ├── your-repo/                 # Your repository (the workspace folder)
│   │   ├── .github/copilot/
│   │   │   └── settings.json      # Plugin defaults or declared folders
│   │   ├── .gitignore             # Lists .hve-core/ (clone option)
│   │   └── .hve-core/             # 👈 Clone option: HVE Core goes here
│   └── hve-core/                  # ❌ Outside the checkout, cannot be declared
├── home/codespace/                # ⚠️ Semi-persistent (survives stops, not rebuilds)
└── <system-dirs>/                 # ❌ Not persistent
```

The clone option's `postCreateCommand` clones HVE Core into `.hve-core/` inside your repository folder. There the copy persists under `/workspaces` and sits inside the checkout, where the settings file can declare it. A clone outside the repository folder, such as `/workspaces/hve-core`, is outside the checkout and cannot be declared.

## Quick Start

For the fastest setup, commit the plugin defaults in Steps 1 and 2 below. To copy selected HVE Core components into your repository's own `.github` folders instead, ask an agent to use the included `hve-core-installer` skill, which records what it copied in `.hve-tracking.json`.

## Manual Setup

These steps set up the plugin defaults. Use one install route at a time: when HVE Core arrives by more than one route, for example the plugin and the VS Code extension, or the plugin and a declared clone, Copilot lists its agents more than once in the subagent list.

> [!NOTE]
> If you added `chat.*Locations` settings for HVE Core, such as `chat.agentFilesLocations`, `chat.instructionsFilesLocations`, or `chat.agentSkillsLocations`, remove them from `.vscode/settings.json` and from `customizations.vscode.settings` in `devcontainer.json`. Copilot does not need them, and VS Code still forwards files from those locations, which adds a second route.

### Step 1: Add Plugin Defaults

Create `.github/copilot/settings.json` in your repository, or add these keys to the existing file:

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

The marketplace key must match the marketplace name, `hve-core`. Each person can turn optional plugins off on the **Plugins** page of the Agent Customizations editor, and enterprise-managed settings take precedence over these defaults.

### Step 2: Commit and Push

```bash
git add .github/copilot/settings.json
git commit -m "feat: add HVE Core plugin defaults"
git push
```

### Step 3: Open a Codespace

* Create a new codespace from the updated branch
* In a codespace that is already running, pull the change and run **Developer: Reload Window**

### Step 4: Validate Installation

1. Open GitHub Copilot Chat (`Ctrl+Alt+I`) with the Copilot agent harness, which is the default.
2. Open the agent picker and confirm `RPI Agent` is listed.
3. Type `/` and confirm HVE Core skills appear with the plugin prefix, such as `/hve-core:rpi-research`.

## Clone Option

Use a clone when you need a pinned or customized copy of HVE Core.

### Add the Clone

Add the clone folder to your `.gitignore`:

```text
# HVE Core clone (created by postCreateCommand)
.hve-core/
```

Clone HVE Core in `devcontainer.json` when the codespace is created:

```jsonc
{
  // ... existing configuration ...

  "postCreateCommand": "[ -d .hve-core ] || git clone --depth 1 https://github.com/microsoft/hve-core.git .hve-core"
}
```

### Declare the Cloned Folders

Declare the clone's folders in `.github/copilot/settings.json`. If the file has the HVE Core plugin keys from Step 1, remove them so HVE Core arrives by one route.

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
* Whether path-specific instructions (those with `applyTo`) load from these folders is not confirmed yet. Use the plugin defaults when you need them.

### Rebuild and Validate

Commit `.gitignore`, `devcontainer.json`, and the settings file. Then create a new codespace, or run **Codespaces: Rebuild Container** from the Command Palette (`Ctrl+Shift+P`) in an existing one. Open the agent picker and confirm `RPI Agent` is listed, then type `/` and confirm skills such as `/rpi-research` or `/hve-core:rpi-research` appear.

## Complete Configuration Examples

These examples are for the clone option and pair with the settings file from [Declare the Cloned Folders](#declare-the-cloned-folders).

### Minimal Configuration

```jsonc
{
  "name": "HVE Core Enabled",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",

  "postCreateCommand": "[ -d .hve-core ] || git clone --depth 1 https://github.com/microsoft/hve-core.git .hve-core"
}
```

### Full-Featured Configuration

```jsonc
{
  "name": "HVE Core Development Environment",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",

  "features": {
    "ghcr.io/devcontainers/features/git:1": {},
    "ghcr.io/devcontainers/features/github-cli:1": {}
  },

  "postCreateCommand": "if [ ! -d .hve-core ]; then git clone --depth 1 https://github.com/microsoft/hve-core.git .hve-core; fi; if [ -d .hve-core/.github/agents ]; then echo '✅ HVE Core ready'; else echo '⚠️ HVE Core missing'; fi",

  "postStartCommand": "cd .hve-core && git pull --ff-only 2>/dev/null || echo 'Update skipped'"
}
```

### Dual-Environment (Local + Codespaces)

Both setups live in the repository, so a local devcontainer built from the same branch gets the same `.github/copilot/settings.json` and runs the same `postCreateCommand`. You don't need a host mount for HVE Core. Remove any mount of `../hve-core` at `/workspaces/hve-core`, because that target is outside the checkout and the settings file cannot declare it.

## Updating HVE Core

After any update, run **Developer: Reload Window** so new chat sessions pick up the change.

### Plugin Defaults

On the **Plugins** page of the Agent Customizations editor, select **Check for and Apply Updates** (the refresh icon), or run **Chat: Update Plugins** from the Command Palette.

### Manual Update

For the clone option, from your repository folder:

```bash
cd .hve-core
git pull
```

### Auto-Update on Codespace Start

Add `postStartCommand` to your devcontainer.json:

```jsonc
{
  "postStartCommand": "cd .hve-core && git pull --ff-only 2>/dev/null || true"
}
```

Codespaces runs `postStartCommand` each time the codespace starts.

### Force Fresh Clone

To always get the latest version on rebuild:

```jsonc
{
  "postCreateCommand": "rm -rf .hve-core && git clone --depth 1 https://github.com/microsoft/hve-core.git .hve-core"
}
```

**Warning:** This removes any local changes on every rebuild.

## Troubleshooting

### Agents Not Appearing

#### Check the plugin defaults

* Confirm `.github/copilot/settings.json` is on the branch the codespace was created from
* Confirm the marketplace key is `hve-core`, which must match the marketplace name
* Open the **Plugins** page of the Agent Customizations editor and check that `hve-core` is listed and turned on
* Check whether enterprise-managed settings apply to you, since they take precedence over repository defaults

#### Check HVE Core was cloned

For the clone option:

```bash
ls .hve-core/.github/agents
```

#### Check postCreateCommand ran

Look at the codespace creation log for clone output or errors.

### Clone Failed During Creation

**Network issues:** Try rebuilding the codespace.

**GitHub rate limiting:** Ensure you're authenticated:

```bash
gh auth status
```

### Settings Not Applied

If the clone exists but its agents don't appear, check `.github/copilot/settings.json`:

* Use relative paths inside the checkout, such as `.hve-core/.github/agents`. Absolute paths such as `/workspaces/hve-core/.github/agents` are rejected.
* Trust the workspace folder. Declared folders load only in a trusted workspace.
* Switch to the plugin defaults if you need path-specific instructions. Loading them from declared folders is not confirmed.

### Agents Appear More Than Once

HVE Core is arriving by more than one route. Look for the VS Code extension, for HVE Core plugin keys and declared folders together in `.github/copilot/settings.json`, and for the old editor settings described in the note under [Manual Setup](#manual-setup), then remove all but one.

### Codespace Rebuild Doesn't Update HVE Core

The clone command skips the clone when `.hve-core` already exists. Update it in place:

```bash
cd .hve-core
git pull
```

Or add the `postStartCommand` from [Auto-Update on Codespace Start](#auto-update-on-codespace-start).

## Limitations

| Aspect                     | Status                                                           |
|----------------------------|------------------------------------------------------------------|
| Codespaces                 | ✅  Designed for this                                             |
| Local devcontainers        | ⚠️  Works but consider other methods                             |
| Team sharing               | ✅  Plugin defaults offered to everyone who opens the repository  |
| Portable paths             | ✅  Relative paths inside the checkout                            |
| Path-specific instructions | ⚠️  Not confirmed from declared folders; use the plugin defaults |
| Version pinning            | ⚠️  Clone option with a release tag                              |
| Offline support            | ❌  Requires network during creation                              |
| Setup complexity           | ✅  Low (one committed settings file)                             |

## Version Pinning

To pin a version, use the clone option and clone a release tag:

```jsonc
{
  "postCreateCommand": "[ -d .hve-core ] || git clone --depth 1 --branch <release-tag> https://github.com/microsoft/hve-core.git .hve-core"
}
```

Replace `<release-tag>` with a tag from the repository's [Releases](https://github.com/microsoft/hve-core/releases) page.

## Next Steps

* [Your First Workflow](../first-workflow.md) - Try HVE Core with a real task
* [Multi-Root Workspace](multi-root.md) - For dual local + Codespaces support
* [Submodule](submodule.md) - For team version control

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
