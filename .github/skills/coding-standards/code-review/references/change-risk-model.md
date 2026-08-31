---
title: Change-Risk Evidence Checklist
description: Advisory evidence checklist for human-confirmed code-review depth selection.
ms.date: 2026-08-29
---

## Outcome

Use six evidence categories to make review-depth recommendations inspectable. The checklist informs a human choice; it does not calculate defect probability, produce an overall risk rating, or select a depth automatically.

## Evidence states

Record one evidence state and a concise evidence statement for every category. The state describes the evidence basis, not confidence in a claim:

* `observed`: Directly supported by the diff, repository, test results, coverage report, or version history
* `unavailable`: The required source is absent, inaccessible, or too shallow to support a claim
* `qualitative`: Interpretation-dependent evidence from available context rather than a reproducible measurement

Treat agent-generated qualitative evidence as proposed until a human confirms or corrects it. In a non-interactive workflow, keep generated evidence labeled as automation-derived. Do not infer evidence that is unavailable. Missing history or coverage does not increase risk by itself; it makes the recommendation incomplete.

## Checklist categories

### Change scope

Describe the size and diffusion of the change, including affected files, directories, subsystems, and whether the work is mechanical or behavior-changing. Use exact counts when the diff supports them. Do not use universal size thresholds.

### Path criticality

Identify security-sensitive, persistence, financial, parsing, shared-boundary, or other critical paths using the component context from [Severity Taxonomy](severity-taxonomy.md). Treat criticality as one input, not an overall change-risk label.

### History

Record available churn, hotspot, and co-change cues. State `unavailable` when repository history is shallow or inaccessible. Historical associations guide attention; they do not prove that a changed file is defective or that an unchanged sibling is missing.

### Test presence

Record whether relevant tests exist or changed and what behavior they exercise. Test presence is distinct from coverage and does not establish test effectiveness by itself.

### Coverage

Record available coverage for the changed behavior or state `unavailable`. Coverage is distinct from test presence and does not establish defect detection by itself.

### Rollback

Describe observed rollback evidence, such as feature flags or a documented reversal path, and hard-to-reverse behavior, such as schema migrations, persisted-data changes, or irreversible configuration.

## Depth recommendation

Recommend a verification depth from the checklist evidence:

* Recommend `basic` only when the available evidence consistently supports a narrow, reversible, well-tested change with no critical-path concern.
* Recommend `standard` for most changes and whenever evidence is incomplete, unavailable in a material category, or inconclusive.
* Recommend `comprehensive` when observed or qualitative evidence identifies critical paths, broad behavioral spread, weak detection for important logic, hard rollback, or material ambiguity.

Explain the recommendation without converting the categories into a numeric score or a Low, Medium, or High profile. Present the checklist and recommendation before asking the human to select `basic`, `standard`, or `comprehensive`. Persist the human-selected depth and a rationale that explains any difference from the recommendation.

## Interpretation safeguards

* Keep the checklist advisory and allow the human to correct every evidence statement.
* Evaluate the intent and combined change surface so mechanical splitting does not hide coupled work.
* Preserve useful batching that genuinely reduces blast radius.
* Do not add authorship or agent-capability modifiers without operational definitions and repository-local validation.

## Evidence basis

The checklist paraphrases empirical findings as attention cues rather than portable prediction rules:

* [Use of Relative Code Churn Measures to Predict System Defect Density](https://doi.org/10.1109/ICSE.2005.1553571)
* [Predicting Faults Using the Complexity of Code Changes](https://doi.org/10.1109/ICSE.2009.5070510)
* [A Large-Scale Empirical Study of Just-In-Time Quality Assurance](https://doi.org/10.1109/TSE.2012.70)
* [Mining Version Histories to Guide Software Changes](https://doi.org/10.1109/TSE.2005.72)
* [Coverage Is Not Strongly Correlated with Test Suite Effectiveness](https://doi.org/10.1145/2568225.2568271)
