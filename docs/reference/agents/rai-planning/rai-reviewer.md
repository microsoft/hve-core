---
title: RAI Reviewer
description: "Responsible AI standards assessment orchestrator for codebase profiling and RAI findings reporting against NIST AI RMF, the AI STRIDE overlay, and the EU AI Act"
sidebar_position: 2
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - rai-planning
  - rai-reviewer
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                 |
|-------------|-------------------------------------------------------|
| Kind        | agent                                                 |
| Source      | `.github/agents/rai-planning/rai-reviewer.agent.md`   |
| Invocation  | Selected from the chat agent picker as `RAI Reviewer` |
| Interactive | Yes                                                   |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Responsible AI standards assessment orchestrator for codebase profiling and RAI findings reporting against NIST AI RMF, the AI STRIDE overlay, and the EU AI Act
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use RAI Reviewer to assess a codebase, changed surface, or proposed plan against supported responsible-AI frameworks. It coordinates framework-specific assessments and reporting. Use RAI Planner for guided system scoping and control planning when those inputs are not yet established.

## How to use it

1. Select `RAI Reviewer` and specify `audit`, `diff`, or `plan`, with a path focus, prior report, or plan as appropriate.
2. Provide framework preferences or allow profiling to identify applicable frameworks.
3. Inspect the consolidated report and evidence limits. Audit and diff modes verify FAIL and PARTIAL findings; plan findings do not become claims of implemented controls.
4. Keep human acceptance pending until qualified review is complete. An unavailable assessment or report-generation failure is not a passing framework result.

## Example usage

Ask: "Review `design/assistant-controls.md` in plan mode against NIST AI RMF and the AI STRIDE overlay. Identify missing oversight and evaluation evidence without claiming the controls are implemented."

Expect a framework-based plan assessment with explicit findings and human acceptance pending. Success means proposed controls, evidence gaps, and verification limits remain distinguishable.
