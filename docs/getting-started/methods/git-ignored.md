---
title: Git-Ignored Folder Installation
description: Install HVE-Core in a git-ignored folder for devcontainer environments
sidebar_position: 3
author: Microsoft
ms.date: 2025-12-03
ms.topic: how-to
keywords:
  - git-ignored
  - installation
  - github copilot
  - devcontainer
estimated_reading_time: 6
---

Git-Ignored Folder installation places HVE-Core inside your project in a `.hve-core/` folder that's excluded from version control. This is ideal for solo developers using devcontainers who want a self-contained setup.

## When to Use This Method

✅ **Use this when:**

* You use local devcontainers (Docker Desktop)
* You're working solo
* You want HVE-Core auto-updated with container rebuilds
* You want a self-contained project (no external dependencies)

❌ **Consider alternatives when:**

* Your team needs version control → [Submodule](submodule.md)
* You use Codespaces → [GitHub Codespaces](codespaces.md)
* You want to share HVE-Core across projects → [Mounted Directory](mounted.md)
* You need paths that work everywhere → [Multi-Root Workspace](multi-root.md)

## How It Works

HVE-Core is cloned into a `.hve-core/` folder inside your project. The folder is added to `.gitignore` so it doesn't pollute your repository.

```text
my-project/
├── .devcontainer/
│   └── devcontainer.json    # postCreateCommand clones HVE-Core
├── .hve-core/               # Git-ignored, contains HVE-Core
│   └── .github/
│       ├── agents/
│       ├── prompts/
│       └── instructions/
├── .gitignore               # Includes .hve-core/
├── .vscode/
│   └── settings.json        # Points to .hve-core paths
└── src/
```

## Quick Start

Install the [VS Code extension](https://marketplace.visualstudio.com/items?itemName=ise-hve-essentials.hve-core) for the fastest setup. Use the manual steps below for clone-based customization.

## Manual Setup

### Step 1: Update .gitignore

Add the HVE-Core folder to your `.gitignore`:

```text
# HVE-Core installation (local only)
.hve-core/
```

### Step 2: Clone HVE-Core

#### PowerShell

```powershell
# Create folder and clone
$hveCoreFolder = ".hve-core"
if (-not (Test-Path $hveCoreFolder)) {
    git clone https://github.com/microsoft/hve-core.git $hveCoreFolder
    Write-Host "✅ Cloned HVE-Core to $hveCoreFolder"
}
```

#### Bash

```bash
HVE_CORE_FOLDER=".hve-core"

if [ ! -d "$HVE_CORE_FOLDER" ]; then
    git clone https://github.com/microsoft/hve-core.git "$HVE_CORE_FOLDER"
    echo "✅ Cloned HVE-Core to $HVE_CORE_FOLDER"
fi
```

### Step 3: Update VS Code Settings

Create or update `.vscode/settings.json`:

```json
{
  "chat.agentFilesLocations": {
    ".hve-core/.github/agents/ado": true,
    ".hve-core/.github/agents/coding-standards": true,
    ".hve-core/.github/agents/data-science": true,
    ".hve-core/.github/agents/design-thinking": true,
    ".hve-core/.github/agents/github": true,
    ".hve-core/.github/agents/project-planning": true,
    ".hve-core/.github/agents/hve-core": true,
    ".hve-core/.github/agents/hve-core/subagents": true,
    ".hve-core/.github/agents/security-planning": true
  },
  "chat.promptFilesLocations": {
    ".hve-core/.github/prompts/ado": true,
    ".hve-core/.github/prompts/coding-standards": true,
    ".hve-core/.github/prompts/design-thinking": true,
    ".hve-core/.github/prompts/github": true,
    ".hve-core/.github/prompts/hve-core": true,
    ".hve-core/.github/prompts/security-planning": true
  },
  "chat.instructionsFilesLocations": {
    ".hve-core/.github/instructions/ado": true,
    ".hve-core/.github/instructions/coding-standards": true,
    ".hve-core/.github/instructions/design-thinking": true,
    ".hve-core/.github/instructions/github": true,
    ".hve-core/.github/instructions/hve-core": true,
    ".hve-core/.github/instructions/project-planning": true,
    ".hve-core/.github/instructions/shared": true
  },
  "chat.agentSkillsLocations": {
    ".hve-core/.github/skills": true,
    ".hve-core/.github/skills/shared": true
  }
}
```

### Step 4: Automate with Devcontainer

Add to `.devcontainer/devcontainer.json` so HVE-Core is cloned on container creation:

```jsonc
{
  // ... existing configuration ...
  
  "postCreateCommand": "[ -d .hve-core ] || git clone --depth 1 https://github.com/microsoft/hve-core.git .hve-core"
}
```

### Step 5: Validate Installation

1. Rebuild your devcontainer (`Ctrl+Shift+P` → "Dev Containers: Rebuild Container")
2. Open GitHub Copilot Chat (`Ctrl+Alt+I`)
3. Click the agent picker dropdown
4. Verify HVE-Core agents appear (task-planner, task-researcher, prompt-builder)

## Complete Devcontainer Example

```jsonc
{
  "name": "My Project with HVE-Core",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  
  "postCreateCommand": "[ -d .hve-core ] || git clone --depth 1 https://github.com/microsoft/hve-core.git .hve-core",
  
  "customizations": {
    "vscode": {
      "settings": {
        "chat.agentFilesLocations": {
          ".hve-core/.github/agents/ado": true,
          ".hve-core/.github/agents/coding-standards": true,
          ".hve-core/.github/agents/data-science": true,
          ".hve-core/.github/agents/design-thinking": true,
          ".hve-core/.github/agents/github": true,
          ".hve-core/.github/agents/project-planning": true,
          ".hve-core/.github/agents/hve-core": true,
          ".hve-core/.github/agents/hve-core/subagents": true,
          ".hve-core/.github/agents/security-planning": true
        },
        "chat.promptFilesLocations": {
          ".hve-core/.github/prompts/ado": true,
          ".hve-core/.github/prompts/coding-standards": true,
          ".hve-core/.github/prompts/design-thinking": true,
          ".hve-core/.github/prompts/github": true,
          ".hve-core/.github/prompts/hve-core": true,
          ".hve-core/.github/prompts/security-planning": true
        },
        "chat.instructionsFilesLocations": {
          ".hve-core/.github/instructions/ado": true,
          ".hve-core/.github/instructions/coding-standards": true,
          ".hve-core/.github/instructions/design-thinking": true,
          ".hve-core/.github/instructions/github": true,
          ".hve-core/.github/instructions/hve-core": true,
          ".hve-core/.github/instructions/project-planning": true,
          ".hve-core/.github/instructions/shared": true
        },
        "chat.agentSkillsLocations": {
          ".hve-core/.github/skills": true,
          ".hve-core/.github/skills/shared": true
        }
      }
    }
  }
}
```

## Updating HVE-Core

### Manual update

```bash
cd .hve-core
git pull
```

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

#### Check settings are applied

1. Open Command Palette (`Ctrl+Shift+P`)
2. Type "Preferences: Open Workspace Settings (JSON)"
3. Verify the paths are correct

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

**Warning:** This deletes any local changes to HVE-Core on every rebuild.

## Limitations

| Aspect           | Status                                                             |
|------------------|--------------------------------------------------------------------|
| Devcontainers    | ✅  Designed for this                                               |
| Codespaces       | ⚠️  Works but not optimal (use [Codespaces method](codespaces.md)) |
| Team sharing     | ⚠️  Each developer clones separately                               |
| Portable paths   | ✅  Relative paths work                                             |
| Version pinning  | ⚠️  Manual (modify clone command)                                  |
| Disk usage       | ⚠️  Per-project copy                                               |
| Setup complexity | ✅  Simple                                                          |

## Next Steps

* [Your First Workflow](../first-workflow.md) - Try HVE-Core with a real task
* [Multi-Root Workspace](multi-root.md) - Share across local + Codespaces
* [Submodule](submodule.md) - Add version control for teams

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
