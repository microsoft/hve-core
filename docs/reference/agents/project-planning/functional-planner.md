---
title: Functional Planner
description: "Read-only Product Manager agent that analyzes PRDs and plans Azure DevOps, GitHub, or Jira work-item hierarchies without mutating a tracker"
sidebar_position: 4
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - project-planning
  - functional-planner
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                         |
|-------------|---------------------------------------------------------------|
| Kind        | agent                                                         |
| Source      | `.github/agents/project-planning/functional-planner.agent.md` |
| Invocation  | Selected from the chat agent picker as `Functional Planner`   |
| Interactive | Yes                                                           |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Read-only Product Manager agent that analyzes PRDs and plans Azure DevOps, GitHub, or Jira work-item hierarchies without mutating a tracker
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use Functional Planner to turn a PRD into a platform-appropriate work-item hierarchy without creating or modifying tracker items. It combines requirements, codebase context, and read-only discovery of related work. Use Backlog Manager to execute the resulting handoff after review.

## How to use it

1. Select `Functional Planner`, supply the PRD, and confirm the Azure DevOps project, GitHub repository, or Jira project key.
2. Confirm the planning framework when the context does not determine it.
3. Review the proposed hierarchy, requirement coverage, and validated types and fields. Unsupported fields remain `needs_review`; contradictory requirements stop dependent planning.
4. Review the plan and handoff before passing them to Backlog Manager. No tracker mutation occurs in this planning session.

## Example usage

Ask: "Plan a work-item hierarchy from `requirements/import-prd.md` for our confirmed GitHub repository. Discover related issues, map every requirement, and leave unsupported hierarchy choices for review. Do not create issues."

Expect a traceable hierarchy and execution handoff with explicit gaps. Success means every requirement maps to proposed work or a named unresolved item, and no planning identifier is mistaken for an existing tracker ID.
