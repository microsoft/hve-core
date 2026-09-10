---
title: security-planning
description: "Security planning and plan-drift analysis for STRIDE, standards, controls, backlog handoff, current findings, and TM7 generation."
sidebar_position: 15
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - project-planning
  - security-planning
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                               |
|-------------|-------------------------------------------------------------------------------------|
| Kind        | skill                                                                               |
| Source      | `.github/skills/project-planning/security-planning`                                 |
| Invocation  | Invoked directly as `/security-planning`, or loaded on demand by referencing agents |
| Interactive | No                                                                                  |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Security planning and plan-drift analysis for STRIDE, standards, controls, backlog handoff, current findings, and TM7 generation.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill directly or through Security Planner, Security Reviewer, or Code
Review for STRIDE planning, control mapping, security backlog guidance, or
correlation of a security baseline with supplied current findings. Drift analysis
does not scan, verify findings, re-rate severity, or modify its inputs.

For threat-model files, a separate generation path produces TM7 and Markdown from
one YAML/JSON specification. Native visual feedback is opt-in and requires Windows,
an interactive desktop, UI Automation, and the pinned Threat Modeling Tool version.
All outputs require qualified security review, not merely successful generation.

## Example usage

Ask: `/security-planning Compare the attached sample security baseline with these
current diff findings. Keep both inputs unchanged and recommend follow-up only.`
Supply finding locations, evidence scope, and the baseline's controls. Expect a
correlation that distinguishes supported drift or new threats from conclusions
suppressed for insufficient evidence. Default planning/customization exclusions
remain visible; a narrow diff cannot establish repository-wide control validation.

For generation instead, provide a sanitized threat-model specification and request
`pre-populated-comprehensive` or `diagram-only-defer-to-tmt` output. Success means
the TM7 model and Markdown report derive from the same specification, with actual
validation evidence and limitations reported separately.

Do not infer consent for the native feedback loop from a generation request: it
takes control of mouse and keyboard until release. Feedback overlays remain
pending human approval, and automated layout gates do not establish semantic
security approval or permission to overwrite the canonical baseline.
