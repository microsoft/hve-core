---
title: Code Review Walkthrough Protocol
description: Orientation-first review walkthrough rules for the full-diff orientation floor and the dispatch board handoff.
ms.date: 2026-06-20
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

The walkthrough should end with appendices that feed the dispatch board:

- changed areas,
- likely entry points,
- likely risk surfaces,
- candidate symbols or functions to inspect,
- questions that merit a deeper dive.

## Register separation

- Register 1: factual narrative walkthrough and orientation summary.
- Register 2: structured findings produced by later detailers and merged back to the board.
