---
title: Git Setup
description: "Interactive, verification-first Git configuration assistant (non-destructive)"
sidebar_position: 7
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - hve-core
  - git-setup
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                          |
|-------------|------------------------------------------------|
| Kind        | prompt                                         |
| Source      | `.github/prompts/hve-core/git-setup.prompt.md` |
| Invocation  | Slash command `/git-setup`                     |
| Interactive | Yes                                            |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Interactive, verification-first Git configuration assistant (non-destructive)
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt to audit Git identity, signing, defaults, and related configuration before proposing improvements. Use direct Git configuration commands when the exact approved change is already known.

## How to use it

Invoke the command in the target environment and answer only the relevant configuration questions. The prompt verifies current settings and requests confirmation before changing them; never provide private-key material.

## Example usage

```text
/git-setup
```

The prompt audits the current Git configuration and presents verified, non-destructive recommendations for confirmation.
