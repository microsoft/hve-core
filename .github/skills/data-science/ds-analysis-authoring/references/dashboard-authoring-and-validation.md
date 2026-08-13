---
title: Dashboard authoring and validation
description: Default component set, caching and interaction-state conventions, and functional, data, and responsiveness validation expectations for analytical dashboards
---

## Scope

These are HVE Core authoring and validation conventions for multi-page analytical dashboards built over an explored dataset. They describe composition and validation judgment. Application launch, browser navigation, element interaction, screenshot capture, and scripted browser automation are native tool capabilities and are not described here.

Column semantics belong to `ds-catalog`. Persistence and versioning belong to `ds-dataops`. Accessibility conformance criteria belong to the `accessibility` skill.

## Default component set

Unless the analysis question dictates otherwise, an exploratory dashboard covers these views. Detect which apply from the dataset's available types rather than rendering empty pages.

| View                          | Purpose                                                                 | Applies when                         |
|-------------------------------|-------------------------------------------------------------------------|--------------------------------------|
| Summary statistics            | Orient the reader with key measures and data-quality signals            | Always                               |
| Univariate analysis           | Inspect one variable's distribution with a selector                     | Always                               |
| Multivariate analysis         | Expose relationships through a correlation view with column filtering   | Two or more numeric variables        |
| Time series                   | Show trends and aggregation over a date range                           | A datetime field exists              |
| Text or embedding exploration | Explore high-dimensional text features through dimensionality reduction | Embedded or free-text features exist |

Keep each page focused on a single question, and modularize each view into a reusable function rather than repeating layout code.

## Caching and interaction state

Caching choice is the most common source of subtle dashboard defects, because the two cache kinds have different correctness properties.

* Cache serializable results, such as loaded frames and computed aggregates, with the data-caching decorator. These are copied per session, so mutation in one session does not leak into another.
* Cache non-serializable global resources, such as database connections and loaded models, with the resource-caching decorator. These are shared across sessions, so treat them as read-only and never store per-user state in them.
* Hold user selections in explicit session state so choices persist across page navigation. Without it, a selection silently resets when the user moves between pages and returns.
* Key cached functions on their real inputs. A cache keyed on too little will serve stale results after a filter change.

## Layout conventions

* Compose with columns, containers, and expanders rather than a single long scroll.
* Keep styling and labeling consistent across pages so a control means the same thing everywhere.
* Fail visibly when an expected input is missing, rather than rendering an empty chart that reads as a legitimate result.

## Validation expectations

Validate a dashboard across four categories. Report findings with reproduction steps and observed versus expected behavior.

| Category                 | What to exercise                                                                              |
|--------------------------|-----------------------------------------------------------------------------------------------|
| Navigation and rendering | Every page reachable; each view renders with data present                                     |
| Interaction              | Selectors, multi-selects, sliders, and date ranges update dependent views                     |
| Data integrity           | Displayed measures agree with the underlying dataset; boundary and missing-value cases behave |
| Responsiveness           | Load and interaction latency against the budgets below; behavior across viewport sizes        |

Derive expected values from the dataset under test or from its declared profile. Do not encode fixed row counts or value ranges from a sample dataset into a reusable validation pass; those assertions fail on every other dataset and hide real defects behind false ones.

## Responsiveness budgets

These are defaults for interactive exploratory dashboards. A project-stated budget supersedes them, and a heavier workload may justify a documented exception.

| Measure                 | Default budget                           |
|-------------------------|------------------------------------------|
| Initial page load       | Under roughly three seconds              |
| Interaction response    | Under roughly one second                 |
| Extended-session memory | Stable rather than growing without bound |

Record the observed measurement alongside the budget. A budget with no measurement is an assumption.

## Reporting

Summarize results by category with pass and fail counts, list findings with reproduction steps and severity, and state which budgets were met. Confirm the destination for any written report with the user rather than assuming one.
