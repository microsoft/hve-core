---
title: Experimental/Graphify
description: Conventions for consuming graphify-out/ knowledge-graph evidence inside the RPI workflow
sidebar_position: 2
author: Microsoft
ms.date: 2026-08-27
ms.topic: reference
keywords:
  - instruction
  - experimental
  - experimental/graphify
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                        |
|-------------|--------------------------------------------------------------|
| Kind        | instruction                                                  |
| Source      | `.github/instructions/experimental/graphify.instructions.md` |
| Invocation  | Applied automatically to `**/graphify-out/**`                |
| Interactive | No                                                           |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Conventions for consuming graphify-out/ knowledge-graph evidence inside the RPI workflow
<!-- END AUTO-GENERATED: overview -->

## When to use it

Apply these rules when RPI work consumes generated evidence from a
`graphify-out/` directory for structural dependency or community questions.
Keep the output read-only, report audit tags, and verify inferred paths against
source; prefer grep for lexical questions and never trigger a graph rebuild
without the user's decision.

## Example usage

<!-- asset-docs:stub -->
Provide a concrete example that shows the asset in action, including representative input and the resulting output.
