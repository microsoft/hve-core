---
title: Git Submodule Installation
description: Set up HVE-Core as a git submodule for version-controlled team consumption
sidebar_position: 7
author: Microsoft
ms.date: 2025-12-02
ms.topic: how-to
keywords:
  - git submodule
  - installation
  - github copilot
  - version control
  - teams
estimated_reading_time: 7
---

Git submodules provide version-controlled, reproducible HVE-Core consumption. Every team member gets the exact same version, and updates are explicit commits.

## When to Use This Method

✅ **Use this when:**

* Your team needs reproducible setups (same version for everyone)
* You want to pin HVE-Core to a specific version
* Updates should be deliberate, reviewed commits
* HVE-Core dependency should be tracked in version control

❌ **Consider alternatives when:**

* You want automatic updates → [Multi-Root Workspace](multi-root.md)
* You're a solo developer without version pinning needs → [Multi-Root Workspace](multi-root.md)

## How It Works

A git submodule embeds HVE-Core as a nested repository within your project. The `.gitmodules` file tracks the repository URL, and your project's git history tracks the exact commit.

```text
your-project/
├── .gitmodules          ← Defines submodule URL
├── lib/
│   └── hve-core/        ← Submodule (points to specific commit)
│       └── .github/
│           ├── agents/
│           ├── prompts/
│           └── instructions/
└── .vscode/
    └── settings.json    ← Points to lib/hve-core paths
```

## Quick Start

Use the `hve-core-installer` agent:

1. Open GitHub Copilot Chat (`Ctrl+Alt+I`)
2. Select `hve-core-installer` from the agent picker
3. Say: "Install HVE-Core using git submodule"
4. Follow the guided setup

## Manual Setup

### Step 1: Add the Submodule

```bash
# From your project root
git submodule add https://github.com/microsoft/hve-core.git lib/hve-core
git commit -m "Add HVE-Core as submodule"
```

This creates a `.gitmodules` file:

```ini
[submodule "lib/hve-core"]
    path = lib/hve-core
    url = https://github.com/microsoft/hve-core.git
    branch = main
```

### Step 2: Configure VS Code Settings

Create or update `.vscode/settings.json`:

```jsonc
{
  "chat.agentFilesLocations": {
    "lib/hve-core/.github/agents/ado": true,
    "lib/hve-core/.github/agents/data-science": true,
    "lib/hve-core/.github/agents/design-thinking": true,
    "lib/hve-core/.github/agents/github": true,
    "lib/hve-core/.github/agents/installer": true,
    "lib/hve-core/.github/agents/project-planning": true,
    "lib/hve-core/.github/agents/hve-core": true,
    "lib/hve-core/.github/agents/hve-core/subagents": true,
    "lib/hve-core/.github/agents/security-planning": true,
    ".github/agents": true
  },
  "chat.promptFilesLocations": {
    "lib/hve-core/.github/prompts/ado": true,
    "lib/hve-core/.github/prompts/design-thinking": true,
    "lib/hve-core/.github/prompts/github": true,
    "lib/hve-core/.github/prompts/hve-core": true,
    "lib/hve-core/.github/prompts/security-planning": true,
    ".github/prompts": true
  },
  "chat.instructionsFilesLocations": {
    "lib/hve-core/.github/instructions/ado": true,
    "lib/hve-core/.github/instructions/coding-standards": true,
    "lib/hve-core/.github/instructions/design-thinking": true,
    "lib/hve-core/.github/instructions/github": true,
    "lib/hve-core/.github/instructions/hve-core": true,
    "lib/hve-core/.github/instructions/shared": true,
    ".github/instructions": true
  },
  "chat.agentSkillsLocations": {
    "lib/hve-core/.github/skills": true,
    "lib/hve-core/.github/skills/shared": true,
    ".github/skills": true
  }
}
```

### Step 3: Configure Devcontainer (Codespaces)

Update `.devcontainer/devcontainer.json` to initialize submodules automatically:

```jsonc
{
  "name": "My Project with HVE-Core",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu",

  "onCreateCommand": "git submodule update --init --recursive",

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

## Team Member Onboarding

When team members clone your project, they need to initialize submodules.

**Option A: Clone with submodules (recommended):**

```bash
git clone --recurse-submodules https://github.com/your-org/your-project.git
```

**Option B: Initialize after clone:**

```bash
git clone https://github.com/your-org/your-project.git
cd your-project
git submodule update --init --recursive
```

**Option C: Configure git to auto-recurse:**

```bash
git config --global submodule.recurse true
# Now all git operations auto-update submodules
```

## Updating HVE-Core

| Task                   | Command                                                               |
|------------------------|-----------------------------------------------------------------------|
| Check for updates      | `cd lib/hve-core && git fetch && git log HEAD..origin/main --oneline` |
| Update to latest       | `git submodule update --remote lib/hve-core`                          |
| Pin to specific commit | `cd lib/hve-core && git checkout <sha>`                               |
| Track different branch | `git config submodule.lib/hve-core.branch develop`                    |

**After updating, commit the change:**

```bash
git add lib/hve-core
git commit -m "Update HVE-Core submodule to latest"
```

### Auto-Update on Container Rebuild

To update HVE-Core when rebuilding your devcontainer:

```jsonc
{
  "updateContentCommand": "git submodule update --remote lib/hve-core || true"
}
```

## Version Pinning

Submodules pin to a specific commit by default. To verify or change the pinned version:

**Check current version:**

```bash
cd lib/hve-core
git log -1 --oneline
```

**Pin to a specific tag or commit:**

```bash
cd lib/hve-core
git checkout v1.2.0  # or a specific commit SHA
cd ..
git add lib/hve-core
git commit -m "Pin HVE-Core to v1.2.0"
```

## Verification

After setup, verify HVE-Core is working:

1. Check `lib/hve-core/` contains the HVE-Core repository
2. Open Copilot Chat (`Ctrl+Alt+I`)
3. Click the agent picker dropdown
4. Verify HVE-Core agents appear (task-planner, task-researcher, etc.)

## Troubleshooting

### Submodule folder is empty

The submodule wasn't initialized:

```bash
git submodule update --init --recursive
```

### Agents not appearing

* **Check settings paths:** Verify `.vscode/settings.json` paths match submodule location
* **Reload window:** `Ctrl+Shift+P` → "Developer: Reload Window"
* **Verify submodule content:** `ls lib/hve-core/.github/agents/`

### "Detached HEAD" warning in submodule

This is normal for submodules. The submodule points to a specific commit, not a branch. To work on the submodule:

```bash
cd lib/hve-core
git checkout main
```

### Merge conflicts in submodule pointer

When multiple team members update the submodule:

```bash
git checkout --theirs lib/hve-core  # Accept their version
# OR
git checkout --ours lib/hve-core    # Keep your version
git add lib/hve-core
git commit
```

## Comparison with Other Methods

| Aspect               | Submodule           | Multi-Root        | Clone         |
|----------------------|---------------------|-------------------|---------------|
| Version controlled   | ✅  Yes              | ⚠️  Partial       | ❌  No         |
| Team reproducibility | ✅  Same version     | ⚠️  May vary      | ⚠️  May vary  |
| Update control       | ✅  Explicit commits | ⚠️  Automatic     | ⚠️  Automatic |
| In workspace         | ✅  Subfolder        | ✅  Workspace root | ❌  External   |
| Initial setup        | 🟡  Medium          | 🟡  Medium        | 🟢  Easy      |

## Next Steps

* [Your First Workflow](../first-workflow.md) - Try HVE-Core with a real task
* [RPI Workflow](../../rpi/) - Research, Plan, Implement methodology
* [Back to Installation Guide](../install.md) - Compare other methods

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
