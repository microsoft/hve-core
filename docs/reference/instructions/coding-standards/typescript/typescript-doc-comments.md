---
title: Coding Standards/Typescript/Typescript Doc Comments
description: "Contract-focused TSDoc conventions for TypeScript. Use when adding or changing reusable functions, classes, types, components, hooks, props, callbacks, or test helpers"
sidebar_position: 1
author: Microsoft
ms.date: 2026-10-09
ms.topic: reference
keywords:
  - instruction
  - coding-standards
  - coding-standards/typescript/typescript-doc-comments
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                      |
|-------------|--------------------------------------------------------------------------------------------|
| Kind        | instruction                                                                                |
| Source      | `.github/instructions/coding-standards/typescript/typescript-doc-comments.instructions.md` |
| Invocation  | Applied automatically to `**/*.ts, **/*.tsx, **/*.mts, **/*.cts`                           |
| Interactive | No                                                                                         |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Contract-focused TSDoc conventions for TypeScript. Use when adding or changing reusable functions, classes, types, components, hooks, props, callbacks, or test helpers
<!-- END AUTO-GENERATED: overview -->

## When to use it

These conventions apply automatically when you or Copilot edit `.ts`, `.tsx`, `.mts`, or `.cts` files, including authored `.d.ts` declaration files. They cover new or materially changed declarations: exported helpers, public classes and types, shared components and hooks, props and callbacks, and reusable test helpers. Existing comments are not retrofitted.

Use them to decide whether a declaration needs a documentation block and what it should say. A comment earns its place by stating behavior the name and signature cannot, such as constraints, ordering, mutation, empty results, side effects, and failures. Routine test callbacks, tooling-only exports, re-export barrels, self-describing constants, and generated or vendored code need no block. The rules describe documentation content; they do not add a linter, generator, or dependency.

## Example usage

Ask Copilot to document a shared helper while a TypeScript file is open:

```text
Add documentation comments to the exported helpers in this file.
```

For a batching helper that rejects invalid sizes, the result describes the contract rather than the types:

```typescript
/**
 * Splits items into consecutive batches of at most `size` elements.
 *
 * @remarks
 * Preserves input order and does not modify `items`.
 *
 * @param size - Maximum batch length; must be a positive safe integer.
 * @returns Batches in input order. Returns an empty array when `items` is empty.
 * @throws A `RangeError` when `size` is not a positive safe integer.
 */
export function chunk<T>(items: readonly T[], size: number): T[][] {
  // ...
}
```

The comment omits `@param items` and JavaScript-style `{Type}` annotations because they would only repeat the signature. A neighboring `export const REQUEST_TIMEOUT_MS = 30_000;` stays undocumented because its name already states its meaning and unit.
