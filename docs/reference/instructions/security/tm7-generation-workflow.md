---
title: Security/Tm7 Generation Workflow
description: Human-in-the-loop contract for TM7 threat-model generation and the native Windows TMT feedback loop
sidebar_position: 4
author: Microsoft
ms.date: 2026-08-27
ms.topic: reference
keywords:
  - instruction
  - security
  - security/tm7-generation-workflow
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                                                            |
|-------------|----------------------------------------------------------------------------------------------------------------------------------|
| Kind        | instruction                                                                                                                      |
| Source      | `.github/instructions/security/tm7-generation-workflow.instructions.md`                                                          |
| Invocation  | Applied automatically to `.github/agents/security/security-planner.agent.md, .github/agents/security/security-reviewer.agent.md` |
| Interactive | No                                                                                                                               |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Human-in-the-loop contract for TM7 threat-model generation and the native Windows TMT feedback loop
<!-- END AUTO-GENERATED: overview -->

## When to use it

Apply this contract when a Security Planner or Reviewer generates a TM7 draft,
updates a model, or considers the native Windows TMT feedback loop. Generation
still requires explicit authorship confirmation before handoff, while native
UI automation requires a separate desktop-takeover confirmation and visual
review.

## Example usage

<!-- asset-docs:stub -->
Provide a concrete example that shows the asset in action, including representative input and the resulting output.
