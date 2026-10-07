---
title: cspell-config
description: "Create or update project cspell configuration by resolving the loaded config, active dictionaries, curated words, ignore paths, and validation evidence. Use when spell-check configuration needs project words or ignores."
sidebar_position: 3
author: Microsoft
ms.date: 2026-10-02
ms.topic: reference
keywords:
  - skill
  - experimental
  - cspell-config
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                        |
|-------------|----------------------------------------------------------------------------------------------|
| Kind        | skill                                                                                        |
| Source      | `.github/skills/experimental/cspell-config`                                                  |
| Invocation  | Invoked directly as `/cspell-config`; model invocation is disabled, so agents do not load it |
| Interactive | No                                                                                           |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Create or update project cspell configuration by resolving the loaded config, active dictionaries, curated words, ignore paths, and validation evidence. Use when spell-check configuration needs project words or ignores.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill when a repository needs a new CSpell configuration or curated updates to project words and ignore rules. Use a one-off spelling command instead when no persistent configuration change is needed.

## How to use it

Run `/cspell-config` from the target repository. The skill discovers the current spelling setup, proposes configuration or dictionary changes, applies the scoped updates, and validates the result.

## Example usage

```text
/cspell-config
```

The skill reviews the current project vocabulary and updates the repository's CSpell configuration and dictionaries where needed.
