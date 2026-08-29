---
name: experiment-design
description: "Experiment design reference for problem-class framing, Minimum Viable Experiment coaching, hypothesis formation, vetting and red flags, and experiment readiness. Use when translating a stated business outcome into candidate data-science problem classes, or when framing, vetting, scoping, or evaluating an experiment of any kind, including data feasibility, architecture, LLM, performance, use-case, UX, prototyping, and hardware experiments."
license: CC-BY-4.0
user-invocable: false
metadata:
  authors: "Microsoft (MVE coaching synthesis); Microsoft (Code With Engineering Playbook); Google LLC (machine-learning problem framing)"
  spec_version: "1.1"
  last_updated: "2026-08-21"
  content_based_on: "HVE Core original MVE coaching material; HVE Core original cross-paradigm routing; https://microsoft.github.io/code-with-engineering-playbook/design/design-reviews/recipes/engineering-feasibility-spikes/; https://microsoft.github.io/code-with-engineering-playbook/design/design-reviews/trade-studies/; https://developers.google.com/machine-learning/problem-framing/problem; https://developers.google.com/machine-learning/guides/rules-of-ml"
---

# Experiment Design Reference Pack

## Goal

Support experiment work end to end: turning unknowns into testable hypotheses, screening out work that is not a real experiment, and scoping it so the result is comparable and decision-ready.

Support the step that precedes it as well: translating a stated business outcome into candidate data-science problem classes with the reasoning that produced them, so a practitioner knows what kind of problem is on the table before deciding what to test.

The two concerns stay distinct. Problem-class framing exposes candidates and never selects one. Experiment work assumes a candidate direction already exists and concludes by selecting an experiment with the team.

This pack is general purpose. It applies to data feasibility, architecture, LLM, performance, use-case, UX, prototyping, and hardware experiments, not to data science alone.

## Inputs

* The problem statement, customer context, and business driver
* The stated business outcome, when the active concern is problem-class framing
* Known unknowns, assumptions, and risks
* The decision the experiment is meant to unblock
* Prior experiment results, when a sequence of experiments is in flight

## Reference index

Read only the reference that matches the active concern.

| Reference                                                     | Read this when                                                                                                                                                                             |
|---------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [problem-framing.md](references/problem-framing.md)           | Translating a stated business outcome into candidate data-science problem classes, applying per-paradigm entry tests, ordering discriminating questions, or recording assignable gaps      |
| [mve-coaching.md](references/mve-coaching.md)                 | Framing an MVE, forming or sharpening hypotheses, applying vetting criteria and red flags, designing the experiment, evaluating results, or producing session and backlog-bridge artifacts |
| [experiment-readiness.md](references/experiment-readiness.md) | Deciding which experiment to run at all: turning a risk landscape into candidates, prioritizing among competing unknowns, comparing options with evidence, or re-prioritizing mid-flight   |
| [provenance.md](references/provenance.md)                     | Confirming what is upstream guidance, what is HVE Core derivation or repository convention, and where upstream is silent                                                                   |

A confirmed problem-class framing request reads [problem-framing.md](references/problem-framing.md) only. Experiment requests read [mve-coaching.md](references/mve-coaching.md) or [experiment-readiness.md](references/experiment-readiness.md) by concern.

## Success criteria

* Problem-class framing returns the surviving candidate problem classes with the entry-test reasoning that kept or discarded each one, and never returns a selection, a ranking, or a confidence score.
* Every framing claim is visibly either a cited entry test or repository-original routing, and no claim implies that a universal external standard governs cross-paradigm routing.
* An unanswered framing question becomes a recorded gap with an answer holder and a coordinator, and the remaining analysis continues.
* Each hypothesis is testable, specific, falsifiable, and tied to a stated rationale.
* The experiment selected is the one whose result changes the most downstream work, chosen from a candidate list rather than from the first idea proposed.
* Work that is a demo, a mini-MVP, or an already-answered question is named as such rather than run as an experiment.
* Every input that could change the result is recorded precisely enough that another person could repeat the experiment and get a comparable answer. An identifier without a version is a label, not a reproducible reference.
* Experiment scope stays minimum-but-sufficient, and experiment code is treated as disposable.

## Constraints

* Reproduce only the minimum text necessary for a specific technical point, and paraphrase everything else. Attribute every reference and describe accurately what each reference reproduces.
* Label repository conventions as substitutions rather than upstream recommendations.
* Keep experiment framing separate from experiment infrastructure. This pack decides whether and how an experiment is worth running; it does not stand up tooling.
* Keep problem-class framing separate from experiment framing. Problem-class framing asks what kind of problem this is; experiment framing asks what to test about a direction already chosen. Do not apply experiment vetting criteria, red flags, or readiness prioritization to a confirmed problem-class framing request.
* Never rank, score, threshold, or recommend a candidate problem class. The practitioner is the subject-matter expert who chooses.

## Ownership boundaries

| Concern                                                                                                                              | Owner                                                                              |
|--------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------|
| Candidate problem classes for a stated business outcome, entry-test reasoning, discriminating questions, and assignable framing gaps | This pack, through [problem-framing.md](references/problem-framing.md)             |
| Whether a proposed outcome is achievable with available data and evidence                                                            | `feasibility`, the evidence-led feasibility study reference                        |
| MVE session directory, artifact filenames, placement, and tracking-file hygiene                                                      | `experiment-designer.instructions.md`, applied automatically to MVE tracking paths |
| Phase order, gates, session writes, and coaching flow                                                                                | The consuming experiment agent                                                     |
| ML environments, reproducibility, tracking, model evaluation, abstractions, and readiness                                            | `ml-experimentation`, the ML-specific experimentation reference                    |
| Pipeline mechanics, data tiering, replay, validation, and DS/MLOps test technique                                                    | `dataops`, the DataOps and testing reference                                       |
| Metric names, instruments, units, cardinality, and PII-safe telemetry                                                                | `telemetry-foundations`, the OpenTelemetry-aligned instrumentation skill           |
| Data sensitivity classification and DPIA thresholds                                                                                  | `privacy-standards`, the privacy classification reference                          |

## Stop rules

* For a confirmed problem-class framing request, an unstated business outcome is the sole stop before candidate analysis. [problem-framing.md](references/problem-framing.md) owns that stop and its job-specific exceptions. The experiment stop rules below govern experiment requests only.
* Stop and name the red flag when the request is a demo, a scaled-down product build, or a question already answered elsewhere. Then offer either the falsifiable hypothesis hiding underneath it or an explicit non-experiment path, rather than halting on the refusal.
* Stop and separate concerns when the request is production implementation rather than experiment design.
* Stop and state the gap when the request depends on guidance this pack does not provide, such as a universal framework, tool, or metric choice made without project context.

## Attribution

This pack declares `CC-BY-4.0`.

[mve-coaching.md](references/mve-coaching.md) is repository-original content under CC BY 4.0. It is not derived from any upstream source and cites no upstream URL.

[problem-framing.md](references/problem-framing.md) layers three source treatments. Its machine-learning entry tests are informed by Google for Developers machine-learning guidance, licensed CC BY 4.0; that material is paraphrased and reorganized, both upstream URLs are cited, and changes are stated. It points readers to the NEOS Guide for optimization problem types as a citation only, and states no NEOS classification of its own. Its cross-paradigm routing, the broader analytical-fit judgement, and the gap and output contract are repository-original.

[experiment-readiness.md](references/experiment-readiness.md) is HVE Core guidance informed by two Microsoft CSE Code With Engineering Playbook documentation pages, which are licensed CC BY 4.0. It paraphrases rather than reproduces, generalizes the upstream practices beyond engagement-shaped engineering work, cites both upstream URLs, and states that changes were made.

See [provenance.md](references/provenance.md) for the consolidated source map and derivation labels.
