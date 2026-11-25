---
title: ado-pull-request
description: "Prepare an Azure Repos pull request from local Git changes, or create it in a confirmed Azure DevOps repository with related work items and optional reviewers."
sidebar_position: 3
author: Microsoft
ms.date: 2026-11-18
ms.topic: reference
keywords:
  - skill
  - azure-devops
  - ado-pull-request
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                              |
|-------------|------------------------------------------------------------------------------------|
| Kind        | skill                                                                              |
| Source      | `.github/skills/azure-devops/ado-pull-request`                                     |
| Invocation  | Invoked directly as `/ado-pull-request`, or loaded on demand by referencing agents |
| Interactive | No                                                                                 |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Prepare an Azure Repos pull request from local Git changes, or create it in a confirmed Azure DevOps repository with related work items and optional reviewers.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Invoke `/ado-pull-request` to prepare a pull request proposal from local Git
changes (`prepare`) or create a new pull request in a confirmed Azure DevOps
repository (`create`) with linked work items and optional reviewers. Use
`prepare` whenever write intent is unclear, because it makes no Azure DevOps
calls. Updating or completing an existing Azure Repos pull request is outside
this skill; use `pull-request` for GitHub pull requests and `gitlab` for GitLab
merge requests.

## Example usage

Run `/ado-pull-request prepare base=main` to generate a local pull request title
and description from your current branch commits without touching Azure DevOps.

Once the proposal is reviewed, run
`/ado-pull-request create adoProject=MyProject repository=web-api base=main draft=true`.
The skill runs mandatory preflight, confirms destination and linked work items,
creates the draft pull request, and returns the live Azure DevOps URL together
with actually linked work items and reviewers.
