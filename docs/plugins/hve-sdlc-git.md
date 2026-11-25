---
title: Git and GitHub pull requests and backlogs
description: Work with local Git, GitHub pull requests, and GitHub issue backlogs without adding unrelated planning tools.
sidebar_position: 5
author: Microsoft
ms.date: 2026-11-24
ms.topic: how-to
keywords:
  - Copilot plugin
  - sdlc-git
---

Use `/git-setup`, `/git-commit`, or `/git-merge` for local work. `/pull-request` and `/pr-reference` prepare and summarize GitHub pull requests, while `/github-backlog` and the GitHub Backlog Executor handle repository issue and sub-issue operations.

## Install

Register the `microsoft/hve-core` marketplace once, then run:

```bash
copilot plugin install hve-sdlc-git@hve-core
```

In VS Code, choose `hve-sdlc-git` in the same marketplace. Pair with [`hve-base`](hve-base) for code review and RPI workflows or [`hve-sdlc-security`](hve-sdlc-security) for a specialist security assessment if useful; no companion install is required. If you already use [All](hve-core), it contains this topic.

See [Pull Request](../reference/skills/hve-core/pull-request) for an entry point.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
