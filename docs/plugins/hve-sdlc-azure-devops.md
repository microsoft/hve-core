---
title: Azure DevOps
description: Work with Azure Boards items, Azure Repos pull requests, and Azure Pipelines builds.
sidebar_position: 6
author: Microsoft
ms.date: 2026-11-24
ms.topic: how-to
keywords:
  - Copilot plugin
  - sdlc-azure-devops
---

Use `/ado-backlog` to inspect work in one project, `/ado-build-info` to investigate a build, or `/ado-pull-request` to prepare an Azure Repos PR. Azure service access and write authorization remain separate from plugin installation.

## Install

Register the `microsoft/hve-core` marketplace once, then run:

```bash
copilot plugin install hve-sdlc-azure-devops@hve-core
```

In VS Code, choose `hve-sdlc-azure-devops` in the same marketplace. Pair with [`hve-project-planning`](hve-project-planning) for requirements authoring if useful; no companion install is required. If you already use [All](hve-core), it contains this topic.

See [Azure Boards backlog](../reference/skills/azure-devops/ado-backlog) for an entry point.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
