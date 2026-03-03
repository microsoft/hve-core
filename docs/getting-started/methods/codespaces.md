---
title: GitHub Codespaces Installation
description: Install HVE-Core in GitHub Codespaces using postCreateCommand
sidebar_position: 8
author: Microsoft
ms.date: 2025-12-03
ms.topic: how-to
keywords:
  - codespaces
  - installation
  - github copilot
  - postCreateCommand
  - cloud development
estimated_reading_time: 7
---

GitHub Codespaces requires a specific installation approach because traditional methods (peer directories, bind mounts) don't work in cloud environments. This method uses `postCreateCommand` to clone HVE-Core into the persistent `/workspaces` directory.

## When to Use This Method

✅ **Use this when:**

* Your project runs exclusively in Codespaces
* You want automatic HVE-Core setup for all users
* You need zero-config onboarding for contributors

❌ **Consider alternatives when:**

* You also need local devcontainer support → [Multi-Root Workspace](multi-root.md)
* Your team needs version control → [Submodule](submodule.md)
* You're using local VS Code only → [Peer Clone](peer-clone.md)

## Why Other Methods Don't Work in Codespaces

| Feature                    | Local Devcontainer | GitHub Codespaces            |
|----------------------------|--------------------|------------------------------|
| `${localWorkspaceFolder}`  | ✅ Resolves to host | ❌ Not available              |
| Bind mounts to host        | ✅ Full support     | ❌ No host access             |
| Persistent storage         | Host filesystem    | `/workspaces` only           |
| User settings modification | ✅ Via file system  | ❌ Only via Settings Sync[^1] |

[^1]: User-level settings require Settings Sync. Workspace/container-level settings can still be configured via `devcontainer.json` using `customizations.vscode.settings`.

## How It Works

Codespaces has a specific storage model:

```text
/
├── workspaces/              # ✅ PERSISTENT - survives stops/restarts
│   ├── your-repo/           # Your cloned repository
│   └── hve-core/            # 👈 HVE-Core goes here
├── home/codespace/          # ⚠️ Semi-persistent (survives stops, not rebuilds)
└── <system-dirs>/           # ❌ Not persistent
```

The `postCreateCommand` clones HVE-Core into `/workspaces/hve-core` where it persists across Codespace sessions.

## Quick Start

Use the `hve-core-installer` agent:

1. Open GitHub Copilot Chat (`Ctrl+Alt+I`)
2. Select `hve-core-installer` from the agent picker
3. Say: "Install HVE-Core for Codespaces"
4. Follow the guided setup

## Manual Setup

### Step 1: Update devcontainer.json

Add the clone command and VS Code settings:

```jsonc
{
  "name": "My Project with HVE-Core",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  
  "postCreateCommand": "[ -d /workspaces/hve-core ] || git clone --depth 1 https://github.com/microsoft/hve-core.git /workspaces/hve-core",
  
  "customizations": {
    "vscode": {
      "settings": {
        "chat.agentFilesLocations": {
          "/workspaces/hve-core/.github/agents/ado": true,
          "/workspaces/hve-core/.github/agents/data-science": true,
          "/workspaces/hve-core/.github/agents/design-thinking": true,
          "/workspaces/hve-core/.github/agents/github": true,
          "/workspaces/hve-core/.github/agents/installer": true,
          "/workspaces/hve-core/.github/agents/project-planning": true,
          "/workspaces/hve-core/.github/agents/hve-core": true,
          "/workspaces/hve-core/.github/agents/hve-core/subagents": true,
          "/workspaces/hve-core/.github/agents/security-planning": true
        },
        "chat.promptFilesLocations": {
          "/workspaces/hve-core/.github/prompts/ado": true,
          "/workspaces/hve-core/.github/prompts/design-thinking": true,
          "/workspaces/hve-core/.github/prompts/github": true,
          "/workspaces/hve-core/.github/prompts/hve-core": true,
          "/workspaces/hve-core/.github/prompts/security-planning": true
        },
        "chat.instructionsFilesLocations": {
          "/workspaces/hve-core/.github/instructions/ado": true,
          "/workspaces/hve-core/.github/instructions/coding-standards": true,
          "/workspaces/hve-core/.github/instructions/design-thinking": true,
          "/workspaces/hve-core/.github/instructions/github": true,
          "/workspaces/hve-core/.github/instructions/hve-core": true,
          "/workspaces/hve-core/.github/instructions/shared": true
        },
        "chat.agentSkillsLocations": {
          "/workspaces/hve-core/.github/skills": true,
          "/workspaces/hve-core/.github/skills/shared": true
        }
      }
    }
  }
}
```

### Step 2: Commit and Push

```bash
git add .devcontainer/devcontainer.json
git commit -m "feat: add HVE-Core support for Codespaces"
git push
```

### Step 3: Create or Rebuild Codespace

* **New Codespace:** Create from the updated branch
* **Existing Codespace:** Rebuild (`Ctrl+Shift+P` → "Codespaces: Rebuild Container")

### Step 4: Validate Installation

1. Open GitHub Copilot Chat (`Ctrl+Alt+I`)
2. Click the agent picker dropdown
3. Verify HVE-Core agents appear (task-planner, task-researcher, prompt-builder)

## Complete Configuration Examples

### Minimal Configuration

```jsonc
{
  "name": "HVE-Core Enabled",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  
  "postCreateCommand": "[ -d /workspaces/hve-core ] || git clone --depth 1 https://github.com/microsoft/hve-core.git /workspaces/hve-core",
  
  "customizations": {
    "vscode": {
      "settings": {
        "chat.agentFilesLocations": {
          "/workspaces/hve-core/.github/agents/ado": true,
          "/workspaces/hve-core/.github/agents/data-science": true,
          "/workspaces/hve-core/.github/agents/design-thinking": true,
          "/workspaces/hve-core/.github/agents/github": true,
          "/workspaces/hve-core/.github/agents/installer": true,
          "/workspaces/hve-core/.github/agents/project-planning": true,
          "/workspaces/hve-core/.github/agents/hve-core": true,
          "/workspaces/hve-core/.github/agents/hve-core/subagents": true,
          "/workspaces/hve-core/.github/agents/security-planning": true
        },
        "chat.promptFilesLocations": {
          "/workspaces/hve-core/.github/prompts/ado": true,
          "/workspaces/hve-core/.github/prompts/design-thinking": true,
          "/workspaces/hve-core/.github/prompts/github": true,
          "/workspaces/hve-core/.github/prompts/hve-core": true,
          "/workspaces/hve-core/.github/prompts/security-planning": true
        },
        "chat.instructionsFilesLocations": {
          "/workspaces/hve-core/.github/instructions/ado": true,
          "/workspaces/hve-core/.github/instructions/coding-standards": true,
          "/workspaces/hve-core/.github/instructions/design-thinking": true,
          "/workspaces/hve-core/.github/instructions/github": true,
          "/workspaces/hve-core/.github/instructions/hve-core": true,
          "/workspaces/hve-core/.github/instructions/shared": true
        },
        "chat.agentSkillsLocations": {
          "/workspaces/hve-core/.github/skills": true,
          "/workspaces/hve-core/.github/skills/shared": true
        }
      }
    }
  }
}
```

### Full-Featured Configuration

```jsonc
{
  "name": "HVE-Core Development Environment",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  
  "features": {
    "ghcr.io/devcontainers/features/git:1": {},
    "ghcr.io/devcontainers/features/github-cli:1": {}
  },
  
  "postCreateCommand": {
    "clone-hve-core": "if [ ! -d /workspaces/hve-core ]; then git clone --depth 1 https://github.com/microsoft/hve-core.git /workspaces/hve-core && echo '✅ HVE-Core cloned'; else echo '✅ HVE-Core present'; fi",
    "verify": "test -d /workspaces/hve-core/.github/agents && echo '✅ Verified' || echo '⚠️ Missing'"
  },
  
  "updateContentCommand": "cd /workspaces/hve-core && git pull --ff-only 2>/dev/null || echo 'Update skipped'",
  
  "customizations": {
    "vscode": {
      "settings": {
        "chat.promptFilesLocations": {
          "/workspaces/hve-core/.github/prompts/ado": true,
          "/workspaces/hve-core/.github/prompts/design-thinking": true,
          "/workspaces/hve-core/.github/prompts/github": true,
          "/workspaces/hve-core/.github/prompts/hve-core": true,
          "/workspaces/hve-core/.github/prompts/security-planning": true,
          ".github/prompts": true
        },
        "chat.instructionsFilesLocations": {
          "/workspaces/hve-core/.github/instructions/ado": true,
          "/workspaces/hve-core/.github/instructions/coding-standards": true,
          "/workspaces/hve-core/.github/instructions/design-thinking": true,
          "/workspaces/hve-core/.github/instructions/github": true,
          "/workspaces/hve-core/.github/instructions/hve-core": true,
          "/workspaces/hve-core/.github/instructions/shared": true,
          ".github/instructions": true
        },
        "chat.agentFilesLocations": {
          "/workspaces/hve-core/.github/agents/ado": true,
          "/workspaces/hve-core/.github/agents/data-science": true,
          "/workspaces/hve-core/.github/agents/design-thinking": true,
          "/workspaces/hve-core/.github/agents/github": true,
          "/workspaces/hve-core/.github/agents/installer": true,
          "/workspaces/hve-core/.github/agents/project-planning": true,
          "/workspaces/hve-core/.github/agents/hve-core": true,
          "/workspaces/hve-core/.github/agents/hve-core/subagents": true,
          "/workspaces/hve-core/.github/agents/security-planning": true,
          ".github/agents": true
        },
        "chat.agentSkillsLocations": {
          "/workspaces/hve-core/.github/skills": true,
          "/workspaces/hve-core/.github/skills/shared": true,
          ".github/skills": true
        }
      }
    }
  }
}
```

### Dual-Environment (Local + Codespaces)

For projects needing HVE-Core in both local devcontainers and Codespaces:

```jsonc
{
  "name": "HVE-Core (Local + Codespaces)",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  
  // Clone if not already present (Codespaces path)
  "postCreateCommand": "[ -d /workspaces/hve-core ] || git clone --depth 1 https://github.com/microsoft/hve-core.git /workspaces/hve-core",
  
  // Local only: mount peer directory (silently fails in Codespaces)
  "mounts": [
    "source=${localWorkspaceFolder}/../hve-core,target=/workspaces/hve-core,type=bind,readonly=true,consistency=cached"
  ],
  
  "customizations": {
    "vscode": {
      "settings": {
        // Both paths - VS Code ignores non-existent paths
        "chat.promptFilesLocations": {
          "/workspaces/hve-core/.github/prompts/ado": true,
          "/workspaces/hve-core/.github/prompts/design-thinking": true,
          "/workspaces/hve-core/.github/prompts/github": true,
          "/workspaces/hve-core/.github/prompts/hve-core": true,
          "/workspaces/hve-core/.github/prompts/security-planning": true,
          "../hve-core/.github/prompts/ado": true,
          "../hve-core/.github/prompts/design-thinking": true,
          "../hve-core/.github/prompts/github": true,
          "../hve-core/.github/prompts/hve-core": true,
          "../hve-core/.github/prompts/security-planning": true
        },
        "chat.instructionsFilesLocations": {
          "/workspaces/hve-core/.github/instructions/ado": true,
          "/workspaces/hve-core/.github/instructions/coding-standards": true,
          "/workspaces/hve-core/.github/instructions/design-thinking": true,
          "/workspaces/hve-core/.github/instructions/github": true,
          "/workspaces/hve-core/.github/instructions/hve-core": true,
          "/workspaces/hve-core/.github/instructions/shared": true,
          "../hve-core/.github/instructions/ado": true,
          "../hve-core/.github/instructions/coding-standards": true,
          "../hve-core/.github/instructions/design-thinking": true,
          "../hve-core/.github/instructions/github": true,
          "../hve-core/.github/instructions/hve-core": true,
          "../hve-core/.github/instructions/shared": true
        },
        "chat.agentFilesLocations": {
          "/workspaces/hve-core/.github/agents/ado": true,
          "/workspaces/hve-core/.github/agents/data-science": true,
          "/workspaces/hve-core/.github/agents/design-thinking": true,
          "/workspaces/hve-core/.github/agents/github": true,
          "/workspaces/hve-core/.github/agents/installer": true,
          "/workspaces/hve-core/.github/agents/project-planning": true,
          "/workspaces/hve-core/.github/agents/hve-core": true,
          "/workspaces/hve-core/.github/agents/hve-core/subagents": true,
          "/workspaces/hve-core/.github/agents/security-planning": true,
          "../hve-core/.github/agents/ado": true,
          "../hve-core/.github/agents/data-science": true,
          "../hve-core/.github/agents/design-thinking": true,
          "../hve-core/.github/agents/github": true,
          "../hve-core/.github/agents/installer": true,
          "../hve-core/.github/agents/project-planning": true,
          "../hve-core/.github/agents/hve-core": true,
          "../hve-core/.github/agents/hve-core/subagents": true,
          "../hve-core/.github/agents/security-planning": true
        },
        "chat.agentSkillsLocations": {
          "/workspaces/hve-core/.github/skills": true,
          "/workspaces/hve-core/.github/skills/shared": true,
          "../hve-core/.github/skills": true,
          "../hve-core/.github/skills/shared": true
        }
      }
    }
  }
}
```

## Updating HVE-Core

### Manual Update

```bash
cd /workspaces/hve-core
git pull
```

### Auto-Update on Codespace Start

Add `updateContentCommand` to your devcontainer.json:

```jsonc
{
  "updateContentCommand": "cd /workspaces/hve-core && git pull --ff-only 2>/dev/null || true"
}
```

This runs when the Codespace starts (not on every terminal open).

### Force Fresh Clone

To always get the latest version on rebuild:

```jsonc
{
  "postCreateCommand": "rm -rf /workspaces/hve-core && git clone --depth 1 https://github.com/microsoft/hve-core.git /workspaces/hve-core"
}
```

**Warning:** This removes any local changes on every rebuild.

## Troubleshooting

### Agents Not Appearing

**Check HVE-Core was cloned:**

```bash
ls /workspaces/hve-core/.github/agents
```

**Check postCreateCommand ran:**

Look at the Codespace creation log for clone output or errors.

### Clone Failed During Creation

**Network issues:** Try rebuilding the Codespace.

**GitHub rate limiting:** Ensure you're authenticated:

```bash
gh auth status
```

### Settings Not Applied

**Check devcontainer.json paths:**

Settings must use absolute paths (`/workspaces/hve-core/...`).

**Verify settings in VS Code:**

1. Open Command Palette (`Ctrl+Shift+P`)
2. Type "Preferences: Open User Settings (JSON)"
3. Check if settings are present

### Codespace Rebuild Doesn't Update HVE-Core

The clone command skips if the folder exists. Force update:

```bash
cd /workspaces/hve-core
git pull
```

Or modify postCreateCommand to always pull (see Auto-Update section).

## Limitations

| Aspect              | Status                                    |
|---------------------|-------------------------------------------|
| Codespaces          | ✅  Designed for this                      |
| Local devcontainers | ⚠️  Works but consider other methods      |
| Team sharing        | ✅  Auto-setup for all contributors        |
| Portable paths      | ⚠️  Absolute paths only                   |
| Version pinning     | ⚠️  Modify clone command for specific tag |
| Offline support     | ❌  Requires network during creation       |
| Setup complexity    | ✅  Low (just devcontainer.json)           |

## Version Pinning

To pin to a specific version:

```jsonc
{
  "postCreateCommand": "[ -d /workspaces/hve-core ] || git clone --depth 1 --branch v1.0.0 https://github.com/microsoft/hve-core.git /workspaces/hve-core"
}
```

Replace `v1.0.0` with your desired version tag.

## Next Steps

* [Your First Workflow](../first-workflow.md) - Try HVE-Core with a real task
* [Multi-Root Workspace](multi-root.md) - For dual local + Codespaces support
* [Submodule](submodule.md) - For team version control

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
