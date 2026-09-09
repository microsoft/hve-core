---
title: analysis-authoring
description: "Authoring conventions for exploratory data analysis notebooks and analytical dashboards, covering section sequence, visualization selection, scale thresholds, caching and state, and dashboard validation budgets. Use when composing or reviewing an EDA notebook, an analytical dashboard, or a dashboard test pass."
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-19
ms.topic: reference
keywords:
  - skill
  - data-science-engineering
  - analysis-authoring
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                        |
|-------------|--------------------------------------------------------------|
| Kind        | skill                                                        |
| Source      | `.github/skills/data-science-engineering/analysis-authoring` |
| Invocation  | Loaded on demand by referencing agents                       |
| Interactive | No                                                           |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Authoring conventions for exploratory data analysis notebooks and analytical dashboards, covering section sequence, visualization selection, scale thresholds, caching and state, and dashboard validation budgets. Use when composing or reviewing an EDA notebook, an analytical dashboard, or a dashboard test pass.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill when composing or reviewing an exploratory data analysis notebook, an analytical dashboard, or a dashboard validation pass. It supplies the editorial judgment that generic tooling does not carry: which sections belong and in what order, which figure answers which question, how to handle dense or high-cardinality data, and what responsiveness budgets to hold a dashboard to.

Reach for a different asset when the question is about column meaning or entity relationships, which `data-catalog` owns; about persistence format or dataset versioning, which `dataops` owns; about accessibility conformance criteria, which the `accessibility` skill owns; or about evaluating an AI system, which `evaluation-design` owns.

The Data Science and Engineering Coach loads this skill automatically when the user confirms the analysis job.

## Example usage

A user confirms the analysis job and asks for an exploratory notebook over a transactions dataset that includes a timestamp column and a high-cardinality merchant column.

Applying this skill, the notebook opens with the analysis question and a data-assets summary that references
the existing profile rather than restating it, moves through structure and quality checks into univariate
distributions, then into multivariate relationships.

Because a datetime field exists, the temporal section is included. Because the merchant column has high
cardinality, its distribution is shown as a top-N bar chart with the remainder grouped rather than as an
unreadable full-cardinality plot. The correlation matrix is fixed to a diverging scale from minus one to one
so weak relationships are not visually exaggerated.

Each figure is preceded by the question it answers and followed by an interpretation placeholder, and the
notebook closes with written limitations and next steps.
