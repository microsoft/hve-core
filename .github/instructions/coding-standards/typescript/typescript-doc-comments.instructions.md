---
description: 'Contract-focused TSDoc conventions for TypeScript. Use when adding or changing reusable functions, classes, types, components, hooks, props, callbacks, or test helpers'
applyTo: '**/*.ts, **/*.tsx, **/*.mts, **/*.cts'
---

# TypeScript Documentation Comments

Document what a caller needs to know that the name and the type signature cannot say. TypeScript already expresses parameter types, return types, optionality, and modifiers; documentation comments add behavior, constraints, and intent.

## Scope

* Applies to new or materially changed declarations in TypeScript source and authored declaration files (`.d.ts`, `.d.mts`, `.d.cts`).
* Does not require retrofitting comments onto unchanged declarations.
* Describes documentation content only. Types, tests, and review remain responsible for enforcing behavior.

## What to Document

Give every reusable API a concise summary, then add only the details callers cannot infer from its name and signature.

Reusable APIs include:

* Exported functions and helpers used beyond their own module
* Public classes, interfaces, type aliases, and enums, plus public members whose meaning or constraints are not self-evident
* Shared UI components and hooks
* Reusable test helpers, such as shared fixtures, page objects, and assertion or setup utilities used across test files
* Declarations in authored declaration files; a `.d.ts` suffix does not mean the file is generated

Document a private or module-local helper when its name and signature hide something a maintainer needs, such as an invariant, an ordering assumption, or a side effect.

The following need no documentation block unless they carry a non-obvious contract:

* Routine test callbacks, such as `describe`, `it`, and hook bodies, and mocks or stubs local to one test
* Tooling-only exports consumed by a framework or build tool, such as a configuration default export
* Re-export barrels; document the original declaration instead
* Constants whose name and value are self-describing, including any unit
* Generated or vendored code; change the generator or upstream source instead

When deciding, ask whether a caller could misuse the API without the comment. If not, skip it.

## Contract Content

Consider these facts and document each one that applies and is not already evident:

* Units and valid ranges, such as milliseconds versus seconds or positive integers only
* How relative paths, URLs, or identifiers are resolved
* Whether inputs, shared state, or the file system are mutated
* Ordering guarantees for returned collections or callback invocations
* What an empty or missing result looks like: an empty array, `undefined`, `null`, or an error
* Side effects such as network calls, file writes, logging, timers, or global state
* Timing: when a callback fires, whether work is deferred, debounced, or batched
* Resource ownership: who must close, dispose, or unsubscribe
* Failure conditions a caller is expected to handle or avoid

For asynchronous APIs, describe what the returned promise resolves to and when it rejects, rather than only stating that a promise is returned. Mention cancellation behavior when the API accepts an `AbortSignal`.

## Comment Syntax and Placement

* Place a `/** ... */` block directly above the declaration it documents. When the declaration has decorators, place the block above the first decorator. Leave only whitespace between the block and the decorators or declaration.
* Start with a one-sentence summary written from the caller's perspective. Do not restate the declaration name.
* Put longer explanation after the summary or under `@remarks`.
* Use `//` comments inside function bodies for implementation reasoning. Keep caller contracts in the documentation block, where editors surface them.
* Document props and callback options on the property declaration inside the interface or type, not as nested `@param props.name` entries on the component. When props are declared inline, describe the non-obvious ones in the component's comment; do not restructure types solely to host documentation.

## Tags

Tags are conditional. Use a tag when it adds information, and omit it when it would only repeat the name or type.

| Tag                          | Use when                                                                                      |
|------------------------------|-----------------------------------------------------------------------------------------------|
| `@param name - description`  | A parameter has a constraint, unit, default behavior, or meaning not evident from its name    |
| `@returns description`       | The result's meaning, ordering, ownership, empty case, or resolved promise value needs saying |
| `@throws description`        | A caller is expected to avoid or handle a specific error                                      |
| `@remarks`                   | Detail is too long for the summary paragraph                                                  |
| `@typeParam T - description` | A generic parameter has a role or constraint the signature does not convey                    |
| `@example`                   | Correct usage, call order, or setup is not obvious from the signature                         |
| `@deprecated description`    | The API is deprecated; name the replacement to use instead                                    |

Avoid these patterns:

* JavaScript-style type annotations such as `@param {string} name` or `@type`; TypeScript syntax already carries types
* Tags that duplicate modifiers, such as `@private`, `@readonly`, `@static`, `@abstract`, or `@async`
* Empty tags or descriptions that repeat the parameter name
* Treating `@throws` as an exhaustive or compiler-checked list; it documents the failures callers should know about

Release-stage tags such as `@public` or `@beta` follow the project's own documentation tooling policy; this guidance does not require them.

## Examples

A reusable helper documents the constraint, ordering, empty-input behavior, aliasing, and failure that its signature cannot express. The generic parameter needs no `@typeParam` because it has no special role, and `items` needs no `@param` because its description would only repeat the name.

<!-- <example-reusable-helper> -->
```typescript
/**
 * Splits items into consecutive batches of at most `size` elements.
 *
 * @remarks
 * Preserves input order and does not modify `items`. Each batch is a new array,
 * but its elements are the same references as in the input.
 *
 * @param size - Maximum batch length; must be a positive safe integer.
 * @returns Batches in input order, where only the last batch may be shorter.
 *   Returns an empty array when `items` is empty.
 * @throws A `RangeError` when `size` is not a positive safe integer.
 */
export function chunk<T>(items: readonly T[], size: number): T[][] {
  if (!Number.isSafeInteger(size) || size < 1) {
    throw new RangeError(`size must be a positive safe integer, received ${size}`);
  }

  const batches: T[][] = [];
  for (let start = 0; start < items.length; start += size) {
    batches.push(items.slice(start, start + size));
  }
  return batches;
}
```
<!-- </example-reusable-helper> -->

Props and callbacks carry their constraints on their own declarations, so every consumer of the type sees them.

<!-- <example-props-callbacks> -->
```typescript
/** Options for a list in which people can select rows. */
export interface SelectionProps {
  /** Maximum number of rows selected at once; further selections are ignored. Omit for no limit. */
  readonly maxSelected?: number;

  /**
   * Called after each user change to the selection, with row IDs in display order.
   * Receives an empty array when the last selected row is cleared. Not called for
   * the initial render.
   */
  readonly onSelectionChange: (selectedIds: readonly string[]) => void;
}
```
<!-- </example-props-callbacks> -->

A self-describing constant and a re-export barrel need no documentation block. The constant's name states its unit, and the re-exported declarations keep their documentation at their source. A constant whose unit or purpose is not evident from its name still needs a summary.

<!-- <example-no-comment-needed> -->
```typescript
export const REQUEST_TIMEOUT_MS = 30_000;

export { chunk } from './chunk';
export type { SelectionProps } from './selection';
```
<!-- </example-no-comment-needed> -->

## Keeping Comments Accurate

* Update or remove a comment in the same change that alters the behavior it describes.
* Before finishing, check each claim in a comment against the code: constraints, ordering, mutation, empty results, and documented errors.
* Document only behavior the implementation provides or the declared contract promises. Do not describe planned behavior.
* A documentation comment does not prove correctness. Tests and review verify behavior.

## References

* [TSDoc](https://tsdoc.org/) for tag syntax and semantics
* [JSDoc Reference in the TypeScript Handbook](https://www.typescriptlang.org/docs/handbook/jsdoc-supported-types.html) for the distinction between documentation tags and JavaScript type annotations
