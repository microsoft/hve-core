---
title: "Pull Request Creation Workflow"
description: "Where Azure DevOps pull request creation moved after the backlog consolidation"
author: Microsoft
ms.date: 2026-08-07
ms.topic: tutorial
keywords:
  - ado
  - pull request
  - migration
estimated_reading_time: 3
sidebar_position: 10
---

Pull request creation still exists. It moved out of the retired ADO Backlog Manager pages and is no longer a Backlog Manager workflow.

## Where This Went

Create an Azure DevOps pull request with the `/ado-create-pull-request` command. The command name is unchanged, and it now ships in the `hve-core` collection rather than the retired `ado` collection. It still discovers work items, identifies reviewers, and links the resulting pull request.

The name is unchanged; the runtime behavior is not. The command now resolves its dependencies through named skill activation rather than direct instruction inclusion, runs under a generic parent agent, and fails closed when a required skill does not resolve, stopping before any Azure DevOps call.

It also gained a mandatory preflight, an explicit destination confirmation, autonomy handling, content sanitization, and human-review controls, and the conditions under which a gate may be skipped are narrower than before. Expect the same result for the same intent, but more stops along the way when context is missing.

## What Changed

The consolidated Backlog Manager agent covers backlog work: discovery, triage, sprint planning, task planning, execution, and single-item creation. Pull request creation is a repository operation rather than a backlog operation, so the agent no longer classifies it, dispatches it, or holds the tools to perform it.

This keeps the agent's authority matched to its documented backlog command surface. Repository mutations run through the dedicated command that owns them.

## Where to Go Next

* [Backlog Management overview](../backlog/README.md) explains the consolidated agent and its workflows.
* [Why backlog management](../backlog/why-backlog-management.md) explains the read-only and mutating split.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
