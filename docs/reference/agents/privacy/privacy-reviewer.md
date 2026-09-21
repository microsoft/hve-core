---
title: Privacy Reviewer
description: "Privacy-focused reviewer orchestrator for assessment planning, evidence review, and report generation"
sidebar_position: 2
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - privacy
  - privacy-reviewer
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                     |
|-------------|-----------------------------------------------------------|
| Kind        | agent                                                     |
| Source      | `.github/agents/privacy/privacy-reviewer.agent.md`        |
| Invocation  | Selected from the chat agent picker as `Privacy Reviewer` |
| Interactive | Yes                                                       |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Privacy-focused reviewer orchestrator for assessment planning, evidence review, and report generation
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use Privacy Reviewer to check whether a privacy plan covers the data lifecycle, DPIA triggers, controls, and follow-up actions. It can review a PRD or BRD when no privacy plan exists, recording that absence as a gap. Use Privacy Planner for the guided creation of the missing plan.

## How to use it

1. Select `Privacy Reviewer` and attach a privacy plan or requirements document with the processing activity to examine.
2. Choose `review` or `plan` mode and state any narrower scope. Without a usable target, the reviewer asks for one before proceeding.
3. Read the persisted report's Evidence, Gaps, DPIA completeness, Risks, and Next steps sections.
4. Resolve outstanding questions with the responsible privacy professionals; the summary is not legal approval.

## Example usage

Ask: "Review `requirements/support.md` for privacy readiness. No privacy plan exists yet. Focus on retention, deletion, and processor relationships, and separate evidence from assumptions."

Expect a requirements-based review that explicitly records the missing privacy plan, identifies DPIA decision gaps, and ranks next actions. Success means the fallback target and missing evidence are clear, not silently treated as a completed privacy assessment.
