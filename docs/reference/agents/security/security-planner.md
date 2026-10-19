---
title: Security Planner
description: "Phase-based security planner producing security models, standards mappings, and backlog handoffs with AI/ML detection and RAI Planner integration"
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - security
  - security-planner
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                     |
|-------------|-----------------------------------------------------------|
| Kind        | agent                                                     |
| Source      | `.github/agents/security/security-planner.agent.md`       |
| Invocation  | Selected from the chat agent picker as `Security Planner` |
| Interactive | Yes                                                       |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Phase-based security planner producing security models, standards mappings, and backlog handoffs with AI/ML detection and RAI Planner integration
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use Security Planner to develop a security model, standards mappings, controls, and backlog handoff from requirements or a scoped system description. It considers trust boundaries and data flows and can connect AI-specific concerns to RAI planning. Use Security Reviewer for evidence-backed findings about existing code or a proposed implementation plan.

## How to use it

1. Select `Security Planner`, supply a PRD or system context, and identify the assets, users, integrations, and boundaries to assess.
2. Confirm scope and component mappings as the planner develops standards and security-model evidence.
3. Review threats, proposed controls, gaps, and backlog priorities before handoff.
4. Treat optional TM7 generation as a separate human-in-the-loop workflow. Security planning and generated models still require professional review; they are not deployment authorization.

## Example usage

Ask: "Plan security for the file-import service in `requirements/import.md`. Map upload, storage, processing, and operator access boundaries, record assumptions, and prepare controls for review without changing code."

Expect a scoped security model, evidence-backed gaps, standards mappings, and actionable backlog drafts. Success means each proposed control addresses an identified exposure and unresolved questions remain visible.
