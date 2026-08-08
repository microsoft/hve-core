---
title: "Data Engineering Standards: CSE Playbook Extract"
description: CSE playbook standards informing the Data Workstream Coach design
sidebar_position: 3
author: Microsoft
ms.date: 2026-08-03
ms.topic: reference
---

**Project:** ds-agent-consolidation
**Method:** 2 (Design Research, supplementary round)
**Date:** 2026-07-31
**Sources:** `design/design-patterns/data-heavy-design-guidance/` and `ml-and-ai-projects/testing-data-science-and-mlops-code/` (MIT licensed)

---

## Finding: The DE Side Is More Prescriptive Than the DS Side

The ML section of the playbook describes phases and checklists. The DataOps section describes **enforceable engineering invariants**. This is a materially different kind of content and it is directly skill-encodable.

---

## Data and DataOps Fundamentals: Enumerated Standards

### Data Tiering: Bronze / Silver / Gold

A named, concrete quality model that the playbook expects data lakes to be divided by.

| Tier   | Definition                                                                                                   | Optimized for        | Consumer                  |
|--------|--------------------------------------------------------------------------------------------------------------|----------------------|---------------------------|
| Bronze | Raw landing area, none or minimal transformation. Immutable, append-only.                                    | Writes and ingestion | Pipeline replay, recovery |
| Silver | Cleansed, semi-processed. Conforms to a known schema and predefined data invariants. May carry augmentation. | Analysis             | Data scientists           |
| Gold   | Highly processed, read-optimized. Typically standard fact and dimension tables.                              | Reads                | Business users            |

Additional storage areas the playbook calls useful: malformed data, intermediate sandbox data, and libraries/packages/binaries.

**Design relevance:** This is a vocabulary the catalog should adopt directly. Every catalog entry can carry a tier. It also gives the data engineering skills a shared frame rather than inventing one.

### Data Validation Placement

Validation belongs **between Bronze and Silver**. Explicitly *not* before Bronze.

Rationale from the playbook: Bronze must remain as close to a copy of source-system data as possible, so the pipeline can be replayed for testing validation logic and for recovery when a transformation bug corrupts downstream data.

Records failing validation route to a **dedicated malformed-data store** for diagnostics.

**Design relevance:** This is a hard placement rule, not a preference. A `ds-data-quality` skill that generates assertions must know where they belong in the pipeline.

### Idempotent, Replayable Pipelines

Pipelines must be re-playable and idempotent so that Silver and Gold corruption can be recovered by deploying a fix and replaying. Idempotency also prevents duplication on replay.

### Testability Through Abstraction

Data transformation code must be separable from data access code so unit tests can target transformation logic.

The playbook is explicit: **move transformation code out of notebooks and into packages.** Testing notebooks is possible but slows the feedback cycle.

**Design relevance:** This directly contradicts a notebook-centric workflow. The unified agent should be pushing users toward extracted packages, not deeper into notebooks. Our existing `gen-jupyter-notebook` asset already encourages helper-function extraction, which aligns.

### Source Control Scope

Everything needed to build the pipeline from scratch belongs in source control: infrastructure-as-code, database objects (schemas, functions, stored procedures), reference and application data, pipeline definitions, and validation and transformation logic.

**Design relevance:** Reinforces the git-tracked permanence principle already adopted.

### Security and Configuration

Sensitive configuration such as connection strings lives in a central secure location per environment. On Azure, secrets in Key Vault per environment with services querying it at runtime.

### Observability

Monitor infrastructure, pipelines, **and data**. The playbook specifically calls out the malformed-record store as an area requiring data monitoring.

**Design relevance:** This is the concrete anchor for the proposed `ds-drift` skill and for the telemetry hook. Malformed-record volume is a first-class monitored signal, not an afterthought.

### Isolation and Concurrency Control

Isolation levels must be chosen deliberately; eventual consistency is a last resort behind batching, sharding, and caching. Optimistic concurrency via version increment or ETag is the recommended default over pessimistic two-phase locking.

**Design relevance:** Lower priority for a consulting DS/DE toolkit but relevant when the engagement touches transactional stores.

---

## Testing Data Science and MLOps Code: Enumerated Patterns

The playbook gives five testable operation categories with concrete pytest patterns.

| Category                | What to test                                                                | Technique                                                                             |
|-------------------------|-----------------------------------------------------------------------------|---------------------------------------------------------------------------------------|
| Saving and loading data | The logic in the load function, not the library                             | Mock `isfile` and `read_csv`; no repository test files                                |
| Transforming data       | Fixed input to fixed output, one verification per test                      | `pytest.fixture` for shared sample data; `pytest.mark.parametrize` for input matrices |
| Model load or predict   | Mock model load and predictions as with file access                         | `pytest.mark.longrunning` to separate smoke and integration tests from the unit loop  |
| Data validation         | No data supplied, wrong format, nulls, outliers                             | Test cases asserting pipeline robustness                                              |
| Model testing           | Adversarial and boundary robustness; accuracy for under-represented classes | Beyond unit testing                                                                   |

**Explicit guidance on ML unit tests:** they check code quality, not accuracy or performance. Does the model accept correctly shaped inputs and produce correctly shaped outputs? Do weights update when `fit` runs? These are closer to narrow integration tests and intentionally do not mock every outside call. The stated benefit is preventing a misconfigured model from burning hours in training.

**Design relevance:** This is a directly encodable skill. It is prescriptive, example-rich, and MIT licensed. A `ds-testing` skill grounded here is high-confidence, low-invention work.

---

## Architecture Tie-In

The playbook connects data work to architecture practice through several existing mechanisms:

| Playbook artifact                                      | HVE Core equivalent                              | Status                                             |
|--------------------------------------------------------|--------------------------------------------------|----------------------------------------------------|
| Decision Log / ADR                                     | `adr-author` skill, `adr-creator` agent          | Exists; connect                                    |
| Trade Study Template                                   | None                                             | Gap; adjacent to feasibility hypothesis comparison |
| Technical Spike Template                               | `experiment-designer` (being expanded)           | Partial overlap                                    |
| Engineering Feasibility Spikes                         | `experiment-designer`                            | Partial overlap                                    |
| Diagram types (class, component, deployment, sequence) | `architecture-diagrams` skill                    | Exists; ERD extension proposed                     |
| Non-Functional Requirements Capture                    | `requirements-author`, `performance-slo-planner` | Exists; connect                                    |
| Observability in Machine Learning                      | `telemetry-foundations`                          | Exists; connect                                    |
| CI with Jupyter Notebooks                              | None                                             | Gap                                                |
| Data Integrity (NFR)                                   | None                                             | Gap; relevant to Bronze/Silver/Gold validation     |

**Notable:** the playbook's example decision log includes an entry titled "Graph Model" under `Architecture/Data-Model/`, confirming that data model decisions are expected to flow through the ADR mechanism rather than a bespoke format. That supports connecting to `adr-author` rather than inventing data-model decision records.

---

## Implications for the Design

1. **The catalog should adopt Bronze/Silver/Gold as a first-class field.** It is the playbook's own vocabulary, it is concrete, and it makes tier-appropriate validation decidable.
2. **`ds-data-quality` has a hard placement rule to encode:** validation sits between Bronze and Silver, failures route to a malformed store. This is not a judgment call.
3. **`ds-testing` is the highest-confidence skill to build.** The playbook supplies patterns, examples, and explicit scope boundaries. Minimal invention required.
4. **The notebook-to-package migration is a playbook expectation**, not a stylistic preference. The agent should actively support extraction.
5. **Data model decisions route to ADR**, not to a new artifact type. Confirms the artifact budget.
6. **Malformed-record monitoring is the concrete anchor for the telemetry hook**, giving `ds-drift` a defined starting signal rather than an abstract mandate.

---

## Remaining Gaps With No Playbook Coverage

* CI for Jupyter notebooks: the playbook has a recipe but HVE Core has nothing.
* Trade Study: template exists in the playbook, no HVE Core equivalent.
* Data Integrity as an NFR: listed but not connected to the Bronze/Silver/Gold validation model.

---

<!-- markdownlint-disable MD036 -->

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
