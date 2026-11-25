---
title: github-backlog
description: "Plan and apply GitHub issue, sub-issue, milestone, label, and pull request field operations in one repository. Use for backlog discovery, triage, grooming, PRD hierarchies, and reviewed handoffs."
sidebar_position: 1
author: Microsoft
ms.date: 2026-11-24
ms.topic: reference
keywords:
  - skill
  - git
  - github-backlog
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                            |
|-------------|----------------------------------------------------------------------------------|
| Kind        | skill                                                                            |
| Source      | `.github/plugins/sdlc-git/skills/git/github-backlog`                             |
| Invocation  | Invoked directly as `/github-backlog`, or loaded on demand by referencing agents |
| Interactive | No                                                                               |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Plan and apply GitHub issue, sub-issue, milestone, label, and pull request field operations in one repository. Use for backlog discovery, triage, grooming, PRD hierarchies, and reviewed handoffs.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Invoke `/github-backlog` for issue, sub-issue, milestone, label, and pull
request field workflows in one GitHub repository, including bounded inspection,
discovery, triage, grooming, PRD hierarchy planning, and reviewed handoff
execution. Use `pull-request` for full GitHub pull request authoring or
updates beyond backlog fields, and use `ado-backlog` or `jira` for Azure Boards
or Jira trackers.

## Example usage

Run `/github-backlog triage example/service "is:issue is:open no:label"` to
review unlabeled issues in `example/service` without modifying GitHub.

The skill runs repository preflight through the GitHub bindings, routes the
request to `backlog-plan`, and returns a reviewable triage table with proposed
labels, milestones, and ambiguities preserved. For approved single-item creation
or handoff execution, invoke `/github-backlog add` or `/github-backlog run` with
the target repository and reviewed artifact.
