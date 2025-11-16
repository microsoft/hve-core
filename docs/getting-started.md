---
title: Getting Started with HVE Core
description: Quick setup guide for using HVE Core Copilot customizations in your projects
author: Microsoft
ms.date: 2025-11-15
ms.topic: getting-started
keywords:
  - github copilot
  - multi-root workspace
  - setup
  - getting started
estimated_reading_time: 5
---

This guide shows you how to configure your project to use HVE Core's GitHub Copilot customizations (chat modes, instructions, and prompts).

## Prerequisites

* VS Code with GitHub Copilot extension installed
* Both repositories cloned as siblings on your machine

## Directory Structure

Clone both repositories side-by-side:

```text
repos/
├── my-project/
└── hve-core/
```

```bash
cd repos
git clone https://github.com/your-org/my-project.git
git clone https://github.com/microsoft/hve-core.git
```

```powershell
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

* Both folders visible in Explorer sidebar
* Type `@` in Copilot Chat to see custom agents from hve-core
* Use `#file:` to access prompt files from hve-core

## Troubleshooting

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
