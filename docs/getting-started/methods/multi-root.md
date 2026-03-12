---
title: Multi-Root Workspace Installation
description: Set up your enterprise fork of HVE-Core using VS Code multi-root workspaces
sidebar_position: 6
author: Microsoft
ms.date: 2026-03-10
ms.topic: how-to
keywords:
  - multi-root workspace
  - installation
  - github copilot
  - codespaces
  - devcontainer
  - enterprise fork
estimated_reading_time: 8
---

Forking HVE-Core lets your enterprise customize agents, prompts, instructions, and skills for your organization while staying connected to upstream improvements. Multi-root workspaces bring that fork into any project workspace, giving teams a portable configuration that works across Local VS Code, Devcontainers, and Codespaces.

## When to Use This Method

✅ **Use this when:**

* Your enterprise maintains a fork of HVE-Core with org-specific customizations
* You need a single configuration that works across Local VS Code, Devcontainers, and Codespaces
* Teams share a common set of customized agents, prompts, and instructions
* You want to pull upstream improvements on your own schedule

❌ **Consider alternatives when:**

* Your team needs version-pinned dependencies without a fork → [Submodule](submodule.md)
* You're contributing back to HVE-Core itself → [Peer Clone](peer-clone.md)

## How It Works

Your enterprise forks the `microsoft/hve-core` repository, adds org-specific agents, prompts, and instructions, then uses a `.code-workspace` file to bring that fork into any project as a secondary root. VS Code treats the fork as part of your project, making all paths work correctly.

```text
┌──────────────────────────────────────────────────┐
│           VS Code Multi-Root Workspace           │
├──────────────────────────────────────────────────┤
│  📁 My Project (primary)                         │
│     └── Your application code                    │
│  📁 HVE-Core Fork (secondary)                    │
│     └── .github/agents, prompts, instructions    │
│     └── Org-specific customizations              │
└──────────────────────────────────────────────────┘
         ↑
   .code-workspace file defines this

   microsoft/hve-core (upstream)
         ↓  sync on your schedule
   your-org/hve-core (fork)
```

## Quick Start

Install the [VS Code extension](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core) for the fastest setup. For guided setup with installation method selection and MCP configuration, install the [HVE Core Installer](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-installer) extension and ask any agent "help me customize hve-core installation". Use the manual steps below for direct configuration.

## Manual Setup

### Step 1: Fork and Clone

If your organization has not already forked HVE-Core, create a fork of `microsoft/hve-core` under your org's GitHub account. Then clone your fork.

#### Local VS Code

```bash
# Clone your org's fork next to your project
cd /path/to/your-projects
git clone https://github.com/your-org/hve-core.git

# Add upstream for syncing improvements
cd hve-core
git remote add upstream https://github.com/microsoft/hve-core.git
```

**Codespaces/Devcontainer:** Your fork will be cloned automatically (see Step 3).

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
      "name": "HVE-Core Fork",
      "path": "/workspaces/hve-core"
    }
  ],
  "settings": {
    "chat.agentFilesLocations": {
      "HVE-Core Fork/.github/agents/ado": true,
      "HVE-Core Fork/.github/agents/data-science": true,
      "HVE-Core Fork/.github/agents/design-thinking": true,
      "HVE-Core Fork/.github/agents/github": true,
      "HVE-Core Fork/.github/agents/project-planning": true,
      "HVE-Core Fork/.github/agents/hve-core": true,
      "HVE-Core Fork/.github/agents/hve-core/subagents": true,
      "HVE-Core Fork/.github/agents/security": true,
      "My Project/.github/agents": true
    },
    "chat.promptFilesLocations": {
      "HVE-Core Fork/.github/prompts/ado": true,
      "HVE-Core Fork/.github/prompts/design-thinking": true,
      "HVE-Core Fork/.github/prompts/github": true,
      "HVE-Core Fork/.github/prompts/hve-core": true,
      "HVE-Core Fork/.github/prompts/security": true,
      "My Project/.github/prompts": true
    },
    "chat.instructionsFilesLocations": {
      "HVE-Core Fork/.github/instructions/ado": true,
      "HVE-Core Fork/.github/instructions/coding-standards": true,
      "HVE-Core Fork/.github/instructions/design-thinking": true,
      "HVE-Core Fork/.github/instructions/github": true,
      "HVE-Core Fork/.github/instructions/hve-core": true,
      "HVE-Core Fork/.github/instructions/shared": true,
      "My Project/.github/instructions": true
    },
    "chat.agentSkillsLocations": {
      "HVE-Core Fork/.github/skills": true,
      "HVE-Core Fork/.github/skills/shared": true,
      "My Project/.github/skills": true
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
  "name": "HVE-Core Fork",
  "path": "../../hve-core"
}
```

### Step 3: Configure Devcontainer (Codespaces)

Update `.devcontainer/devcontainer.json` to clone your org's fork:

```jsonc
{
  "name": "My Project + HVE-Core",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",

  "onCreateCommand": "git clone --depth 1 https://github.com/your-org/hve-core.git /workspaces/hve-core 2>/dev/null || git -C /workspaces/hve-core pull --ff-only || true",

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

> [!WARNING]
> You must open the `.code-workspace` file, not the folder.

* `File` → `Open Workspace from File...` → select `hve-core.code-workspace` (Local)
* Run `code .devcontainer/hve-core.code-workspace` in terminal (Codespaces)

The VS Code title bar should show your workspace name, not just the folder name.

## Path Resolution

Multi-root workspaces use folder names for paths:

| Path Style           | Example                                 | Recommended       |
|----------------------|-----------------------------------------|-------------------|
| Folder name relative | `"HVE-Core Fork/.github/agents"`        | ✅  Yes            |
| Absolute path        | `"/workspaces/hve-core/.github/agents"` | ⚠️  Less portable |

The folder names in your `.code-workspace` file (`"name": "HVE-Core Fork"`) become path prefixes in settings.

## Keeping Your Fork Updated

Sync your fork with upstream `microsoft/hve-core` to pick up new agents, prompts, and improvements. Pull from your fork into workspaces on a schedule that suits your team.

### Syncing Upstream Changes into Your Fork

```bash
# From your fork's local clone
git fetch upstream
git merge upstream/main
# Resolve any conflicts with your org customizations, then push
git push origin main
```

### Pulling Fork Updates into Workspaces

| Strategy       | Configuration                                       | When Updates Apply |
|----------------|-----------------------------------------------------|--------------------|
| Manual         | Run `git -C /workspaces/hve-core pull` when desired | On demand          |
| On rebuild     | Add `updateContentCommand` to devcontainer.json     | Container rebuild  |
| On every start | Add `postStartCommand` to devcontainer.json         | Every startup      |

> [!TIP]
> Update on rebuild for stability:

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

* Confirm the workspace is open by checking that the title bar shows the workspace name
* Ensure `path` values in `.code-workspace` point to the correct locations
* Reload the window with `Ctrl+Shift+P` → "Developer: Reload Window"

### "Folder not found" error

* For local setups, verify HVE-Core is cloned at the relative path specified
* For Codespaces, check that `onCreateCommand` ran successfully in creation logs

### Settings not applying

* Folder settings override workspace settings, so check for conflicts at the folder level
* Use folder names (`"HVE-Core Fork/..."`) instead of absolute paths

## Next Steps

* [Your First Workflow](../first-workflow.md) - Try HVE-Core with a real task
* [RPI Workflow](../../rpi/) - Research, Plan, Implement methodology
* [Back to Installation Guide](../install.md) - Compare other methods

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
