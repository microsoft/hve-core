---
title: shared-work-handoff
description: Read or share bounded repository context and decision rationale with independent named-consumer continuation. Use for reusable context or accountable work handoffs.
sidebar_position: 8
author: Microsoft
ms.date: 2026-10-06
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
Read or share bounded repository context and decision rationale with independent named-consumer continuation. Use for reusable context or accountable work handoffs.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `/shared-work-handoff read` for bounded repository context and decision rationale without accepting work. Named consumers may independently accept, reject, or request clarification on a verified content revision; the canonical owner can record a disposition for one consumer without closing the publication or other consumers.

Use the ordinary RPI skills when one person continues work within private `.copilot-tracking` state. Update a canonical artifact directly when no cross-person continuation is needed. Do not use repository-backed handoffs for content that requires physical erasure.

## Example usage

```text
/shared-work-handoff read provider=repository-files target=.hve/handoffs/api-timeout.md shared-ref=main
/shared-work-handoff prepare preview provider=repository-files target=.hve/handoffs/api-timeout.md
```

Read mode has no stage or mutation and reports historical limitations. Preparation checks selected sources, actual repository-wide audience, authority, retention, and expected content/event/provider revisions before previewing a mutation. After separately approved publication, run the same mutation mode with `finalize`.

Response-only appends preserve other consumers; changed content requires fresh acceptance. Format `1` is experimental, and older unsupported records are historical-only without automatic migration.

See [Share Context and Continue Work](../../../rpi/shared-work-handoff) for roles, source baselines, historical policy, bounded backlinks, and the optional manual PR offer. Team labels are not access controls; every publication and tracker mutation retains its separate approval boundary.
