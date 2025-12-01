---
title: Getting Started with HVE Core
description: Quick setup guide for using HVE Core Copilot customizations in your projects
author: Microsoft
ms.date: 2025-11-21
ms.topic: tutorial
keywords:
  - github copilot
  - multi-root workspace
  - setup
  - getting started
estimated_reading_time: 5
---

This guide shows you how to configure your project to use HVE Core's GitHub Copilot customizations (chat modes, instructions, and prompts).

## Automated Installation (Recommended)

**Fastest method:** Use the `hve-core-installer` agent for automated setup (~30 seconds):

1. Open GitHub Copilot Chat in VS Code (Ctrl+Alt+I)
2. Select the `hve-core-installer` agent from the agent picker dropdown
3. Follow the guided installation

The installer will:

* Clone the hve-core repository as a sibling to your workspace
* Validate the repository structure
* Update your VS Code settings.json with chat mode, prompt, and instruction paths
* Make all HVE Core components immediately available

## Manual Installation

### Prerequisites

* VS Code with GitHub Copilot extension installed
* Both repositories cloned as siblings on your machine

## Directory Structure

Clone both repositories side-by-side:

```text
repos/
├── my-project/
└── hve-core/
```

```console
cd repos
git clone https://github.com/your-org/my-project.git
git clone https://github.com/microsoft/hve-core.git
```

## Workspace Configuration

Add these settings to your project's `.vscode/settings.json`:

```json
{
  "chat.promptFilesLocations": {
    "../hve-core/.github/prompts": true
  },
  "chat.instructionsFilesLocations": {
    "../hve-core/.github/instructions": true
  },
  "chat.modeFilesLocations": {
    "../hve-core/.github/chatmodes": true
  }
}
```

This tells GitHub Copilot to discover customizations from the hve-core repository.

## Development Container Setup

If using dev containers, add this mount to your `.devcontainer/devcontainer.json`:

```json
{
  "mounts": [
    "source=${localWorkspaceFolder}/../hve-core,target=/workspaces/hve-core,type=bind,consistency=cached"
  ]
}
```

After updating, rebuild the container:

* Press `F1` and select **Dev Containers: Rebuild Container**
* Or run: **Remote-Containers: Rebuild Container** from the Command Palette

## Verifying Setup

Check that everything works:

1. Open GitHub Copilot Chat view (Ctrl+Alt+I)
2. Click the **agent picker dropdown** at the top of the chat panel
3. Verify custom agents from hve-core appear in the list:
   * task-planner
   * task-researcher
   * prompt-builder
   * pr-review
4. Select an agent and submit a test prompt

**Troubleshooting:** If custom agents don't appear, verify the `chat.modeFilesLocations` setting points to the correct path in your workspace settings.

## Troubleshooting

### Installation Issues

If the automated installation encounters issues, try these solutions:

#### "Not in a git repository" error

* Ensure you have a git repository initialized in your current workspace
* Run `git init` if needed, then retry installation

#### "Git not found" error

* Install Git and ensure it's available in your PATH
* Verify: Open terminal and run `git --version`
* Windows: Download from [git-scm.com](https://git-scm.com)
* macOS: Install via Homebrew `brew install git` or Xcode Command Line Tools
* Linux: Install via package manager `apt install git` or `yum install git`

#### "Clone failed" error

* Check network connectivity to github.com
* Verify you don't already have a `../hve-core` directory
* Try cloning manually: `git clone https://github.com/microsoft/hve-core.git ../hve-core`

#### "Settings update failed" error

* Check VS Code settings.json file permissions
* Manually backup your settings: Copy `settings.json` before retrying
* Verify settings.json is valid JSON (no syntax errors)

#### Agent not available

* Ensure GitHub Copilot extension is installed and active
* Reload VS Code window: Ctrl+Shift+P → "Developer: Reload Window"
* Check that hve-core repository is cloned as a sibling to your workspace

### Configuration Issues

**Problem:** Copilot not discovering hve-core customizations

**Solution:** Ensure you opened the `.code-workspace` file, not just the folder. The window title should show the workspace name, and both folders should appear in Explorer.

## Next Steps

* Explore [Chat Modes](../.github/chatmodes/README.md) for available agents
* Review [Instructions](../.github/instructions/README.md) for coding guidelines
* Check the [README](../README.md) for feature overview

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
