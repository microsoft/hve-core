---
description: 'Convergence rpi-research contract for evidence-backed experiment recommendations and Experiment Designer dispositions'
---

# Experiment Recommendation Research

## Purpose

Use `rpi-research` to compare candidate experiments and recommend one cohesive Minimum Viable Experiment (MVE) when material design decisions depend on prior art or current external facts. Research can propose and connect hypotheses, methods, thresholds, controls, scope, resources, enablement, and analysis. Experiment Designer and the user accept, revise, reject, or defer each material field.

Research cannot validate a hypothesis, produce an experiment result, replace a feasibility study, authorize data or resources, commit business thresholds or partner participation, or reduce work the team agreed to perform jointly.

## Activation Boundary

Activate one convergence Research cycle after Phase 1 establishes a clear problem, decision purpose, unknowns, constraints, and evidence criteria, and one of these gaps could materially change hypothesis formation, vetting, or design:

* Whether an existing solution or prior attempt already answers the proposed question.
* Whether a current platform, API, standard, hardware, policy, or compatibility constraint changes the experiment boundary.
* Whether an authoritative source establishes a baseline or counterexample the team must account for.
* Which experiment class, method, threshold range, control, minimum scope, resource set, enablement approach, or result-analysis method best fits the decision.

Adequate supplied evidence skips Research. Do not activate Research to replace stakeholder discovery, data access, technical feasibility, experiment execution, or result evaluation.

## Research Brief

Provide the experiment decision purpose, participants and intended use, explicit questions and evidence criteria, source and date scope, non-goals, licensing, privacy, Responsible AI, cost, and schedule constraints, and the current `context.md` assumptions, unknowns, risks, prior attempts, and relevant artifacts. Use `convergence` mode and pass the experiment session directory as the trusted alternate Research evidence root.

Complete wider, deeper, and contrarian waves across candidate experiment classes, hypotheses, methods, threshold ranges, controls, scope, resources, enablement approaches, and result-analysis methods. Tie every researched item to a named experiment-design decision or uncertainty rather than producing a generic literature review.

When isolation materially improves evidence quality or protects the active context, `rpi-research` may dispatch `RPI Researcher` once per bounded lane, such as prior experiments, benchmark ranges, current platform constraints, accepted analysis methods, or Responsible AI and privacy sources. Helper returns remain unverified suggestions until the active Research phase reads each cited source. Only the primary Research artifact assigns canonical evidence IDs and owns findings or recommendations.

## Recommendation Contract

Recommend one MVE design only when the evidence supports convergence. Preserve viable alternatives and evidence-based rejection rationale. Label every recommended field with evidence IDs, confidence, and unresolved assumptions.

| MVE plan field                 | Research contribution                                                                                        | Final owner                                                                    |
|--------------------------------|--------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------|
| Hypothesis                     | Propose evidence-backed hypotheses from unknowns, prior attempts, counterexamples, and decision needs        | Experiment Designer and user accept, revise, prioritize, or reject             |
| Experiment method              | Compare methods and recommend one against the hypothesis, constraints, and evidence criteria                 | Experiment Designer and user accept or revise                                  |
| Success and failure thresholds | Recommend ranges from baselines, benchmarks, regulatory minima, and prior performance                        | User and decision owner commit thresholds, coached by Experiment Designer      |
| Scope and exclusions           | Recommend minimum sufficient scope from dependencies, confounders, costs, and schedule facts                 | Experiment Designer and user commit scope                                      |
| Required data and resources    | Recommend requirements from availability, prerequisites, licensing, external costs, and platform constraints | User and owning team commit resources; feasibility owns technical viability    |
| Enablement requirements        | Recommend prerequisite knowledge, pairing patterns, and measurable enablement criteria                       | User and partner team commit ownership progression                             |
| Result-analysis method         | Compare analytical methods, metrics, assumptions, and standards and recommend one                            | Experiment Designer selects with a domain expert or statistician when required |

## Return and Reconciliation

Read the completed primary Research artifact before changing experiment context. Preserve alternatives, rejection rationale, the selected recommendation, confidence, unresolved assumptions, and a decision-to-evidence map. For each investigated assumption, record one result in `context.md`:

* `supported`: current evidence supports retaining the assumption as a hypothesis input.
* `contradicted`: evidence weakens or invalidates the assumption; revise or retire the affected hypothesis candidate.
* `inconclusive`: evidence does not settle the assumption; keep it explicit for experiment validation.

Preserve the primary Research artifact path and evidence IDs. For every material recommended field, record `accepted`, `revised`, `rejected`, or `deferred` and the Experiment Designer or user rationale in the owning experiment artifact. Research findings remain preparation evidence. They never set a hypothesis verdict, count as an experiment run, satisfy success criteria, or prove partner-team enablement.

When Research returns `Blocked` or `Needs clarification`, record the smallest unresolved gap and stop only the dependent hypothesis or design decision. If `rpi-research` or a required lookup capability is unavailable, do not substitute training-data claims.

Re-enter Research only when a new current-fact gap or a user revision invalidates a material part of the recommendation. Use a new task slug and a complete revised brief rather than an ad hoc lookup. Research completes before `mve-plan.md` is approved.

## Ownership Boundaries

* The consuming Experiment Designer owns phase order, session writes, user decisions, and transitions.
* `experiment-design` owns hypotheses, vetting, experiment selection, minimum scope, and result interpretation.
* `feasibility` owns whether available data and technical evidence support the proposed outcome.
* `ml-experimentation` owns ML environments, reproducibility, tracking, and production readiness.
* The partner team still performs collaborative validation from the agreed starting point. Prior Research improves preparation, not scope reduction.