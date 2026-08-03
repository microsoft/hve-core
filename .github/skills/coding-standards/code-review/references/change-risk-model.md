---
title: Change-Risk Model
description: Signal taxonomy and scoring rubric for deterministic, evidence-based change-risk profiling.
ms.date: 2026-07-29
---

## The Change-Risk Profile

The model produces an advisory **Change-Risk Profile**: a vector of named, evidenced signals, never a single opaque score. To build the profile, evaluate each signal below as High, Medium, or Low based on git history, then combine them into a named-signal profile citing the specific evidence (e.g., "High Diffusion: 12 files across 4 subsystems"). The profile informs the human-scoping step, drives depth-tier selection, and ranks hotspot candidates using deterministic, git-computable signals.


## Risk factors

Evaluate every change across four distinct factors. All signals are computable deterministically using `git log` and `git diff`.

### Likelihood
How likely the change introduces a defect. Measure using:

* `Size` — lines added or modified.
* `Diffusion` — number of files, directories, and subsystems touched.
* `Entropy` — scatter of the change across the codebase.
* `Hotspot Overlap` — intersection with trailing 90-day high-churn or high-complexity files.
* `Missed Co-change` — touching one file of a historically coupled cluster while missing its siblings.

### Severity
The blast radius if the change fails. Measure using:

* `Path Criticality` — classification of touched paths per [Severity Taxonomy](severity-taxonomy.md).
* *Note: Dependency fan-in and call-graph analysis are deferred to v2 to maintain language-agnostic determinism.*

### Detectability
Whether a defect would be caught before impact. Measure using:

* `Test Presence` — test files included in the diff.
* `Coverage` — touched-file test coverage (where CI data is available).

### Recoverability
How quickly the change can be backed out. Measure using:

* `Reversibility Markers` — presence of feature flags.
* `Hard-to-Rollback` — schema migrations, database changes, or irreversible config changes versus standard code.

## Agentic-era modifiers

Agent-authored code requires specific adjustments to classic risk models. Apply the following modifiers to the profile:

* `Provenance-Aware Weighting` — detect agent authorship (e.g., `Co-authored-by:` trailers). Neutralize traditional "author experience" signals, as agents have perfect recall of immediate context but zero memory of historical design intent.
* `Comprehension Ratio` — evaluate the semantic weight of the delta. A 4,000-line mechanical rename scores lower on Likelihood than 40 lines changing core retry semantics.
* `Amplification Ratio` — compare the RPI plan artefact delta to the actual code delta. Flag high-risk mismatches where a small plan produces an enormous code delta, or a large plan produces a suspiciously small diff.

## Cold starts and confidence

The model relies on git history. For repositories with shallow history, signal confidence degrades.

* If trailing 90-day history is insufficient to calculate Hotspot Overlap or Missed Co-change, explicitly state: *"Confidence: Low (shallow history). Relying on Size and Diffusion signals."*
* Widen confidence intervals and default to standard depth tiers unless Size or Diffusion signals are extreme. Never artificially inflate a risk rating due to missing data.

## Gaming and Goodhart's Law

Agents aware of the scoring model may attempt to game it (e.g., pathologically splitting changes to lower Diffusion scores).

* The profile is advisory input to a human-confirmed scoping step, not a gate.
* Batch-splitting that genuinely reduces per-change blast radius is acceptable engineering behavior.
* The human-scoping protocol evaluates the *intent* of the change, serving as the ultimate safeguard against metric manipulation.
