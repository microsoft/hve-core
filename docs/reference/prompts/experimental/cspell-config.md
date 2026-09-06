---
title: Cspell Config
description: Create or update the project cspell configuration with project words and ignores
sidebar_position: 1
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - experimental
  - cspell-config
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                  |
|-------------|--------------------------------------------------------|
| Kind        | prompt                                                 |
| Source      | `.github/prompts/experimental/cspell-config.prompt.md` |
| Invocation  | Slash command `/cspell-config`                         |
| Interactive | Yes                                                    |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Create or update the project cspell configuration with project words and ignores
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt when a repository needs a new CSpell configuration or curated updates to project words and ignore rules. Use a one-off spelling command instead when no persistent configuration change is needed.

## How to use it

Run the slash command from the target repository. The prompt discovers the current spelling setup, proposes configuration or dictionary changes, applies the scoped updates, and validates the result.

## Example usage

```text
/cspell-config
```

The prompt reviews the current project vocabulary and updates the repository's CSpell configuration and dictionaries where needed.
