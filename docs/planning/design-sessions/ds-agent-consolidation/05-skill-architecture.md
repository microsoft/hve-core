---
title: "Skill Architecture: DS/DE Consolidation"
description: Settled skill architecture and routing model for the Data Workstream Coach
sidebar_position: 6
author: Microsoft
ms.date: 2026-08-03
ms.topic: reference
---

**Project:** ds-agent-consolidation
**Date:** 2026-08-01
**Status:** Cut settled, supersedes the three-skill proposal in `04-brainstorming.md`

---

## What Changed and Why

An earlier round proposed a linear six-phase planner with three skills. That framing broke down under two observations:

1. **The work is not linear.** A data scientist arrives saying "I need an ERD for these three tables" or "help me figure out if this data supports the ask." They do not arrive saying "I would like to begin Phase 1."
2. **The scope is wider than catalog plus feasibility.** Roughly a dozen distinct jobs span discovery, data engineering, analysis and modeling, and operations.

The agent's job is therefore **routing, not phase orchestration**. Identify which job the user is on, load the matching skill entry point, do the work, and know what it connects to.

**Consequence:** gates become per-job rather than per-phase. Most jobs need none. Two genuinely do: a durable customer-facing write, and crossing a privacy sensitivity threshold.

---

## Established Skill Patterns in the Repository

Measured from existing skills, four patterns exist. The cut below assigns each new skill to one.

| Pattern        | Shape                                                               | Example                 | Size                                       |
|----------------|---------------------------------------------------------------------|-------------------------|--------------------------------------------|
| Reference Pack | SKILL.md plus indexed references; knowledge to consult              | `privacy-standards`     | 72 lines, 7 references                     |
| Workflow       | SKILL.md plus references plus templates; phases with durable output | `adr-author`            | 175 lines, 3 modes, converges at one write |
| Orchestrator   | Thin SKILL.md, dispatch logic, subagent routing                     | `code-review`           | 46 lines, 9 references                     |
| Tool Wrapper   | Parse in, render out, preference state                              | `architecture-diagrams` | 200+ lines, format preference contract     |

---

## The Cut

| Skill            | Pattern                    | Status | Owns                                                                                            |
|------------------|----------------------------|--------|-------------------------------------------------------------------------------------------------|
| `ds-catalog`     | Workflow plus Tool Wrapper | New    | Ontology, entities, relationships, tier, classification, ERD source model                       |
| `ds-dataops`     | Reference Pack             | New    | Tiering rules, validation placement, idempotency, lineage, transformation patterns, **testing** |
| `ds-feasibility` | Workflow                   | New    | Twelve-section study, entry modes, thesis coaching, go/no-go                                    |
| experiment skill | Reference Pack             | New    | Backs and deepens `experiment-designer`                                                         |

Four skills. One extension. Everything else connects to what already exists.

---

## Skill Detail

### `ds-catalog`: planning and execution

The catalog is **both** a planning artifact and an execution surface. It is not merely an inventory table; it is a semantic layer describing what entities exist, what they mean, and how they relate.

This is why it did not fold into `ds-dataops`. Dataops governs **pipeline mechanics** (tiers, validation, idempotency). Cataloging governs **meaning** (entity semantics and relationships). Different work.

**Framing:** Microsoft Fabric and its ontology capability inform the semantic model target. This gives the catalog a real semantic-layer destination rather than a generic metadata schema, and reflects where MSFT-adjacent data science engagements typically land.

**Carries:**

* Entity and relationship model (the ontology)
* Tier assignment: `bronze | silver | gold | malformed | sandbox`
* Sensitivity classification using `privacy-standards` citation-field vocabulary (`gdpr_article`, `ccpa_section`, `nist_pf_category`, `nistir8062_objective`, `owasp_privacy_id`) rather than invented levels
* Lineage pointers
* Source and volume metadata

**Rendering is delegated, not owned.** The catalog holds the semantic model; visualization routes to three existing surfaces:

| Surface                 | Use                                          |
|-------------------------|----------------------------------------------|
| `architecture-diagrams` | Mermaid or ASCII ERD, git-checkable, in-repo |
| Mural                   | Collaborative working sessions               |
| Figma                   | Design-adjacent collaborative review         |

This keeps one diagram convention per surface rather than inventing a fourth.

**ERD extension to `architecture-diagrams`:** the skill has a documented four-step contract (discovery, parsing, relationship mapping, generation) with format selection already pluggable through a preference contract. Adding ER support means new parsers (SQL DDL, Prisma, SQLAlchemy) and cardinality notation. The seams exist; the parsing layer is the real work.

### `ds-dataops`: reference pack, testing included

**Grounded in:** `design/design-patterns/data-heavy-design-guidance/` and `ml-and-ai-projects/testing-data-science-and-mlops-code/` (both MIT).

Testing folds in here rather than standing alone. The DataOps guidance already states the invariant: *ensure data transformation code is testable, and move transformation code out of notebooks into packages*. The five pytest categories are **how you satisfy an invariant this skill already asserts**, not an adjacent concern.

**Carries:**

| Area                    | Content                                                                                                       |
|-------------------------|---------------------------------------------------------------------------------------------------------------|
| Tiering                 | Bronze/Silver/Gold as a behavioral state machine, not a taxonomy                                              |
| Validation placement    | Bronze-to-Silver boundary only; refusal-with-alternative when asked to place it earlier                       |
| Malformed routing       | Failed records to a dedicated diagnostic store                                                                |
| Idempotency             | Re-playable pipelines so corruption is recoverable by fix-and-replay                                          |
| Testability             | Transformation code separated from data access code                                                           |
| Notebook-to-package     | Detectable trigger, then offer extraction with a test stub                                                    |
| Source control scope    | IaC, database objects, reference data, pipeline definitions, validation and transformation logic              |
| Testing                 | Five pytest categories: saving/loading, transforming, model load/predict, data validation, model testing      |
| Drift versus validation | Validation detects errors and triggers rectification; drift detects legitimate change and triggers retraining |

**Scope guard to state prominently:** ML unit tests check code quality, not accuracy or performance.

### `ds-feasibility`: workflow

**Grounded in:** `ml-and-ai-projects/feasibility-studies/` (MIT). Closest precedent is `adr-author`: multiple entry modes converging on a single durable write.

Twelve playbook sections, appended progressively. Experiment thesis formation is coached conversationally in the manner of `dt-coach`; results including abandoned approaches aggregate into the Hypothesis Testing section. No separate experiment artifact.

Output is a recommendation: either documented gaps preventing a positive outcome with possible re-scoping, or recommendations and technical assets for operationalization.

### Experiment skill: backs `experiment-designer`

`experiment-designer` is currently lightweight. A skill backing gives it depth without narrowing it to data science.

**Carries:** MVE method depth, plus the CSE model-experimentation conventions: virtual environments, folder and source-control structure, experiment tracking and reproducibility (dataset names and versions, parameters, code, environment), dataset and model abstractions with defined APIs, and the five-item model evaluation checklist.

Consistent with the earlier decision that `experiment-designer` stays general-purpose and joins the collection as a peer rather than being absorbed.

> **Partly reversed, 2026-08-03.** The bundling above was implemented as the `experiment-design` skill, and the CSE model-experimentation conventions and ML checklists were later split out into a separate `ml-experimentation` skill.
>
> Keeping them together made the pack's general-purpose claim false in practice: two of its three substantive references were ML-only, and its own description advertised ML checklist structure.
>
> `experiment-design` now carries MVE method depth plus general experiment-readiness guidance, and `experiment-designer` reaches the ML material through a conditional route bound to a recorded experiment type. The decision that the agent stays general-purpose is unchanged and is in fact what motivated the split.

---

## What Dissolved

| Proposed skill      | Disposition                                                                                                                                                               |
|---------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `ds-drift`          | Metric names conform to `telemetry-foundations`; the validation-versus-drift distinction belongs in `ds-dataops`; thresholds are engagement-specific. No independent home |
| `ds-testing`        | Folds into `ds-dataops`; testing satisfies an invariant dataops already asserts                                                                                           |
| `ds-data-contracts` | Folds into `ds-dataops`                                                                                                                                                   |
| `ds-transformation` | Folds into `ds-dataops`                                                                                                                                                   |
| `ds-data-quality`   | Folds into `ds-dataops`                                                                                                                                                   |

---

## Connect, Do Not Rebuild

| Capability                                           | Existing home                         |
|------------------------------------------------------|---------------------------------------|
| Notebooks, dashboards, eval datasets, synthetic data | Absorbed agents                       |
| Telemetry vocabulary, PII emission denylist          | `telemetry-foundations`               |
| Data classification, DPIA thresholds                 | `privacy-standards`                   |
| Responsible AI assessment                            | `rai-planner`                         |
| Diagram rendering                                    | `architecture-diagrams`, Mural, Figma |
| Decision records                                     | `adr-author`                          |
| Work item emission                                   | `backlog-templates`                   |
| Upstream and downstream requirements                 | `brd-builder`, `prd-builder`          |

---

## Agent Shape: Job Routing Protocol

Settled. The agent is **session-persistent with user-driven job selection**, modeled on `dt-coach` rather than the six-phase planners.

The decisive question was not "adaptive or fixed" but **"is job selection user-driven or agent-inferred."** Agent-inferred routing has no precedent in the repository and fails on ambiguity. User-driven selection with explicit, recorded transitions is exactly how `dt-coach` handles nine methods with genuinely different activities.

### Two-level model

| Level   | Completes?       | Analogue                                        |
|---------|------------------|-------------------------------------------------|
| Session | Never            | A `dt-coach` project                            |
| Job     | Depends on class | A DT method, or the canonical deck sub-workflow |

`dt-coach` already proves a bounded sub-workflow can complete inside an unbounded session: canonical deck generation starts, finishes, and coaching continues. Feasibility-study completion is the same shape: a job terminates, the session does not.

### Three lifecycle classes

Rather than N job types each with bespoke state, every job declares one of three classes. This keeps the state schema a discriminated union with three branches, not an open-ended union type.

| Class        | Terminates               | Phases                                  | Resume behavior                                            |
|--------------|--------------------------|-----------------------------------------|------------------------------------------------------------|
| `episodic`   | Per invocation           | Frame, Execute, Confirm                 | No cross-session resume; prior outputs listed as artifacts |
| `bounded`    | Yes, at a recommendation | Six, with the conventional gate cadence | Full phase-pointer resume                                  |
| `continuous` | Never                    | None; enrichment events                 | Resume by reading the artifact itself                      |

### Job registry

| Job             | Class      | Primary skill                             | Durable output                      |
|-----------------|------------|-------------------------------------------|-------------------------------------|
| `catalog`       | continuous | `ds-catalog`                              | `data-catalog.md`, git-tracked      |
| `model-diagram` | episodic   | `ds-catalog` plus `architecture-diagrams` | Mermaid or ASCII, in repo           |
| `feasibility`   | bounded    | `ds-feasibility`                          | `feasibility-study.md`, git-tracked |
| `pipeline`      | episodic   | `ds-dataops`                              | Transformation and validation code  |
| `analysis`      | episodic   | absorbed agents                           | Notebooks, dashboards               |
| `experiment`    | episodic   | experiment skill                          | Tracking setup, evaluation code     |
| `testing`       | episodic   | `ds-dataops`                              | Test files                          |
| `observability` | episodic   | `ds-dataops` plus `telemetry-foundations` | Instrumentation code                |

### Episodic phase shape

Three steps, no hard gates unless a durable customer-facing write occurs.

| Step    | Behavior                                                                               |
|---------|----------------------------------------------------------------------------------------|
| Frame   | Confirm the target, read the catalog for relevant context, state what will be produced |
| Execute | Do the work, writing to the customer repository                                        |
| Confirm | Summarize what was produced and what it connects to; record an artifact entry          |

### Bounded phase shape: `feasibility`

The twelve CSE sections group into six phases matching the conventional planner cadence, so the gate rhythm is familiar to anyone who has used the other planners.

| Phase         | CSE sections                                          | Gate                |
|---------------|-------------------------------------------------------|---------------------|
| 1 Frame       | Problem Definition, Deep Contextual Understanding     | hard                |
| 2 Access      | Data Access, Data Discovery, Architecture Discovery   | summary-and-advance |
| 3 Explore     | Exploratory Data Analysis, Data Pre-Processing        | summary-and-advance |
| 4 Hypothesize | Concept Ideation, Hypothesis Testing, Concept Testing | hard                |
| 5 Assess      | Risk Assessment, Responsible AI                       | summary-and-advance |
| 6 Recommend   | Go/no-go recommendation and next steps                | hard                |

### Continuous shape: `catalog`

No phases. Enrichment events append to the catalog and record a state entry. Two conditions interrupt:

* A durable write to the git-tracked catalog runs a sensitive-content scan first, following the `adr-creator` precedent. Non-zero scan result blocks the write pending user confirmation.
* Crossing a privacy sensitivity threshold routes to `privacy-planner` rather than proceeding.

### Job transition protocol

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

**Mid-session switching is supported and is the case the design must get right.** The failure mode identified in review (user mid-feasibility asks for an ERD) resolves as: pause `feasibility` at its recorded phase pointer, run `model-diagram` as an episodic job, offer to resume `feasibility` at the recorded phase.

### State schema

Session-level state in `.copilot-tracking/ds/{project-slug}/session-state.md`, YAML in markdown, following the `dt-coach` convention rather than planner JSON. The path uses `ds/` to match the `dt/` precedent for coach-shaped agents.

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

Combines the `dt-coach` announce-and-restore sequence with planner phase-pointer awareness.

1. Read `session-state.md`.
2. Validate that it parses and contains `project`, `current`, `jobs`, `job_log`.
3. Restore from `current.job` and `current.class`.
4. If `current.class` is `bounded`, restore the phase pointer and gate status.
5. Review recent `job_log` and `session_log` entries.
6. Scan `jobs` for any `paused` bounded work and any `active` continuous work.
7. Announce: the active job, its state, any paused work available to resume, and a brief summary of prior progress.

**If state is missing or corrupted**, reconstruct from artifacts rather than restarting. The git-tracked catalog and feasibility study are the durable record; a feasibility study with eight of twelve sections populated indicates the phase. Offer the reconstruction to the user for confirmation rather than assuming it.

### Flow-state awareness

The agent minimizes interruption during work and reserves checkpoints for moments that genuinely warrant them.

**Interrupts only for:**

* A durable customer-facing write, preceded by a sensitive-content scan
* A privacy sensitivity threshold crossing
* A hard gate in a bounded job
* An ambiguous job transition

**Never interrupts for:** episodic work in progress, catalog enrichment below the sensitivity threshold, or reference loading.

**On every resume**, state where the user is before asking anything. Announce active job, paused work, and last activity, then ask.

**On job completion**, name what finished and what it connects to, then offer options rather than auto-advancing.

### What this resolves from adversarial review

| Risk raised                          | Resolution                                                                                                                         |
|--------------------------------------|------------------------------------------------------------------------------------------------------------------------------------|
| State model union type               | Three lifecycle classes, not N job types. Discriminated union with three branches                                                  |
| Intent routing ambiguity             | Job selection is user-driven. The agent offers and confirms; it never infers silently                                              |
| Mid-session switching corrupts state | Explicit transition protocol with class-specific outgoing disposition; bounded jobs pause rather than abandon                      |
| Validation script breakage           | Coach-shaped, not planner-shaped. `Validate-PlannerArtifacts.ps1` governs the six-phase planners; `dt-coach` is already outside it |
| Phase convention violation           | No violation. The agent does not claim to be a six-phase planner. The `feasibility` job internally uses the conventional cadence   |
| Instruction budget                   | Comparable to `dt-coach` at roughly 930 lines including its foundation skill. Parity with a working agent, not overload            |

## Resolved: Disclaimer, Handoff, and Content Scanning

### Disclaimer cadence

**Coaching style, with a footer on handoff-destined artifacts.**

Session start follows the `dt-coach` pattern: display once, gated on `disclaimerShownAt` being null, never repeat. This is not the planner cadence.

A disclaimer footer is appended to any artifact **designed for handoff** (to another person or to an agentic process). The rule keys on *who receives it*, not on where it is stored.

| Artifact                                         | Footer                                               |
|--------------------------------------------------|------------------------------------------------------|
| `data-catalog.md`                                | Yes; shared with customer                            |
| `feasibility-study.md`                           | Yes; shared with customer and feeds planning handoff |
| Requirements handoff payload                     | Yes; consumed by another agent                       |
| Notebooks, pipelines, tests, transformation code | No; working outputs                                  |
| Session state                                    | No; internal                                         |

Requires a new H2 section in `.github/instructions/shared/disclaimer-language.instructions.md`. The parser derives the slug from the first word of the heading, so word order matters: a heading such as `## Data-Science Coaching` yields slug `data-science`.

### Feasibility output routes to requirements planning, not backlog

**No `backlog-templates` registration.** No `WI-DS-` prefix, no field block, no caller table update. That build work is removed entirely.

The `feasibility` job's Recommend phase ends with a **guided handoff into functional and non-functional requirements planning**. Requirements are derived from what the study found feasible; work items are emitted downstream through the existing planner path.

**This handoff does double duty.** Beyond routing, it pulls data engineering and data science into the non-functional requirement disciplines that data science engagements routinely skip: security, privacy, Responsible AI, performance, and data integrity. The gate is arguably the most valuable connection in the design, not merely a convenience.

The agent guides the user into planning rather than emitting work items itself.

### Sensitive-content scanning: reuse and extend

**Reuse** `.github/skills/project-planning/adr-author/scripts/scan_sensitive_content.py`. It is a deterministic regex scanner returning JSON findings with `high` and `warn` confidence labels, non-zero exit on any high-confidence finding, and internal-URL detection gated behind `--public` for public repositories only.

**Posture: block.** Any high-confidence finding blocks the write until the user confirms redaction, matching `adr-creator`. Data cataloging carries higher exposure than architecture decision records: a catalog enumerates customer data sources, column names, and classifications rather than mentioning a system in passing.

**Trigger: any output write.** Broader than the `adr-creator` gate, which fires only on durable ADR writes.

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

#### Gaps in the current implementation

The existing ruleset is intentionally conservative and prose-oriented. Extending it for data work requires:

| Gap                                       | Why it matters for data work                                                                                                                                                                                                    |
|-------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Connection strings and DSNs               | Generated pipeline code routinely embeds them; no current rule                                                                                                                                                                  |
| Cloud storage account keys and SAS tokens | Common in data ingestion code                                                                                                                                                                                                   |
| Column-name heuristics                    | A catalog lists column names such as `ssn`, `dob`, `patient_id`. The current scanner deliberately avoids name and role heuristics because prose produces false positives; a schema column list is structured and far less noisy |
| Sample or example rows                    | Catalogs and notebooks embed representative records that may contain real values                                                                                                                                                |
| Non-US national identifier shapes         | Only the US `\d{3}-\d{2}-\d{4}` pattern exists today                                                                                                                                                                            |
| Non-US phone shapes                       | The current pattern is North American                                                                                                                                                                                           |
| Customer or tenant identifiers            | Engagement-specific; likely a configurable denylist rather than a fixed rule                                                                                                                                                    |

**Extension approach:** add a `--data` mode alongside the existing `--public` gate, activating column-name and connection-string rules that would be noisy against prose but are appropriate against schemas and pipeline code. This preserves current behavior for ADR callers while strengthening detection for data callers.

The `_redact()` masking helper and JSON finding shape are reused unchanged.

---

<!-- markdownlint-disable MD036 -->

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
