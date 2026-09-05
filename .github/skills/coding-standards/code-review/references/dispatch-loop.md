---
title: Code Review Dispatch Loop
description: Human-steered review loop, dispatch board contract, and manifest-backed walk-back rules.
ms.date: 2026-06-20
---

## Purpose

The dispatch loop turns the walkthrough into a human-steered review experience. It keeps the review grounded in a single orientation pass while letting the human choose what to inspect next.

## Dispatch board contract

Present an enumerated dispatch board that lists review items with enough context to act on them immediately. Each board item should carry:

- `id` — a stable identifier for the item,
- `area` — the review area or subsystem,
- `status` — pending, in_progress, or complete,
- `register` — the register that should own the next work,
- `summary` — a short description suitable for human selection,
- `links` — openable file or symbol references,
- `selectableSymbols` — candidate symbols or functions worth inspecting.

## Canonical manifest schema

Use a canonical `dispatch-manifest.json` file to track the loop state across the run.

```json
{
  "phaseGates": {
    "orientationConfirmed": true,
    "humanAccepted": false,
    "walkbackComplete": false,
    "emissionReady": false
  },
  "currentPhase": "orientation",
  "nextActions": [
    {
      "id": "bookmark-1",
      "kind": "bookmark",
      "target": "authentication",
      "reason": "High-risk entry point"
    }
  ],
  "boardItems": [
    {
      "id": "board-1",
      "area": "authentication",
      "status": "pending",
      "register": "register-2",
      "summary": "Review the auth change path",
      "links": ["src/auth.ts:42"],
      "selectableSymbols": ["authenticateUser"]
    }
  ]
}
```

## Three-phase protocol

1. Scrape orientation
   - Present the walkthrough and the initial dispatch board.
   - Pause for a human confirmation before deeper dispatch.

2. Curiosity bookmarking
   - Let the human bookmark or reject board items.
   - Record the selected targets in `nextActions` and the board.

3. Deep dives
   - Dispatch detailers, explainers, or a researcher wrapper depending on the request depth.
   - Merge the results back onto the board before the next iteration.

## Walk-back rules

After each deep dive:

- merge the structured findings back to the matching board item,
- update the item status and the manifest `nextActions`,
- preserve openable links and selectable symbols for follow-on inspection,
- keep the narration factual and the findings structured until the final merge.

## Traversal orientation

The human should be able to steer the loop by asking for more context, choosing a board item, or requesting a full sweep. For non-interactive runs, the review may fall back to a batch sweep of all board items.

## Register separation

- Register 1 remains the factual walkthrough and explanatory prose.
- Register 2 is the structured findings payload that detailers produce and that the walk-back phase merges into the board.
