---
title: "Method 4 Brainstorming: DS/DE Agent Consolidation"
description: Superseded brainstorming and encoding decisions for the Data Workstream Coach design
sidebar_position: 5
author: Microsoft
ms.date: 2026-08-03
ms.topic: reference
---

> [!WARNING]
> **Partially superseded.** The skill cut here was replaced in [the skill architecture](./05-skill-architecture.md). Encoding decisions and the CSE asset enumeration remain accurate and are carried forward into the consolidated design. Encoding decisions and the CSE asset enumeration remain accurate and are carried forward into the consolidated design.
>
> Use [the consolidated design](data-workstream-coach-design) for the current design.

**Project:** ds-agent-consolidation
**Method:** 4 (Brainstorming, re-run on grounded evidence)
**Date:** 2026-07-31

---

## Governing Constraint

Minimal asset generation. Precedent: the RAI workflow reduced twelve generated documents to four including its state file. The Security planner runs on two.

Mechanism inherited from `planner-identity-base.instructions.md`: **progressive disclosure**. One markdown file grows section by section across phases; one `state.json` carries resume state; backlog handoff is deferred to the final phase. No per-phase files, no interim drafts.

---

## CSE Playbook: Enumerated DS/DE Assets

Source: `microsoft.github.io/code-with-engineering-playbook/ml-and-ai-projects/` (MIT licensed).

| Asset                         | Type                  | Owner         | Disposition                                         |
|-------------------------------|-----------------------|---------------|-----------------------------------------------------|
| Envisioning Summary           | Document              | TPM-led       | Out of scope; DS contributes SME input only         |
| Data Exploration Workshop     | Event + outputs       | DS/DE-led     | Feeds catalog and feasibility study                 |
| Feasibility Study Report      | Document              | DS/DE-owned   | Primary deliverable                                 |
| ML Fundamentals Checklist     | Checklist, 6 sections | DS-owned      | Tracked as state; surfaced as a feasibility section |
| ML Model Production Checklist | Checklist             | DS-owned      | Tracked as state                                    |
| Model Experimentation records | Tracked artifacts     | DS-owned      | Needs durable enumeration; see open question        |
| Testing DS/MLOps code         | Code + conventions    | DS/DE-owned   | Working output, not a tracked document              |
| Responsible AI review         | Assessment            | Cross-cutting | Delegate to `rai-planner`                           |
| ERD                           | Diagram               | DE-owned      | Mermaid via extended `architecture-diagrams`        |

Adjacent playbook sections worth referencing: Data and DataOps Fundamentals, Observability in Machine Learning, CI with Jupyter Notebooks, Trade Study Template, Decision Log / ADR.

---

## Structural Insight: The Feasibility Study Is a Container

The playbook's feasibility study has twelve sections that subsume most of what we had been treating as peer artifacts:

Problem Definition · Deep Contextual Understanding · Data Access · Data Discovery · Architecture Discovery · Concept Ideation · EDA · Data Pre-Processing · Hypothesis Testing · Concept Testing · Risk Assessment · Responsible AI

This maps directly onto the progressive-disclosure pattern. The feasibility study **is** the growing markdown file. Phases append sections rather than spawning documents.

---

## Ideation Against HMW1: Catalog as Keystone

**Rejected:** catalog-as-state. The catalog is a customer-shared artifact and cannot double as internal agent state.

**Retained:**

* Catalog is markdown with defined sections, Word-convertible, suitable for direct customer sharing.
* Sensitivity classification is a **required field** on every entry, not an optional annotation. Cataloging and privacy classification are the same act.
* Crossing a sensitivity threshold triggers a gate that routes to `privacy-planner`, mirroring the existing DPIA hard gate.
* Each entry carries fields that feed RAI risk classification directly, so `rai-planner` consumes the catalog rather than re-interviewing.
* Progressive enrichment: the catalog begins as a stub on first contact with a data source and deepens as understanding grows. No cataloging ceremony.

**Candidate grounding standards (all permissively licensed):**

| Standard                  | Origin                   | Relevance                                           |
|---------------------------|--------------------------|-----------------------------------------------------|
| DCAT                      | W3C Recommendation       | Data catalog vocabulary                             |
| Croissant                 | MLCommons, Apache 2.0    | ML-specific dataset metadata                        |
| Frictionless Data Package | Open                     | Lightweight, pragmatic for messy consulting reality |
| OpenLineage               | LF AI & Data, Apache 2.0 | Lineage as a first-class standard                   |
| Datasheets for Datasets   | Gebru et al.             | The questions, for the human-readable layer         |

---

## Ideation Against HMW2: Agentic Data Engineering

Confirmed greenfield: no ETL, pipeline, transformation, ingestion, lineage, or drift capability exists anywhere in the repository.

### Revised skill cut (supersedes the four-skill proposal)

An earlier draft proposed four skills: `ds-data-contracts`, `ds-transformation`, `ds-data-quality`, `ds-drift`. Encoding the CSE DataOps standards revealed that tier semantics, validation placement, and malformed routing are **one coherent model**, not three. Splitting them would fragment a single concern across skills that constantly cross-reference.

| Skill        | Owns                                                                                                               |
|--------------|--------------------------------------------------------------------------------------------------------------------|
| `ds-dataops` | Bronze/Silver/Gold tiering, validation placement, idempotency, malformed routing, lineage, transformation patterns |
| `ds-testing` | The five CSE testing categories with pytest patterns                                                               |
| `ds-drift`   | Observability for data and model signals, anchored on malformed-record volume                                      |

**Design rule retained:** these skills produce working code and assertions, never planning documents.

### Encoding: Bronze/Silver/Gold as a state machine

Tier is a required enumerated field on every catalog entry (`bronze | silver | gold | malformed | sandbox`). Its value is that it makes downstream agent behavior decidable rather than advisory.

| Tier        | Behavior it unlocks                                                                           |
|-------------|-----------------------------------------------------------------------------------------------|
| `bronze`    | Refuse validation placement here; refuse transformation in place; enforce append-only framing |
| `silver`    | Require schema conformance and declared invariants before marking complete                    |
| `gold`      | Expect fact and dimension shape; flag a renamed silver table                                  |
| `malformed` | Auto-register as a monitored signal for the telemetry hook                                    |

### Encoding: validation placement as a refusal with alternative

Validation assertions are generated for the Bronze-to-Silver boundary. If the user requests validation before Bronze landing, the skill explains why Bronze must remain a faithful source copy (replay for testing, replay for recovery) and offers the correct placement instead.

This is the same refusal-with-alternative shape as the DPIA hard gate in `privacy-planner`. Precedent exists.

Two outputs fall out, both code: assertion definitions at the boundary, and a malformed-record route with a destination.

### Encoding: notebook-to-package migration as a detectable trigger

The playbook expects transformation code to move out of notebooks into packages. The agent watches for a condition rather than lecturing upfront.

**Trigger:** transformation logic in a notebook cell executed more than once, copied across cells, or exceeding a length threshold.

**Offer:** extract to a package function with a matching test stub, using the pytest patterns from `ds-testing`.

This is observable in the workspace, not hypothetical.

### Encoding: `ds-testing` as near-direct transcription

The playbook supplies pattern, example, and scope boundary for five categories. Minimal invention required.

```text
ds-testing/
  SKILL.md
  references/
    saving-loading.md      # mock isfile and read_csv; no repository fixtures
    transforming.md        # fixtures plus parametrize; one assertion per test
    model-load-predict.md  # mock; longrunning mark separates integration tests
    data-validation.md     # no data, wrong format, nulls, outliers
    model-testing.md       # adversarial, boundary, under-represented classes
```

Scope guard to state loudly: **ML unit tests check code quality, not accuracy or performance.** The playbook says this plainly and it is the most commonly violated rule in data science codebases.

---

## Ideation Against HMW3: Orchestration Without Proliferation

* **Handoff by reference, not by document.** The agent invokes `privacy-planner` and stores a pointer; privacy artifacts stay privacy-owned.
* **Reuse `cross_planner_refs`**, the existing linking field in the privacy planner, rather than inventing a new mechanism.
* **One backlog handoff, deferred to the end**, through `backlog-templates`, exactly as RAI, Privacy, Security, SSSC, and Accessibility already do.
* **The catalog is the integration surface.** BRD context lands in it, PRD contributions generate from it, RAI reads it, privacy classifies within it. One shared artifact rather than N handoff documents.
* **Notebooks, pipelines, tests, and ERDs are working outputs** in the customer's repository. The agent does not shadow them with tracking documents.

---

## Storage Model

A departure from the inherited planner pattern. RAI, Privacy, and Security write everything to gitignored `.copilot-tracking/`. Customer-facing DS deliverables cannot live there.

Precedent exists: the ADR workflow writes to `docs/planning/adrs/`, which is git-tracked.

**Governing principle (user-stated):** if an asset needs permanence, it lands in the repository in a meaningful git-tracked way.

| Tier                 | Location                          | Contents                                              |
|----------------------|-----------------------------------|-------------------------------------------------------|
| Working state        | `.copilot-tracking/` (gitignored) | `state.json`, phase gates, checklist completion flags |
| Durable deliverables | `docs/` (git-tracked)             | Data catalog, feasibility study, ERD                  |
| Working outputs      | Customer repository               | Notebooks, pipelines, tests, transformation code      |

---

## Proposed Artifact Budget

| Artifact                          | Audience                     | Pattern                                                                                                                        |
|-----------------------------------|------------------------------|--------------------------------------------------------------------------------------------------------------------------------|
| `data-catalog.md`                 | Customer-shared, git-tracked | Defined sections, Word-convertible, standards-grounded, sensitivity classification required                                    |
| `feasibility-study.md`            | Customer-shared, git-tracked | Progressive; twelve playbook sections appended by phase; absorbs the data plan once transformations and cleaning routines lock |
| `state.json`                      | Internal, gitignored         | Resume state, phase gates, checklist tracking                                                                                  |
| `{ado,github}-backlog-handoff.md` | Internal to backlog          | Deferred, conditional                                                                                                          |

Two customer deliverables, one state file, one conditional handoff.

---

## Resolved Questions

### R1: Model experimentation enumeration

**Decision:** No separate artifact. The agent coaches experiment ideation conversationally, in the manner of the DT Coach, helping the user surface what could be studied and form theses. Results aggregate into a subsection of the feasibility study.

**Rationale:** Hypothesis Testing is already one of the twelve playbook feasibility sections, so abandoned and successful experiments both have a natural home. The thesis-formation value comes from the coaching interaction, not from a document that enumerates theses in advance.

**Consequence:** Artifact budget holds at two customer-facing deliverables.

### R2: Does one agent hold this scope?

**Decision:** Yes. One agent with deep hooks into, and understanding of, what the skills offer.

**Rationale:** DT Coach is an existence proof within this repository. It runs nine methods across three spaces, loads three skill packages with roughly thirty references, manages persistent state, and supports non-linear method transitions, all as a single agent. The DS/DE scope is comparable in breadth and no more complex in structure.

**Consequence:** No subagent family required. Breadth is carried by skill depth and disciplined on-demand reference loading.

### R3: The telemetry, privacy, and drift seam

Examining `telemetry-foundations` and `privacy-standards` together revealed a boundary among three concerns, not the two first assumed.

| Concern                                                             | Owner                            | `ds-drift` relationship                            |
|---------------------------------------------------------------------|----------------------------------|----------------------------------------------------|
| Metric naming, instrument types, UCUM units, cardinality discipline | `telemetry-foundations`          | Conforms; contributes `data.*` and `model.*` names |
| PII in emitted telemetry                                            | `telemetry-foundations` denylist | Obeys; cannot emit denylisted fields as dimensions |
| PII in source data, classification, DPIA thresholds                 | `privacy-standards`              | Reads classification; never classifies             |
| Which data and model signals matter, and what thresholds mean       | `ds-drift`                       | Owns                                               |

**Governing rule:** `ds-drift` never decides what is sensitive. It reads a classification produced elsewhere and applies emission constraints accordingly.

**Proposed metric names**, conforming to the existing `<domain>.<entity>.<measure>` pattern:

| Metric                              | Instrument | Unit | Signal                                      |
|-------------------------------------|------------|------|---------------------------------------------|
| `data.validation.records.malformed` | counter    | `1`  | Records failing Bronze-to-Silver validation |
| `data.validation.duration`          | histogram  | `s`  | Validation stage cost                       |
| `data.pipeline.replay.count`        | counter    | `1`  | Idempotency exercise frequency              |
| `model.inference.duration`          | histogram  | `s`  | Serving latency                             |
| `data.feature.distribution.shift`   | gauge      | `1`  | Distribution drift score                    |

**Cardinality pitfall:** drift monitoring is dense with tempting dimensions (per-column, per-feature, per-source, per-tier). `ds-drift` needs a hard rule permitting only bounded dimensions such as `source`, `tier`, and `validation_rule`, never per-record or per-feature-value.

### R4: Catalog and privacy inventory overlap

`privacy-standards` already owns a data inventory concept: *"Start with a data inventory and map the personal data lifecycle: collection, transfer, storage, use, sharing, retention, and deletion."* The DS catalog is a different inventory (technical shape, tier, schema, lineage) covering the same underlying data assets.

**Decision:** the DS catalog carries a classification field informed by privacy work, adopting `privacy-standards` **citation-field vocabulary** (`gdpr_article`, `ccpa_section`, `nist_pf_category`, `nistir8062_objective`, `owasp_privacy_id`) rather than inventing sensitivity levels.

**Rationale:** cataloging and privacy classification are the same act. A single artifact with borrowed vocabulary beats two overlapping inventories.

**Corollary:** `privacy-standards` is broadly applicable and stays general-purpose. Where the data science and data engineering workflow reveals gaps in it, improve that skill rather than forking a data-science-specific variant.

### R5: Skill authoring pattern to follow

`privacy-standards` establishes the house style for a standards-grounded skill:

* `license: mixed` with explicit attribution metadata and `content_based_on` source URLs
* An attribution and licensing posture section stating paraphrase-not-quote
* A citation-field vocabulary so findings carry stable source references
* A phase-to-framework mapping table
* A scope caveat ("planning aid, not legal advice")

`ds-dataops` and `ds-testing` should follow the same shape. The CSE playbook being MIT licensed makes the posture simpler than privacy's mixed-license situation.

---

## Open Questions

1. **ML Fundamentals Checklist visibility.** Currently proposed as tracked state surfaced as a feasibility section. Some customers may expect to see the checklist itself as a discrete artifact. Rendering choice; does not affect the artifact budget.
2. **ERD tooling.** `architecture-diagrams` already renders Mermaid and ASCII but is scoped to Azure IaC. Extending it for data models is cheaper than a new skill and produces git-checkable output, unlike Figma or Mural.

---

## Scope Boundary

Project handoff and runbook assembly are **out of scope** for this design. A separate session is designing a handoff agent that will consume these artifacts. Our constraint is narrower and decidable per-artifact: anything requiring permanence must be git-tracked in the repository.

---

<!-- markdownlint-disable MD036 -->

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
