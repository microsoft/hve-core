---
title: Security, supply chain, privacy, Responsible AI, and accessibility
description: Plan and review application security, software supply chain security (SSSC), privacy, Responsible AI, and accessibility.
sidebar_position: 7
author: Microsoft
ms.date: 2026-11-24
ms.topic: how-to
keywords:
  - Copilot plugin
  - sdlc-security
  - privacy
  - responsible-ai
  - accessibility
---

Choose Security Reviewer, SSSC Reviewer, Privacy Reviewer, RAI Reviewer, or Accessibility Reviewer for evidence-based assessments of a codebase or plan. Security Planner, SSSC Planner, Privacy Planner, RAI Planner, and Accessibility Planner produce threat models, DPIAs, risk assessments, conformance mappings, and reviewable backlog handoffs without modifying source code by default.

## Install

Register the `microsoft/hve-core` marketplace once, then run:

```bash
copilot plugin install hve-sdlc-security@hve-core
```

In VS Code, choose `hve-sdlc-security` in the same marketplace. Pair with [`hve-base`](hve-base) for code review and RPI workflows if useful; no companion install is required. If you already use [All](hve-core), it contains this topic.

See [Security Reviewer](../reference/agents/security/security-reviewer) for an entry point.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
