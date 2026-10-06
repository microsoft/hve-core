---
title: accessibility
description: "Consolidated accessibility skill entrypoint for WCAG 2.2, ARIA Authoring Practices, cognitive accessibility, Section 508, EN 301 549, design intent verification, and the Accessibility Planner workflow."
sidebar_position: 1
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - accessibility
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                        |
|-------------|----------------------------------------------|
| Kind        | skill                                        |
| Source      | `.github/skills/accessibility/accessibility` |
| Invocation  | Loaded on demand by referencing agents       |
| Interactive | No                                           |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Consolidated accessibility skill entrypoint for WCAG 2.2, ARIA Authoring Practices, cognitive accessibility, Section 508, EN 301 549, design intent verification, and the Accessibility Planner workflow.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Accessibility Planner and reviewing workflows load this skill for framework
selection, standards mapping, evidence planning, scanning, and design-intent
verification. It is load-only, not a slash command. Choose planning when you need
to define scope and evidence; choose the scanner or runtime harness only when
authorized targets and their separate prerequisites are ready.

A static scan cannot settle keyboard behavior, announcement correctness, reflow,
or every semantic issue. The skill distinguishes methods that decide a criterion
from those that merely inform it. Harness completion and AT-stack calibration are
not conformance verdicts.

## Example usage

Ask Accessibility Planner to load `accessibility` for a sample checkout dialog.
Supply its states, keyboard expectations, intended announcements, and target
framework/level. Request an evidence plan before any browser or scanner execution.
Expect mappings for the relevant surface/state pairs, suitable verification
methods, and manual assistive-technology work where automation cannot decide.

After separately authorizing a local test target and prerequisites, a coverage
workflow can collect probe results and render a matrix, EARL output, and manual
test plans. Success means each claimed result has an adequate method and evidence;
inconclusive observations remain `cantTell`, not passes. An authored design-intent
record is read-only during verification, and missing checks stay visible.

Remote scanning needs explicit host authorization, which constrains only the
initial target, not every browser-derived request. Do not use confidential pages
or unapproved networks, reproduce restricted standards text, or substitute
automation for required qualified human review.
