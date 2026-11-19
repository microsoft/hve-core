---
title: ado-build-info
description: "Inspect Azure Pipelines build status, failures, logs, and changes for a build ID, Azure Repos PR, or branch. Use for read-only build investigation."
sidebar_position: 2
author: Microsoft
ms.date: 2026-11-18
ms.topic: reference
keywords:
  - skill
  - azure-devops
  - ado-build-info
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                            |
|-------------|----------------------------------------------------------------------------------|
| Kind        | skill                                                                            |
| Source      | `.github/plugins/sdlc-azure-devops/skills/azure-devops/ado-build-info`           |
| Invocation  | Invoked directly as `/ado-build-info`, or loaded on demand by referencing agents |
| Interactive | No                                                                               |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Inspect Azure Pipelines build status, failures, logs, and changes for a build ID, Azure Repos PR, or branch. Use for read-only build investigation.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Invoke `/ado-build-info` for read-only investigation of Azure Pipelines build
status, failure logs, or commit changes by build ID, Azure Repos pull request,
or branch. It never queues, retries, cancels, or modifies pipelines. Use
`ado-pull-request` to prepare or create an Azure Repos pull request, or
`ado-backlog` for Azure Boards work-item operations.

## Example usage

Run `/ado-build-info MyProject "PR 482" logs save` to investigate the latest
pipeline run for pull request 482 and record findings locally.

The skill resolves branch `refs/pull/482/merge`, queries the latest build with
`queueTimeDescending`, retrieves status and failing log excerpts with secrets
redacted, summarizes the root error in chat, and writes the structured report to
`.copilot-tracking/pr/<YYYY-MM-DD>-build-<buildId>.md`.
