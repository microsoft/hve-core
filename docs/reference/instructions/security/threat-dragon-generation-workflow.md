---
title: Security/Threat Dragon Generation Workflow
description: Human-in-the-loop contract for OWASP Threat Dragon threat-model generation
sidebar_position: 4
author: Microsoft
ms.date: 2026-10-06
ms.topic: reference
keywords:
  - instruction
  - security
  - security/threat-dragon-generation-workflow
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                                                            |
|-------------|----------------------------------------------------------------------------------------------------------------------------------|
| Kind        | instruction                                                                                                                      |
| Source      | `.github/instructions/security/threat-dragon-generation-workflow.instructions.md`                                                |
| Invocation  | Applied automatically to `.github/agents/security/security-planner.agent.md, .github/agents/security/security-reviewer.agent.md` |
| Interactive | No                                                                                                                               |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Human-in-the-loop contract for OWASP Threat Dragon threat-model generation
<!-- END AUTO-GENERATED: overview -->

## When to use it

Apply this contract when a Security Planner or Security Reviewer generates or
refreshes an OWASP Threat Dragon model from a threat-model spec, in any phase.
The generated model stays unconfirmed until the user explicitly confirms it, so
it cannot become a phase artifact, advance a gate, or be handed off before then.
Use the TM7 generation workflow instead for Microsoft Threat Modeling Tool
output and its native feedback loop.

## Example usage

A user asks the Security Planner for a Threat Dragon version of the current
threat model. The agent reads the `security-planning` skill's Threat Dragon
generation reference, runs `generate_threat_dragon.py` on the spec, presents the
spec and the generated JSON model, and asks the user to confirm explicitly
before treating the model as authored or final. If the user does not reply, the
model is reported as awaiting confirmation.
