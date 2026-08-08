---
title: "Method 2 Research: DS Agent Consolidation"
description: Design research findings for the Data Workstream Coach consolidation
sidebar_position: 2
author: Microsoft
ms.date: 2026-08-03
ms.topic: reference
---

**Project:** ds-agent-consolidation  
**Method:** 2 (Design Research)  
**Date:** 2026-07-31  
**Entry reason:** Backward transition from Method 5 after ungrounded concept sketch failed. Addressing single-source research debt flagged in Method 3 readiness check.

---

## Evidence Source

**Primary:** Lead dev of HVE Core, with direct experience of data science consulting engagements. SME evidence, single source. Externally unvalidated.

---

## Findings

### F1: Week one is TPM-owned, but DS is in the room

The opening phase of an engagement is customer conversation and business problem understanding, primarily owned by the TPM. The data scientist participates during business problem refinement, contributing subject matter expertise rather than consuming a finished brief.

**Implication:** Envisioning Summary is **not** a data scientist artifact. Remove from the DS shortlist. Earlier assumption was wrong.

---

### F2: The DS workstream forks from a BRD-derived project description

The data scientist has access to a project description typically produced via the BRD workflow. They fork their workstream from that point. Their output synthesizes back into the PRD and flows onward through normal delivery.

**Implication:** The DS toolkit sits **between** existing HVE Core capabilities rather than beside them. `BRD Builder` upstream, `PRD Builder` downstream. Integration points already exist and should be used rather than duplicated.

---

### F3: Data cataloging is a "should," not an "is"

Direct quote of intent: data scientists *should* be indexing the customer's data. The phrasing signals a known-correct practice that does not happen reliably in the field.

**Implication:** Data catalog is not a compliance artifact. It is the foundational act that makes feasibility assessment, data quality evaluation, RAI exposure reasoning, and credible PRD contribution possible. Everything downstream depends on it.

---

### F4: The role spans data engineering, not just data science

Consulting engagements routinely require processing raw data, understanding existing data, and reshaping it before any analysis or modeling can begin. This data engineering work is often the majority of effort.

**Implication:** Our working model of the user has been too narrow. The existing `gen-data-spec` agent profiles a single clean file. It does not support multi-source inventory, lineage reasoning, or pipeline planning. This is a genuine gap in the current collection, not a refinement of an existing asset.

---

### F5: The toolkit spans most of the SDLC, not a slot between two documents

An earlier framing placed the DS toolkit "between BRD and PRD." Corrected: the workstream has tendrils across the agentic SDLC. The repository's own role guide already places data scientists in five lifecycle stages: Discovery, Product Definition, Implementation, Review, and Delivery.

Two further stages have a plausible claim not reflected in current documentation:

| Stage         | Claim                                                                                                                                                                   |
|---------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Decomposition | Data workstream breakdown has real specificity (feasibility gates, data acquisition blockers, research spikes).                                                         |
| Operations    | Model drift, data drift, retraining triggers, and monitoring. Absent from the current role guide, and arguably where data science work fails most often after delivery. |

**Implication:** Breadth is real, but the answer is still one agent with deep skills rather than a family of stage-scoped entry points. The agent serves both the data scientist and the data engineer.

---

### F6: Privacy and telemetry are critical hooks, not optional extras

Privacy and telemetry capabilities must be wired into the toolkit alongside RAI.

* **Privacy:** Directly implied by customer data indexing. A catalog built without privacy classification is how PII ends up somewhere it should not be. Cataloging and privacy classification are the same act.
* **Telemetry:** For data work this means data drift, pipeline health, and model observability. Maps directly onto the Operations gap identified in F5.

**Implication:** Four cross-cutting dependencies for the collection: RAI, Privacy, Telemetry, and the BRD/PRD connectors.

---

### F7: Cross-repository capability sweep

A full sweep across `.github/agents/**`, `.github/skills/**`, `.github/prompts/**`, `.github/instructions/**`, and `collections/*.collection.yml` for data-adjacent capability produced the following disposition map.

#### Absorb (folds into the unified agent)

| Asset                      | Path                            | Rationale                                                                     |
|----------------------------|---------------------------------|-------------------------------------------------------------------------------|
| `gen-data-spec`            | `.github/agents/data-science/`  | Data dictionary and machine-readable profile engine; becomes the catalog core |
| `gen-jupyter-notebook`     | `.github/agents/data-science/`  | Notebook generation with enforced structure                                   |
| `gen-streamlit-dashboard`  | `.github/agents/data-science/`  | Dashboard scaffolding                                                         |
| `test-streamlit-dashboard` | `.github/agents/data-science/`  | Output validation                                                             |
| `eval-dataset-creator`     | `.github/agents/data-science/`  | Evaluation dataset curation                                                   |
| `synth-data-generate`      | `.github/prompts/data-science/` | Synthetic and simulation data                                                 |

#### Depend on (cross-cutting skills, not duplicated)

| Asset                   | Path                               | Rationale                                                           |
|-------------------------|------------------------------------|---------------------------------------------------------------------|
| `privacy-standards`     | `.github/skills/project-planning/` | Data-flow reasoning, DPIA thresholds, NIST PF / GDPR / CCPA mapping |
| `privacy-planner`       | `.github/agents/privacy/`          | Owns data inventory, data-flow maps, DPIA gate                      |
| `rai-standards`         | `.github/skills/rai/`              | NIST AI RMF 1.0, AI STRIDE, EU AI Act risk tiers                    |
| `rai-planner`           | `.github/skills/project-planning/` | Risk classification and impact assessment                           |
| `telemetry-foundations` | `.github/skills/shared/`           | OpenTelemetry vocabulary, PII handling in observability             |
| `backlog-templates`     | `.github/skills/shared/`           | Work-item handoff with planner-specific field blocks                |

#### Connect to (upstream and downstream handoffs)

| Asset                     | Path                               | Rationale                                                       |
|---------------------------|------------------------------------|-----------------------------------------------------------------|
| `brd-builder`             | `.github/agents/project-planning/` | Upstream; project description the DS workstream forks from      |
| `prd-builder`             | `.github/agents/project-planning/` | Downstream; DS output synthesizes into PRD                      |
| `requirements-author`     | `.github/skills/project-planning/` | Canonical BRD/PRD templates and handoff contracts               |
| `experiment-designer`     | `.github/agents/experimental/`     | MVE hypothesis formation; overlaps feasibility study territory  |
| `vally-tests`             | `.github/skills/hve-core/`         | Grader catalog for evaluating data transforms and model outputs |
| `code-review`             | `.github/skills/coding-standards/` | Pipeline and notebook code review                               |
| `performance-slo-planner` | `.github/skills/project-planning/` | Pipeline SLO definition                                         |
| `rpi-research`            | `.github/skills/rpi/`              | Data source investigation during Discovery                      |

#### Confirmed gaps (nothing exists anywhere in the repo)

* **Data engineering:** No ETL, ELT, pipeline orchestration, transformation, reshaping, or ingestion capability exists in any collection. Confirms F4 as a true greenfield gap rather than an extension.
* **Drift detection:** No data drift, model drift, or retraining-trigger capability. Confirms the Operations gap in F5.
* **ML-specific testing:** No model testing, data quality testing, or pipeline testing. Existing testing assets cover dashboards and agent conformance only.

#### Overlap resolved: `experiment-designer`

`experiment-designer` coaches Minimum Viable Experiment design including data feasibility and technical risk, which is adjacent to the Feasibility Study artifact on our shortlist.

**Decision:** `experiment-designer` was intended as a broad, general-purpose tool. It stays general-purpose and is expanded so its MVE framing is not accidentally data-science-shaped. It joins the DS/DE collection as a bundled peer rather than being absorbed or duplicated.

**Rationale:** Hypothesis formation is genuinely valuable in a data science workflow but is not uniquely a data science concern. Keeping it generic and co-packaged lets the unified agent hand off to it without owning it, and avoids narrowing a tool that has broader utility.

**Follow-on work:** Expand `experiment-designer` capabilities to reduce incidental overlap with DS feasibility work, and add it to the DS/DE collection manifest.

---

## Corrections to Prior Assumptions

| Prior assumption                                | Corrected finding                                                                | Source |
|-------------------------------------------------|----------------------------------------------------------------------------------|--------|
| Envisioning Summary is a DS artifact            | TPM-owned; DS contributes SME input only                                         | F1     |
| DS toolkit is standalone                        | Integrates with BRD and PRD workflows                                            | F2     |
| DS toolkit sits between BRD and PRD             | Spans most of the SDLC; five documented stages plus Decomposition and Operations | F5     |
| Data inventory is one skill among five          | Foundational anchor for the whole toolkit                                        | F3     |
| User is "data scientist doing analysis"         | User spans data engineering and data science                                     | F4     |
| RAI is the main cross-cutting concern           | RAI, Privacy, and Telemetry are all critical                                     | F6     |
| Data engineering might extend an existing asset | Nothing exists anywhere in the repo; true greenfield                             | F7     |

---

## Revised Artifact Scope

| Artifact                             | Status                | Notes                                                          |
|--------------------------------------|-----------------------|----------------------------------------------------------------|
| Envisioning Summary                  | ❌ Removed             | TPM-owned (F1)                                                 |
| Data Catalog / Inventory             | ⬆️ Promoted to anchor | Foundational; inseparable from privacy classification (F3, F6) |
| Data Engineering / Reshaping support | 🆕 New gap identified | Not covered by any current asset (F4)                          |
| Feasibility Study                    | ✅ Retained            | Depends on catalog                                             |
| ML Fundamentals Checklist            | ✅ Retained            | Depends on catalog                                             |
| DS/MLOps Testing                     | ✅ Retained            | Partially exists                                               |
| RAI integration                      | ✅ Retained            | Exists; wire as dependency                                     |
| Privacy integration                  | 🆕 Added              | Critical hook (F6)                                             |
| Telemetry integration                | 🆕 Added              | Critical hook; covers Operations gap (F5, F6)                  |
| Simulation / synthetic data          | ✅ Retained            | Exists; extend                                                 |

---

## Architecture Direction (carried from Method 4)

One agent, skill-backed, serving both the data scientist and the data engineer. Breadth is handled through depth of skills rather than proliferation of agents or stage-scoped entry points.

---

## Research Quality Assessment

| Dimension               | Status                                           |
|-------------------------|--------------------------------------------------|
| Multi-source validation | ❌ Single source (lead dev SME)                   |
| Real-world grounding    | ✅ Based on lived engagement experience           |
| Evidence over opinion   | ⚠️ Recalled practice, not observed or documented |
| Assumption testing      | ✅ Four prior assumptions corrected               |

**Standing caveat:** All findings derive from one practitioner's recollection. Validation with additional data science consultants would materially strengthen confidence, particularly on F3 (how often cataloging is actually skipped) and F4 (the true data engineering / data science effort split).

---

<!-- markdownlint-disable MD036 -->

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
