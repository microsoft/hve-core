---
title: "Build Monitoring Workflow"
description: "Where Azure DevOps build status, logs, and failure analysis moved after the backlog consolidation"
author: Microsoft
ms.date: 2026-11-18
ms.topic: tutorial
keywords:
  - ado
  - build
  - pipeline
  - migration
estimated_reading_time: 3
sidebar_position: 9
---

Use `/ado-build-info` to inspect an Azure Pipelines build. Supply the Azure DevOps project and a build ID, Azure Repos PR, or branch.

## Where This Went

Ask for status, relevant log excerpts, or changes. The Backlog Manager uses the same skill for Azure Pipelines. GitHub Actions runs use the GitHub tools instead.

## What Changed

The agent no longer holds pipeline mutation authority. It reads build status, logs, changes, definitions, and runs, but it does not advance a build stage. Promoting or retrying a stage is a deliberate pipeline action that belongs outside a work-item agent.

To open an Azure Repos PR, use `/ado-pull-request`; see [Pull Request Creation](pr-creation.md).

## Where to Go Next

* [Backlog Management overview](../backlog/README.md) explains the consolidated agent and its workflows.
* [Execution workflow](../backlog/execution.md) describes how reviewed changes reach a tracker.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
