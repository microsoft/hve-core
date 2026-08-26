---
title: Code Review Dispatch Loop
description: Human-steered review loop, dispatch board contract, and manifest-backed walk-back rules.
ms.date: 2026-08-26
---

## Purpose

The dispatch loop turns the walkthrough into a human-steered review experience. It keeps the review grounded in a single orientation pass while letting the human choose what to inspect next.

## Dispatch board contract

Present an enumerated dispatch board that lists review items with enough context to act on them immediately. Each board item should carry:

* `id`: a stable identifier for the item
* `area`: the review area or subsystem
* `status`: pending, in_progress, or complete
* `register`: the register that should own the next work
* `summary`: a short description suitable for human selection
* `preliminarySignal`: a factual, evidence-backed explanation of the contract,
  regression, validation, or rollout question that makes the area review-worthy
* `links`: openable changed-file or symbol references supporting the signal
* `selectableSymbols`: candidate symbols or functions worth inspecting

## Decision-ready confirmation surface

Do not reduce the board to area names alone. Present the initial board as a table
with `#`, `Area`, `Status`, and `Preliminary signal`; place the strongest
supporting file or symbol references in each signal. After the table, present one
`Confirm before dispatch` section containing:

* recommended perspectives, with the board item IDs each perspective owns and a
  concise scope-based rationale
* perspectives not recommended, with a concise reason when their omission may
  otherwise be surprising
* one recommended depth tier, with a rationale tied to change size, blast radius,
  hotspot classes, validation surface, or ambiguity
* one prompt that lets the human edit the board, perspective set, or depth, or
  approve the complete recommendation

Keep target and profile selection independent. The profile supplies the starting
perspective set; the confirmed change surface and specialist signals explain any
additions or omissions. Depth remains an independent rigor choice.

## Canonical manifest schema

Use a canonical `dispatch-manifest.json` file to track the loop state across the run.

```json
{
  "reviewTarget": {
    "kind": "pull_request",
    "provider": "github",
    "id": "123",
    "headSha": "0123456789abcdef"
  },
  "reviewProfile": "standard",
  "recommendedPerspectives": ["functional", "standards", "readiness"],
  "selectedPerspectives": ["functional", "standards", "readiness"],
  "recommendedDepth": "standard",
  "depthTier": "standard",
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
      "preliminarySignal": "The changed request path now crosses the shared authorization boundary.",
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
