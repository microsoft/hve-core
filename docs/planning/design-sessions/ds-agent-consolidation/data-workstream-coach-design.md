---
title: "Data Workstream Coach: Consolidated Design"
description: Consolidated design for the Data Workstream Coach and its supporting skills
sidebar_position: 8
author: Microsoft
ms.date: 2026-08-03
ms.topic: reference
---

**Project:** ds-agent-consolidation
**Date:** 2026-08-01
**Status:** Design complete. Two product decisions outstanding.
**Origin:** Design Thinking session, Methods 1 through 5

> [!CAUTION]
> **Disclaimer:** This agent is an assistive coaching tool only. It does not conduct user research, observe stakeholders, or speak for the people whose problems you are designing for, and it does not replace primary research, direct stakeholder contact, design review, or product and strategy decision authority.
> Personas, problem statements, journey maps, empathy maps, concept tests, and other Design Thinking artifacts produced with this tool are scaffolding for your own research and synthesis, not substitutes for real stakeholder voice or observed behavior.
> Validate all AI-generated assumptions, personas, themes, and insights against actual stakeholders before treating any Design Thinking artifact as a basis for product, design, or strategy commitments. Outputs from this tool do not constitute validated research findings or design approval.

* [ ] Reviewed and validated by a qualified human reviewer

---

## Contents

1. [Problem and Scope](#1-problem-and-scope)
2. [Architecture](#2-architecture)
3. [Agent Identity](#3-agent-identity)
4. [Job Routing Protocol](#4-job-routing-protocol)
5. [Session State](#5-session-state)
6. [Skills](#6-skills)
7. [Data Catalog Schema](#7-data-catalog-schema)
8. [Feasibility Study](#8-feasibility-study)
9. [Functional Planner source boundary](#9-functional-planner-source-boundary)
10. [ERD Rendering](#10-erd-rendering)
11. [Content Scanning](#11-content-scanning)
12. [Asset Disposition](#12-asset-disposition)
13. [Repository Conventions](#13-repository-conventions)
14. [Outstanding Decisions](#14-outstanding-decisions)
15. [Standing Caveats](#15-standing-caveats)
16. [Sources](#16-sources)
17. [Companion Artifacts](#17-companion-artifacts)

---

## 1. Problem and Scope

### Confirmed problem statement

> Data scientists using HVE Core face a cluttered, overlapping toolset that doesn't clearly differentiate from what Copilot already does natively, and it also doesn't help them produce the structured engagement artifacts a CSE engagement requires.

### Primary user

The data scientist, who in practice owns the full engagement path regardless of what the org chart says, and whose role spans **data engineering as well as data science**. The engineering half is often the majority of effort on a consulting engagement.

### How the workstream sits in the SDLC

The data scientist participates in business problem refinement contributing subject matter expertise, then forks a workstream from the BRD-derived project description. Output synthesizes back into the PRD and flows onward through normal delivery.

The repository's own role guide already places data scientists in five lifecycle stages: Discovery, Product Definition, Implementation, Review, and Delivery. Decomposition and Operations have plausible claims not yet reflected in that guide.

### Out of scope

Project handoff and runbook assembly. A separate effort owns that work and will consume these artifacts.

### Governing constraint

Anything requiring permanence is git-tracked in the repository.

---

## 2. Architecture

### Decisions

| ID  | Decision                                      | Rationale                                                                                       |
|-----|-----------------------------------------------|-------------------------------------------------------------------------------------------------|
| D1  | One agent, coach-shaped                       | Session-persistent, modeled on `dt-coach`, not the six-phase planners                           |
| D2  | Job selection is user-driven                  | The agent offers and confirms; it never infers silently. Load-bearing decision                  |
| D3  | Three lifecycle classes                       | `episodic`, `bounded`, `continuous`: a discriminated union with three branches, not N job types |
| D4  | Four skills plus one extension                | Breadth carried by skill depth rather than agent proliferation                                  |
| D5  | Two customer-facing deliverables              | Catalog and feasibility study, both git-tracked                                                 |
| D6  | Feasibility routes to requirements planning   | Not to backlog. Pulls DS/DE into NFR disciplines they routinely skip                            |
| D7  | Catalog adopts `privacy-standards` vocabulary | Cataloging and privacy classification are the same act                                          |
| D8  | `experiment-designer` stays general-purpose   | Hypothesis formation is valuable to DS but not uniquely a DS concern                            |
| D9  | Data model decisions route to ADR             | The CSE decision log already includes a data model entry under `Architecture/Data-Model/`       |
| D10 | Skills produce working code and assertions    | Never planning documents. Keeps the artifact budget honest                                      |

### Why routing rather than phases

An earlier round proposed a linear six-phase planner. That framing broke on two observations:

1. **The work is not linear.** A data scientist arrives saying "I need an ERD for these three tables" or "help me figure out if this data supports the ask." They do not arrive saying "I would like to begin Phase 1."
2. **The scope is wider than catalog plus feasibility.** Roughly a dozen distinct jobs span discovery, data engineering, analysis and modeling, and operations.

**Consequence:** gates are per-job, not per-phase. Most jobs need none. Two genuinely do: a durable customer-facing write, and crossing a privacy sensitivity threshold.

### Execution model

Skills **generate** code and assertions. They do not execute against customer data sources, transformation engines, or telemetry backends. Documentation must state this plainly; an earlier draft claimed assertions "run" and that claim was withdrawn.

---

## 3. Agent Identity

| Property           | Value                                                               |
|--------------------|---------------------------------------------------------------------|
| Name               | `Data Workstream Coach`                                             |
| Path               | `.github/agents/data-science/data-workstream-coach.agent.md`        |
| Foundation skill   | `.github/skills/data-science/data-workstream-foundation/SKILL.md`   |
| State              | `.copilot-tracking/ds/{project-slug}/session-state.md`              |
| Disclaimer heading | `## Data-Science Coaching` in `disclaimer-language.instructions.md` |

**Naming rationale.** "Workstream" reflects the research finding that the data scientist owns a workstream forking from the BRD-derived project description and feeding the PRD (not a project, not a phase). "Coach" signals the `dt-coach` archetype rather than a planner, setting accurate expectations about gates and completion.

**Job routing lives in the foundation skill**, following `dt-coach` rather than the planner identity-instructions pattern. This keeps the agent body thin and makes the routing protocol loadable on demand.

**Disclaimer heading word order matters.** The validator takes the first whitespace-delimited token, so `## Data-Science Coaching` yields slug `data-science`.

### Foundation skill layout

```text
.github/skills/data-science/data-workstream-foundation/
  SKILL.md
  references/
    job-registry.md          # eight jobs, classes, skills, outputs
    lifecycle-classes.md     # episodic, bounded, continuous semantics
    transition-protocol.md   # signals, confirmation, disposition, job_log
    session-state.md         # schema and resume algorithm
    flow-state.md            # when to interrupt, when not to
```

### Disclaimer cadence

Coaching style, not planner style.

Session start displays the disclaimer once, gated on `disclaimerShownAt` being null. Never repeats.

A footer is appended to artifacts **designed for handoff** (to another person or to an agentic process). The rule keys on who receives it, not where it is stored.

| Artifact                                         | Footer                                            |
|--------------------------------------------------|---------------------------------------------------|
| `data-catalog.md`                                | Yes; shared with customer                         |
| `feasibility-study.md`                           | Yes; shared with customer, feeds planning handoff |
| Requirements handoff payload                     | Yes; consumed by another agent                    |
| Notebooks, pipelines, tests, transformation code | No; working outputs                               |
| Session state                                    | No; internal                                      |

---

## 4. Job Routing Protocol

### Two-level model

| Level   | Completes?       | Analogue                                        |
|---------|------------------|-------------------------------------------------|
| Session | Never            | A `dt-coach` project                            |
| Job     | Depends on class | A DT method, or the canonical deck sub-workflow |

`dt-coach` already proves a bounded sub-workflow can complete inside an unbounded session: canonical deck generation starts, finishes, and coaching continues. Feasibility-study completion is the same shape.

### Three lifecycle classes

| Class        | Terminates               | Phases                         | Resume behavior                                            |
|--------------|--------------------------|--------------------------------|------------------------------------------------------------|
| `episodic`   | Per invocation           | Frame, Execute, Confirm        | No cross-session resume; prior outputs listed as artifacts |
| `bounded`    | Yes, at a recommendation | Six, conventional gate cadence | Full phase-pointer resume                                  |
| `continuous` | Never                    | None; enrichment events        | Resume by reading the artifact itself                      |

### Job registry

| Job             | Class      | Primary skill                          | Durable output                      |
|-----------------|------------|----------------------------------------|-------------------------------------|
| `catalog`       | continuous | `ds-catalog`                           | `data-catalog.md`, git-tracked      |
| `model-diagram` | episodic   | `ds-catalog` + `architecture-diagrams` | Mermaid or ASCII, in repo           |
| `feasibility`   | bounded    | `ds-feasibility`                       | `feasibility-study.md`, git-tracked |
| `pipeline`      | episodic   | `ds-dataops`                           | Transformation and validation code  |
| `analysis`      | episodic   | absorbed agents                        | Notebooks, dashboards               |
| `experiment`    | episodic   | experiment skill                       | Tracking setup, evaluation code     |
| `testing`       | episodic   | `ds-dataops`                           | Test files                          |
| `observability` | episodic   | `ds-dataops` + `telemetry-foundations` | Instrumentation code                |

### Episodic phase shape

Three steps. No hard gates unless a durable customer-facing write occurs.

| Step    | Behavior                                                                               |
|---------|----------------------------------------------------------------------------------------|
| Frame   | Confirm the target, read the catalog for relevant context, state what will be produced |
| Execute | Do the work, writing to the customer repository                                        |
| Confirm | Summarize what was produced and what it connects to; record an artifact entry          |

### Transition protocol

Adapted from the `dt-coach` method-transition protocol. Every transition is explicit, user-confirmed, and recorded.

1. Detect a transition signal: explicit request, topic shift, or completion of the active job.
2. Do not switch silently. Name the current job, name the proposed job, and ask.
3. On confirmation, resolve the outgoing job by class:
   * `episodic`: complete the current step or discard cleanly; nothing to preserve beyond artifacts
   * `bounded`: record the phase pointer and gate status; the job is **paused**, not abandoned
   * `continuous`: flush pending enrichment to the catalog
4. Append a `job_log` entry with `from_job`, `to_job`, `rationale`, `outgoing_disposition`, and date.
5. Load the incoming job's skill entry point.
6. Announce the switch and what carried over.

**Mid-session switching is supported and is the case the design must get right.** The canonical failure case (user mid-feasibility asks for an ERD) resolves as: pause `feasibility` at its recorded phase pointer, run `model-diagram` as an episodic job, offer to resume `feasibility` at the recorded phase.

### Flow-state awareness

**Interrupts only for:**

* A durable customer-facing write, preceded by a content scan
* A privacy sensitivity threshold crossing
* A hard gate in a bounded job
* An ambiguous job transition

**Never interrupts for:** episodic work in progress, catalog enrichment below the sensitivity threshold, or reference loading.

**On every resume**, state where the user is before asking anything.

**On job completion**, name what finished and what it connects to, then offer options rather than auto-advancing.

---

## 5. Session State

YAML in markdown at `.copilot-tracking/ds/{project-slug}/session-state.md`, following the `dt-coach` convention rather than planner JSON. The `ds/` path matches the `dt/` precedent for coach-shaped agents.

```yaml
project:
  name: ""
  slug: ""
  created: "YYYY-MM-DD"

current:
  job: "catalog"
  class: "continuous"
  phase: ""          # populated for bounded jobs only
  disclaimerShownAt: null

jobs:
  catalog:
    class: continuous
    status: active            # never | active
    artifact: "docs/.../data-catalog.md"
    last_enriched: "YYYY-MM-DD"
  feasibility:
    class: bounded
    status: paused            # never | active | paused | complete
    phase: 3
    phaseGates:
      phase1: { gate: hard, confirmedAt: "..." }
      phase4: { gate: hard, confirmedAt: null }
      phase6: { gate: hard, confirmedAt: null }
    artifact: "docs/.../feasibility-study.md"
  model-diagram:
    class: episodic
    status: never
    invocations: []

job_log:
  - from_job: null
    to_job: "catalog"
    rationale: "Session initialized"
    outgoing_disposition: null
    date: "YYYY-MM-DD"

session_log:
  - date: "YYYY-MM-DD"
    job: "catalog"
    summary: ""

artifacts: []

cross_agent_refs: []    # pointers to privacy, RAI, ADR outputs
```

Per-job blocks carry only the fields their class requires. An `episodic` job never has `phaseGates`; a `continuous` job never has `phase`.

### Resume protocol

1. Read `session-state.md`.
2. Validate that it parses and contains `project`, `current`, `jobs`, `job_log`.
3. Restore from `current.job` and `current.class`.
4. If `current.class` is `bounded`, restore the phase pointer and gate status.
5. Review recent `job_log` and `session_log` entries.
6. Scan `jobs` for any `paused` bounded work and any `active` continuous work.
7. Announce: active job, its state, any paused work available to resume, and a brief summary of prior progress.

**If state is missing or corrupted**, reconstruct from artifacts rather than restarting. The git-tracked catalog and feasibility study are the durable record; a feasibility study with eight of twelve sections populated indicates the phase. Offer the reconstruction for confirmation rather than assuming it.

---

## 6. Skills

Four skills plus one extension. Each maps to an established repository pattern.

| Skill                   | Pattern                    | Precedent                             |
|-------------------------|----------------------------|---------------------------------------|
| `ds-catalog`            | Workflow plus Tool Wrapper | `adr-author`, `architecture-diagrams` |
| `ds-dataops`            | Reference Pack             | `privacy-standards`                   |
| `ds-feasibility`        | Workflow                   | `adr-author`                          |
| experiment skill        | Reference Pack             | `privacy-standards`                   |
| `architecture-diagrams` | Tool Wrapper               | Extension, not new                    |

### `ds-dataops`

**Grounded in:** CSE `data-heavy-design-guidance` and `testing-data-science-and-mlops-code` (MIT).

Testing folds in here rather than standing alone. The DataOps guidance already states the invariant: ensure transformation code is testable, move it out of notebooks into packages. The five pytest categories are **how you satisfy an invariant this skill already asserts**.

#### Bronze / Silver / Gold as a state machine

Tier is recorded in the catalog; its meaning and consequences live here.

| Tier        | Definition                                                   | Behavior it unlocks                                                        |
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

* Pipelines must be re-playable and idempotent so corruption is recoverable by fix-and-replay
* Transformation code separates from data access code so unit tests can target transformation logic
* Everything needed to build the pipeline from scratch belongs in source control: IaC, database objects, reference data, pipeline definitions, validation and transformation logic
* Sensitive configuration lives in a central secure store per environment
* Monitor infrastructure, pipelines, **and data**, since malformed-record volume is a first-class signal

#### Notebook-to-package migration

**Trigger:** transformation logic in a notebook cell exceeding roughly 15 lines, or duplicated across cells. The threshold matches the existing `gen-jupyter-notebook` cell-length convention. Repeated execution is detected by cell duplication rather than execution count.

**Offer:** extract to a package function with a matching test stub.

#### Testing references

| Reference            | Content                                                                                                                                                     |
|----------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `saving-loading`     | Test the logic in the load function, not the library. Mock `isfile` and `read_csv`; no repository fixture files, so tests behave identically on any machine |
| `transforming`       | Fixed input to fixed output, one verification per test. `pytest.fixture` for shared sample data, `pytest.mark.parametrize` for input matrices               |
| `model-load-predict` | Mock model load and prediction as with file access. `pytest.mark.longrunning` separates smoke and integration tests from the unit loop                      |
| `data-validation`    | Test cases for no data supplied, unexpected format, nulls, outliers                                                                                         |
| `model-testing`      | Adversarial and boundary robustness; verify accuracy for under-represented classes                                                                          |

**Scope guard to state prominently:** ML unit tests check **code quality, not accuracy or performance**. Does the model accept correctly shaped inputs and produce correctly shaped outputs? Do weights update when `fit` runs? These are closer to narrow integration tests and intentionally do not mock every outside call.

#### Validation versus drift

The playbook draws a distinction the skill must preserve:

> **Data validation** detects errors (a datum outside its expected range). **Data drift detection** uncovers legitimate changes truly representative of the modeled phenomenon.
>
> Validation issues trigger re-routing and rectification. Drift triggers adaptation or retraining.

#### Observability vocabulary

Metric names conform to the existing `<domain>.<entity>.<measure>` pattern in `telemetry-foundations`. No invented conventions.

| Metric                              | Instrument | Unit | Signal                                      |
|-------------------------------------|------------|------|---------------------------------------------|
| `data.validation.records.malformed` | counter    | `1`  | Records failing Bronze-to-Silver validation |
| `data.validation.duration`          | histogram  | `s`  | Validation stage cost                       |
| `data.pipeline.replay.count`        | counter    | `1`  | Idempotency exercise frequency              |
| `model.inference.duration`          | histogram  | `s`  | Serving latency                             |
| `data.feature.distribution.shift`   | gauge      | `1`  | Distribution drift score                    |

**Cardinality discipline.** Drift monitoring is dense with tempting dimensions. Bounded dimensions only: `source`, `tier`, `validation_rule`. Never per-record or per-feature-value.

**Ownership seam.** `telemetry-foundations` owns naming, instruments, units, cardinality, and the PII emission denylist. `privacy-standards` owns classification and DPIA thresholds. `ds-dataops` owns which data and model signals matter. **It never decides what is sensitive**; it reads a classification produced elsewhere.

### `ds-catalog`

The catalog is **both** a planning artifact and an execution surface: a semantic layer describing what entities exist, what they mean, and how they relate.

This is why it did not fold into `ds-dataops`. Dataops governs **pipeline mechanics**; cataloging governs **meaning**. Different work.

**Framing:** Microsoft Fabric and its ontology capability inform the semantic model target, giving the catalog a real destination rather than a generic metadata schema. Adopted as framing, not as a binding format.

Schema in [section 7](#7-data-catalog-schema).

**Rendering is delegated, not owned:**

| Surface                 | Use                                          |
|-------------------------|----------------------------------------------|
| `architecture-diagrams` | Mermaid or ASCII ERD, git-checkable, in-repo |
| Mural                   | Collaborative working sessions               |
| Figma                   | Design-adjacent collaborative review         |

**Enrichment is user-driven.** The agent may notice an uncatalogued source and offer, but never enriches silently.

### `ds-feasibility`

**Grounded in:** CSE `feasibility-studies` (MIT). Closest precedent is `adr-author`: multiple entry modes converging on a single durable write.

Detail in [section 8](#8-feasibility-study).

### Experiment skill

`experiment-designer` is currently lightweight. A skill backing gives it depth without narrowing it to data science.

**Scope:** new skill under `.github/skills/data-science/`, referenced by the existing agent. The agent gains a reference; its scope does not narrow.

**Carries:** MVE method depth, plus CSE model-experimentation conventions.

| Area                           | Expected outcome                                                                                                                                                                                                                |
|--------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Virtual environments           | Documentation of creation and dependency install; config files committed. HVE Core convention is `uv`                                                                                                                           |
| Folder and source control      | Agreed structure pushed to the repo; `.gitignore` scope; a decision on notebook storage and versioning (`nbstripout` named for output stripping)                                                                                |
| Experiment tracking            | Choose a framework, ensure access, document local setup, define datasets and evaluation so experiments are comparable. Full reproducibility requires tracking dataset names **and versions**, parameters, code, and environment |
| Dataset and model abstractions | Building blocks have defined APIs so they can be replaced or extended without breaking the flow; mock blocks for unit tests; APIs shared with engineering                                                                       |
| Model evaluation               | Logic approved by stakeholders; relationship to business KPIs analyzed; flow applicable to all present and future models; evaluation code unit-tested and reviewed; flow facilitates error analysis                             |

### What dissolved

| Proposed skill      | Disposition                                                                                                                          |
|---------------------|--------------------------------------------------------------------------------------------------------------------------------------|
| `ds-drift`          | Metric names conform to `telemetry-foundations`; validation-versus-drift belongs in `ds-dataops`; thresholds are engagement-specific |
| `ds-testing`        | Folds into `ds-dataops`; satisfies an invariant dataops already asserts                                                              |
| `ds-data-contracts` | Folds into `ds-dataops`                                                                                                              |
| `ds-transformation` | Folds into `ds-dataops`                                                                                                              |
| `ds-data-quality`   | Folds into `ds-dataops`                                                                                                              |

---

## 7. Data Catalog Schema

### Relationship to the existing profile schema

`gen-data-spec` already produces a per-dataset JSON profile with columns, semantic roles, feature sets, and quality flags. The catalog is **not a replacement**; it is the **level above**.

| Layer                                                  | Owner                   | Scope          |
|--------------------------------------------------------|-------------------------|----------------|
| Column detail, stats, quality flags                    | Existing profile schema | One dataset    |
| Entities, relationships, tier, classification, lineage | Catalog                 | The engagement |

Migration is additive rather than a rewrite.

### `DS_CATALOG_V1`

Customer-facing markdown with YAML frontmatter carrying the machine-readable model, followed by human-readable sections. Frontmatter makes it parseable for ERD rendering; the body makes it Word-convertible and shareable.

```yaml
---
catalog_version: DS_CATALOG_V1
engagement: <ENGAGEMENT_NAME>
generated_at: <ISO_8601_TIMESTAMP>
last_enriched: <ISO_8601_TIMESTAMP>

entities:
  - id: <ENTITY_ID>
    name: <BUSINESS_NAME>
    description: <WHAT_THIS_REPRESENTS>
    source:
      system: <SOURCE_SYSTEM>
      location: <PATH_OR_CONNECTION_REFERENCE>
      format: <csv|parquet|jsonl|table|api>
      access_confirmed: <true|false>
    tier: <bronze|silver|gold|malformed|sandbox>
    grain: <WHAT_ONE_ROW_REPRESENTS>
    volume:
      row_estimate: <COUNT_OR_NULL>
      period_covered: <RANGE_OR_NULL>
      update_frequency: <CADENCE>
    profile_ref: <PATH_TO_DATA_PROFILE_JSON_OR_NULL>
    classification:
      sensitivity: <none|internal|confidential|restricted>
      contains_personal_data: <true|false>
      data_categories: [<CATEGORY>]
      nist_pf_category: <NIST_PF_ID_OR_NULL>
      gdpr_article: <ARTICLE_OR_NULL>
      dpia_ref: <PRIVACY_PLAN_REF_OR_NULL>
    lineage:
      derived_from: [<ENTITY_ID>]
      transform_ref: <PATH_TO_TRANSFORM_CODE_OR_NULL>
    open_questions: [<QUESTION>]

relationships:
  - from: <ENTITY_ID>
    to: <ENTITY_ID>
    cardinality: <one-to-one|one-to-many|many-to-many>
    join_keys:
      from_field: <FIELD_NAME>
      to_field: <FIELD_NAME>
    confidence: <confirmed|inferred|assumed>
    basis: <HOW_THIS_WAS_ESTABLISHED>

coverage:
  entities_catalogued: <COUNT>
  entities_access_confirmed: <COUNT>
  entities_classified: <COUNT>
  relationships_confirmed: <COUNT>
  relationships_inferred: <COUNT>
---
```

### Design notes

**`confidence` on relationships is load-bearing.** Consulting engagements routinely infer joins from column names before anyone confirms them. Recording `inferred` versus `confirmed` prevents a guess hardening into an assumption, and gives the feasibility study something honest to report.

**`profile_ref` is the seam to `gen-data-spec`.** The catalog points at the existing JSON profile rather than duplicating column detail.

**Tier lives in the catalog, not `ds-dataops`.** The catalog records *what tier an entity is*; `ds-dataops` owns *what that tier means*. Data versus rules.

**`access_confirmed` reflects the CSE Data Access section.** The playbook requires verifying the full team has access before feasibility proceeds. A field is checkable; prose is not.

**Classification uses `privacy-standards` citation-field vocabulary** (`gdpr_article`, `nist_pf_category`, and siblings) rather than invented sensitivity levels.

### Body sections

Generated from frontmatter, human-readable, Word-convertible:

1. Overview and engagement context
2. Entity summary table: name, grain, tier, sensitivity, access status
3. Entity relationship diagram
4. Per-entity detail: source, volume, lineage, open questions
5. Coverage summary
6. Open questions and access gaps
7. Disclaimer footer

---

## 8. Feasibility Study

### The study is a container, not a peer document

The CSE feasibility study has twelve sections that subsume most artifacts previously treated as peers. Phases append sections; no per-phase files.

| Phase         | CSE sections                                          | Gate                |
|---------------|-------------------------------------------------------|---------------------|
| 1 Frame       | Problem Definition, Deep Contextual Understanding     | hard                |
| 2 Access      | Data Access, Data Discovery, Architecture Discovery   | summary-and-advance |
| 3 Explore     | Exploratory Data Analysis, Data Pre-Processing        | summary-and-advance |
| 4 Hypothesize | Concept Ideation, Hypothesis Testing, Concept Testing | hard                |
| 5 Assess      | Risk Assessment, Responsible AI                       | summary-and-advance |
| 6 Recommend   | Verdict, evidence summary, handoff payload            | hard                |

The cadence matches the conventional planner rhythm, so gate behavior is familiar.

### Experiment enumeration

The agent coaches thesis formation conversationally, in the manner of `dt-coach`. Results, including abandoned approaches and why, aggregate into the Hypothesis Testing section. No separate artifact.

### ML Fundamentals Checklist

Tracked as state, surfaced as a study section. Six areas: data quality and governance, feasibility study, evaluation and metrics, model baseline, experimentation setup, production.

### ML Model Production Checklist

Eleven items, tracked as state:

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

Item 11 routes to `rai-planner`. Items 8 through 10 route to `ds-dataops` observability.

### Output

A recommendation on next steps: either documented gaps preventing a positive outcome with possible re-scoping, or recommendations and technical assets for operationalization.

---

## 9. Functional Planner source boundary

The feasibility study itself is the durable producer artifact. One constrained
YAML block inside the Markdown study owns machine facts, including stable UUID
concept and revision identities, item classes, criteria state, typed relations,
provenance, review state, and lifecycle lineage. No temporary or sibling handoff
artifact is created.

A separate Functional Planner workstream owns future adoption. It will declare
supported profile versions, select actionable capability candidates, allocate
`FR-###`, preserve UUID-to-FR mappings, reconcile revisions and lifecycle
events, and render traceability views. It remains read-only toward the source
study.

This workstream does not modify `requirements-author`, Functional Planner, or a
non-functional planner. It does not claim that direct intake already works.

---

## 10. ERD Rendering

### Render from the catalog, do not parse source files

Adding ERD support via SQL DDL, Prisma, and SQLAlchemy parsers would require cardinality inference without database introspection. That work disappears if the ERD renders from the catalog's `entities` and `relationships` blocks, which already carry names, join keys, and explicit cardinality.

**The catalog is the parse target.** Establishing entities and relationships is cataloging work done with domain experts, exactly the CSE Data Discovery activity that calls for an ERD. Inferring from DDL would be less accurate, since DDL rarely encodes the semantic relationships that matter.

### Contract to `architecture-diagrams`

The skill gains one input type. Its existing four-step contract holds.

| Existing behavior                      | ERD addition                                            |
|----------------------------------------|---------------------------------------------------------|
| Parses IaC to find components          | Reads catalog `entities`                                |
| Maps component relationships           | Reads catalog `relationships` with declared cardinality |
| Renders ASCII or Mermaid by preference | Adds Mermaid `erDiagram` output                         |
| Format preference in state             | Unchanged                                               |

Mermaid's `erDiagram` syntax expresses cardinality natively, so notation is a rendering concern rather than an inference problem.

**Relationship confidence renders visibly.** Inferred and assumed relationships are marked so a reviewer can see what has been confirmed.

---

## 11. Content Scanning

Extends `.github/skills/project-planning/adr-author/scripts/scan_sensitive_content.py`. Preserves current behavior for ADR callers; activates additional rules only under `--data`.

### Posture

**Block.** Any high-confidence finding blocks the write until the user confirms redaction, matching `adr-creator`. Data cataloging carries higher exposure than architecture decision records: a catalog enumerates customer data sources, column names, and classifications.

### Trigger: any output write

Broader than the `adr-creator` gate, which fires only on durable ADR writes.

| Write                                     | Scan |
|-------------------------------------------|------|
| Catalog enrichment, git-tracked           | Yes  |
| Feasibility study section append          | Yes  |
| Requirements handoff payload              | Yes  |
| Generated transformation or pipeline code | Yes  |
| Generated test files                      | Yes  |
| Generated notebooks                       | Yes  |
| Diagram output                            | Yes  |

Data processing code is included deliberately. Connection strings, sample records, and hardcoded identifiers appear in generated pipeline code at least as often as in prose.

### Column-name detection

Denylist against **structured input only**. The current scanner avoids name heuristics because prose produces false positives; catalog frontmatter and schema definitions are structured, so the noise problem does not apply.

| Confidence | Patterns                                                                                                                                                                               |
|------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `high`     | `ssn`, `social_security`, `national_id`, `passport`, `tax_id`, `drivers_license`, `credit_card`, `card_number`, `cvv`, `account_number`, `routing_number`                              |
| `warn`     | `dob`, `date_of_birth`, `birth_date`, `email`, `phone`, `address`, `postal`, `zip`, `patient_id`, `member_id`, `mrn`, `full_name`, `first_name`, `last_name`, `salary`, `compensation` |

Matched case-insensitively with word-boundary and underscore-separator tolerance so `patientId`, `patient_id`, and `PatientID` all match.

**Explicitly excluded** to control false positives: `customer_id`, `order_id`, `user_id`, `batch_size`, `order_date`, `created_at`, and any name whose only sensitive-adjacent token is `id` on a non-personal entity.

### Connection strings and credentials (`high`)

| Category                  | Shape                                                                                  |
|---------------------------|----------------------------------------------------------------------------------------|
| `connection_string`       | `Server=`, `Data Source=`, `Initial Catalog=`, `User Id=`, `Password=` key-value pairs |
| `jdbc_odbc_uri`           | `jdbc:`, `odbc:` URI prefixes                                                          |
| `db_uri_with_credentials` | `postgres://`, `mysql://`, `mongodb://`, `redis://` containing a userinfo segment      |
| `sas_token`               | Query strings containing `sig=` alongside `se=` and `sp=`                              |
| `storage_key`             | `AccountKey=` followed by a base64-shaped value                                        |
| `bearer_token`            | `Authorization: Bearer` followed by a token-shaped value                               |

### Additional rules

**Sample-row detection (`warn`).** Markdown table rows or JSON arrays under a heading or key matching `sample`, `example`, or `preview`. A structural signal, not confidently distinguishable from synthetic data, so it does not block alone.

**Non-US identifier and phone shapes (`high`).** Extends the existing US-only patterns: UK National Insurance, Canadian SIN, E.164 international phone format.

**Customer and tenant identifiers (configurable).** A `--denylist <path>` argument accepts a caller-supplied term list matching at `high` confidence. Keeps customer names out of the shared ruleset.

### Behavior

Any `high` finding sets non-zero exit and blocks the write. `warn` findings surface without blocking. The existing `_redact()` masking and JSON finding shape are reused unchanged.

**On block**, the agent reports the finding category and masked preview, then requires explicit user confirmation that content has been redacted before retrying. Automatic masking is not offered: the user must see what was flagged.

### Privacy threshold

Routing to `privacy-planner` triggers on `classification.sensitivity` of `restricted`, or `contains_personal_data: true` combined with an unset `dpia_ref`.

---

## 12. Asset Disposition

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

`privacy-standards`, `privacy-planner`, `rai-standards`, `rai-planner`, `telemetry-foundations`.

### Connect to as handoffs

`brd-builder` (upstream), `prd-builder` and `requirements-author` (downstream), `experiment-designer`, `vally-tests`, `code-review`, `performance-slo-planner`, `rpi-research`, `adr-author`, `architecture-diagrams`.

### Confirmed greenfield

A full cross-repository sweep found zero existing coverage for:

* Data engineering: ETL, ELT, pipelines, transformation, ingestion, lineage
* Drift detection
* ML-specific testing
* CI for Jupyter notebooks
* Trade Study
* Data Integrity as an NFR

---

## 13. Repository Conventions

Verified against the current repository.

### SKILL.md frontmatter

Schema at `scripts/linting/schemas/skill-frontmatter.schema.json`.

**Required:** `name` (kebab-case, matching directory), `description`.

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
  content_based_on: "https://microsoft.github.io/code-with-engineering-playbook/..."
---
```

**Must not declare** `tools`, `model`, `agent`, `handoffs`, or `applyTo`. Per `hve-builder.instructions.md`, those belong to agents, prompts, or instructions.

### Licensing

Paraphrase-first, even for MIT content. Reproduce only the minimum needed for a technical point, with attribution. Every reference file cites its upstream URL. Standards identifiers and structural names (Bronze/Silver/Gold, checklist item names) are facts and reproduce verbatim.

### Agent frontmatter

Schema at `scripts/linting/schemas/agent-frontmatter.schema.json`. Only `description` is required; `name`, `tools`, and `handoffs` are optional but practically necessary here.

### Validation

| Command                             | Checks                                          |
|-------------------------------------|-------------------------------------------------|
| `npm run lint:frontmatter`          | SKILL.md and agent frontmatter against schemas  |
| `npm run validate:skills`           | Skill directory layout, references organization |
| `npm run lint:collections-metadata` | Collection YAML and markdown consistency        |
| `npm run validate:local`            | Non-mutating aggregate                          |

`lint:ai-artifacts` governs six-phase planners. A coach-shaped agent falls outside it, as `dt-coach` already does.

### Collection regeneration

After any collection manifest change:

```bash
npm run plugin:generate
npm run extension:prepare
npm run extension:prepare:prerelease
npm run docs:generate
```

Do not edit `plugins/` directly.

---

## 14. Outstanding Decisions

Two decisions remain. Both are product calls, not technical unknowns.

### Collection migration

`collections/data-science.collection.yml` lists five agents and one prompt that this design absorbs.

| Option         | Effect                                                               |
|----------------|----------------------------------------------------------------------|
| Delete         | Clean, breaking for anyone invoking them directly                    |
| Deprecate      | Mark `maturity: deprecated`, keep working, remove in a later release |
| Keep alongside | The unified agent is additive; specialists remain for direct use     |

Deprecation is the conventional middle path and the manifest schema already supports the `deprecated` maturity value.

### Functional Planner adoption

Functional Planner adoption is a separate workstream. The producer profile is
complete here; parser support, item-selection policy, `FR-###` allocation,
UUID-to-FR reconciliation, and compatibility evaluations belong there.

---

## 15. Standing Caveats

**Single-source research.** Every finding derives from one practitioner's recollection. The two most load-bearing (how often cataloging is actually skipped, and the true data engineering to data science effort split) would benefit most from validation with a second practitioner.

**Artifact location.** These design artifacts sit in `docs/design-thinking/`, which `docs/docusaurus/sidebars.js` autogenerates into the published site. Customer deliverables must not land in an autogenerated path. This affects both the design and the current session output.

**Instruction budget.** Estimated at roughly 1400 lines across agent, foundation skill, and four skills. `dt-coach` plus its foundation runs about 930. Larger, but skills load on demand rather than all at once.

---

## 16. Sources

CSE playbook content is MIT licensed. Paraphrase-first still applies.

| Source                            | Path under `microsoft.github.io/code-with-engineering-playbook/` |
|-----------------------------------|------------------------------------------------------------------|
| ML and AI Projects                | `ml-and-ai-projects/`                                            |
| ML Fundamentals Checklist         | `ml-and-ai-projects/ml-fundamentals-checklist/`                  |
| ML Model Production Checklist     | `ml-and-ai-projects/ml-model-checklist/`                         |
| Feasibility Studies               | `ml-and-ai-projects/feasibility-studies/`                        |
| Data Exploration                  | `ml-and-ai-projects/data-exploration/`                           |
| Model Experimentation             | `ml-and-ai-projects/model-experimentation/`                      |
| Testing DS and MLOps Code         | `ml-and-ai-projects/testing-data-science-and-mlops-code/`        |
| Data and DataOps Fundamentals     | `design/design-patterns/data-heavy-design-guidance/`             |
| Observability in Machine Learning | `observability/ml-observability/`                                |
| Responsible AI in ISE             | `ml-and-ai-projects/responsible-ai/`                             |

Candidate catalog grounding standards, not yet selected: DCAT (W3C), Croissant (MLCommons, Apache 2.0), Frictionless Data Package, OpenLineage (LF AI & Data, Apache 2.0), Datasheets for Datasets (Gebru et al.), and Microsoft Fabric ontology as framing.

---

## 17. Companion Artifacts

This document is self-contained. The companions below hold the reasoning and evidence behind it.

| Artifact                                                     | Contents                                                                          |
|--------------------------------------------------------------|-----------------------------------------------------------------------------------|
| [Research record](./02-research.md)                          | Seven findings, six corrected assumptions, full cross-repository capability sweep |
| [Data engineering standards](02b-data-engineering-standards) | CSE DataOps and testing standards extract with implications                       |
| [Skill architecture](./05-skill-architecture.md)             | Skill cut derivation, agent shape reasoning, adversarial review responses         |
| [Contract record](./06-contracts.md)                         | Contract derivations with design notes                                            |

### Superseded

| Artifact                  | Why                                                                                             |
|---------------------------|-------------------------------------------------------------------------------------------------|
| `03-synthesis.md`         | Predates six of seven research findings                                                         |
| `04-brainstorming.md`     | Skill cut superseded; encoding decisions carried forward here                                   |
| `implementation-guide.md` | Described a six-phase planner, three skills, and `backlog-templates` registration; all replaced |
| `00-work-framing.md`      | Pointer document; superseded by this consolidation                                              |

---

<!-- markdownlint-disable MD036 -->

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
