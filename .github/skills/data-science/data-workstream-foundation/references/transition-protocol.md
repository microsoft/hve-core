---
title: Data Workstream Transition Protocol
description: User-confirmed job transition, outgoing disposition, state mutation, and routing rules for Data Workstream Coach sessions
---

# Data Workstream Transition Protocol

## Purpose

Use this protocol whenever an explicit request, topic shift, or job completion
suggests a different job. A transition changes the foreground job, not the
project or coaching-session identity.

## Transition sequence

1. Detect the signal and identify the current and proposed jobs from the job
   registry.
2. State the applicable transition rule: the current job's lifecycle class
   determines what must happen before leaving it.
3. Name the source job, destination job, expected carryover, and proposed
   outgoing disposition.
4. Ask for explicit confirmation. Continue the current job if the user declines
   or has not answered.
5. Resolve the outgoing job by class:
   * `episodic`: finish Confirm and use `completed`, or abandon without a
     durable partial output and use `discarded-cleanly`.
   * `bounded`: persist phase and gates and use `paused`, unless its terminal
     recommendation was reached and persisted as `complete`.
   * `continuous`: pass the durable-write gate for pending enrichment, persist
     it, and use `flushed`. If the gate blocks, keep the enrichment pending and
     report that the transition cannot complete yet.
6. Append one `job_log` entry containing timestamp, `from_job`, `to_job`,
   rationale, source class, outgoing disposition, and carryover artifacts.
7. Update `current` using the session-state mutation rules.
8. Load the destination's primary skill or confirmed specialist route.
9. Announce the switch, what carried over, and the destination's next coaching
   step before asking a destination-specific question.

## Outgoing dispositions

| Source class | Allowed disposition              |
|--------------|----------------------------------|
| `episodic`   | `completed`, `discarded-cleanly` |
| `bounded`    | `paused`, `complete`             |
| `continuous` | `flushed`                        |

Do not use a generic `switched` value. The class-specific disposition is the
evidence that resumable or terminal work was handled correctly.

## Pause, detour, and return

For a bounded-job detour, persist the source phase and gates before starting the
episodic destination. On destination completion, offer to resume the paused job
at its recorded phase. Do not resume automatically. If the user chooses another
job, record another confirmed transition.

## Completion transitions

Completion is not permission to auto-advance. Persist completion first, then
offer options such as closing, resuming paused work, enriching continuous work,
or selecting another job. A later resume announces completed work but does not
re-enter it.

## Provenance

This transition protocol is repository-original guidance licensed under
CC BY 4.0. It does not reproduce or summarize an external standard.
