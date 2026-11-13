---
title: RPI Refiner
description: "Assesses one fresh-context subtractive lens across completed RPI work (logic/branching/error boundaries/performance, conventions/SDKs/libraries/language versions, assumptions/architecture/abstractions/tests, or documents/domain language/infrastructure) and returns candidate removals, simplifications, and redesigns for the calling agent to verify. Use during rpi-refine when isolating fresh-context subtractive review lenses would help."
sidebar_position: 3
author: Microsoft
ms.date: 2026-11-12
ms.topic: reference
keywords:
  - agent
  - hve-core
  - rpi-refiner
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                    |
|-------------|--------------------------------------------------------------------------|
| Kind        | agent                                                                    |
| Source      | `.github/agents/hve-core/subagents/rpi-refiner.agent.md`                 |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly) |
| Interactive | No                                                                       |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Assesses one fresh-context subtractive lens across completed RPI work (logic/branching/error boundaries/performance, conventions/SDKs/libraries/language versions, assumptions/architecture/abstractions/tests, or documents/domain language/infrastructure) and returns candidate removals, simplifications, and redesigns for the calling agent to verify. Use during rpi-refine when isolating fresh-context subtractive review lenses would help.
<!-- END AUTO-GENERATED: overview -->

## When to use it

`RPI Refiner` is an optional fresh-context helper dispatched by [rpi-refine](../../../skills/rpi/rpi-refine), not a user-selected agent. When `rpi-refine` inspects completed work and subagent dispatch is available, it sends up to four parallel `RPI Refiner` lanes so each lens reads the touched files without inheriting the rationale that justified extra code, tests, docs, or workarounds during implementation.

Each dispatch assigns one subtractive lens (logic, branching, error boundaries, and performance; conventions, SDKs, libraries, and language versions; assumptions, architecture, abstractions, and tests; or documents, domain language, and infrastructure), the touched workspace paths, and the active review depth (`surface`, `standard`, or `deep`).
It also passes the trust-boundary rule that protects input validation, containment, authentication, authorization, secret redaction, and untrusted-content checks from being flagged as unneeded defensive clutter.

The subagent returns candidate removals, simplifications, consolidations, and redesigns with exact workspace-relative paths and symbols or headings, plus a brief Kept as-is summary and any unassessed boundaries.
The parent selects each lane's reasoning effort when the dispatch tool supports that parameter. The frontmatter `max` fallback applies only on hosts that honor reasoning-effort frontmatter; VS Code's Local harness ignores that field and uses the effort chosen for the helper's model in the model picker.
The `rpi-refine` parent verifies each candidate at its cited file before assigning an `RF-xxx` ID or recording `FD-xxx` route decisions. `RPI Refiner` never edits files, runs validation, dispatches other agents, or speaks to the user.

## Example usage

A representative lens dispatch from `rpi-refine`:

```text
Lens: Conventions, SDKs, libraries, and language versions.
Inspect src/offline/outbox.ts, src/net/retry.ts, and package.json (standard depth).
Identify missed workspace helpers or SDKs, leftover scaffolding from earlier assumptions,
avoidable dependencies versus hand-rolled logic replaceable by existing modules, and
current-version language features or safe non-breaking upgrade opportunities. Preserve all
trust-boundary and input-validation checks.
```

`RPI Refiner` returns candidate findings for `outbox.ts` duplicating `retryWithBackoff` in `src/net/retry.ts` and a leftover `legacyQueueVersion` flag from an earlier draft, notes that `package.json` added no new runtime dependencies under Kept as-is, and stops once the assigned files are covered. The `rpi-refine` parent reads both files, confirms them, and records `RF-001` and `RF-002` in the canonical refinement record.
