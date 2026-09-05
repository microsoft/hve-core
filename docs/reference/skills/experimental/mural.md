---
title: mural
description: "Mural workspace, room, mural, and widget workflows via the Mural REST API exposed through a Python CLI. Use when you need to read or write Mural content or automate widget creation."
sidebar_position: 5
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - skill
  - experimental
  - mural
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                   |
|-------------|-------------------------------------------------------------------------|
| Kind        | skill                                                                   |
| Source      | `.github/skills/experimental/mural`                                     |
| Invocation  | Invoked directly as `/mural`, or loaded on demand by referencing agents |
| Interactive | No                                                                      |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Mural workspace, room, mural, and widget workflows via the Mural REST API exposed through a Python CLI. Use when you need to read or write Mural content or automate widget creation.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill when you need to authenticate to Mural, inspect workspaces and
murals, or create and update widgets through the Mural REST API. Production API
requests are restricted to Mural's public API origin and refuse redirects.

Do not use this skill as a generic HTTP client or to target an arbitrary remote
API origin. HTTP overrides are limited to explicitly enabled loopback testing.

## Example usage

Authenticate interactively, inspect the active profile, and list workspaces:

```bash
python -m mural auth login
python -m mural auth status
python -m mural workspace list
```
