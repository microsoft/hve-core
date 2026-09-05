---
title: experiment-design
description: "Experiment design reference for problem-class framing, Minimum Viable Experiment coaching, hypothesis formation, vetting and red flags, and experiment readiness. Use when translating a stated business outcome into candidate data-science problem classes, or when framing, vetting, scoping, or evaluating an experiment of any kind, including data feasibility, architecture, LLM, performance, use-case, UX, prototyping, and hardware experiments."
sidebar_position: 5
author: Microsoft
ms.date: 2026-08-28
ms.topic: reference
keywords:
  - skill
  - project-planning
  - experiment-design
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                               |
|-------------|-----------------------------------------------------|
| Kind        | skill                                               |
| Source      | `.github/skills/project-planning/experiment-design` |
| Invocation  | Loaded on demand by referencing agents              |
| Interactive | No                                                  |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Experiment design reference for problem-class framing, Minimum Viable Experiment coaching, hypothesis formation, vetting and red flags, and experiment readiness. Use when translating a stated business outcome into candidate data-science problem classes, or when framing, vetting, scoping, or evaluating an experiment of any kind, including data feasibility, architecture, LLM, performance, use-case, UX, prototyping, and hardware experiments.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Reach for this skill when work needs an experiment framed, vetted, or scoped:

* Shaping a Minimum Viable Experiment: choosing the experiment type, judging whether it is worth pursuing, and recognizing red flags that mean it is not.
* Turning a vague idea into a falsifiable hypothesis with a stated success threshold.
* Deciding which unknown to test first when several compete for the same limited time.
* Scoping an experiment to the minimum sufficient to answer its question, and evaluating the result against criteria set before the run.

The skill is general purpose. It ships in the data-science-engineering and experimental collections, but its coaching applies to any experiment: data feasibility, architecture, LLM, performance, use-case, UX, prototyping, and hardware work alike.

Choose a different asset when:

* The question is about ML experimentation setup, experiment tracking frameworks, model evaluation flow, or the ML fundamentals and model-production checklists. Use the `ml-experimentation` skill.
* The question is about data tiering, pipeline invariants, or data test suites. Use the `dataops` skill.
* The question is about MVE tracking-artifact naming or session-directory layout. That is governed by `experiment-designer.instructions.md`, which applies automatically under `.copilot-tracking/mve/`.
* You want an interactive coach rather than a reference. Use the `Experiment Designer` agent, which loads this skill.

## Example usage

Ask an agent that loads this skill to pressure-test an idea:

```text
We think adding a re-ranking step will improve retrieval quality.
Help me turn that into an MVE.
```

The skill supplies the hypothesis format, the vetting criteria used to decide whether the experiment earns its cost, and the red flags that mark an experiment as unfalsifiable or already answered. It then produces a hypothesis statement with an explicit success threshold. Handing the result to downstream planning is a separate, optional step: once an experiment plan is complete and you explicitly ask to move the work into a backlog, the skill supplies the backlog-brief template for that transition.
