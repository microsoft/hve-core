---
title: shared-work-handoff
description: "Prepare, resume, or close a minimized repository-backed work handoff with explicit acceptance and revision safety. Use for accountable continuation between teammates."
sidebar_position: 9
author: Microsoft
ms.date: 2026-08-28
ms.topic: reference
keywords:
  - skill
  - rpi
  - shared-work-handoff
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                              |
|-------------|----------------------------------------------------------------------------------------------------|
| Kind        | skill                                                                                              |
| Source      | `.github/skills/rpi/shared-work-handoff`                                                           |
| Invocation  | Invoked directly as `/shared-work-handoff`; model invocation is disabled, so agents do not load it |
| Interactive | No                                                                                                 |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Prepare, resume, or close a minimized repository-backed work handoff with explicit acceptance and revision safety. Use for accountable continuation between teammates.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `/shared-work-handoff` when a named teammate needs minimized continuation context in a checked-in repository file and must explicitly accept, reject, or request clarification on a verified revision. It is also suitable for recording an authorized final disposition after acceptance.

Use the ordinary RPI skills when one person continues work within private `.copilot-tracking` state. Update a canonical artifact directly when no cross-person continuation is needed. Do not use repository-backed handoffs for content that requires physical erasure.

## Example usage

```text
/shared-work-handoff prepare preview provider=repository-files target=.hve/handoffs/api-timeout.md
```

The skill checks the explicit source paths, audience, disclosure authority, retention constraints, and expected predecessor revision. It then previews the exact minimized record and the separate publication action. After that action is authorized and completed, run the same mode with `finalize` to verify the selected shared reference and return either a finalized receipt, `still-prepared`, or `conflict`.

See [Share Work for Another Contributor](../../../rpi/shared-work-handoff) for role assignment, source baseline semantics, consent boundaries, conflict handling, recipient responses, and terminal dispositions.
