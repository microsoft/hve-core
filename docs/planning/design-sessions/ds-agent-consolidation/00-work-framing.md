---
title: DS/DE Consolidation Work Framing
description: Superseded work framing for the Data Workstream Coach design session
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-03
ms.topic: reference
---

> [!WARNING]
> **Superseded.** This was a pointer document written before contracts were resolved.
>
> Use [the consolidated design](data-workstream-coach-design), the self-contained current design.

**Project:** ds-agent-consolidation
**Date:** 2026-08-01
**Status:** Superseded

> [!CAUTION]
> **Disclaimer:** This agent is an assistive coaching tool only. It does not conduct user research, observe stakeholders, or speak for the people whose problems you are designing for, and it does not replace primary research, direct stakeholder contact, design review, or product and strategy decision authority.
> Personas, problem statements, journey maps, empathy maps, concept tests, and other Design Thinking artifacts produced with this tool are scaffolding for your own research and synthesis, not substitutes for real stakeholder voice or observed behavior.
> Validate all AI-generated assumptions, personas, themes, and insights against actual stakeholders before treating any Design Thinking artifact as a basis for product, design, or strategy commitments. Outputs from this tool do not constitute validated research findings or design approval.

* [ ] Reviewed and validated by a qualified human reviewer

---

## Read This First

This document is the single entry point. The companion artifacts contain the reasoning; this contains the decisions and the open work.

| Artifact                            | Role                                                                                                            |
|-------------------------------------|-----------------------------------------------------------------------------------------------------------------|
| `02-research.md`                    | Seven findings, six corrected assumptions, cross-repository capability sweep                                    |
| `02b-data-engineering-standards.md` | CSE DataOps and testing standards extract                                                                       |
| `03-synthesis.md`                   | Initial themes (**stale**, predates six of seven findings)                                                      |
| `04-brainstorming.md`               | Ideation and encoding decisions (**partially stale**, skill cut superseded)                                     |
| `05-skill-architecture.md`          | Skill cut, agent shape, job routing protocol (**current**)                                                      |
| `06-contracts.md`                   | Resolved contracts: catalog schema, handoff payload, agent identity, ERD rendering, scanner rules (**current**) |
| `implementation-guide.md`           | **Stale.** Replaced by this document                                                                            |

---

## The Problem

> Data scientists using HVE Core face a cluttered, overlapping toolset that doesn't clearly differentiate from what Copilot already does natively, and it also doesn't help them produce the structured engagement artifacts a CSE engagement requires.

**Primary user:** the data scientist, who in practice owns the full engagement path regardless of the org chart, and whose role spans data engineering as well as data science.

**Out of scope:** project handoff and runbook assembly. A separate effort owns that and will consume these artifacts.

**Governing constraint:** anything requiring permanence is git-tracked in the repository.

---

## What Is Settled

### Architecture

| Decision                                    | Detail                                                                                                             |
|---------------------------------------------|--------------------------------------------------------------------------------------------------------------------|
| One agent, coach-shaped                     | Session-persistent, modeled on `dt-coach`, not the six-phase planners                                              |
| Job selection is user-driven                | The agent offers and confirms; it never infers silently. This is the load-bearing decision                         |
| Three lifecycle classes                     | `episodic`, `bounded`, `continuous`: a discriminated union with three branches, not N job types                    |
| Four skills plus one extension              | `ds-catalog`, `ds-dataops`, `ds-feasibility`, an experiment skill, and an ERD extension to `architecture-diagrams` |
| Two customer-facing deliverables            | Catalog and feasibility study, git-tracked                                                                         |
| Feasibility routes to requirements planning | Not to backlog. This pulls DS/DE into NFR disciplines they routinely skip                                          |
| Disclaimer is coaching-cadence              | Session start once, plus a footer on handoff-destined artifacts only                                               |
| Content scanning blocks                     | Any output write, including generated pipeline code                                                                |

### Job registry

| Job             | Class      | Skill                                  | Output                              |
|-----------------|------------|----------------------------------------|-------------------------------------|
| `catalog`       | continuous | `ds-catalog`                           | `data-catalog.md`, git-tracked      |
| `model-diagram` | episodic   | `ds-catalog` + `architecture-diagrams` | Mermaid or ASCII                    |
| `feasibility`   | bounded    | `ds-feasibility`                       | `feasibility-study.md`, git-tracked |
| `pipeline`      | episodic   | `ds-dataops`                           | Transformation and validation code  |
| `analysis`      | episodic   | absorbed agents                        | Notebooks, dashboards               |
| `experiment`    | episodic   | experiment skill                       | Tracking setup, evaluation code     |
| `testing`       | episodic   | `ds-dataops`                           | Test files                          |
| `observability` | episodic   | `ds-dataops` + `telemetry-foundations` | Instrumentation code                |

### Skill content

#### `ds-dataops`

Reference pack, grounded in CSE DataOps and testing guidance (MIT). Bronze/Silver/Gold as a behavioral state machine; validation at the Bronze-to-Silver boundary only, with refusal-with-alternative when asked to place it earlier; malformed routing; idempotent replay; notebook-to-package extraction; five pytest categories; the validation-versus-drift distinction.

#### `ds-feasibility`

Workflow, `adr-author`-shaped. Twelve CSE sections grouped into six phases with gates at 1, 4, and 6. Experiment thesis formation coached conversationally; results including abandoned approaches land in Hypothesis Testing.

#### `ds-catalog`

Ontology-first, Fabric-framed. Entity and relationship model, tier assignment, sensitivity classification using `privacy-standards` citation-field vocabulary. Delegates rendering to `architecture-diagrams`, Mural, and Figma.

#### Experiment skill

Backs and deepens `experiment-designer`, which stays general-purpose. CSE model-experimentation conventions plus MVE method depth.

### What dissolved

`ds-drift`, `ds-testing`, `ds-data-contracts`, `ds-transformation`, `ds-data-quality`. Each found a home in `ds-dataops` or in an existing skill.

---

## What Is Open

Five of the seven contracts identified in review are now resolved in [the contract record](./06-contracts.md):

| Item                  | Resolution                                                                                                                                                               |
|-----------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Data catalog schema   | `DS_CATALOG_V1` frontmatter with entities, relationships, tier, classification, lineage. Sits above the existing `gen-data-spec` profile schema rather than replacing it |
| Feasibility handoff   | `FEASIBILITY_TO_PRD_HANDOFF_V1`, modeled on the existing `BRD_TO_PRD_HANDOFF_V1` that `requirements-author` already ingests                                              |
| Agent identity        | `Data Workstream Coach`, foundation-skill routing, disclaimer heading specified                                                                                          |
| ERD rendering         | Renders from catalog entities and relationships. No SQL, Prisma, or SQLAlchemy parsers needed                                                                            |
| Scanner `--data` mode | Column-name denylist against structured input, connection-string and credential patterns, sample-row detection, configurable customer denylist                           |

**What still needs a decision:**

| Item                          | Nature                                                                                                                       |
|-------------------------------|------------------------------------------------------------------------------------------------------------------------------|
| Collection migration          | Product decision: delete, deprecate, or keep the five absorbed agents alongside. Deprecation is the conventional middle path |
| Feasibility handoff formality | Confirm with the `requirements-author` owner whether a formal payload is wanted or a conversational handoff suffices         |

Smaller items with suggested resolutions are listed at the end of `06-contracts.md`.

---

## What Can Start Now

With contracts resolved, the buildable set is substantially larger.

| Work                                     | Blocked by                                   |
|------------------------------------------|----------------------------------------------|
| `ds-dataops` reference pack              | Nothing                                      |
| Experiment skill                         | Nothing                                      |
| `ds-catalog` skill                       | Nothing; schema is specified                 |
| Scanner `--data` extension               | Nothing; rules are specified                 |
| ERD rendering in `architecture-diagrams` | Depends on a catalog existing to render from |
| `ds-feasibility` skill                   | Handoff formality confirmation               |
| Agent and foundation skill               | Nothing; identity is specified               |
| Collection manifest                      | Migration decision                           |

**Suggested first move:** `ds-dataops`. It is fully specified, MIT-grounded, has no dependencies, and everything else references its invariants.

---

## Repository Conventions

Verified against the current repo. These apply regardless of how the open items resolve.

### SKILL.md frontmatter

Schema at `scripts/linting/schemas/skill-frontmatter.schema.json`. Required: `name` (kebab-case, matching directory), `description`. Recommended for these skills: `license: MIT`, `user-invocable: false`, and a `metadata` block with `authors`, `spec_version`, `last_updated`, `content_based_on`.

Skill frontmatter must not declare `tools`, `model`, `agent`, `handoffs`, or `applyTo`. Per `hve-builder.instructions.md`, those belong to agents, prompts, or instructions.

### Licensing

Paraphrase-first, even for MIT content. Reproduce only the minimum needed for a technical point, with attribution. Every reference file cites its upstream URL. Standards identifiers and structural names (Bronze/Silver/Gold, checklist item names) are facts and reproduce verbatim.

### Agent frontmatter

Schema at `scripts/linting/schemas/agent-frontmatter.schema.json`. Only `description` is required; `name`, `tools`, and `handoffs` are optional but practically necessary here.

### Validation

`npm run lint:frontmatter`, `npm run validate:skills`, `npm run lint:collections-metadata`, `npm run validate:local`. Note that `lint:ai-artifacts` governs six-phase planners; a coach-shaped agent falls outside it, as `dt-coach` already does.

---

## Standing Caveats

**Single-source research.** Every finding derives from one practitioner's recollection. The two most load-bearing (how often cataloging is actually skipped, and the true data engineering to data science effort split) would benefit most from a second practitioner.

**Artifact location.** These design artifacts sit in `docs/design-thinking/`, which `docs/docusaurus/sidebars.js` autogenerates into the published site. Customer deliverables must not land in an autogenerated path. This affects both the design and the current session output.

**Instruction budget.** Estimated at roughly 1400 lines across agent, identity, and four skills. `dt-coach` plus its foundation runs about 930. Larger, but the skills load on demand rather than all at once.

---

## Source Index

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

Candidate catalog grounding standards, not yet selected: DCAT (W3C), Croissant (MLCommons, Apache 2.0), Frictionless Data Package, OpenLineage (LF AI & Data, Apache 2.0), Datasheets for Datasets (Gebru et al.), and Microsoft Fabric ontology as framing.

---

<!-- markdownlint-disable MD036 -->

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
