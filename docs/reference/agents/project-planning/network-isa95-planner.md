---
title: Network ISA-95 Planner
description: ISA-95-aligned network planning for secure edge Kubernetes to Azure connectivity and remediation roadmaps
sidebar_position: 6
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - project-planning
  - network-isa95-planner
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                            |
|-------------|------------------------------------------------------------------|
| Kind        | agent                                                            |
| Source      | `.github/agents/project-planning/network-isa95-planner.agent.md` |
| Invocation  | Selected from the chat agent picker as `Network ISA-95 Planner`  |
| Interactive | Yes                                                              |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
ISA-95-aligned network planning for secure edge Kubernetes to Azure connectivity and remediation roadmaps
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use Network ISA-95 Planner to assess segmentation and plan secure edge Kubernetes connectivity to Azure for brownfield or greenfield sites. It organizes recommendations around zones, conduits, allowed flows, and operational constraints. Use a broader architecture reviewer when the decision is not primarily about site networking.

## How to use it

1. Select `Network ISA-95 Planner` and provide the site type, levels present, Kubernetes model, connectivity, segmentation, identity, logging, and change-window constraints.
2. For brownfield sites, describe reusable infrastructure and who can change it. For greenfield sites, describe target trust boundaries and connectivity expectations.
3. Resolve missing intake facts before asking for a final alignment classification or remediation roadmap.
4. Review the plain-language assessment and YAML companion together, including effort, confidence, and highest-risk exposures. Planning does not deploy network changes.

## Example usage

Ask: "Assess our brownfield edge site from `design/site-network.md`. Reuse existing firewall and gateway controls where evidence supports them, ask for missing ownership details, and produce a staged remediation plan without deployment."

Expect an intake-gated assessment with explicit flows, constraints, and prioritized recommendations. Success means unknown site facts remain visible rather than becoming confident alignment scores.
