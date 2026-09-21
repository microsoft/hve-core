---
title: Security/Vex Generation
description: "VEX generation rules: evidence requirements, confidence routing, forbidden transitions, report templates, and licensing posture for AI-assisted vulnerability triage - Brought to you by microsoft/hve-core"
sidebar_position: 5
author: Microsoft
ms.date: 2026-08-27
ms.topic: reference
keywords:
  - instruction
  - security
  - security/vex-generation
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                                                       |
|-------------|-----------------------------------------------------------------------------------------------------------------------------|
| Kind        | instruction                                                                                                                 |
| Source      | `.github/instructions/security/vex-generation.instructions.md`                                                              |
| Invocation  | Applied automatically to `.github/agents/security/sssc-reviewer.agent.md, .github/agents/security/subagents/cve-*.agent.md` |
| Interactive | No                                                                                                                          |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
VEX generation rules: evidence requirements, confidence routing, forbidden transitions, report templates, and licensing posture for AI-assisted vulnerability triage - Brought to you by microsoft/hve-core
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use these instructions when SSSC review or CVE analysis drafts VEX triage
reports and OpenVEX statements. Resolve aliases across available advisory
sources, route by evidence confidence, and keep uncertainty at
`under_investigation`; use the `vex` skill as the canonical status-logic and
schema reference.

## Example usage

<!-- asset-docs:stub -->
Provide a concrete example that shows the asset in action, including representative input and the resulting output.
