---
title: workstream-handoff
description: "Hand off a changed interface, schedule or assumption to the affected workstream. Preview and, with approval, post the context on its GitHub issue."
sidebar_position: 10
author: Microsoft
ms.date: 2026-11-22
ms.topic: reference
keywords:
  - skill
  - rpi
  - workstream-handoff
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                |
|-------------|--------------------------------------------------------------------------------------|
| Kind        | skill                                                                                |
| Source      | `.github/skills/rpi/workstream-handoff`                                              |
| Invocation  | Invoked directly as `/workstream-handoff`, or loaded on demand by referencing agents |
| Interactive | No                                                                                   |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Hand off a changed interface, schedule or assumption to the affected workstream. Preview and, with approval, post the context on its GitHub issue.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill when a change makes another workstream's next step different: a job now produces an output its consumer used to build, a rollout date moved, or an approval blocks deployed tests but not local ones. Use [RPI](rpi) for ordinary task follow-up.

Start in the authorized target workspace. Identify the producer's RPI task, what changed, and the local plans or snapshots it may read. Discovery stays local. For delivery, the skill uses the **existing issue that tracks the colleague's affected task**, even if your change was discussed on a different issue. If it cannot tell which issue that is, it asks for the receiver's issue link rather than guessing or opening a new issue.

## Example usage

```text
/workstream-handoff producer=release change="The release job now writes the receipt" scope="release and publisher plans" receiver-issue=<publisher task issue URL>
```

If the publisher's plan still calls for a second writer, the preview on your side might read: "The release job now writes the receipt. Consume it instead of generating a second copy. You can test the reader locally; keep publication off until the release owner approves it."

RPI shows you the **publisher task's issue** and the full comment. Approve that revision for that issue and, once the backlog workflow's required review gates are satisfied, RPI posts one comment and returns its link or ID. Decline, or run without an authorized GitHub writer, and the text stays in your local draft. Posting does not assign work, edit the publisher's plan or mark the handoff accepted.

Run the check again when either side changes. RPI does not repeat an already-posted comment. A correction needs fresh approval; an uncertain delivery is checked before any retry. If the publisher already adapted, the skill retires the old advice.
