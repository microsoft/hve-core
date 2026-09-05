---
title: Ado Create Pull Request
description: "Create an Azure DevOps pull request with generated description, linked work items, and reviewers"
sidebar_position: 1
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - hve-core
  - ado-create-pull-request
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                        |
|-------------|--------------------------------------------------------------|
| Kind        | prompt                                                       |
| Source      | `.github/prompts/hve-core/ado-create-pull-request.prompt.md` |
| Invocation  | Slash command `/ado-create-pull-request`                     |
| Interactive | Yes                                                          |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Create an Azure DevOps pull request with generated description, linked work items, and reviewers
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt when a reviewed branch is ready for an Azure DevOps pull request with discovered work items and reviewers. Use the description-only workflow when you are not ready to create an external pull request.

## How to use it

Provide or confirm the Azure DevOps project, repository, source branch, and destination. Add draft status, work item IDs, or reviewer filters when needed; destination confirmation, sanitization, and human-review gates still apply before mutation.

## Example usage

```text
/ado-create-pull-request adoProject=hve-core isDraft=true
```

After the required confirmations, the prompt creates a draft pull request with a generated description and eligible links.
