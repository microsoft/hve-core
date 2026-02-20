---
title: "Stage 1: Setup"
description: Install and configure HVE Core tooling for your project with guided onboarding
author: Microsoft
ms.date: 2026-02-18
ms.topic: how-to
keywords:
  - ai-assisted project lifecycle
  - setup
  - installation
  - configuration
  - onboarding
estimated_reading_time: 6
---

## Overview

Setup is the entry point for every HVE Core engagement. This stage covers installing HVE Core collections, configuring your development environment, and establishing preferences that persist across sessions. All roles begin here before advancing to Discovery.

## When You Enter This Stage

You enter Setup when starting a new project or joining an existing engagement that uses HVE Core tooling.

> [!NOTE]
> Prerequisites: VS Code with GitHub Copilot Chat enabled. See [Getting Started](../../getting-started/install.md) for detailed installation instructions.

## Available Tools

| Tool               | Type        | How to Invoke                       | Purpose                                         |
|--------------------|-------------|-------------------------------------|-------------------------------------------------|
| hve-core-installer | Agent       | Select **hve-core-installer** agent | Install and configure HVE Core for your project |
| memory             | Agent       | Select **memory** agent             | Store persistent preferences and conventions    |
| checkpoint         | Prompt      | `/checkpoint`                       | Save current environment state                  |
| git-setup          | Prompt      | `/git-setup`                        | Configure Git settings for the project          |
| writing-style      | Instruction | Auto-activated on `**/*.md`         | Enforces voice and tone conventions             |
| markdown           | Instruction | Auto-activated on `**/*.md`         | Enforces Markdown formatting rules              |
| prompt-builder     | Instruction | Auto-activated on AI artifacts      | Enforces authoring standards                    |
| hve-core-location  | Instruction | Auto-activated on `**`              | Resolves missing references to hve-core paths   |

## Role-Specific Guidance

All roles pass through Setup as their first step. Engineers and new contributors spend the most time here configuring language-specific tooling. TPMs and Tech Leads typically complete Setup quickly and advance to [Stage 2: Discovery](discovery.md).

For role-specific onboarding paths, see the [Role Guides](../roles/).

## Starter Prompts

Select **hve-core-installer** agent:

```text
Set up HVE Core for my Python microservices project. Install the rpi and
coding-standards collections. Configure .copilot-tracking/ in .gitignore
and verify agents appear in the Copilot Chat picker.
```

```text
/checkpoint mode=save description=python-microservices-setup
```

```text
/git-setup
```

Select **memory** agent:

```text
Store my coding conventions: use 4-space indentation for Python, enforce
type hints on all public functions, and prefer pytest over unittest for
test files under tests/.
```

## Stage Outputs and Next Stage

Setup produces a configured development environment with HVE Core collections installed and user preferences stored. Transition to [Stage 2: Discovery](discovery.md) when installation is complete.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
