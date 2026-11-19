---
title: RPI and HVE Builder
description: Run a resumable research, plan, implement, and review cycle, or author and review a Copilot customization.
sidebar_position: 2
author: Microsoft
ms.date: 2026-11-18
ms.topic: how-to
keywords:
  - Copilot plugin
  - rpi-builder
---

Start with `/rpi-research` for an evidence-backed question or `/hve-builder` to work on an agent, instruction, or skill. The RPI Agent coordinates a longer lifecycle; the RPI Workflow canvas is optional.

## Install

Register the `microsoft/hve-core` marketplace once, then run:

```bash
copilot plugin install hve-rpi-builder@hve-core
```

In VS Code, choose `hve-rpi-builder` in the same marketplace. Pair with [`hve-sdlc-git`](hve-sdlc-git) for pull requests if useful; no companion install is required. If you already use [All](hve-core), it contains this topic.

See [RPI lifecycle](../reference/skills/rpi/rpi) for an entry point.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
