---
title: prompt-builder
description: Compatibility alias for legacy prompt-building requests. Routes creation and improvement to the hve-builder skill.
sidebar_position: 6
author: Microsoft
ms.date: 2026-09-11
ms.topic: reference
keywords:
  - skill
  - hve-core
  - prompt-builder
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                            |
|-------------|----------------------------------------------------------------------------------|
| Kind        | skill                                                                            |
| Source      | `.github/skills/hve-core/prompt-builder`                                         |
| Invocation  | Invoked directly as `/prompt-builder`, or loaded on demand by referencing agents |
| Interactive | No                                                                               |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Compatibility alias for legacy prompt-building requests. Routes creation and improvement to the hve-builder skill.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this compatibility alias when an existing workflow or request uses
`prompt-builder` to create or improve Copilot customization artifacts. It maps
`promptFiles` to HVE Builder targets and treats `files` as reference context, not
write targets. Missing approved targets route to create; existing targets route
to improve. Use HVE Builder directly for its full mode vocabulary.

Choose `prompt-analyze` for read-only review or `prompt-refactor` for cleanup that
must preserve behavior. A scoped explanation request authorizes neither source
improvement nor a review pass.

## Example usage

For an existing sample artifact, ask: `/prompt-builder
promptFiles=.github/prompts/sample/summarize.prompt.md
files=docs/sample-output-contract.md requirements=Improve missing-evidence handling
and make the expected citation format explicit. Only the prompt is writable.`
Replace these illustrative paths with actual files and supply observable acceptance
criteria.

The alias should pass the target, requirements, reference context, and boundary to
HVE Builder. Expect one shared lifecycle: capture existing behavior, author the
candidate, validate, run the review pass, and resolve the overall outcome from
the review verdict and validation result for the delivered revision.

Success means the approved artifact meets its requirements and the returned
verdicts identify evidence and limitations. The reference document remains
unchanged, and unavailable gates are not reported as passes. For a missing target,
approve its creation explicitly; do not let a legacy argument silently expand
the write boundary or start a second assessment loop.
