---
title: Setup Methods
description: Guides for each way to install HVE Core and load it in the Copilot agent harness
sidebar_label: Overview
sidebar_custom_props:
  accessibleName: "Overview: Setup Methods"
sidebar_position: 0
author: Microsoft
ms.date: 2026-11-02
ms.topic: overview
keywords:
  - setup
  - installation
  - workspace
  - configuration
  - copilot plugin
estimated_reading_time: 3
---

HVE Core installs several ways. The Copilot Plugin is the starting point: it carries every agent, skill, and instruction and works in VS Code and Copilot CLI. The other methods suit teams that pin a version, customize components, or work in containers. For MCP setup or a repository copy, ask an agent to use the included `hve-core-installer` skill.

## Available Methods

| Method                                | Best For                                   | How Copilot Loads It                      | Complexity |
|---------------------------------------|--------------------------------------------|-------------------------------------------|------------|
| [Copilot Plugin](cli-plugins.md)      | Most people, in VS Code or Copilot CLI     | Plugin                                    | Low        |
| [VS Code Extension](extension.md)     | Marketplace installs with release channels | VS Code extension forwarding              | Low        |
| [Git Submodule](submodule.md)         | Pinned versions for a team                 | Repository settings                       | Medium     |
| [Git-Ignored Clone](git-ignored.md)   | Local-only customization                   | Plugin from source or repository settings | Low        |
| [Peer Clone](peer-clone.md)           | Side-by-side development and contribution  | Plugin from source                        | Medium     |
| [Multi-Root Workspace](multi-root.md) | Editing HVE Core next to your project      | Plugin from source                        | Medium     |
| [Mounted Workspace](mounted.md)       | Sharing one host copy with containers      | Repository settings                       | Medium     |
| [Codespaces](codespaces.md)           | Cloud-based development                    | Repository default or settings            | Low        |

To offer HVE Core to everyone who opens a repository without copying any files, commit the plugin defaults described in [Offer the Plugin to Your Team](../install#offer-the-plugin-to-your-team).

## Which Method Should You Choose?

Start with the **Copilot Plugin**. Move to a **Git Submodule** when your team needs a pinned, version-controlled copy, or copy HVE Core into your repository when it should own and customize the files. Use one method at a time: Copilot keeps copies that arrive by different routes, and each agent then appears more than once.

[Comparing Setup Methods](comparison.md) puts every method side by side. See the [Getting Started](../README.md) guide for the recommended onboarding sequence.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
