---
title: Plain Language
description: "Use when composing any user-facing reply or generated prose, including questions, progress updates, explanations, and summaries."
sidebar_position: 4
author: Microsoft
ms.date: 2026-10-26
ms.topic: reference
keywords:
  - instruction
  - shared
  - shared/plain-language
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                        |
|-------------|--------------------------------------------------------------|
| Kind        | instruction                                                  |
| Source      | `.github/instructions/shared/plain-language.instructions.md` |
| Invocation  | Included through explicit reference                          |
| Interactive | No                                                           |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Use when composing any user-facing reply or generated prose, including questions, progress updates, explanations, and summaries.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this rule for explanations, questions, progress updates, summaries, and
generated prose. Write for a capable colleague who does not know HVE's internal
labels. Keep necessary technical terms and exact names, commands, schema keys,
required headings, and verbatim disclosures.

The rule has no automatic file attachment. Root instructions and active agents
import it through relative paths, and skills read it by name unless already
loaded; all retain a short direct reminder. This avoids an extra always-on copy
alongside the entry-point guidance. Installing HVE or finding this instruction
in an inventory does not prove that its full content reached a particular request.

For a task that requires machine-only output, follow that format without an
extra explanation. Use the
[Markdown writing-style instruction](../hve-core/writing-style) for additional
document voice and presentation guidance.

## Example usage

For a question about an import that skips existing identifiers, explain the
practical effect before naming a technical property:

```text
Retrying this import will not add duplicate rows because it skips identifiers
already stored. This property is called idempotence.
```

Prefer "Agree on which decisions need your input before moving on" to
"Resolve the decision-participation boundary before advancing the workflow."
The instruction is a writing default, not evidence that every model response
will follow it. Verify actual request inclusion separately from response quality.
