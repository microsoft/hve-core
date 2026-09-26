---
title: rpi-implement
description: "Execute an authorized, evidence-ready RPI plan, maintain current task and closure evidence, and record completed work. Use to begin or resume implementation."
sidebar_position: 2
author: Microsoft
ms.date: 2026-09-25
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
Execute an authorized, evidence-ready RPI plan, maintain current task and closure evidence, and record completed work. Use to begin or resume implementation.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `rpi-implement` to work through an approved plan. Declare the scope as the full plan, one `Pxx` phase, or one `Pxx-Txx` task; the skill starts at the first unchecked dependency-ready item in that scope and works in plan order. It checks each `Pxx-Txx` marker as soon as its `Requirements:` hold, runs the checks the plan names, and keeps a condensed changes log in `.copilot-tracking/changes/` that describes the behavior or functionality each completed item changed rather than the edits made.

Implementation also keeps the plan current. Checked task markers, implementation-only
`Guidance:` pointers and out-of-scope `## Follow-Up Items` do not change the assessed-content
hash, so normal progress can resume. Changes to task wording, references, requirements,
architecture, capability, safety, dependencies or other assessed content return to the planning
owner for current identity and parent closure before affected work resumes. Ordinary supported
corrections need no routine second critique; missing or materially changed coverage needs an actual
assessment. An unresolved significant choice needs user direction, not a generic approval prompt.

Before changing source, the implementer runs the [rpi-plan hashing helper](rpi-plan#verify-a-plans-assessed-content-hash)
against the saved plan and compares its version, exact projection and SHA-256 with the covering
assessment and parent-closure evidence. Missing tooling, failed computation or unverifiable
identity returns to planning without a hand-built projection or another critique from implementation.

An approved plan has evidence-backed readiness and authorization for the declared scope. A direct
Implementation request or authorized automatic progression needs no second plan approval.
Agent self-checks and historical Revise verdicts with resolved findings are not human-signature
gates. Genuine human attestations and explicit phase boundaries still apply to their named actions.

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
