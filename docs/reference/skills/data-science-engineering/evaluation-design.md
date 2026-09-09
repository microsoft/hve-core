---
title: evaluation-design
description: "Design evaluation datasets and supporting documentation for AI systems and agents, covering the scoping interview, difficulty distribution, dataset contract, sample review, and metric and tooling selection. Use when building or reviewing an evaluation set for a conversational agent, assistant, or retrieval-grounded AI system."
sidebar_position: 5
author: Microsoft
ms.date: 2026-08-19
ms.topic: reference
keywords:
  - skill
  - data-science-engineering
  - evaluation-design
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                       |
|-------------|-------------------------------------------------------------|
| Kind        | skill                                                       |
| Source      | `.github/skills/data-science-engineering/evaluation-design` |
| Invocation  | Loaded on demand by referencing agents                      |
| Interactive | No                                                          |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Design evaluation datasets and supporting documentation for AI systems and agents, covering the scoping interview, difficulty distribution, dataset contract, sample review, and metric and tooling selection. Use when building or reviewing an evaluation set for a conversational agent, assistant, or retrieval-grounded AI system.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill when building or reviewing an evaluation dataset for a system whose output is a response: a conversational agent, an assistant, or a retrieval-grounded application. It covers the scoping interview, the difficulty balance, the dataset contract, the sample review, and the metric and tooling selection that follow from what the system actually does.

Reach for `ml-experimentation` instead when the subject is a trained model's predictive performance, which is a different measurement problem. Route to `rai-planner` when the interview surfaces a risk that needs assessment rather than a test case.

The Data Science and Engineering Coach loads this skill automatically when the user confirms the evaluation job, which also places any durable write behind the workstream's sensitive-content scan gate.

## Example usage

A user confirms the evaluation job for a support assistant that answers from a product knowledge base, calls a ticket-lookup tool, and must refuse account changes.

Applying this skill, the session works through the interview one question at a time, establishing scope,
grounding sources and their quality, tool use, refusal requirements, and evaluation cadence, then presents a
summary for confirmation before generating anything.

Because the assistant has strict refusal requirements and touches account data, the default balance is
adjusted upward for the negative and safety categories while every category stays at or above five percent.

The generated dataset carries both machine-readable forms, with grounding pairs naming the source each answer
should rest on and refusal pairs asserting the specific action expected rather than merely that the system
declines. A representative sample spanning the categories is reviewed with the user before the full set is
finalized, and the accompanying evaluation guide records the composition rationale, the metric plan with its
acceptable bars, and the tooling recommendation with its prerequisites.
