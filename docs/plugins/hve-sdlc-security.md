---
title: Security and software supply chain security
description: Plan and review application security and software supply chain security (SSSC).
sidebar_position: 6
author: Microsoft
ms.date: 2026-11-18
ms.topic: how-to
keywords:
  - Copilot plugin
  - sdlc-security
---

Choose Security Reviewer for an evidence-based assessment of a codebase or SSSC Reviewer for its software supply chain. Security Planner and SSSC Planner produce plans and reviewable handoffs rather than changing the repository by default.

## Install

Register the `microsoft/hve-core` marketplace once, then run:

```bash
copilot plugin install hve-sdlc-security@hve-core
```

In VS Code, choose `hve-sdlc-security` in the same marketplace. Pair with [`hve-sdlc-responsible-ai`](hve-sdlc-responsible-ai) for AI systems or [`hve-sdlc-git`](hve-sdlc-git) for code review if useful; no companion install is required. If you already use [All](hve-core), it contains this topic.

See [Security Reviewer](../reference/agents/security/security-reviewer) for an entry point.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
