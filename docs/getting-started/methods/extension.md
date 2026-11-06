---
title: VS Code Extension Installation
description: Install HVE Core as a VS Code extension from the Marketplace and learn which components reach Copilot sessions
sidebar_position: 2
author: Microsoft
ms.date: 2026-11-06
ms.topic: how-to
keywords:
  - extension
  - installation
  - marketplace
  - github copilot
estimated_reading_time: 5
---

The HVE Core extension, `ise-hve-essentials.hve-core`, installs HVE Core from the VS Code Marketplace with Stable and PreRelease channels. VS Code forwards the extension's agents and skills to Copilot chat sessions. The extension's instructions may not reach those sessions, and the extension has no canvases, so the [Copilot Plugin](cli-plugins) is the better fit when you need either.

## When to Use This Method

✅ **Use this when:**

* You manage editor tools through the VS Code Marketplace
* You want Stable or PreRelease release channels with published-release assurance
* You mostly use HVE Core agents and skills
* You don't need to customize HVE Core components

❌ **Consider alternatives when:**

* You need path-specific instructions in Copilot sessions, or canvases → [Copilot Plugin](cli-plugins)
* You need to customize agents, skills, or instructions → [Copy HVE Core Into Your Repository](../install#copy-hve-core-into-your-repository) or [Git-Ignored Folder](git-ignored)
* Your team needs to version control HVE Core → [Git Submodule](submodule)
* You're contributing to HVE Core or testing an unpublished branch → [Peer Directory Clone](peer-clone)

## How It Works

The extension ships the complete HVE Core component set. Stable and PreRelease use the same extension identity and component content and differ in version, cadence, and source commit.

```text
VS Code
├── HVE Core extension (from the Marketplace)
│   ├── .github/agents/         # Forwarded to Copilot sessions
│   ├── .github/skills/         # Forwarded to Copilot sessions
│   └── .github/instructions/   # May not reach Copilot sessions
└── Copilot chat sessions use the forwarded agents and skills
```

## Quick Start

### Option 1: Install from Marketplace (Recommended)

1. Open VS Code
2. Go to Extensions view (`Ctrl+Shift+X`)
3. Search for "HVE Core"
4. Click **Install**

**Or click here:** [Install HVE Core Extension](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core)

### Option 2: Install from Command Line

```bash
code --install-extension ise-hve-essentials.hve-core
```

### Option 3: Install Using VS Code Insiders

```bash
code-insiders --install-extension ise-hve-essentials.hve-core
```

## Verification

1. Open GitHub Copilot Chat (`Ctrl+Alt+I`). New chat sessions use the Copilot harness by default.
2. Open the agent picker and confirm HVE Core agents such as `RPI Agent`, `Documentation`, and `ADR Creator` appear.
3. Type `/` and confirm HVE Core skills such as `rpi-research` appear.

If you install another route later, such as the plugin, uninstall the extension first so agents do not appear twice.

## Post-Installation (Optional)

These optional configurations improve your HVE Core experience but are not required for basic functionality.

### Update Your .gitignore

HVE Core agents write working files to a `.copilot-tracking/` folder in your project. Add this line to your project's `.gitignore`:

```text
.copilot-tracking/
```

This applies to the extension too. Agents create the folder in your project directory when you use workflows such as `rpi-research` or `code-review`. The [installation guide](../install.md#post-installation-update-your-gitignore) describes what the folder stores.

## What's Included

The extension provides all HVE Core components:

| Component           | Examples                                                                | Reaches Copilot sessions |
|---------------------|-------------------------------------------------------------------------|--------------------------|
| Chat agents         | RPI Agent, Code Review, ADR Creator                                     | Yes                      |
| User-invoked skills | `/git-commit`, `/pull-request` for GitHub or Azure DevOps, `/git-merge` | Yes                      |
| Skills              | rpi-research, pr-reference, demo-video                                  | Yes                      |
| Instructions        | markdown, python-script, writing-style                                  | May not                  |

HVE Core no longer ships prompt files. [Retired Prompt Commands](../package-migration.md#retired-prompt-commands) maps each former prompt command to its replacement.

## Updating

VS Code updates the extension through its extension system:

* Extensions update automatically when new versions are released (default)
* Open Extensions view → find "HVE Core" → click **Update** for manual updates
* Right-click the extension → "Switch to Pre-Release Version" to select the PreRelease channel

Source moves through reviewed promotions from `main` to `release/prerelease`
to `release/stable`. PreRelease is packaged from `release/prerelease`; Stable
is packaged from `release/stable` and may lag newer `main` content. Both
channels include active components labeled `stable`, `preview`, and
`experimental`.

The plugin has one registration, `microsoft/hve-core`, which tracks `main`;
there are no PreRelease or Stable plugin channels.

## Comparison with Other Methods

### Pros ✅

| Advantage             | Detail                                                 |
|-----------------------|--------------------------------------------------------|
| Marketplace managed   | Install, update, and pick a channel in Extensions view |
| Release channels      | Stable and PreRelease builds with release assurance    |
| Automatic updates     | VS Code updates the extension for you                  |
| No repository changes | Nothing is added to your project                       |
| Works everywhere      | Local, devcontainers, Codespaces, any environment      |

### Cons ❌

| Limitation                 | Detail                                                        |
|----------------------------|---------------------------------------------------------------|
| Instructions may not apply | Copilot sessions may not receive the extension's instructions |
| No canvases                | Canvases such as the RPI Workflow canvas come with the plugin |
| No customization           | Can't modify custom agents, skills, or instructions           |
| No version pinning         | Uses the latest version of the selected channel               |
| No team control            | Can't enforce specific versions across a team                 |

## Common Scenarios

### Scenario 1: Quick Personal Use

**Goal:** Start using HVE Core agents right away

**Solution:** Install the extension from the Marketplace

#### Steps

1. Install the extension from the Marketplace
2. Select `RPI Agent` or run a direct RPI phase skill such as `/rpi-research`

### Scenario 2: Multi-Machine Developer

**Goal:** Use HVE Core consistently across laptop, desktop, and Codespaces

**Solution:** Install the extension on all machines through Settings Sync

#### Steps

1. Enable Settings Sync in VS Code
2. Install the extension on one machine
3. Settings Sync installs it on your other devices

### Scenario 3: Team Adoption

**Goal:** Get a whole team using HVE Core quickly

**Solution:** Share the extension link and install instructions

#### Steps

1. Share the Marketplace link with the team
2. Team members install the extension

To offer HVE Core to everyone who opens a particular repository instead, commit the plugin defaults described in [Offer the Plugin to Your Team](../install#offer-the-plugin-to-your-team).

### Scenario 4: Want to Customize Later

**Goal:** Start with the extension and add customization as needs grow

**Solution:** Use the included installer skill to copy HVE Core into your repository

#### Steps

1. Start with the HVE Core extension for the complete managed component set
2. When you need MCP configuration or repository-owned components, ask an agent to use the included `hve-core-installer` skill
3. Review component paths and collisions before the installer copies the full set
4. Uninstall the extension once your repository has its copies, so agents do not appear twice

## Troubleshooting

### Extension Not Appearing

#### Check extension is installed

1. Open Extensions view (`Ctrl+Shift+X`)
2. Search "HVE Core"
3. Verify "Installed" badge appears

#### Reload VS Code

1. Command Palette (`Ctrl+Shift+P`)
2. "Developer: Reload Window"

### Agents Not Showing in Copilot Chat

#### Verify GitHub Copilot is active

1. Check Copilot icon in status bar
2. Sign in if needed

#### Check extension status

1. Extensions view → "HVE Core"
2. Verify no errors shown
3. Click "Show Extension Output" if issues

### Instructions Not Applied in Copilot Sessions

The extension's instructions may not reach Copilot sessions. If you rely on path-specific instructions, uninstall the extension, install the [Copilot Plugin](cli-plugins), and reload the window.

### Conflicting Installation Methods

If you have the extension and another route, such as the plugin or a clone, each agent appears more than once. Copilot does not remove copies that arrive by different routes, so keep one:

* To keep the extension, uninstall the plugin, remove the clone, and delete any HVE Core entries from `chat.*Locations` settings or `.github/copilot/settings.json`
* To keep the other route, uninstall the extension

### Update Not Appearing

#### Force check for updates

1. Extensions view → ⋯ (More Actions)
2. "Check for Extension Updates"

#### Manually update

1. Extensions view → Find "HVE Core"
2. Click "Update" button

## Need MCP Configuration or a Repository Copy?

The extension includes the `hve-core-installer` skill. Ask an agent to use it when you need MCP guidance, help choosing an install route, or a copy of HVE Core owned by your repository.

1. Ask an agent to use `hve-core-installer`.
2. Confirm that the installer copies every component into your repository.
3. Review agents, instructions, distributable skill directories, and collisions before anything is written.

| Capability                  | HVE Core Extension | Installer Skill                    |
|-----------------------------|-------------------:|------------------------------------|
| Complete managed content    |                Yes | Copied into your repository        |
| MCP configuration guidance  |                 No | Curated server templates           |
| Repository-owned copies     |                 No | Agents, instructions, skills       |
| Installation route guidance |                 No | Plugin, clone, and settings routes |

> [!NOTE]
> The installer is a skill that works within any agent conversation. There is no separate installer agent or extension identity.

## Migration Guide

For retired plugin or extension identities, start with [Migrate to the HVE Core Identity](../package-migration). VS Code does not provide a universal automatic migration between different extension IDs.

### From a Clone to the Extension

1. Remove HVE Core entries you added for the clone, such as `chat.*Locations` settings or folder entries in `.github/copilot/settings.json`
2. Uninstall the plugin if you installed the clone as a plugin from source
3. Optionally delete the clone
4. Install the extension following the Quick Start above
5. Reload the window and verify that agents appear in Copilot Chat

### From the Extension to the Plugin

1. Uninstall the extension from Extensions view
2. Install the [Copilot Plugin](cli-plugins)
3. Reload the window and verify that agents appear in Copilot Chat

To customize HVE Core instead, follow [Copy HVE Core Into Your Repository](../install#copy-hve-core-into-your-repository) or a clone method such as [Peer Directory Clone](peer-clone).

## Limitations

| Aspect                           | Status                                           |
|----------------------------------|--------------------------------------------------|
| Instructions in Copilot sessions | ⚠️ May not reach them                            |
| Canvases                         | ❌ Not included                                   |
| Customization                    | ❌ Cannot modify components                       |
| Version control                  | ⚠️ Extension updates only, no git control        |
| Team enforcement                 | ⚠️ Each member installs independently            |
| Dev/testing                      | ⚠️ Pre-release channel only, not custom branches |
| Portable paths                   | ✅ Works everywhere                               |
| Setup complexity                 | ✅ Simplest possible                              |
| Disk usage                       | ✅ Single installation across all projects        |

## Next Steps

* [Your First Workflow](../first-workflow.md) to try HVE Core with a real task
* [Copilot Plugin](cli-plugins) for instructions and canvases in Copilot sessions
* [Peer Directory Clone](peer-clone.md) for a customizable installation

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
