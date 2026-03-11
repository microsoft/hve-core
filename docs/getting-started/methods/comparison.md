---
title: Comparing Setup Methods
description: Decision matrix, decision tree, and method comparison to help you choose the right HVE installation approach
sidebar_position: 9
author: Microsoft
ms.date: 2026-03-11
ms.topic: reference
keywords:
  - installation
  - comparison
  - decision matrix
  - setup methods
estimated_reading_time: 3
---

Use this page when you need a detailed side-by-side comparison of all available setup methods. For a quick recommendation, see the [Install](../install) page.

## Help You Choose

Answer these three questions to narrow down the best method for your environment:

1. **What's your development environment?**
   * Local VS Code (no devcontainer)
   * Local devcontainer (Docker Desktop)
   * GitHub Codespaces
   * Both local and Codespaces

2. **Solo or team development?**
   * Solo: just you, no version control of HVE-Core needed
   * Team: multiple people, need reproducible setup

3. **Update preference?**
   * Auto: always get latest HVE-Core
   * Controlled: pin to specific version, update explicitly

## Decision Matrix

| Environment               | Team | Updates    | Recommended Method                         |
|---------------------------|------|------------|--------------------------------------------|
| **Any** (simplest)        | Any  | Auto       | [VS Code Extension](extension) ⭐           |
| Local (no container)      | Solo | Manual     | [Peer Directory Clone](peer-clone)         |
| Local (no container)      | Team | Controlled | [Submodule](submodule)                     |
| Local devcontainer        | Solo | Auto       | [Git-Ignored Folder](git-ignored)          |
| Local devcontainer        | Team | Controlled | [Submodule](submodule)                     |
| Codespaces only           | Solo | Auto       | [GitHub Codespaces](codespaces)            |
| Codespaces only           | Team | Controlled | [Submodule](submodule)                     |
| Both local + Codespaces   | Any  | Any        | [Multi-Root Workspace](multi-root)         |
| Advanced (shared install) | Solo | Auto       | [Mounted Directory](mounted)               |
| Any (CLI preferred)       | Any  | Manual     | [CLI Plugins](cli-plugins)                 |

## Quick Decision Tree

```text
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  Want the simplest setup?                                       │
│  └─ Yes ──────────────────────────────► VS Code Extension ⭐   │
│                                                                 │
│  Need to customize HVE-Core?                                    │
│  ├─ Local VS Code only ──────────────► Peer Directory Clone    │
│  ├─ Local devcontainer only ─────────► Git-Ignored Folder      │
│  ├─ Codespaces only ─────────────────► GitHub Codespaces       │
│  └─ Both local + Codespaces ─────────► Multi-Root Workspace    │
│                                                                 │
│  Working in a team?                                             │
│  └─ Yes, need version control ───────► Submodule               │
│                                                                 │
│  Prefer terminal/CLI workflows?                                 │
│  └─ Yes ──────────────────────────────► CLI Plugins            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Installation Methods by Category

### Simplest Method (Recommended for Most Users)

| Method                                  | Best For                         | Complexity |
|-----------------------------------------|----------------------------------|------------|
| [VS Code Extension](extension) ⭐       | Anyone wanting zero-config setup | Minimal    |

### Consumer Methods (Customization + Version Control)

These methods are for projects that want to use and potentially customize HVE-Core components:

| Method                                    | Best For                      | Complexity |
|-------------------------------------------|-------------------------------|------------|
| [Multi-Root Workspace](multi-root)        | Any environment, portable     | Low        |
| [Submodule](submodule)                    | Teams needing version control | Medium     |

### Developer Methods

These methods are for HVE-Core contributors or advanced scenarios:

| Method                                    | Best For                      | Complexity |
|-------------------------------------------|-------------------------------|------------|
| [Peer Directory Clone](peer-clone)        | Local VS Code, solo           | Low        |
| [Git-Ignored Folder](git-ignored)         | Local devcontainer, solo      | Low        |
| [Mounted Directory](mounted)              | Advanced devcontainer sharing | High       |
| [GitHub Codespaces](codespaces)           | Codespaces-only projects      | Medium     |
| [CLI Plugins](cli-plugins)               | Terminal-based CLI workflows  | Low        |

## Still Not Sure?

Start with the [Marketplace Install](../install#marketplace-install-recommended) for the fastest path. If you outgrow it later, any clone-based method can be adopted alongside or instead of the extension.

For detailed documentation on each method, see the [Setup Methods Overview](.).

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
