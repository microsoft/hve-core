---
title: "Build Monitoring Workflow"
description: "Where Azure DevOps build status, logs, and failure analysis moved after the backlog consolidation"
author: Microsoft
ms.date: 2026-08-06
ms.topic: tutorial
keywords:
  - ado
  - build
  - pipeline
  - migration
estimated_reading_time: 3
sidebar_position: 9
---

Build monitoring still exists. It moved out of the retired ADO Backlog Manager pages and into the consolidated Backlog Manager agent.

## Where This Went

Retrieve build status, logs, changes, and failure analysis with the `/ado-get-build-info` command. That command is unchanged and now ships in the `hve-core` collection rather than the retired `ado` collection.

The Backlog Manager agent still classifies a build or pipeline request and dispatches it to the Azure DevOps build reference inside the `backlog-management` skill. GitHub Actions runs are queried directly through the GitHub tool surface.

## What Changed

The agent no longer holds pipeline mutation authority. It reads build status, logs, changes, definitions, and runs, but it does not advance a build stage. Promoting or retrying a stage is a deliberate pipeline action that belongs outside a work-item agent.

Pull request creation is no longer a Backlog Manager workflow either. Use `/ado-create-pull-request`, which is also unchanged and ships in `hve-core`.

## Where to Go Next

* [Backlog Management overview](../backlog/README.md) explains the consolidated agent and its workflows.
* [Execution workflow](../backlog/execution.md) describes how reviewed changes reach a tracker.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
