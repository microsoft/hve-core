---
title: Data Workstream Lifecycle Classes
description: Discriminated lifecycle semantics for episodic, bounded, and continuous jobs in a persistent coaching session
---

# Data Workstream Lifecycle Classes

## Purpose

Classify every registered job as exactly one of `episodic`, `bounded`, or
`continuous`. The class determines valid state fields, outgoing disposition,
resume behavior, and completion behavior. Job completion never ends the
coaching session automatically.

## Class contract

| Class        | Termination                                       | Valid state                                            | Resume behavior                                                                  |
|--------------|---------------------------------------------------|--------------------------------------------------------|----------------------------------------------------------------------------------|
| `episodic`   | One invocation ends after Frame, Execute, Confirm | `status`, `invocations`, artifact and summary pointers | List prior invocations; run again only after a new explicit request              |
| `bounded`    | Ends at its recommendation or terminal gate       | `status`, `phase`, `phase_gates`, artifact pointer     | Restore phase and gates; completed work stays terminal unless explicitly revised |
| `continuous` | Does not terminate during the project             | `status`, artifact pointer, `last_enriched_at`         | Read the durable artifact and restore it as active background context            |

## Episodic jobs

Use this sequence for each invocation:

1. Frame: confirm the target, relevant catalog context, and expected output.
2. Execute: route to the owning skill or specialist and perform the confirmed
   work.
3. Confirm: summarize the output and connections, append an invocation and
   artifact record, and mark that invocation complete.

An episodic invocation may be abandoned before a durable output exists. Record
the outgoing disposition as `discarded-cleanly`. A completed invocation remains
in history and is not repeated on resume. A later explicit request creates a new
invocation rather than reopening the old one.

## Bounded jobs

Allowed statuses are `never`, `active`, `paused`, and `complete`.

* Starting sets `active` and records the initial phase and gates.
* Leaving before the terminal recommendation records the current phase and gate
  states, then sets `paused`.
* Resuming restores the recorded phase and gates before any new question.
* Reaching the terminal recommendation sets `complete`, persists the terminal
  state, and offers choices without advancing to another job.
* A completed job is not re-entered during a later resume. Revision requires an
  explicit user request and a recorded rationale.

## Continuous jobs

Allowed statuses are `never` and `active`.

* Starting creates or adopts the durable artifact and sets `active`.
* Enrichment events update the artifact and `last_enriched_at` after the
  durable-write gate succeeds.
* Leaving the foreground flushes confirmed pending enrichment before recording
  `flushed` as the outgoing disposition.
* Resume reads the artifact itself to restore current catalog context.

## Session completion boundary

The session is unbounded. An episodic invocation or bounded job can complete
inside it, while continuous work remains available. After completion:

1. Name what completed and its durable outputs.
2. Persist terminal or invocation state.
3. List paused bounded work and active continuous work.
4. Offer user-selected next actions, including close, without auto-selecting
   another job.

## Invalid states

* An episodic block with `phase` or `phase_gates`
* A continuous block with `phase`, `phase_gates`, or `complete`
* A bounded block marked `paused` without a resumable phase
* A completed bounded job silently reset to `active`
* Any class change without an explicit user-confirmed correction and log entry

## Provenance

This lifecycle model is repository-original guidance licensed under CC BY 4.0.
It does not reproduce or summarize an external standard.
