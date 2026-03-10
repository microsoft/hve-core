---
title: Setup Methods
description: Detailed guides for each HVE Core installation and workspace configuration method
sidebar_label: Overview
sidebar_position: 0
author: Microsoft
ms.topic: overview
keywords:
  - setup
  - installation
  - workspace
  - configuration
estimated_reading_time: 3
---

HVE Core supports multiple setup methods. Choose the approach that fits your environment and workflow.

## Available Methods

| Method                                | Best For                                  | Complexity |
|---------------------------------------|-------------------------------------------|------------|
| [VS Code Extension](extension.md)     | Quick start, individual developers        | Low        |
| [Multi-Root Workspace](multi-root.md) | Teams with shared configuration           | Medium     |
| [Git Submodule](submodule.md)         | Pinned versions, CI integration           | Medium     |
| [Peer Clone](peer-clone.md)           | Side-by-side development and contribution | Medium     |
| [Mounted Workspace](mounted.md)       | Container and remote environments         | Medium     |
| [Git-Ignored Clone](git-ignored.md)   | Local-only customization                  | Low        |
| [Codespaces](codespaces.md)           | Cloud-based development                   | Low        |
| [CLI Plugins](cli-plugins.md)         | Terminal-first workflows                  | Medium     |

## Which Method Should You Choose?

Start with the **VS Code Extension** if you want the fastest path. Move to **Multi-Root Workspace** or **Git Submodule** when your team needs shared, version-controlled configuration.

See the [Getting Started](../README.md) guide for the recommended onboarding sequence.
