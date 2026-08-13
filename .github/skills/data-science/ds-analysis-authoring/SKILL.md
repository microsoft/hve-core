---
name: ds-analysis-authoring
description: "Authoring conventions for exploratory data analysis notebooks and analytical dashboards, covering section sequence, visualization selection, scale thresholds, caching and state, and dashboard validation budgets. Use when composing or reviewing an EDA notebook, an analytical dashboard, or a dashboard test pass."
license: CC-BY-4.0
user-invocable: false
metadata:
  authors: "Microsoft (planning synthesis)"
  spec_version: "1.0"
  last_updated: "2026-08-05"
---

# Analysis Authoring Conventions

## Goal

Produce exploratory notebooks and analytical dashboards whose structure, visualization choices, and scale handling are deliberate rather than incidental. This skill supplies the editorial judgment that generic file, notebook, terminal, and browser tooling does not carry.

## Flow

1. Confirm the analysis question, the datasets in scope, and the deliverable shape: notebook, dashboard, or both.
2. Read the available profile and objectives artifacts rather than re-deriving column semantics. `ds-catalog` owns the profile contract and semantic roles.
3. Select the deliverable's section sequence from the matching reference, including only the conditional sections the data supports.
4. Choose each visualization from its analytical goal, applying the scale thresholds rather than plotting whole datasets by default.
5. Record interpretation next to each figure so a reader learns what the figure answers, not only what it shows.
6. Validate the deliverable against its completeness expectations, and for dashboards apply the responsiveness budgets as project-adjustable defaults.

## Inputs

* The analysis question and intended audience
* Dataset locations and, when available, an existing data profile and declared objectives
* The deliverable shape and its destination
* Any project-specific performance budget that overrides the defaults here

## Success criteria

* The deliverable follows the section sequence for its shape, and conditional sections appear only when the data supports them.
* Every figure is preceded by the question it answers and is followed by an interpretation placeholder or an actual reading.
* Visualization selection matches the analytical goal, and dense or high-cardinality data is sampled, binned, or truncated deliberately.
* Every meaningful distinction is encoded in a channel besides colour, and categorical and continuous scales use colourblind-safe palettes.
* Notebook code stays modular, with repeated transformation logic extracted rather than duplicated across cells.
* Dashboard caching distinguishes serializable data from global resources, and cross-page interaction state is explicit.
* Dashboard validation reports functional, data, and responsiveness findings against stated budgets.
* Uncertainty, data limitations, and open questions are written down rather than implied.

## Constraints

* Describe judgment, not tool mechanics. Notebook creation, cell execution, output inspection, browser navigation, and screenshots are native tool capabilities and are not narrated here.
* Reference profile and objectives artifacts instead of copying their contents into the deliverable.
* Keep persistence format and dataset versioning with `ds-dataops`, which owns pipeline invariants and storage conventions.
* Keep entity semantics, relationships, and semantic roles with `ds-catalog`.
* Treat the performance budgets as defaults. A project-stated budget supersedes them.
* Do not embed environment-specific absolute paths in a deliverable.

## Ownership boundaries

| Concern                                                                   | Owner                  |
|---------------------------------------------------------------------------|------------------------|
| Column semantics, semantic roles, profile and objectives contracts        | `ds-catalog`           |
| Persistence format, dataset versioning, pipeline and validation placement | `ds-dataops`           |
| Accessibility conformance criteria and assistive-technology review        | `accessibility`        |
| Evaluation dataset design for AI systems                                  | `ds-evaluation-design` |
| Trained-model evaluation, tracking, and readiness                         | `ml-experimentation`   |

## Stop rules

* Stop and ask when the analysis question is unstated, because section selection and visualization choice both depend on it.
* Stop and record a limitation rather than inventing an explanation for a pattern the data does not support.
* Stop and route to `ds-catalog` when column meaning, grain, or relationships are ambiguous.
* Stop and route accessibility conformance work to the `accessibility` skill rather than restating criteria here.

## Package resources

| Resource                                                                                  | Use                                                                   |
|-------------------------------------------------------------------------------------------|-----------------------------------------------------------------------|
| [eda-notebook-authoring.md](references/eda-notebook-authoring.md)                         | Read when composing or reviewing an exploratory notebook              |
| [dashboard-authoring-and-validation.md](references/dashboard-authoring-and-validation.md) | Read when composing, reviewing, or validating an analytical dashboard |

## Attribution

This package is repository-original content licensed CC BY 4.0. The section sequences, selection thresholds, completeness expectations, and default budgets are HVE Core conventions rather than reproductions of an upstream specification.
