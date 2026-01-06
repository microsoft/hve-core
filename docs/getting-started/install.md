---
title: Installing HVE-Core
description: Choose the right installation method for your environment
author: Microsoft
ms.date: 2025-12-02
ms.topic: how-to
keywords:
  - installation
  - setup
  - github copilot
  - devcontainer
  - codespaces
estimated_reading_time: 5
---

HVE-Core provides GitHub Copilot customizations (chat modes, instructions, and prompts) that enhance your development workflow. This guide helps you choose the right installation method for your environment.

## Quick Start

> **Starter prompt:** "Help me choose how to install this library"

Open Copilot Chat, select the `hve-core-installer` agent, and use this prompt. The agent will ask three questions about your environment and recommend the best method.

## Help Me Choose

Answer these questions to find your recommended installation method:

1. **What's your development environment?**
   - Local VS Code (no devcontainer)
   - Local devcontainer (Docker Desktop)
   - GitHub Codespaces
   - Both local and Codespaces

2. **Solo or team development?**
   - Solo: Just you, no version control of HVE-Core needed
   - Team: Multiple people, need reproducible setup

3. **Update preference?**
   - Auto: Always get latest HVE-Core
   - Controlled: Pin to specific version, update explicitly

### Decision Matrix

| Environment               | Team | Updates    | Recommended Method                              |
|---------------------------|------|------------|-------------------------------------------------|
| Local (no container)      | Solo | Manual     | [Peer Directory Clone](methods/peer-clone.md)   |
| Local (no container)      | Team | Controlled | [Submodule](methods/submodule.md)               |
| Local devcontainer        | Solo | Auto       | [Git-Ignored Folder](methods/git-ignored.md)    |
| Local devcontainer        | Team | Controlled | [Submodule](methods/submodule.md)               |
| Codespaces only           | Solo | Auto       | [GitHub Codespaces](methods/codespaces.md)      |
| Codespaces only           | Team | Controlled | [Submodule](methods/submodule.md)               |
| Both local + Codespaces   | Any  | Any        | [Multi-Root Workspace](methods/multi-root.md) ⭐ |
| Advanced (shared install) | Solo | Auto       | [Mounted Directory](methods/mounted.md)         |

⭐ **Multi-Root Workspace** is the recommended method for most users.

### Quick Decision Tree

```text
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  Which environment?                                             │
│  ├─ Local VS Code only ──────────────► Peer Directory Clone    │
│  ├─ Local devcontainer only ─────────► Git-Ignored Folder      │
│  ├─ Codespaces only ─────────────────► GitHub Codespaces       │
│  └─ Both local + Codespaces ─────────► Multi-Root Workspace ⭐ │
│                                                                 │
│  Working in a team?                                             │
│  └─ Yes, need version control ───────► Submodule               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Installation Methods

### Consumer Methods (Recommended for Most Users)

These methods are for projects that want to use HVE-Core's customizations:

| Method                                          | Best For                      | Complexity |
|-------------------------------------------------|-------------------------------|------------|
| [Multi-Root Workspace](methods/multi-root.md) ⭐ | Any environment, portable     | Low        |
| [Submodule](methods/submodule.md)               | Teams needing version control | Medium     |

### Developer Methods

These methods are for HVE-Core contributors or advanced scenarios:

| Method                                        | Best For                      | Complexity |
|-----------------------------------------------|-------------------------------|------------|
| [Peer Directory Clone](methods/peer-clone.md) | Local VS Code, solo           | Low        |
| [Git-Ignored Folder](methods/git-ignored.md)  | Local devcontainer, solo      | Low        |
| [Mounted Directory](methods/mounted.md)       | Advanced devcontainer sharing | High       |
| [GitHub Codespaces](methods/codespaces.md)    | Codespaces-only projects      | Medium     |

## Using the Installer Agent

The `hve-core-installer` agent automates any installation method:

1. Open GitHub Copilot Chat in VS Code (`Ctrl+Alt+I`)
2. Select `hve-core-installer` from the agent picker
3. Answer the environment detection questions
4. The agent executes your chosen method

The agent handles:

- Environment detection (Local VS Code, Devcontainer, Codespaces)
- Repository cloning or configuration
- VS Code settings updates
- Devcontainer configuration
- Validation of the installation

## Validation

After installation, verify everything works:

1. Open GitHub Copilot Chat (`Ctrl+Alt+I`)
2. Click the agent picker dropdown
3. Verify HVE-Core agents appear (task-planner, task-researcher, prompt-builder)
4. Select an agent and submit a test prompt

Run the installer in validation mode:

> "Validate my HVE-Core installation"

## Next Steps

- [Your First Workflow](first-workflow.md) - Try HVE-Core with a real task
- [RPI Workflow](../rpi/README.md) - Research, Plan, Implement methodology
- [Contributing](../contributing/README.md) - Contribute to HVE-Core

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨GitHub Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
