---
title: SDLC coding standards, documentation, RCA, and Vally tests
description: Apply language coding standards, author documentation, investigate root causes, and build Vally conformance tests.
sidebar_position: 3
author: Microsoft
ms.date: 2026-11-24
ms.topic: how-to
keywords:
  - Copilot plugin
  - hve-sdlc
  - coding-standards
  - documentation
  - root-cause-analysis
  - vally
---

Use the language and writing instructions for Bash, Bicep, C#, PowerShell, Python, Rust, Terraform, TypeScript, and Markdown. Invoke the Documentation agent or `/documentation` for audit, drift, validation, and authoring workflows, `/root-cause-analysis` for structured incident investigation, and `/vally-tests` or Vally Test Author for conformance tests.

## Install

Register the `microsoft/hve-core` marketplace once, then run:

```bash
copilot plugin install hve-sdlc@hve-core
```

In VS Code, choose `hve-sdlc` in the same marketplace. Pair with [`hve-base`](hve-base) for RPI workflows and code review if useful; no companion install is required. If you already use [All](hve-core), it contains this topic.

See [Documentation](../reference/skills/hve-core/documentation) or [Vally Tests](../reference/skills/hve-core/vally-tests) for an entry point.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
