---
title: Accessibility Coverage Matrix
description: How the accessibility coverage-matrix workflow builds, refreshes, reports, and probes a criterion-by-surface-by-method matrix for runtime and static evidence
sidebar_position: 3
sidebar_label: Coverage Matrix
keywords:
  - accessibility coverage matrix
  - runtime probes
  - accessibility evidence
  - coverage workflow
tags:
  - agents
  - accessibility
author: Microsoft
ms.date: 2026-07-08
ms.topic: concept
estimated_reading_time: 5
---

## Overview

The Accessibility Coverage Matrix workflow evaluates whether an accessibility assessment has enough evidence to call a criterion, surface, and method cell covered. It combines static evidence, prior reports, and runtime probe results into a single model that uses method adequacy rules instead of treating every passing check as equal.

## Execution Modes

The workflow supports four execution modes.

| Mode | Purpose | Typical use |
|------|---------|-------------|
| `build` | Create or expand the matrix from the current evidence set | Initial matrix creation |
| `refresh` | Recompute the matrix after new findings or updated inputs | Re-running after code or evidence changes |
| `report` | Render the current matrix state into the JSON and markdown artifacts | Sharing findings or preparing review |
| `probe` | Run the runtime harness for a specific probe against the current inventory | Investigating a gap or validating a candidate |

## Grid Model and Cell Lifecycle

The matrix is modeled as a criterion x surface x method grid.

* Criterion represents a framework-specific success criterion or control identifier.
* Surface represents a discrete UI surface such as a page, component, widget, global chrome, or content type.
* Method represents the evidence method, such as static-source, axe-auto, runtime-automation, manual-keyboard, cognitive-walkthrough, screen-reader, or another method name recorded by the engine.

Each cell moves through a lifecycle of not-started, blocked, partial, fail, pass, or not-applicable. The lifecycle changes when new evidence is ingested, when a human override is applied, or when the engine re-runs coverage after a probe or report refresh.

| Lifecycle state | Meaning |
|-----------------|---------|
| `not-started` | No evidence has been recorded for the cell yet |
| `blocked` | Evidence collection is prevented by a dependency or external constraint |
| `partial` | Some evidence exists, but it is incomplete or inconclusive |
| `fail` | The current evidence indicates a gap or a failing result |
| `pass` | A winning result has been recorded for the cell |
| `not-applicable` | The cell does not apply to the current surface and criterion |

## Method Adequacy Semantics

A cell is counted as covered only when the winning evidence method is allowed by the criterion's `adequateMethods` list or by the probe-criteria-map for that criterion. A pass from an inadequate method does not count as covered.

The engine computes adequate coverage by taking the number of applicable cells that are covered through an adequate method and dividing that total by the number of applicable cells in the scope, then expressing the result as a percentage. This is reported for each framework and for the overall matrix.

## Surface Inventory and Runtime Harness

The accessibility-surface-inventory subagent is the sole producer of `a11y-runtime.config.json`. It should inspect the codebase profile, infer the appropriate runtime discovery strategy, and emit a reviewable config that conforms to the schema at `.github/skills/accessibility/accessibility/scripts/runtime_a11y/config-schema.json`.

The runtime harness lives under `.github/skills/accessibility/accessibility/scripts/runtime_a11y/`. The workflow uses that package directory to run the matrix engine and to execute probes against the inventory that the config file describes.

## Output Artifacts

The workflow persists two runtime artifacts under `.copilot-tracking/accessibility/coverage/`.

* `coverage-matrix-{repo-slug}.json` stores the structured matrix model, coverage summaries, and cell-level evidence state.
* `coverage-matrix-{repo-slug}.md` renders the same state for review and handoff, including the canonical accessibility disclaimer and an unchecked human-review checkbox.

## Related Files

| File type | Location |
|-----------|----------|
| Prompt | [.github/prompts/accessibility/accessibility-coverage-matrix.prompt.md](../../../.github/prompts/accessibility/accessibility-coverage-matrix.prompt.md) |
| Subagent | [.github/agents/accessibility/subagents/accessibility-surface-inventory.agent.md](../../../.github/agents/accessibility/subagents/accessibility-surface-inventory.agent.md) |
| Skill | [.github/skills/accessibility/accessibility/SKILL.md](../../../.github/skills/accessibility/accessibility/SKILL.md) |
| Reviewer page | [Accessibility Reviewer](accessibility-reviewer) |
| Planner page | [Accessibility Planner](accessibility-planner) |
