---
title: Evaluation guide
description: One sectioned guide for the curation, metric selection, and tooling decisions that accompany an evaluation dataset
---

## Purpose

Copy this guide alongside the JSON and CSV dataset files. It records why the dataset looks the way it does, which a bare dataset cannot convey to the next reader or to a reviewer six months later.

Leave every review checkbox unchecked. A reviewer marks their own review; an agent never does.

## Evaluation guide

```markdown
# Evaluation Guide: {System Name}

## Curation Notes

### Business context

{The problem the system addresses and the outcomes it is meant to move}

### Scope

#### In scope

{Tasks the system handles}

#### Out of scope

{Explicit exclusions, and what the system should do when asked anyway}

### Grounding sources

{Sources relied on, and a frank assessment of their completeness and currency}

### Composition

| Category  | Count | Rationale        |
|-----------|-------|------------------|
| Easy      | {n}   | {why this share} |
| Grounding | {n}   | {why this share} |
| Hard      | {n}   | {why this share} |
| Negative  | {n}   | {why this share} |
| Safety    | {n}   | {why this share} |

{Note any deviation from the default balance and what drove it}

### Population coverage

One row for every confirmed user population, including any population whose count is zero.

| Population   | Pairs | Rationale                                 |
|--------------|-------|-------------------------------------------|
| {population} | {n}   | {why this population has this many pairs} |

A pair may serve several populations, so these counts overlap and do not sum to the dataset total. The category table above partitions the dataset; this one does not.

{Explain any population whose count is zero, and what it would take to cover it}

These counts describe the evaluation pairs that were designed. They do not establish how common a population is among real users, whether the coverage is statistically adequate, whether the system treats populations fairly, or whether the dataset satisfies a legal or policy obligation. Those are assessment decisions and belong to `rai-planner`.

### Open items

{Pairs marked for subject-matter review, and unresolved scope questions}

### Review

- [ ] Pairs reviewed for accuracy by a qualified reviewer
- [ ] Expected behaviors reconciled against authoritative sources
- [ ] Refusal and safety pairs reviewed

### Maintenance

{When to revisit: after material system changes, on a stated cadence, or on grounding-source updates}

## Metric Selection

### System properties

| Property                    | Value    | Consequence for measurement  |
|-----------------------------|----------|------------------------------|
| Draws on grounding sources  | {yes/no} | {what this makes measurable} |
| Calls tools or services     | {yes/no} | {what this makes measurable} |
| Elevated risk profile       | {yes/no} | {what this makes measurable} |
| Cost or latency constraints | {yes/no} | {what this makes measurable} |

### Risks and Detecting Metrics

This table records detection coverage, not risk assessment. Route severity, likelihood, classification, and approval to `rai-planner`. Keep a named risk visible as `unmeasured` when no detecting metric is available.

| Risk         | Source                      | Detecting metric         |
|--------------|-----------------------------|--------------------------|
| {named risk} | Confirmed interview summary | {metric or `unmeasured`} |

### Selected metrics

| Metric | Priority          | Why this system needs it | Acceptable bar                 |
|--------|-------------------|--------------------------|--------------------------------|
| {name} | {high/medium/low} | {rationale}              | {threshold or qualitative bar} |

### Not measured by tooling

{Dimensions the chosen tooling cannot produce, and how they will be checked instead}

### Currency

Evaluator names and availability confirmed against {source} on {date}.

## Tool Recommendations

### Team profile

* Development approach: {low-code / pro-code / mixed}
* Evaluation mode: {manual / batch / both}
* Cadence: {frequency}

### Recommendation

#### {Recommended option}

{Why it fits this team's approach, cadence, and metric plan}

### Prerequisites

{Credentials, deployed judge models, environment configuration, and access needed before the first run}

### What gates a release

{Which evaluation must pass before shipping, and which is advisory}

### Considered and not chosen

{Alternatives and the specific reason each was set aside}
```
