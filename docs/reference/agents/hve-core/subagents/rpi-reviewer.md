---
title: RPI Reviewer
description: "Reviews one bounded, context-heavy portion of RPI evidence assigned by the review parent and returns findings with evidence locations, why each matters, and suggested severity and route as suggestions for the calling agent to verify. Use during review when isolating a large comparison would help."
sidebar_position: 3
author: Microsoft
ms.date: 2026-09-11
ms.topic: reference
keywords:
  - agent
  - hve-core
  - rpi-reviewer
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                    |
|-------------|--------------------------------------------------------------------------|
| Kind        | agent                                                                    |
| Source      | `.github/agents/hve-core/subagents/rpi-reviewer.agent.md`                |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly) |
| Interactive | No                                                                       |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Reviews one bounded, context-heavy portion of RPI evidence assigned by the review parent and returns findings with evidence locations, why each matters, and suggested severity and route as suggestions for the calling agent to verify. Use during review when isolating a large comparison would help.
<!-- END AUTO-GENERATED: overview -->

## When to use it

`RPI Reviewer` is an optional helper that [rpi-review](../../../skills/rpi/rpi-review) may use, not a required step and not something a user selects. The review parent compares the evidence and writes the record itself.

It hands this helper one bounded, context-heavy portion of the comparison when reading it all in the parent's context would crowd out the review, for example checking every `Requirements:` block against a large changes record or tracing one requirement through source and validation output.

The assignment is in the parent's own words with the evidence paths to read and the acceptance basis to compare against. It does not need an `RV-xxx` ID or a `Pxx` or `Pxx-Txx` boundary. The helper returns candidate findings with expected behavior, observed evidence and location, why each may matter, and suggested severity and route, plus what it found consistent and what it could not assess.

Every candidate is a suggestion. The review parent reads the cited evidence, goes deeper on anything that needs it, records an `RV-xxx` finding only when it confirms the candidate, and decides execution status, outcome, and every route in `## Parent Decision Record`. The helper writes no file, runs no validation, and never speaks to the user.

## Example usage

A representative assignment from an `rpi-review` run:

```text
Compare the Requirements: blocks in .copilot-tracking/plans/2026-09-11/example-plan.md
phases P02 and P03 against the completion and validation evidence in
.copilot-tracking/changes/2026-09-11/example-changes.md. Report any requirement
without matching evidence and any validation recorded as skipped. Read only those
two files.
```

The helper returns, for example, two candidate findings: a P03 requirement whose changes entry cites a test that the validation section records as skipped, and a P02 requirement with no changes entry at all. The parent reads both locations, confirms the first as a defect routed to `rpi-implement`, and finds the second was completed under a renamed task, so it records that one as consistent instead.
