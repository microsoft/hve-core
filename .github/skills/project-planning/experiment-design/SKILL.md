---
name: experiment-design
description: "Experiment design reference for Minimum Viable Experiment coaching, hypothesis formation, vetting and red flags, and experiment readiness. Use when framing, vetting, scoping, or evaluating an experiment of any kind, including data feasibility, architecture, LLM, performance, use-case, UX, prototyping, and hardware experiments."
license: CC-BY-4.0
user-invocable: false
metadata:
  authors: "Microsoft (MVE coaching synthesis); Microsoft (Code With Engineering Playbook)"
  spec_version: "1.0"
  last_updated: "2026-08-03"
  content_based_on: "HVE Core original MVE coaching material; https://microsoft.github.io/code-with-engineering-playbook/design/design-reviews/recipes/engineering-feasibility-spikes/; https://microsoft.github.io/code-with-engineering-playbook/design/design-reviews/trade-studies/"
---

# Experiment Design Reference Pack

## Goal

Support experiment work end to end: turning unknowns into testable hypotheses, screening out work that is not a real experiment, and scoping it so the result is comparable and decision-ready.

This pack is general purpose. It applies to data feasibility, architecture, LLM, performance, use-case, UX, prototyping, and hardware experiments, not to data science alone.

## Inputs

* The problem statement, customer context, and business driver
* Known unknowns, assumptions, and risks
* The decision the experiment is meant to unblock
* Prior experiment results, when a sequence of experiments is in flight

## Reference index

Read only the reference that matches the active concern.

| Reference                                                     | Read this when                                                                                                                                                                             |
|---------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [mve-coaching.md](references/mve-coaching.md)                 | Framing an MVE, forming or sharpening hypotheses, applying vetting criteria and red flags, designing the experiment, evaluating results, or producing session and backlog-bridge artifacts |
| [experiment-readiness.md](references/experiment-readiness.md) | Deciding which experiment to run at all: turning a risk landscape into candidates, prioritizing among competing unknowns, comparing options with evidence, or re-prioritizing mid-flight   |
| [provenance.md](references/provenance.md)                     | Confirming what is upstream guidance, what is HVE Core derivation or repository convention, and where upstream is silent                                                                   |

## Success criteria

* Each hypothesis is testable, specific, falsifiable, and tied to a stated rationale.
* The experiment selected is the one whose result changes the most downstream work, chosen from a candidate list rather than from the first idea proposed.
* Work that is a demo, a mini-MVP, or an already-answered question is named as such rather than run as an experiment.
* Every input that could change the result is recorded precisely enough that another person could repeat the experiment and get a comparable answer. An identifier without a version is a label, not a reproducible reference.
* Experiment scope stays minimum-but-sufficient, and experiment code is treated as disposable.

## Constraints

* Reproduce only the minimum text necessary for a specific technical point, and paraphrase everything else. Attribute every reference and describe accurately what each reference reproduces.
* Label repository conventions as substitutions rather than upstream recommendations.
* Keep experiment framing separate from experiment infrastructure. This pack decides whether and how an experiment is worth running; it does not stand up tooling.

## Ownership boundaries

| Concern                                                                                   | Owner                                                                              |
|-------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------|
| MVE session directory, artifact filenames, placement, and tracking-file hygiene           | `experiment-designer.instructions.md`, applied automatically to MVE tracking paths |
| Phase order, gates, session writes, and coaching flow                                     | The consuming experiment agent                                                     |
| ML environments, reproducibility, tracking, model evaluation, abstractions, and readiness | `ml-experimentation`, the ML-specific experimentation reference                    |
| Pipeline mechanics, data tiering, replay, validation, and DS/MLOps test technique         | `ds-dataops`, the DataOps and testing reference                                    |
| Metric names, instruments, units, cardinality, and PII-safe telemetry                     | `telemetry-foundations`, the OpenTelemetry-aligned instrumentation skill           |
| Data sensitivity classification and DPIA thresholds                                       | `privacy-standards`, the privacy classification reference                          |

## Stop rules

* Stop and name the red flag when the request is a demo, a scaled-down product build, or a question already answered elsewhere. Then offer either the falsifiable hypothesis hiding underneath it or an explicit non-experiment path, rather than halting on the refusal.
* Stop and separate concerns when the request is production implementation rather than experiment design.
* Stop and state the gap when the request depends on guidance this pack does not provide, such as a universal framework, tool, or metric choice made without project context.

## Attribution

This pack declares `CC-BY-4.0`.

[mve-coaching.md](references/mve-coaching.md) is repository-original content under CC BY 4.0. It is not derived from any upstream source and cites no upstream URL.

[experiment-readiness.md](references/experiment-readiness.md) is HVE Core guidance informed by two Microsoft CSE Code With Engineering Playbook documentation pages, which are licensed CC BY 4.0. It paraphrases rather than reproduces, generalizes the upstream practices beyond engagement-shaped engineering work, cites both upstream URLs, and states that changes were made.

See [provenance.md](references/provenance.md) for the consolidated source map and derivation labels.
