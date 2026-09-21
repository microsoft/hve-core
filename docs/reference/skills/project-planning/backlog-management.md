---
title: backlog-management
description: "Shared backlog conventions for Azure DevOps, GitHub, and Jira. Use for platform resolution, autonomy tiers, sanitization guards, and story quality."
sidebar_position: 3
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - project-planning
  - backlog-management
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                |
|-------------|------------------------------------------------------|
| Kind        | skill                                                |
| Source      | `.github/skills/project-planning/backlog-management` |
| Invocation  | Loaded on demand by referencing agents               |
| Interactive | No                                                   |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Shared backlog conventions for Azure DevOps, GitHub, and Jira. Use for platform resolution, autonomy tiers, sanitization guards, and story quality.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Backlog Manager and the backlog planning and execution skills load this shared
contract for platform resolution, story quality, similarity assessment, autonomy,
sanitization, and recovery. It is not a direct slash command and does not itself
provide tracker access. Use `backlog-plan`, `functional-planner`, or
`backlog-execute` as the entry point appropriate to your task.

## Example usage

Ask Backlog Manager to assess two sample requirements against existing GitHub
issues in your confirmed repository, using `backlog-management` through the
read-only planning workflow. Supply the requirement text and relevant issue
identifiers, and request recommendations only.

The workflow should resolve one platform, read the matching platform reference,
and record whether each candidate is Match, Similar, Distinct, or Uncertain using
acceptance criteria as evidence. Success is a reviewable plan that preserves
ambiguities instead of silently merging or closing issues.

If execution is later authorized, internal planning IDs and temporary keys must
not leak into tracker payloads, ingested notification-triggering markup must be
neutralized, and probable secrets stop the operation. Successful live creation
logs, not conversation memory or dry-run keys, govern recovery.
