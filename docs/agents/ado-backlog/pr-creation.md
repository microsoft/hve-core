---
title: "Pull Request Creation Workflow"
description: "Where Azure DevOps pull request creation moved after the backlog consolidation"
author: Microsoft
ms.date: 2026-11-18
ms.topic: tutorial
keywords:
  - ado
  - pull request
  - migration
estimated_reading_time: 3
sidebar_position: 10
---

Use `/ado-pull-request` to prepare or create a pull request in Azure Repos. Use `/pull-request` for GitHub.

## Where This Went

`/ado-pull-request prepare` drafts the title and description from local Git evidence without contacting Azure DevOps. Use `create` when you want to open the PR. The workflow confirms the project and repository, discovers work items and reviewers, and asks for the necessary approvals before writing. Its result distinguishes actual links and reviewer assignments from proposals.

## What Changed

The consolidated Backlog Manager agent covers backlog work: discovery, triage, sprint planning, task planning, execution, and single-item creation. Pull request creation is a repository operation rather than a backlog operation, so the agent no longer classifies it, dispatches it, or holds the tools to perform it.

This keeps the agent's authority matched to its documented backlog command surface. Repository mutations run through the dedicated skill that owns them.

## Where to Go Next

* [Backlog Management overview](../backlog/README.md) explains the consolidated agent and its workflows.
* [Why backlog management](../backlog/why-backlog-management.md) explains the read-only and mutating split.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
