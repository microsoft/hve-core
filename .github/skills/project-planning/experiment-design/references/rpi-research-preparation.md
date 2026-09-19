---
description: 'Bounded rpi-research preparation contract for prior art, existing solutions, current constraints, and already-answered experiment questions'
---

# Experiment Research Preparation

## Purpose

Use `rpi-research` to prepare an experiment when a material unknown depends on prior art or current external facts. Research can sharpen, weaken, retire, or leave an assumption unresolved. It cannot validate a hypothesis, produce an experiment result, replace a feasibility study, or reduce work that the team committed to perform jointly.

## Activation Boundary

Activate Research after problem and context discovery when one of these gaps could materially change hypothesis formation or vetting:

* Whether an existing solution or prior attempt already answers the proposed question.
* Whether a current platform, API, standard, hardware, policy, or compatibility constraint changes the experiment boundary.
* Whether an authoritative source establishes a baseline or counterexample the team must account for.

Adequate supplied evidence skips Research. Do not activate Research to replace stakeholder discovery, data access, technical feasibility, experiment execution, or result evaluation.

## Research Brief

Provide the experiment decision purpose, participants and intended use, explicit questions and evidence criteria, source and date scope, non-goals, licensing and schedule constraints, and the current `context.md` assumptions, unknowns, risks, prior attempts, and relevant artifacts. Use `analysis` or `comparison` mode and the default Research evidence root.

## Return and Reconciliation

Read the completed primary Research artifact before changing experiment context. For each investigated assumption, record one result in `context.md`:

* `supported`: current evidence supports retaining the assumption as a hypothesis input.
* `contradicted`: evidence weakens or invalidates the assumption; revise or retire the affected hypothesis candidate.
* `inconclusive`: evidence does not settle the assumption; keep it explicit for experiment validation.

Preserve the primary Research artifact path and evidence IDs. Research findings remain preparation evidence. They never set a hypothesis verdict, count as an experiment run, satisfy success criteria, or prove partner-team enablement.

When Research returns `Blocked` or `Needs clarification`, record the smallest unresolved gap and stop only the dependent hypothesis or design decision. If `rpi-research` or a required lookup capability is unavailable, do not substitute training-data claims.

## Ownership Boundaries

* The consuming Experiment Designer owns phase order, session writes, user decisions, and transitions.
* `experiment-design` owns hypotheses, vetting, experiment selection, minimum scope, and result interpretation.
* `feasibility` owns whether available data and technical evidence support the proposed outcome.
* `ml-experimentation` owns ML environments, reproducibility, tracking, and production readiness.
* The partner team still performs collaborative validation from the agreed starting point. Prior Research improves preparation, not scope reduction.

## License

This reference is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).