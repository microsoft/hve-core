---
title: Peer Directory Clone Installation
description: Install HVE-Core as a sibling directory for local VS Code development
author: Microsoft
ms.date: 2025-12-03
ms.topic: how-to
keywords:
  - peer directory
  - installation
  - github copilot
  - local development
estimated_reading_time: 5
---

Peer Directory Clone places HVE-Core as a sibling folder next to your project. This is the simplest method for developers working with local VS Code without devcontainers.

## When to Use This Method

✅ **Use this when:**

* You're using local VS Code (no devcontainer)
* You're working solo on a project
* You want the simplest possible setup
* You're developing or testing HVE-Core itself

❌ **Consider alternatives when:**

* You use devcontainers → [Git-Ignored Folder](git-ignored.md) or [Mounted Directory](mounted.md)
* You use Codespaces → [GitHub Codespaces](codespaces.md)
* Your team needs version control → [Submodule](submodule.md)
* You need paths that work everywhere → [Multi-Root Workspace](multi-root.md)

## How It Works

HVE-Core is cloned into a sibling directory. Your project's VS Code settings reference it using relative paths.

```text
projects/
├── my-project/              # Your project
│   └── .vscode/
│       └── settings.json    # Points to ../hve-core
│
└── hve-core/                # Sibling directory
    └── .github/
        ├── agents/
        ├── prompts/
        └── instructions/
```

## Quick Start

Use the `hve-core-installer` agent:

1. Open GitHub Copilot Chat (`Ctrl+Alt+I`)
2. Select `hve-core-installer` from the agent picker
3. Say: "Install HVE-Core using peer directory clone"
4. Follow the guided setup

## Manual Setup

### Step 1: Clone HVE-Core

Open a terminal in your project's parent directory:

```bash
# Navigate to parent of your project
cd /path/to/projects

# Clone HVE-Core as a sibling
git clone https://github.com/microsoft/hve-core.git
```

Your directory structure should now look like:

```text
projects/
├── my-project/
└── hve-core/
```

### Step 2: Update VS Code Settings

Create or update `.vscode/settings.json` in your project:

```json
{
  "chat.agentFilesLocations": {
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
  "chat.promptFilesLocations": {
    "../hve-core/.github/prompts/ado": true,
    "../hve-core/.github/prompts/design-thinking": true,
    "../hve-core/.github/prompts/github": true,
    "../hve-core/.github/prompts/hve-core": true,
    "../hve-core/.github/prompts/security-planning": true
  },
  "chat.instructionsFilesLocations": {
    "../hve-core/.github/instructions/ado": true,
    "../hve-core/.github/instructions/coding-standards": true,
    "../hve-core/.github/instructions/design-thinking": true,
    "../hve-core/.github/instructions/github": true,
    "../hve-core/.github/instructions/hve-core": true,
    "../hve-core/.github/instructions/shared": true
  },
  "chat.agentSkillsLocations": {
    "../hve-core/.github/skills": true,
    "../hve-core/.github/skills/shared": true
  }
}
```

### Step 3: Validate Installation

Verify HVE-Core directories are accessible:

```bash
ls ../hve-core/.github/agents
```

You should see `.agent.md` files. Then validate in VS Code:

1. Reload VS Code window (`Ctrl+Shift+P` → "Developer: Reload Window")
2. Open GitHub Copilot Chat (`Ctrl+Alt+I`)
3. Click the agent picker dropdown
4. Verify HVE-Core agents appear (task-planner, task-researcher, prompt-builder)

## Updating HVE-Core

To get the latest version:

```bash
cd ../hve-core
git pull
```

No VS Code restart required. Changes take effect immediately.

## Troubleshooting

### Agents Not Appearing

**Check the relative path:**

```bash
# From your project directory
ls ../hve-core/.github/agents
```

If the path doesn't resolve, verify:

1. HVE-Core is cloned at the correct location
2. Your terminal is in your project directory
3. The relative path in settings.json is correct

**Check VS Code settings:**

1. Open Command Palette (`Ctrl+Shift+P`)
2. Type "Preferences: Open User Settings (JSON)"
3. Verify no conflicting settings override your workspace settings

### Path Breaks After Moving Project

Relative paths break if your project moves. Options:

1. Re-clone HVE-Core next to the new location
2. Update settings.json with the new relative path
3. Switch to [Multi-Root Workspace](multi-root.md) for portable paths

### Doesn't Work in Devcontainer

Peer directory clone doesn't work in devcontainers because the container can't access files outside the mounted workspace.

**Solutions:**

* Use [Git-Ignored Folder](git-ignored.md) for self-contained installation
* Use [Mounted Directory](mounted.md) to share HVE-Core across projects
* Use [Multi-Root Workspace](multi-root.md) for the most portable solution

## Limitations

| Aspect           | Status                               |
|------------------|--------------------------------------|
| Devcontainers    | ❌  Not supported                     |
| Codespaces       | ❌  Not supported                     |
| Team sharing     | ⚠️  Each developer clones separately |
| Portable paths   | ⚠️  Breaks if project moves          |
| Version pinning  | ⚠️  Manual (use git checkout)        |
| Setup complexity | ✅  Very simple                       |
| Update process   | ✅  Just git pull                     |

## Next Steps

* [Your First Workflow](../first-workflow.md) - Try HVE-Core with a real task
* [Multi-Root Workspace](multi-root.md) - Upgrade to portable paths
* [Submodule](submodule.md) - Add version control for teams

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
