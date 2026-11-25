---
title: Base workflow, builder, code review, and canvases
description: Run the RPI lifecycle, build Copilot customizations with HVE Builder, review code, and open the RPI Workflow, Session Log, and Code Review canvases.
sidebar_position: 2
author: Microsoft
ms.date: 2026-11-24
ms.topic: how-to
keywords:
  - Copilot plugin
  - hve-base
  - rpi
  - hve-builder
  - code-review
---

Start with `/rpi-research` for an evidence-backed question, `/hve-builder` to author or review an agent, instruction, or skill, or `/code-review` (or the Code Review agent) to review a captured change. The RPI Agent coordinates a longer lifecycle, and the plugin ships the RPI Workflow, Session Log, and Code Review canvases.

## Install

Register the `microsoft/hve-core` marketplace once, then run:

```bash
copilot plugin install hve-base@hve-core
```

In VS Code, choose `hve-base` in the same marketplace. Pair with [`hve-sdlc`](hve-sdlc) for language coding standards and documentation workflows or [`hve-sdlc-git`](hve-sdlc-git) for Git and GitHub pull requests if useful; no companion install is required. If you already use [All](hve-core), it contains this topic.

See [RPI Agent](../reference/agents/hve-core/rpi-agent) or [Code Review](../reference/skills/coding-standards/code-review) for an entry point.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
