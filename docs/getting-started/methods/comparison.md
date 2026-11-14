---
title: Comparing Setup Methods
description: Decision matrix, decision tree, and side-by-side comparison for choosing how to install HVE Core for the Copilot agent harness
sidebar_position: 9
author: Microsoft
ms.date: 2026-11-10
ms.topic: reference
keywords:
  - installation
  - comparison
  - decision matrix
  - setup methods
  - copilot plugin
estimated_reading_time: 4
---

Use this page to compare every setup method side by side. For a quick recommendation, see [Installing HVE Core](../install).

## Help You Choose

Three questions narrow down the method:

1. Do you need to pin or change HVE Core files?
   * No: install the plugin, or offer it to your team through repository settings
   * Yes: copy HVE Core into your repository or keep a clone
2. Solo or team development?
   * Solo: just you, no version control of HVE Core needed
   * Team: multiple people who need a reproducible setup
3. Where do you work?
   * Local VS Code, with or without a devcontainer
   * GitHub Codespaces
   * Copilot CLI

## Decision Matrix

| Need                                        | Team | Updates              | Recommended Method                                               |
|---------------------------------------------|------|----------------------|------------------------------------------------------------------|
| The full set with the least setup           | Any  | Auto, follows `main` | [Copilot Plugin](cli-plugins.md) ⭐                              |
| The same setup for everyone in a repository | Team | Auto, follows `main` | [Repository default](../install#offer-the-plugin-to-your-team)   |
| Marketplace release channels                | Any  | Auto                 | [VS Code Extension](extension.md)                                |
| A customized copy owned by your repository  | Team | Controlled           | [Repository copy](../install#copy-hve-core-into-your-repository) |
| A pinned version                            | Team | Controlled           | [Git Submodule](submodule.md)                                    |
| Local customization without a container     | Solo | Manual               | [Peer Directory Clone](peer-clone.md)                            |
| Local customization in a devcontainer       | Solo | Manual               | [Git-Ignored Folder](git-ignored.md)                             |
| Codespaces                                  | Any  | Depends on the route | [GitHub Codespaces](codespaces.md)                               |
| Editing HVE Core next to your project       | Solo | Manual               | [Multi-Root Workspace](multi-root.md)                            |
| One host copy shared by containers          | Solo | Manual               | [Mounted Directory](mounted.md)                                  |

## Quick Decision Tree

```text
Want the full set with the least setup?
└─ Yes ─────────────────────────────► Copilot Plugin ⭐

Want every teammate to get HVE Core from the repository?
├─ Without copying files ───────────► Repository default
└─ Pinned to a version ─────────────► Git Submodule

Need to customize HVE Core?
├─ Repository owns the copies ──────► Repository copy
├─ Local VS Code only ──────────────► Peer Directory Clone
├─ Local devcontainer ──────────────► Git-Ignored Folder
└─ Codespaces ──────────────────────► GitHub Codespaces

Prefer Marketplace release channels?
└─ Yes ─────────────────────────────► VS Code Extension
```

## How Each Method Loads

Copilot reaches HVE Core through a plugin, through the project's own `.github` folders, through folders listed in `.github/copilot/settings.json`, or through VS Code's extension forwarding. The route decides which components arrive.

| Method               | Copilot loads it through                                  | Path-specific instructions                    | Version control      |
|----------------------|-----------------------------------------------------------|-----------------------------------------------|----------------------|
| Copilot Plugin       | Plugin                                                    | Yes                                           | Follows `main`       |
| Repository default   | Plugin, offered by `.github/copilot/settings.json`        | Yes                                           | Follows `main`       |
| Repository copy      | The project's own `.github` folders                       | Yes                                           | Your repository      |
| VS Code Extension    | VS Code extension forwarding                              | May not reach Copilot sessions                | Marketplace channels |
| Git Submodule        | Folders listed in repository settings                     | Not confirmed                                 | Pinned commit        |
| Git-Ignored Folder   | Plugin from source, or folders in repository settings     | Yes as a plugin, not confirmed from settings  | Manual `git pull`    |
| Peer Directory Clone | Plugin from source                                        | Yes                                           | Manual `git pull`    |
| Multi-Root Workspace | Plugin from source                                        | Yes                                           | Manual `git pull`    |
| Mounted Directory    | Folders in repository settings, when inside the workspace | Not confirmed                                 | Shared host copy     |
| GitHub Codespaces    | Repository default, or folders in repository settings     | Yes with the default, not confirmed otherwise | Depends on the route |

Use one method at a time. Copilot keeps copies that arrive by different routes, so a second route makes each agent appear twice.

## Still Not Sure?

Start with the [Copilot Plugin](cli-plugins.md). If you outgrow it, move to a repository copy or a clone method, and uninstall the plugin when you switch.

For detailed documentation on each method, see the [Setup Methods Overview](.).

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
