---
title: Mounted Directory Installation
description: Advanced devcontainer setup mounting HVE-Core from host filesystem
sidebar_position: 5
author: Microsoft
ms.date: 2025-12-03
ms.topic: how-to
keywords:
  - mounted directory
  - installation
  - github copilot
  - devcontainer
  - advanced
estimated_reading_time: 8
---

Mounted Directory installation shares a single HVE-Core clone across multiple devcontainer projects by mounting a peer directory from the host filesystem. This is an **advanced method** requiring container rebuilds.

## When to Use This Method

✅ **Use this when:**

* You have multiple devcontainer projects needing HVE-Core
* You want a single shared installation (one update applies everywhere)
* You're comfortable with devcontainer configuration
* You're using local devcontainers only (not Codespaces)

❌ **Consider alternatives when:**

* You use Codespaces → [GitHub Codespaces](codespaces.md) (mounts don't work)
* You want simpler setup → [Git-Ignored Folder](git-ignored.md)
* Your team needs version control → [Submodule](submodule.md)
* You need paths that work everywhere → [Multi-Root Workspace](multi-root.md)

## ⚠️ Important Limitations

**This method does NOT work in GitHub Codespaces.** Codespaces doesn't support `${localWorkspaceFolder}` or bind mounts to host filesystem.

**Requires container rebuild.** After adding the mount, you must rebuild the devcontainer before HVE-Core becomes accessible.

## How It Works

HVE-Core is cloned on your **host machine** as a sibling to your project. The devcontainer mounts this directory into the container at `/workspaces/hve-core`.

```text
Host File System:
projects/
├── my-project/                    # Your project (workspace)
│   └── .devcontainer/
│       └── devcontainer.json      # Contains mount configuration
│
└── hve-core/                      # Peer directory on HOST
    └── .github/
        ├── agents/
        ├── prompts/
        └── instructions/

Inside Container (after rebuild):
/workspaces/
├── my-project/                    # Mounted workspace
└── hve-core/                      # Mounted peer directory
```

## Installation Workflow

This method requires a multi-phase workflow:

```text
┌─────────────────────────────────────────────────────────────┐
│ Phase 1: Clone HVE-Core on HOST                             │
│          ↓                                                  │
│ Phase 2: Add mount to devcontainer.json                     │
│          ↓                                                  │
│ Phase 3: Rebuild container (1-3 minutes)                    │
│          ↓                                                  │
│ Phase 4: Configure VS Code settings                         │
│          ↓                                                  │
│ Phase 5: Validate installation                              │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

Use the `hve-core-installer` agent:

1. Open GitHub Copilot Chat (`Ctrl+Alt+I`)
2. Select `hve-core-installer` from the agent picker
3. Say: "Install HVE-Core using mounted directory"
4. Follow the multi-phase guided setup

## Manual Setup

### Phase 1: Clone HVE-Core on Host

**Important:** Clone on your **host machine**, not inside the container.

Open a terminal on your host (not in VS Code's container terminal):

```bash
# Navigate to parent of your project
cd /path/to/projects

# Clone HVE-Core as a sibling
git clone https://github.com/microsoft/hve-core.git
```

Verify structure:

```text
projects/
├── my-project/
└── hve-core/        # ← Must exist on HOST before rebuild
```

### Phase 2: Add Mount to devcontainer.json

Update `.devcontainer/devcontainer.json`:

```jsonc
{
  // ... existing configuration ...
  
  "mounts": [
    "source=${localWorkspaceFolder}/../hve-core,target=/workspaces/hve-core,type=bind,readonly=true,consistency=cached"
  ]
}
```

**Alternative object format:**

```jsonc
{
  "mounts": [
    {
      "type": "bind",
      "source": "${localWorkspaceFolder}/../hve-core",
      "target": "/workspaces/hve-core"
    }
  ]
}
```

### Phase 3: Rebuild Container

⚠️ **Container rebuild is required** to apply the mount.

1. Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on macOS)
2. Type "Dev Containers: Rebuild Container"
3. Press Enter and wait for rebuild (1-3 minutes)

**What happens during rebuild:**

* Current container stops
* New container builds with mount configuration
* Extensions reinstall
* Lifecycle scripts re-run

### Phase 4: Configure VS Code Settings

After rebuild, update `.vscode/settings.json`:

```json
{
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
```

**Or add to devcontainer.json** (recommended for team sharing):

```jsonc
{
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

### Phase 5: Validate Installation

1. Open GitHub Copilot Chat (`Ctrl+Alt+I`)
2. Click the agent picker dropdown
3. Verify HVE-Core agents appear (task-planner, task-researcher, prompt-builder)

**Verify mount from container terminal:**

```bash
ls /workspaces/hve-core/.github/agents
```

## Complete Devcontainer Example

```jsonc
{
  "name": "My Project with Mounted HVE-Core",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
  
  "mounts": [
    "source=${localWorkspaceFolder}/../hve-core,target=/workspaces/hve-core,type=bind,readonly=true,consistency=cached"
  ],
  
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

## Updating HVE-Core

Update on your **host machine**:

```bash
cd /path/to/projects/hve-core
git pull
```

Changes are immediately available in all containers using the mount. No rebuild required for content updates.

## Troubleshooting

### Mount Point Empty After Rebuild

**Cause:** HVE-Core wasn't cloned on the host, or was cloned in the wrong location.

**Fix:**

1. Exit the container
2. Clone HVE-Core on your host machine (see Phase 1)
3. Verify the path matches the mount source
4. Rebuild the container

**Check from host terminal:**

```bash
# On host, not in container
ls /path/to/projects/hve-core/.github
```

### Container Fails to Start

**Cause:** Mount source path doesn't exist.

**Fix:**

1. Check `devcontainer.json` mount path
2. Ensure HVE-Core exists at `${localWorkspaceFolder}/../hve-core`
3. Remove the mount temporarily to start the container
4. Clone HVE-Core, then add mount back and rebuild

### Agents Not Appearing

**Check mount is working:**

```bash
# Inside container
ls /workspaces/hve-core/.github/agents
```

**Check settings paths match:**

Settings must use absolute container paths (`/workspaces/hve-core/...`), not relative paths.

### Doesn't Work in Codespaces

This is expected. Codespaces doesn't support `${localWorkspaceFolder}` or host bind mounts.

**Solution:** Use [postCreateCommand](codespaces.md) for Codespaces, or [Multi-Root Workspace](multi-root.md) for dual-environment support.

## Limitations

| Aspect              | Status                                   |
|---------------------|------------------------------------------|
| Devcontainers       | ✅  Full support                          |
| Codespaces          | ❌  Not supported (no host access)        |
| Team sharing        | ⚠️  Each developer clones on their host  |
| Portable paths      | ⚠️  Absolute container paths             |
| Version pinning     | ⚠️  Manual (use git checkout on host)    |
| Shared installation | ✅  One clone serves all projects         |
| Setup complexity    | ⚠️  High (multi-phase, requires rebuild) |
| Update process      | ✅  Just git pull on host                 |

## Next Steps

* [Your First Workflow](../first-workflow.md) - Try HVE-Core with a real task
* [Multi-Root Workspace](multi-root.md) - Simpler portable solution
* [postCreateCommand](codespaces.md) - If you also need Codespaces support

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
