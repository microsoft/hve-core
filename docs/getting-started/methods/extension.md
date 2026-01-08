---
title: VS Code Extension Installation
description: Install HVE-Core as a VS Code extension from the marketplace
author: Microsoft
ms.date: 2026-01-07
ms.topic: how-to
keywords:
  - extension
  - installation
  - marketplace
  - github copilot
estimated_reading_time: 4
---

VS Code Extension installation provides HVE-Core directly through the VS Code Marketplace. This is the simplest zero-configuration method that works across all environments.

## When to Use This Method

✅ **Use this when:**

* You want the simplest possible setup
* You don't need to customize HVE-Core components
* You work across different machines and environments
* You want automatic updates through VS Code
* You prefer marketplace-managed extensions
* You want a clean, zero-configuration setup

❌ **Consider alternatives when:**

* You need to customize chat modes, prompts, or instructions → [Peer Clone](peer-clone.md) or [Git-Ignored](git-ignored.md)
* Your team needs to version control HVE-Core → [Submodule](submodule.md)
* You're contributing to HVE-Core development → [Peer Clone](peer-clone.md)
* You need to test pre-release versions → [Multi-Root Workspace](multi-root.md)

## How It Works

The extension packages all HVE-Core components (chat agents, prompts, instructions) as a standard VS Code extension. Once installed, all components are immediately available without any additional configuration.

```text
VS Code Extension System
├── Extension installed via marketplace
│   ├── .github/chatmodes/      # All chat agents
│   ├── .github/prompts/        # All prompt templates
│   ├── .github/instructions/   # All coding guidelines
│   └── scripts/dev-tools/      # PR reference generation
└── No workspace configuration needed!
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

After installation, verify everything works:

1. Open GitHub Copilot Chat (`Ctrl+Alt+I`)
2. Click the agent picker dropdown
3. Verify HVE-Core agents appear:
   * task-planner
   * task-researcher
   * task-implementor
   * pr-review
   * adr-creation

## What's Included

The extension provides all HVE-Core components:

| Component      | Count | Examples                                      |
|----------------|-------|-----------------------------------------------|
| Chat Agents    | 16    | task-planner, pr-review, adr-creation         |
| Prompts        | 10    | git-commit, pull-request, ado-create-pr       |
| Instructions   | 16    | markdown, python-script, commit-message       |
| Dev Tools      | 2     | Generate-PrReference.ps1, pr-ref-gen.sh       |

## Updating

The extension updates automatically through VS Code's extension system:

* **Auto-updates (default):** Extensions update automatically when new versions are released
* **Manual updates:** Extensions view → Find "HVE Core" → Click **Update**
* **Pre-release versions:** Right-click extension → "Switch to Pre-Release Version"

## Comparison with Other Methods

### Pros ✅

* **Zero configuration** - No workspace settings or file cloning required
* **Works everywhere** - Local, devcontainers, Codespaces, any environment
* **Automatic updates** - VS Code manages updates seamlessly
* **No repository pollution** - Nothing added to your project
* **Instant availability** - Works immediately after installation
* **No manual setup** - No scripts to run or paths to configure
* **Marketplace managed** - Centralized distribution and versioning

### Cons ❌

* **No customization** - Can't modify chat modes, prompts, or instructions
* **Extension updates only** - Can't easily test development versions
* **No version pinning** - Uses latest version (or opt into pre-release)
* **No team control** - Can't enforce specific versions across team
* **Limited flexibility** - Can't combine with custom local modifications

## Common Scenarios

### Scenario 1: Quick Personal Use

**Goal:** Start using HVE-Core immediately without setup

**Solution:** Install the extension from marketplace

**Steps:**

1. Install extension from marketplace
2. Start using `@task-planner` and other agents
3. That's it!

### Scenario 2: Multi-Machine Developer

**Goal:** Use HVE-Core consistently across laptop, desktop, and Codespaces

**Solution:** Install extension on all machines via Settings Sync

**Steps:**

1. Enable Settings Sync in VS Code
2. Install extension on one machine
3. Extensions automatically sync to other devices

### Scenario 3: Team Adoption

**Goal:** Get entire team using HVE-Core quickly

**Solution:** Share extension link and install instructions

**Steps:**

1. Share marketplace link with team
2. Team members install extension
3. Everyone has consistent experience immediately

### Scenario 4: Want to Customize Later

**Goal:** Start with extension, later switch to customization

**Solution:** Use extension initially, migrate to Peer Clone when needed

**Steps:**

1. Start with extension for quick setup
2. When customization needed, uninstall extension
3. Follow [Peer Clone](peer-clone.md) method for local modifications

## Troubleshooting

### Extension Not Appearing

**Check extension is installed:**

1. Open Extensions view (`Ctrl+Shift+X`)
2. Search "HVE Core"
3. Verify "Installed" badge appears

**Reload VS Code:**

1. Command Palette (`Ctrl+Shift+P`)
2. "Developer: Reload Window"

### Agents Not Showing in Copilot Chat

**Verify GitHub Copilot is active:**

1. Check Copilot icon in status bar
2. Sign in if needed

**Check extension status:**

1. Extensions view → "HVE Core"
2. Verify no errors shown
3. Click "Show Extension Output" if issues

### Conflicting Installation Methods

If you have both extension and manual installation (like Peer Clone):

**Problem:** Duplicate agents appearing

**Solution:** Choose one method:

* Keep extension: Remove manual installation (delete cloned folder, remove workspace settings)
* Keep manual: Uninstall extension

### Update Not Appearing

**Force check for updates:**

1. Extensions view → ⋯ (More Actions)
2. "Check for Extension Updates"

**Manually update:**

1. Extensions view → Find "HVE Core"
2. Click "Update" button

## Migration Guide

### From Manual Installation to Extension

If you're currently using manual methods like Peer Clone:

1. **Remove workspace settings** - Delete HVE-Core paths from `.vscode/settings.json`
2. **Optionally remove cloned folder** - Delete hve-core clone if no longer needed
3. **Install extension** - Follow Quick Start above
4. **Verify** - Test agents appear in Copilot Chat

### From Extension to Manual Installation

If you need customization:

1. **Uninstall extension** - Extensions view → Uninstall "HVE Core"
2. **Follow manual method** - See [Peer Clone](peer-clone.md) for local customization
3. **Customize** - Edit chat modes, prompts, or instructions as needed

## Limitations

| Aspect           | Status                                                      |
|------------------|-------------------------------------------------------------|
| Customization    | ❌ Cannot modify components                                 |
| Version control  | ⚠️ Extension updates only, no git control                   |
| Team enforcement | ⚠️ Each member installs independently                       |
| Dev/testing      | ⚠️ Pre-release channel only, not custom branches            |
| Portable paths   | ✅ Works everywhere                                         |
| Setup complexity | ✅ Simplest possible                                        |
| Disk usage       | ✅ Single installation across all projects                  |

## Next Steps

* [Your First Workflow](../first-workflow.md) - Try HVE-Core with a real task
* [Multi-Root Workspace](multi-root.md) - Combine extension with custom components
* [Peer Clone](peer-clone.md) - Switch to customizable installation

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨GitHub Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
