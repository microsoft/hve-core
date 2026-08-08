---
title: "DS/DE Agent Consolidation: Implementation Guide"
description: Superseded implementation guide for the Data Workstream Coach consolidation
sidebar_position: 9
author: Microsoft
ms.date: 2026-08-03
ms.topic: reference
---

> [!WARNING]
> **Superseded.** This document describes a six-phase planner with three skills and `backlog-templates` registration. All three were replaced in later design rounds.
>
> Use [the work framing](./00-work-framing.md) as the entry point. See [the skill architecture](./05-skill-architecture.md) for the current skill cut and agent shape.
>
> Retained for the standards extracts in sections 4 through 7, which remain accurate.

**Project:** ds-agent-consolidation
**Date:** 2026-08-01
**Status:** Superseded
**Origin:** Design Thinking session, Methods 1-5 (see sibling artifacts in this directory)

> [!CAUTION]
> **Disclaimer:** This agent is an assistive coaching tool only. It does not conduct user research, observe stakeholders, or speak for the people whose problems you are designing for, and it does not replace primary research, direct stakeholder contact, design review, or product and strategy decision authority.
> Personas, problem statements, journey maps, empathy maps, concept tests, and other Design Thinking artifacts produced with this tool are scaffolding for your own research and synthesis, not substitutes for real stakeholder voice or observed behavior.
> Validate all AI-generated assumptions, personas, themes, and insights against actual stakeholders before treating any Design Thinking artifact as a basis for product, design, or strategy commitments. Outputs from this tool do not constitute validated research findings or design approval.

* [ ] Reviewed and validated by a qualified human reviewer

---

## 1. Problem and Scope

**Confirmed problem statement:**

> Data scientists using HVE Core face a cluttered, overlapping toolset that doesn't clearly differentiate from what Copilot already does natively, and it also doesn't help them produce the structured engagement artifacts a CSE engagement requires.

**Primary user:** the data scientist, who in practice owns the full DS engagement path regardless of what the org chart says, and whose role spans data engineering as well as data science.

**Scope boundary:** project handoff and runbook assembly are out of scope. A separate effort is designing a handoff agent that will consume these artifacts. The governing constraint here is narrower and decidable per artifact: anything requiring permanence is git-tracked in the repository.

---

## 2. Architecture Decisions

| ID | Decision                                                             | Rationale                                                                                                                                        |
|----|----------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| D1 | One agent with deep skill hooks, not a subagent family               | `dt-coach` is an existence proof: nine methods, three skill packages, ~30 references, persistent state, non-linear transitions, all in one agent |
| D2 | Three skills, not four                                               | Tier semantics, validation placement, and malformed routing are one coherent model; splitting fragments it                                       |
| D3 | Two customer-facing deliverables, git-tracked                        | Catalog and feasibility study are shared with the customer and must be Word-convertible                                                          |
| D4 | Feasibility study is the durable record                              | It accrues across SDLC phases; state loss is recoverable by reading it                                                                           |
| D5 | Orchestration is one-way handoff                                     | Hand off, or continue building the document. No bidirectional contract to design                                                                 |
| D6 | Catalog adopts `privacy-standards` citation-field vocabulary         | Cataloging and privacy classification are the same act; do not invent sensitivity levels                                                         |
| D7 | `experiment-designer` stays general-purpose, joins the collection    | Hypothesis formation is valuable to DS but not uniquely a DS concern                                                                             |
| D8 | Data model decisions route to ADR                                    | The playbook's own decision log includes a data model entry under `Architecture/Data-Model/`                                                     |
| D9 | Skills produce working code and assertions, never planning documents | Keeps the artifact budget honest                                                                                                                 |

---

## 3. Artifact Budget

Modeled on the RAI planner's progressive-disclosure pattern, which reduced twelve documents to four. Security runs on two.

| Artifact                          | Location                                     | Tracked    | Audience                          |
|-----------------------------------|----------------------------------------------|------------|-----------------------------------|
| `data-catalog.md`                 | `docs/`                                      | Git        | Customer-shared                   |
| `feasibility-study.md`            | `docs/`                                      | Git        | Customer-shared                   |
| `state.json`                      | `.copilot-tracking/ds-plans/{project-slug}/` | Gitignored | Internal                          |
| `{ado,github}-backlog-handoff.md` | `.copilot-tracking/ds-plans/{project-slug}/` | Gitignored | Internal, deferred to final phase |

Notebooks, pipelines, tests, transformation packages, and ERDs are **working outputs in the customer repository**. The agent does not shadow them with tracking documents.

### Execution model caveat

The skills generate code and assertions; they do **not** execute against customer data sources, transformation engines, or telemetry backends. Documentation must state this plainly. An earlier draft claimed assertions "run"; that claim was withdrawn under adversarial review.

---

## 4. The Feasibility Study as Progressive Container

The CSE feasibility study has twelve sections that subsume most artifacts previously treated as peers. Phases append sections; no per-phase files.

| Section                                | Populated during |
|----------------------------------------|------------------|
| Problem Definition and Desired Outcome | Phase 1          |
| Deep Contextual Understanding          | Phase 1          |
| Data Access                            | Phase 2          |
| Data Discovery                         | Phase 2          |
| Architecture Discovery                 | Phase 2          |
| Concept Ideation and Iteration         | Phase 3          |
| Exploratory Data Analysis              | Phase 3          |
| Data Pre-Processing                    | Phase 3          |
| Hypothesis Testing                     | Phase 4          |
| Concept Testing                        | Phase 4          |
| Risk Assessment                        | Phase 5          |
| Responsible AI                         | Phase 5          |

**Experiment enumeration** lives in Hypothesis Testing. The agent coaches thesis formation conversationally, in the manner of `dt-coach`, and results, including abandoned approaches and why, aggregate into that section. No separate artifact.

**Output of the study** is a recommendation on next steps: either documented gaps preventing a positive outcome with possible re-scoping, or recommendations and technical assets for moving to operationalization.

---

## 5. Skill Specifications

### 5.1 `ds-dataops`

**Grounded in:** `design/design-patterns/data-heavy-design-guidance/` (MIT)

**Owns:** tiering, validation placement, idempotency, malformed routing, lineage, transformation patterns.

#### Bronze / Silver / Gold as a state machine

Tier is a required enumerated field on every catalog entry: `bronze | silver | gold | malformed | sandbox`.

| Tier        | Definition                                                   | Agent behavior it unlocks                                                  |
|-------------|--------------------------------------------------------------|----------------------------------------------------------------------------|
| `bronze`    | Raw landing, immutable, append-only, optimized for ingestion | Refuse validation placement here; refuse in-place transformation           |
| `silver`    | Cleansed, conforms to known schema and predefined invariants | Require schema conformance and declared invariants before marking complete |
| `gold`      | Read-optimized, standard fact and dimension tables           | Expect fact/dimension shape; flag a renamed silver table                   |
| `malformed` | Records failing validation, retained for diagnosis           | Auto-register as a monitored signal                                        |
| `sandbox`   | Intermediate working data                                    | No downstream guarantees                                                   |

#### Validation placement as refusal-with-alternative

Validation assertions belong at the **Bronze-to-Silver boundary**. If the user requests validation before Bronze landing, the skill explains why Bronze must remain a faithful source copy (replay for testing validation logic, replay for recovery from transformation bugs) and offers the correct placement.

Same shape as the DPIA hard gate in `privacy-planner`.

#### Other encoded invariants

* Pipelines must be re-playable and idempotent so corruption is recoverable by fix-and-replay.
* Transformation code separates from data access code so unit tests can target transformation logic.
* Everything needed to build the pipeline from scratch belongs in source control: IaC, database objects, reference data, pipeline definitions, validation and transformation logic.
* Sensitive configuration lives in a central secure store per environment.

#### Notebook-to-package migration trigger

The playbook expects transformation code to move out of notebooks into packages. Encode as a detectable trigger, not a lecture.

**Trigger:** transformation logic in a notebook cell executed more than once, copied across cells, or exceeding a length threshold.

**Offer:** extract to a package function with a matching test stub using `ds-testing` patterns.

This is observable in the workspace.

### 5.2 `ds-testing`

**Grounded in:** `ml-and-ai-projects/testing-data-science-and-mlops-code/` (MIT)

Highest-confidence, lowest-invention skill. The playbook supplies pattern, example, and scope boundary for five categories.

```text
ds-testing/
  SKILL.md
  references/
    00-index.md
    01-saving-loading.md
    02-transforming.md
    03-model-load-predict.md
    04-data-validation.md
    05-model-testing.md
```

| Reference               | Content                                                                                                                                                     |
|-------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `01-saving-loading`     | Test the logic in the load function, not the library. Mock `isfile` and `read_csv`; no repository fixture files, so tests behave identically on any machine |
| `02-transforming`       | Fixed input to fixed output, one verification per test. `pytest.fixture` for shared sample data, `pytest.mark.parametrize` for input matrices               |
| `03-model-load-predict` | Mock model load and prediction as with file access. `pytest.mark.longrunning` separates smoke and integration tests from the unit loop                      |
| `04-data-validation`    | Test cases for no data supplied, unexpected format, nulls, outliers                                                                                         |
| `05-model-testing`      | Adversarial and boundary robustness; verify accuracy for under-represented classes                                                                          |

**Scope guard to state prominently:** ML unit tests check **code quality, not accuracy or performance**. Does the model accept correctly shaped inputs and produce correctly shaped outputs? Do weights update when `fit` runs? These are closer to narrow integration tests and intentionally do not mock every outside call. The stated benefit is preventing a misconfigured model from burning hours in training.

### 5.3 `ds-drift`

**Grounded in:** `ml-and-ai-projects/ml-model-checklist/`, `design/design-patterns/data-heavy-design-guidance/` (MIT), governed by `telemetry-foundations`.

#### Critical distinction the playbook draws

**Data validation** detects errors (a datum outside its expected range). **Data drift detection** uncovers legitimate changes truly representative of the modeled phenomenon (user preferences shift).

> Validation issues trigger re-routing and rectification. Drift triggers adaptation or retraining.

These are different mechanisms with different responses. The skill must not conflate them.

#### Proposed metric names

Conforming to the existing `<domain>.<entity>.<measure>` pattern in `telemetry-foundations`. No invented conventions.

| Metric                              | Instrument | Unit | Signal                                      |
|-------------------------------------|------------|------|---------------------------------------------|
| `data.validation.records.malformed` | counter    | `1`  | Records failing Bronze-to-Silver validation |
| `data.validation.duration`          | histogram  | `s`  | Validation stage cost                       |
| `data.pipeline.replay.count`        | counter    | `1`  | Idempotency exercise frequency              |
| `model.inference.duration`          | histogram  | `s`  | Serving latency                             |
| `data.feature.distribution.shift`   | gauge      | `1`  | Distribution drift score                    |

#### Cardinality discipline

Drift monitoring is dense with tempting dimensions: per-column, per-feature, per-source, per-tier. `telemetry-foundations` warns that every attribute multiplies time-series count.

**Hard rule:** bounded dimensions only (`source`, `tier`, `validation_rule`). Never per-record or per-feature-value.

#### Ownership seam

| Concern                                             | Owner                            | `ds-drift` relationship                            |
|-----------------------------------------------------|----------------------------------|----------------------------------------------------|
| Metric naming, instruments, UCUM units, cardinality | `telemetry-foundations`          | Conforms; contributes `data.*` and `model.*` names |
| PII in emitted telemetry                            | `telemetry-foundations` denylist | Obeys; cannot emit denylisted fields as dimensions |
| PII in source data, classification, DPIA            | `privacy-standards`              | Reads classification; never classifies             |
| Which signals matter, threshold meaning             | `ds-drift`                       | Owns                                               |

**Governing rule:** `ds-drift` never decides what is sensitive. It reads a classification produced elsewhere and applies emission constraints accordingly.

---

## 6. Model Experimentation Conventions

**Grounded in:** `ml-and-ai-projects/model-experimentation/` (MIT)

The playbook names five practice areas. These inform agent behavior rather than becoming a separate skill.

| Area                                | Expected outcome                                                                                                                                                                                                                  |
|-------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Virtual environments                | Documentation of environment creation and dependency install; config files committed (`requirements.txt`, `environment.yml`, or `pyproject.toml`). HVE Core convention is `uv`; align with `uv-projects.instructions.md`          |
| Folder and source control structure | Agreed folder structure pushed to the repo; `.gitignore` determining what syncs; a decision on how notebooks are stored and versioned. CookieCutter Data Science named as a reference structure                                   |
| Experiment tracking                 | Choose a framework, ensure access for all users, document local setup, define datasets and evaluation so experiments are comparable, track dataset names and versions, parameters, code, and environment for full reproducibility |
| Datasets and model abstractions     | Building blocks have defined APIs so they can be replaced or extended without breaking the experimentation flow; mock building blocks for unit tests; APIs shared with engineering                                                |
| Model evaluation                    | Evaluation logic approved by stakeholders; relationship to business KPIs analyzed; evaluation flow applicable to all present and future models; evaluation code unit-tested and reviewed; flow facilitates error analysis         |

**Note:** `nbstripout` is named for stripping notebook output before versioning. Relevant to the notebook-versioning decision the agent should prompt for.

---

## 7. ML Model Production Checklist

**Grounded in:** `ml-and-ai-projects/ml-model-checklist/` (MIT)

Eleven items, tracked as state and surfaced as a feasibility study section.

1. Is there a well-defined baseline, and does the model beat it?
2. Are ML performance metrics defined for both training and scoring?
3. Is the model benchmarked, with a documented and reproducible train/test split?
4. Can ground truth be obtained or inferred in production?
5. Has the data distribution of training, testing, and validation sets been analyzed?
6. Have goals and hard limits for performance, prediction speed, and cost been established?
7. How will the model integrate into other systems, and what impact will it have?
8. How will incoming data quality be monitored?
9. How will drift in data characteristics be monitored?
10. How will performance be monitored?
11. Have ethical concerns been taken into account?

Item 11 routes to `rai-planner`. Items 8-10 route to `ds-drift`.

---

## 8. Asset Disposition

### Absorb into the unified agent

| Asset                      | Path                            |
|----------------------------|---------------------------------|
| `gen-data-spec`            | `.github/agents/data-science/`  |
| `gen-jupyter-notebook`     | `.github/agents/data-science/`  |
| `gen-streamlit-dashboard`  | `.github/agents/data-science/`  |
| `test-streamlit-dashboard` | `.github/agents/data-science/`  |
| `eval-dataset-creator`     | `.github/agents/data-science/`  |
| `synth-data-generate`      | `.github/prompts/data-science/` |

### Depend on as cross-cutting skills

`privacy-standards`, `privacy-planner`, `rai-standards`, `rai-planner`, `telemetry-foundations`, `backlog-templates`.

### Connect to as handoffs

`brd-builder` (upstream), `prd-builder` (downstream), `requirements-author`, `experiment-designer`, `vally-tests`, `code-review`, `performance-slo-planner`, `rpi-research`, `adr-author`, `architecture-diagrams`.

---

## 9. Repository Conventions to Satisfy

### SKILL.md frontmatter

Schema: `scripts/linting/schemas/skill-frontmatter.schema.json`

**Required:** `name` (kebab-case, must match directory name), `description` (trigger metadata, not marketing).

**Recommended for these skills:**

```yaml
---
name: ds-dataops
description: "..."
license: MIT
user-invocable: false
metadata:
  authors: "Microsoft (ISE Engineering Fundamentals Playbook); Microsoft (planning synthesis)"
  spec_version: "1.0"
  last_updated: "YYYY-MM-DD"
  content_based_on: "https://microsoft.github.io/code-with-engineering-playbook/design/design-patterns/data-heavy-design-guidance/"
---
```

**Must not include:** `tools`, `model`, `agent`, `handoffs`, `applyTo`.

### Licensing posture

Default rule is **paraphrase-first**, even for MIT content. Reproduce only the minimum text needed for a technical point, with clear attribution. Every `references/*.md` cites its upstream source URL. Standards identifiers and structural names (Bronze/Silver/Gold, checklist item names) are facts and are reproduced verbatim.

### Agent frontmatter

Schema: `scripts/linting/schemas/agent-frontmatter.schema.json`

**Required:** `description`.

**Needed for a planner-shaped agent:** `name`, `tools` (read, edit/createFile, edit/createDirectory, edit/editFiles, execute/runInTerminal, execute/getTerminalOutput, search, web, agent), `handoffs` for cross-planner routing.

### State schema

Location: `.copilot-tracking/ds-plans/{project-slug}/state.json`

Required fields per `planner-identity-base.instructions.md`: `projectSlug`, `currentPhase`, `entryMode`, `phaseGates` (with `gate` type and `confirmedAt` per phase), `disclaimerShownAt`, `noticeLog`, `nextActions`, `userPreferences.autonomyTier`.

Six-step per-turn protocol: load state, confirm phase and gate, load required skill references, ask 3-5 focused questions, update state fields, persist both markdown and state before ending the turn.

### Disclaimer

Requires a new H2 section in `.github/instructions/shared/disclaimer-language.instructions.md`. The parser derives the slug from the first word of the heading, so a heading such as `## Data-Science Planning` yields slug `data-science`, planner key `data-science-planner`, and disclaimer id `data-science-full-disclaimer`. Exactly one `> [!CAUTION]` blockquote beginning with `**Disclaimer:**`.

Emit at the **end** of artifacts, not the start. Set `state.disclaimerShownAt` on first emission and append a `noticeLog` entry.

### Backlog templates

Adding a sixth caller requires:

| Requirement          | Proposed value                                                               |
|----------------------|------------------------------------------------------------------------------|
| ADO work-item prefix | `WI-DS-`                                                                     |
| GitHub temp ID       | `{{DS-TEMP-N}}`                                                              |
| Planner key          | `data-science`                                                               |
| Field block          | `data_tier`, `data_source`, `validation_rule`, `checklist_item`, `risk_tier` |

Autonomy tiers use the canonical vocabulary: `manual`, `supervised` (default), `autonomous`. Content sanitization applies before emission: replace `.copilot-tracking/` references with descriptive phrases, replace absolute paths with workspace-relative references, strip state pointers, preserve standards identifiers verbatim.

### Collection manifest

Update `collections/data-science.collection.yml` and `.md`. Every referenced subagent must appear in `items`. After any change:

```bash
npm run plugin:generate
npm run extension:prepare
npm run extension:prepare:prerelease
npm run docs:generate
```

Do not edit `plugins/` directly.

### Validation

| Command                             | Checks                                                         |
|-------------------------------------|----------------------------------------------------------------|
| `npm run lint:frontmatter`          | SKILL.md and agent frontmatter against schemas                 |
| `npm run validate:skills`           | Skill directory layout, references organization, Python config |
| `npm run lint:ai-artifacts`         | Planner artifact footers, disclaimer blocks, phase gates       |
| `npm run lint:collections-metadata` | Collection YAML and markdown consistency                       |
| `npm run validate:local`            | Non-mutating aggregate                                         |

---

## 10. Confirmed Gaps

Nothing in the repository covers these. All are greenfield.

| Gap                                                                       | Evidence                                                            |
|---------------------------------------------------------------------------|---------------------------------------------------------------------|
| Data engineering: ETL, ELT, pipelines, transformation, ingestion, lineage | Full cross-repository sweep found zero assets                       |
| Drift detection                                                           | No data drift, model drift, or retraining-trigger capability        |
| ML-specific testing                                                       | Existing testing assets cover dashboards and agent conformance only |
| CI for Jupyter notebooks                                                  | Playbook has a recipe; HVE Core has nothing                         |
| Trade Study                                                               | Playbook template exists; no HVE Core equivalent                    |
| Data Integrity as an NFR                                                  | Listed in the playbook, unconnected to tiering and validation       |

---

## 11. Pressure-Test Targets

Adversarial review produced ten risks. Three were rated blocking; user correction deflated all three. What remains genuinely open:

| Item                                 | Severity | Status                                                                                                                      |
|--------------------------------------|----------|-----------------------------------------------------------------------------------------------------------------------------|
| Skill execution model                | Serious  | Resolved by stating plainly that skills generate, users validate. Documentation must not claim assertions run               |
| `backlog-templates` field block      | Serious  | Real build work. Section 9 proposes values; needs review before implementation                                              |
| Split storage recovery               | Deflated | Feasibility study is the durable record; state loss is recoverable by reading it. A recovery step should still be specified |
| Disclaimer registration              | Deflated | Disclaimers bind to agents, not artifacts. Registration is a build task                                                     |
| Orchestration contracts              | Deflated | One-way handoff; no bidirectional contract exists to design                                                                 |
| ERD via `architecture-diagrams`      | Minor    | Cost estimate was optimistic. ER semantics, cardinality notation, and schema parsing are a domain expansion                 |
| ML Fundamentals Checklist visibility | Minor    | Rendering choice; does not affect the artifact budget                                                                       |
| Collection migration                 | Minor    | Procedural: where the new agent lives, whether the five old agents are deleted, breaking-change implications                |

### Recommended before implementation

1. **Validate with a second practitioner.** Every finding derives from one person's recollection. F3 (how often cataloging is actually skipped) and F4 (the true DE/DS effort split) would benefit most.
2. **Confirm the `backlog-templates` field block** with whoever owns that skill.
3. **Specify the state-recovery step** for the case where `state.json` is absent but the feasibility study exists.
4. **Decide the collection migration path.** Replace in place or introduce alongside.

---

## 12. Source Index

All CSE playbook content is MIT licensed. Paraphrase-first still applies.

| Source                            | URL                                                                              |
|-----------------------------------|----------------------------------------------------------------------------------|
| ML and AI Projects                | `https://microsoft.github.io/code-with-engineering-playbook/ml-and-ai-projects/` |
| ML Fundamentals Checklist         | `.../ml-and-ai-projects/ml-fundamentals-checklist/`                              |
| ML Model Production Checklist     | `.../ml-and-ai-projects/ml-model-checklist/`                                     |
| Feasibility Studies               | `.../ml-and-ai-projects/feasibility-studies/`                                    |
| Data Exploration                  | `.../ml-and-ai-projects/data-exploration/`                                       |
| Model Experimentation             | `.../ml-and-ai-projects/model-experimentation/`                                  |
| Testing DS and MLOps Code         | `.../ml-and-ai-projects/testing-data-science-and-mlops-code/`                    |
| Data and DataOps Fundamentals     | `.../design/design-patterns/data-heavy-design-guidance/`                         |
| Observability in Machine Learning | `.../observability/ml-observability/`                                            |
| Responsible AI in ISE             | `.../ml-and-ai-projects/responsible-ai/`                                         |

Candidate open standards for catalog grounding, not yet selected:

| Standard                  | Origin                   | Relevance                   |
|---------------------------|--------------------------|-----------------------------|
| DCAT                      | W3C Recommendation       | Data catalog vocabulary     |
| Croissant                 | MLCommons, Apache 2.0    | ML dataset metadata         |
| Frictionless Data Package | Open                     | Lightweight, pragmatic      |
| OpenLineage               | LF AI & Data, Apache 2.0 | Lineage events              |
| Datasheets for Datasets   | Gebru et al.             | Human-readable question set |

---

## 13. Companion Artifacts

| File                                | Contents                                                                          |
|-------------------------------------|-----------------------------------------------------------------------------------|
| `02-research.md`                    | Seven findings, six corrected assumptions, full cross-repository capability sweep |
| `02b-data-engineering-standards.md` | CSE DataOps and testing standards extract                                         |
| `03-synthesis.md`                   | Initial themes (superseded; predates six of seven findings)                       |
| `04-brainstorming.md`               | Ideation, encoding decisions, resolved questions, artifact budget                 |

---

<!-- markdownlint-disable MD036 -->

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
