---
title: Finding Deep Verifier
description: Deep adversarial verification of FAIL and PARTIAL findings for a single security skill
sidebar_position: 3
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - security
  - finding-deep-verifier
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                    |
|-------------|--------------------------------------------------------------------------|
| Kind        | agent                                                                    |
| Source      | `.github/agents/security/subagents/finding-deep-verifier.agent.md`       |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly) |
| Interactive | No                                                                       |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Deep adversarial verification of FAIL and PARTIAL findings for a single security skill
<!-- END AUTO-GENERATED: overview -->

## When to use it

Reviewer orchestrators dispatch this worker to verify all FAIL and PARTIAL findings for one skill or supported RAI framework in audit or diff mode. It searches for confirming and contradicting evidence rather than accepting an assessor's claims unchanged. Plan mode skips this verification stage.

## Example usage

The parent supplies the skill, profile, non-empty candidate findings, and diff context for an authorization change. The worker returns a verification verdict and supporting evidence for each finding. A RAI dispatch explicitly supplies `Domain=rai` and the framework contract; unsupported domains are rejected. The parent decides how to consolidate the results, and the worker does not implement suggested fixes.
