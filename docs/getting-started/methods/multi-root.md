---
title: Multi-Root Workspace Installation
description: Set up HVE-Core using VS Code multi-root workspaces for any environment
author: Microsoft
ms.date: 2025-12-02
ms.topic: how-to
keywords:
  - multi-root workspace
  - installation
  - github copilot
  - codespaces
  - devcontainer
estimated_reading_time: 8
---

Multi-root workspaces are the **RECOMMENDED** method for consuming HVE-Core. This approach works in any environment (Local VS Code, Devcontainers, Codespaces) and provides the most portable configuration.

## When to Use This Method

✅ **Use this when:**

* You want a single configuration that works everywhere
* Your project uses Codespaces or devcontainers
* You need paths that work for the whole team
* You want integrated source control across both projects

❌ **Consider alternatives when:**

* Your team needs version-pinned dependencies → [Submodule](submodule.md)
* You're developing HVE-Core itself → [Peer Clone](peer-clone.md)

## How It Works

A `.code-workspace` file defines multiple folders as a single workspace. VS Code treats HVE-Core as part of your project, making all paths work correctly.

```text
┌─────────────────────────────────────────────┐
│         VS Code Multi-Root Workspace        │
├─────────────────────────────────────────────┤
│  📁 My Project (primary)                    │
│     └── Your code                           │
│  📁 HVE-Core Library (secondary)            │
│     └── .github/chatmodes, prompts, etc.    │
└─────────────────────────────────────────────┘
         ↑
   .code-workspace file defines this
```

## Quick Start

Use the `hve-core-installer` agent:

1. Open GitHub Copilot Chat (`Ctrl+Alt+I`)
2. Select `hve-core-installer` from the agent picker
3. Say: "Install HVE-Core using multi-root workspace"
4. Follow the guided setup

## Manual Setup

### Step 1: Clone HVE-Core

**Local VS Code:**

```bash
# Clone next to your project
cd /path/to/your-projects
git clone https://github.com/microsoft/hve-core.git
```

**Codespaces/Devcontainer:** HVE-Core will be cloned automatically (see Step 3).

### Step 2: Create the Workspace File

Create `.devcontainer/hve-core.code-workspace` in your project:

```jsonc
{
  "folders": [
    {
      "name": "My Project",
      "path": ".."
    },
    {
      "name": "HVE-Core Library",
      "path": "/workspaces/hve-core"
    }
  ],
  "settings": {
    "chat.modeFilesLocations": {
      "HVE-Core Library/.github/chatmodes": true,
      "My Project/.github/chatmodes": true
    },
    "chat.promptFilesLocations": {
      "HVE-Core Library/.github/prompts": true,
      "My Project/.github/prompts": true
    },
    "chat.instructionsFilesLocations": {
      "HVE-Core Library/.github/instructions": true,
      "My Project/.github/instructions": true
    }
  },
  "extensions": {
    "recommendations": [
      "github.copilot",
      "github.copilot-chat"
    ]
  }
}
```

**For local development**, use a relative path instead:

```jsonc
{
  "name": "HVE-Core Library",
  "path": "../../hve-core"
}
```

### Step 3: Configure Devcontainer (Codespaces)

Update `.devcontainer/devcontainer.json`:

```jsonc
{
  "name": "My Project + HVE-Core",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",

  "onCreateCommand": "git clone --depth 1 https://github.com/microsoft/hve-core.git /workspaces/hve-core 2>/dev/null || git -C /workspaces/hve-core pull --ff-only || true",

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

**Critical:** You must open the `.code-workspace` file, not the folder.

* **Local:** `File` → `Open Workspace from File...` → select `hve-core.code-workspace`
* **Codespaces:** Run `code .devcontainer/hve-core.code-workspace` in terminal

The VS Code title bar should show your workspace name, not just the folder name.

## Path Resolution

Multi-root workspaces use folder names for paths:

| Path Style           | Example                                    | Recommended       |
|----------------------|--------------------------------------------|-------------------|
| Folder name relative | `"HVE-Core Library/.github/chatmodes"`     | ✅  Yes            |
| Absolute path        | `"/workspaces/hve-core/.github/chatmodes"` | ⚠️  Less portable |

The folder names in your `.code-workspace` file (`"name": "HVE-Core Library"`) become path prefixes in settings.

## Keeping HVE-Core Updated

| Strategy       | Configuration                                       | When Updates Apply |
|----------------|-----------------------------------------------------|--------------------|
| Manual         | Run `git -C /workspaces/hve-core pull` when desired | On demand          |
| On rebuild     | Add `updateContentCommand` to devcontainer.json     | Container rebuild  |
| On every start | Add `postStartCommand` to devcontainer.json         | Every startup      |

**Recommended:** Update on rebuild for stability:

```jsonc
{
  "updateContentCommand": "git -C /workspaces/hve-core pull --ff-only || true"
}
```

## Verification

After setup, verify HVE-Core is working:

1. Check the Explorer sidebar shows both folders
2. Open Copilot Chat (`Ctrl+Alt+I`)
3. Click the agent picker dropdown
4. Verify HVE-Core agents appear (task-planner, task-researcher, etc.)

## Troubleshooting

### Agents not appearing

* **Verify workspace is open:** Title bar should show workspace name
* **Check folder paths:** Ensure `path` values in `.code-workspace` are correct
* **Reload window:** `Ctrl+Shift+P` → "Developer: Reload Window"

### "Folder not found" error

* **Local:** Verify HVE-Core is cloned at the relative path specified
* **Codespaces:** Check `onCreateCommand` ran successfully in creation logs

### Settings not applying

* **Settings precedence:** Folder settings override workspace settings
* **Path format:** Use folder names (`"HVE-Core Library/..."`) not absolute paths

## Next Steps

* [Your First Workflow](../first-workflow.md) - Try HVE-Core with a real task
* [RPI Workflow](../../rpi/README.md) - Research, Plan, Implement methodology
* [Back to Installation Guide](../install.md) - Compare other methods

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨GitHub Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
