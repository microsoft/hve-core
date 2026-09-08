---
title: rpi-implement
description: "Execute an approved RPI plan, maintain current planning state, and record implementation evidence. Use when implementation is ready to begin or resume."
sidebar_position: 2
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - skill
  - rpi
  - rpi-implement
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                           |
|-------------|---------------------------------------------------------------------------------|
| Kind        | skill                                                                           |
| Source      | `.github/skills/rpi/rpi-implement`                                              |
| Invocation  | Invoked directly as `/rpi-implement`, or loaded on demand by referencing agents |
| Interactive | No                                                                              |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Execute an approved RPI plan, maintain current planning state, and record implementation evidence. Use when implementation is ready to begin or resume.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `rpi-implement` to execute an approved plan. Declare the scope as the full plan, one `Pxx` phase, or one `Pxx-Txx` task; the skill starts at the first unchecked dependency-ready item in that scope and works in plan order. It records evidence under descriptive headings in `.copilot-tracking/changes/`, checks each `Pxx-Txx` marker as soon as its `Requirements:` hold, and runs the checks the task names plus whatever the changed behavior warrants.

Implementation also keeps the plan current. It may clarify task wording or references, add a `Guidance:` block to a later task when earlier work created something that task needs, record out-of-scope work under `## Follow-Up Items`, and pause only affected dependent work when a discovery requires a new user decision. The original critique is not repeated.

Reach for a different asset when:

* No approved plan exists. Run [rpi-plan](rpi-plan) first; do not implement from research alone.
* The implementation is finished and needs acceptance. Run [rpi-review](rpi-review).
* The change is small and isolated. Edit directly instead of creating lifecycle artifacts.

## Example usage

Run one bounded task:

```text
/rpi-implement plan=.copilot-tracking/plans/2026-09-04/blob-storage-plan.md task=P01-T01
```

The skill sends one `RPI Implement` opening with the scope, write boundary, and planned validation, then reports material results as they land. A bounded closeout confirms only its scope:

```text
* Implementation execution: Complete for P01-T01
* Completed markers: P01-T01; remaining active-plan markers: P01-T02, P02-T01, P03-T01
* Validation: `npm run test:py -- tests/storage` passed
* Plan updates: added `Guidance:` to P02-T01 pointing at `BlobStorageClient.upload_stream`
* Review readiness: not ready; P01-T02 and later phases remain

| Artifact                                                                                                                     | Description    |
|------------------------------------------------------------------------------------------------------------------------------|----------------|
| [.copilot-tracking/changes/2026-09-04/blob-storage-changes.md](.copilot-tracking/changes/2026-09-04/blob-storage-changes.md) | Changes record |

## Next Steps

Run `/rpi-implement plan=... task=P01-T02`, or omit `task` to complete the rest of the plan.
```

A later invocation can implement accepted `RV-xxx` findings from a review as ordinary work; no second review is required.
