---
title: Problem-class framing
description: Translating a stated business outcome into candidate data-science problem classes using cited entry tests, discriminating questions, and assignable gaps, without selecting a framing for the practitioner
---

## Sources

* Google for Developers, [Introduction to Machine Learning Problem Framing: Understand the problem](https://developers.google.com/machine-learning/problem-framing/problem), licensed CC BY 4.0.
* Google for Developers, [Rules of Machine Learning](https://developers.google.com/machine-learning/guides/rules-of-ml), licensed CC BY 4.0.

The machine-learning entry tests below are informed by those two pages and have been changed: they are paraphrased, reorganized into per-paradigm entry tests, restated in this repository's vocabulary, and placed inside a cross-paradigm procedure the upstream pages do not describe. `THIRD-PARTY-NOTICES` carries the attribution CC BY 4.0 requires.

The NEOS Guide is an authority a reader can consult for optimization problem types, including [Optimization Problem Types](https://neos-guide.org/guide/types/), [Linear Programming](https://neos-guide.org/guide/types/lp/), [Integer Programming](https://neos-guide.org/guide/types/integer/), and [Nonlinear Constrained Optimization](https://neos-guide.org/guide/types/nonlin/). Its terms reserve rights, so it is cited only. No NEOS text, taxonomy, classification, diagram, or derivative of them is reproduced or paraphrased here.

No external standard adjudicates across paradigms. Every cross-paradigm routing judgement, the broader analytical-fit disposition, the gap contract, and the output contract below are repository-original.

## Read this when

A practitioner has a business outcome and does not yet know what kind of data-science problem it is. This file produces the candidate problem classes and the reasoning behind them. It does not decide which one to pursue, estimate whether it is achievable, or design an experiment.

## Provenance labels

Carry these labels into the output so the practitioner can see what is grounded and what is judgement.

| Label | Meaning                                                               |
|-------|-----------------------------------------------------------------------|
| `[G]` | Grounded in a cited source named in this file                         |
| `[O]` | Repository-original routing judgement; no external source adjudicates |
| `[A]` | Assumed from the conversation and not verified against data           |

## The one stop before analysis

A stated business outcome is required before candidate analysis begins. It is the only stop this procedure applies before producing candidates.

1. Coach for it first. Lead with the decision or change the framing should enable, then follow up on who acts on it and what would be different if it worked.
2. If the outcome is stated, proceed to the procedure.
3. If it stays unstated, do not analyze candidates and do not treat defining it as an experiment. Complete the invocation with a single outcome-definition gap carrying an answer holder and a coordinator, and record explicitly that no candidate analysis was performed.

Experiment vetting criteria, experiment red flags, the unclear-problem-as-experiment fallback in [mve-coaching.md](mve-coaching.md), and readiness prioritization in [experiment-readiness.md](experiment-readiness.md) govern experiment requests. None of them applies to a confirmed problem-class framing request.

## Procedure

1. Restate the outcome for framing purposes and mark the restatement `[O]`. Name any ambiguity the restatement exposes; that ambiguity is usually the highest-power question in step 3.
2. Apply the entry test for every candidate problem class. Keep a class when its entry test passes or cannot yet be evaluated. Discard a class only when its entry test plainly fails, and record the failure reason rather than dropping it silently.
3. Order the unresolved questions by discriminating power: how many candidates the answer eliminates, not how easy it is to answer.
4. Work the questions in that order. Ask the practitioner for each value before recording it as unknown.
5. When elicitation does not produce a value, mark it unknown, record the gap, and continue with the remaining questions. An unanswered question never terminates the run.
6. Produce the output contract. Present the surviving candidates, the entry-test reasoning for each, the discriminating questions with their current state, the gap list, and any terminal disposition.

## Candidate problem classes and entry tests

| Candidate class           | Entry test                                                                                                                                       | Label |
|---------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|-------|
| Supervised classification | A categorical outcome is labelled for past cases, and the features exist at the moment the prediction must be made                               | `[G]` |
| Supervised regression     | The same conditions hold with a continuous target rather than a categorical one                                                                  | `[G]` |
| Time-to-event analysis    | The outcome is when something happens rather than whether it happened, and some observations are still in progress rather than negative          | `[O]` |
| Forecasting               | The target is time ordered, past behavior is a plausible basis for extrapolation, and the forecast itself does not materially change the outcome | `[O]` |
| Causal inference          | The question is what happens if an input is set to a value, not what has historically co-occurred with that value                                | `[O]` |
| Constrained optimization  | The task is choosing decision variables against a stated objective under stated constraints, rather than estimating an unknown quantity          | `[O]` |
| Reinforcement learning    | An agent acts repeatedly in an environment, observes a reward, and has enough interaction volume for a policy to be learned                      | `[O]` |
| Generative modelling      | The required output is new content conditioned on context, and quality is judged against an evaluation rubric rather than a labelled target      | `[O]` |
| Not a modelling problem   | The population is too small to support inference, or the value lies in shared understanding rather than a fitted model                           | `[O]` |

### Machine learning versus a non-machine-learning approach

Before committing to any modelling class, compare the machine-learning approach against a non-machine-learning baseline on the value it adds, its cost and ongoing maintenance, and the resources it requires. A predictive machine-learning framing additionally requires data that carries usable predictive signal and a prediction someone can act on. Starting with a heuristic and moving to machine learning only once that heuristic becomes hard to maintain is a defensible path `[G]`.

This test decides machine learning versus not machine learning. It does not decide whether the problem is a data problem at all. Statistics, optimization, and decision analysis are outside its scope, and no cited source adjudicates them; the broader analytical-fit judgement is `[O]` and must be presented as such.

### Optimization structure

When a constrained-optimization framing survives, its mathematical structure narrows the work further. This procedure does not classify that structure. Record the structural question as a discriminating question with its own gap `[O]`, and point the practitioner to the NEOS Guide pages cited above.

## Gaps

Every unanswered question becomes a gap. A gap is a coordinator handoff, not a practitioner to-do list.

| Field          | Content                                                                     |
|----------------|-----------------------------------------------------------------------------|
| Needed fact    | The specific value or definition required                                   |
| Why it matters | Which candidates the answer keeps or eliminates                             |
| Answer holder  | The person or role who holds the fact, or `unassigned` when none is known   |
| Coordinator    | The person who will obtain it, often not the answer holder, or `unassigned` |
| Status         | `unknown` until a value is supplied                                         |

Record `unassigned` rather than a guess whenever an answer holder or a coordinator is not known, and name the unassigned ownership in the completion evidence. An unowned gap is a finding, not an omission, and it does not prevent the invocation from completing.

## Output contract

A completed framing invocation returns:

* The restated outcome, labelled `[O]`.
* The surviving candidate classes, each with its entry test, its provenance label, and its current status.
* Discarded classes with the entry-test failure that removed them.
* The discriminating questions in power order, with current answers or `unknown`.
* The gap table.
* Any terminal disposition, such as a non-machine-learning `[G]` or a not-a-modelling-problem `[O]` result.

An invocation stopped for an unstated business outcome returns the outcome-definition gap and an explicit statement that no candidate analysis was performed.

## What this procedure never does

* It never selects, ranks, scores, or confidence-thresholds a candidate. The practitioner is the subject-matter expert and makes that call.
* It never estimates feasibility. `feasibility` owns whether a proposed outcome is achievable with the available data and evidence.
* It never designs or scopes an experiment. That begins after a framing direction is chosen.
* It never invents a missing fact. Unknowns are labelled and assigned.
* It never presents an original routing judgement as though a standard supports it.
