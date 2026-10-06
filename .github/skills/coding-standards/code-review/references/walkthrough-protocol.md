---
title: Code Review Walkthrough Protocol
description: Orientation-first review walkthrough rules for the full-diff orientation floor and the dispatch board handoff.
ms.date: 2026-08-26
---

## Purpose

Use this protocol before any detailed dispatch. It creates a factual Register 1 walkthrough that explains what changed, how the change is wired, and where the highest-value review attention should go.

## Orientation floor

1. Map the Diff
   - Enumerate the changed files and the main logical areas touched.
   - Summarize the change by area rather than by line number.
   - Capture the user-visible intent and the implementation shape.

2. Map the Runway
   - Identify the major entry points, control flow, data flow, and call paths that the change affects.
   - Note the blast radius for shared modules, APIs, persistence boundaries, configuration surfaces, and auth or security checks.
   - Call out the most likely hotspots for deeper review.

3. Produce the walkthrough
   - Use factual, neutral prose.
   - Keep the tone descriptive and evidence-based.
   - Do not assign severity, verdicts, or recommendations in this register.

## Read contract

- Read the full diff range before dispatching any detailers.
- Prefer one full-range review over many narrow reads.
- When the diff crosses multiple areas, capture each area in the orientation summary rather than sampling only one path.

## Appendix outputs for dispatch

The walkthrough should end with a decision-ready dispatch appendix. Group files
into coherent review areas rather than producing one item per file. For each
area include:

* a concise area name,
* a factual preliminary signal that explains what changed, why it merits review,
  and any visible contract, regression, validation, or rollout boundary,
* openable changed-file or symbol references that support the signal,
* likely entry points and blast radius,
* candidate symbols or functions to inspect,
* and questions that merit a deeper dive.

The preliminary signal is orientation evidence, not a finding. It may identify a
specific mismatch or verification question visible in the supplied evidence, but
it does not assign severity, declare a defect proven, recommend a fix, or issue a
verdict.

## Register separation

- Register 1: factual narrative walkthrough and orientation summary.
- Register 2: structured findings produced by later detailers and merged back to the board.
