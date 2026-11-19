---
title: Git, pull requests, and code review
description: Work with local Git and GitHub pull requests without adding tracker-specific planning tools.
sidebar_position: 4
author: Microsoft
ms.date: 2026-11-18
ms.topic: how-to
keywords:
  - Copilot plugin
  - sdlc-git
---

Use `/git-setup`, `/git-commit`, or `/git-merge` for local work. `/pull-request` prepares a GitHub pull request; `/code-review` or the Code Review agent reviews a captured change. The Code Review canvas is optional.

## Install

Register the `microsoft/hve-core` marketplace once, then run:

```bash
copilot plugin install hve-sdlc-git@hve-core
```

In VS Code, choose `hve-sdlc-git` in the same marketplace. Pair with [`hve-sdlc-security`](hve-sdlc-security) for a specialist security assessment if useful; no companion install is required. If you already use [All](hve-core), it contains this topic.

See [Code Review](../reference/skills/coding-standards/code-review) for an entry point.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
