---
title: Hve Core/Writing Style
description: "Use for Markdown-specific voice, tone, and presentation alongside the shared Plain Language instruction."
sidebar_position: 8
author: Microsoft
ms.date: 2026-10-15
ms.topic: reference
keywords:
  - instruction
  - hve-core
  - hve-core/writing-style
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                         |
|-------------|---------------------------------------------------------------|
| Kind        | instruction                                                   |
| Source      | `.github/instructions/hve-core/writing-style.instructions.md` |
| Invocation  | Applied automatically to `**/*.md`                            |
| Interactive | No                                                            |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Use for Markdown-specific voice, tone, and presentation alongside the shared Plain Language instruction.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Apply this guidance whenever authoring or revising Markdown prose so voice,
tone, sentence structure, and vocabulary match the audience and purpose. Use
the shared [Plain Language instruction](../shared/plain-language) for the
communication default and the Markdown instructions for syntax and lint rules.
Prefer surface-specific community or Mural style when that narrower context applies.

## Example usage

When summarizing a configuration change, keep the explanation direct without
renaming the setting:

```text
The request timed out because request_timeout_ms was set too low. Increase that
setting to allow more time for the response.
```

Reuse the same accurate term rather than introducing synonyms for variety.
Break a complex explanation into shorter sentences, while retaining necessary
technical distinctions.
