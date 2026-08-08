---
title: "DS/DE Consolidation: Resolved Contracts"
description: Resolved catalog, handoff, agent, ERD, and scanning contracts for the Data Workstream Coach
sidebar_position: 7
author: Microsoft
ms.date: 2026-08-03
ms.topic: reference
---

**Project:** ds-agent-consolidation
**Date:** 2026-08-01
**Resolves:** open items 1 through 5 in `00-work-framing.md`
**Method:** modeled on existing repository contracts, not invented

---

## 1. Data Catalog Schema

### The insight that resolves it

`gen-data-spec` already produces a per-dataset JSON profile with columns, semantic roles, feature sets, and quality flags. The catalog is **not a replacement**; it is the level above: entities, their relationships, and engagement-wide concerns that a single-dataset profile cannot express.

That makes the migration path additive rather than a rewrite.

| Layer                                                  | Owner                   | Scope          |
|--------------------------------------------------------|-------------------------|----------------|
| Column detail, stats, quality flags                    | Existing profile schema | One dataset    |
| Entities, relationships, tier, classification, lineage | Catalog                 | The engagement |

### Catalog structure

The catalog is customer-facing markdown with a YAML frontmatter header carrying the machine-readable model, followed by human-readable sections. Frontmatter makes it parseable for ERD rendering; the body makes it Word-convertible and shareable.

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

**`confidence` on relationships is load-bearing.** Consulting engagements routinely infer joins from column names before anyone confirms them. Recording `inferred` versus `confirmed` prevents a guess from hardening into an assumption, and it gives the feasibility study something honest to report.

**`profile_ref` is the seam to `gen-data-spec`.** The catalog points at the existing JSON profile rather than duplicating column detail. Absorbing that agent means its profile output becomes a catalog attachment, not a competing artifact.

**Tier lives in the catalog, not `ds-dataops`.** This resolves the ownership question raised in review. `ds-catalog` records *what tier an entity is*; `ds-dataops` owns *what that tier means and what behavior it unlocks*. Data versus rules.

**`access_confirmed` reflects the CSE Data Access section.** The playbook explicitly requires verifying the full team has access before feasibility proceeds. Making it a field rather than prose makes it checkable.

**Fabric ontology as framing, not schema.** `entities`, `grain`, and `relationships` with explicit cardinality align with semantic-model thinking without binding the catalog to a Fabric-specific format. A Fabric export becomes a rendering target alongside Mermaid, Mural, and Figma.

### Body sections

Generated from frontmatter, human-readable, Word-convertible:

1. Overview and engagement context
2. Entity summary table: name, grain, tier, sensitivity, access status
3. Entity relationship diagram, rendered, see section 4
4. Per-entity detail: source, volume, lineage, open questions
5. Coverage summary: what is catalogued, classified, and confirmed
6. Open questions and access gaps
7. Disclaimer footer

---

## 2. Feasibility-to-Requirements Handoff

### Contract

Modeled directly on `BRD_TO_PRD_HANDOFF_V1`, which `requirements-author` already ingests at PRD Assess. Same shape, same conventions, so the receiving side is familiar.

```yaml
schema_version: FEASIBILITY_TO_PRD_HANDOFF_V1
handoff_id: <HANDOFF_ID>
handoff_at: <ISO_8601_TIMESTAMP>

feasibility_study:
  id: <STUDY_ID>
  version: <STUDY_VERSION>
  title: <STUDY_TITLE>
  artifact_path: <STUDY_PATH>
  artifact_sha256: <STUDY_SHA256>

catalog:
  artifact_path: <CATALOG_PATH>
  entities_catalogued: <COUNT>
  entities_access_confirmed: <COUNT>

recommendation:
  verdict: <proceed|proceed-with-scope-reduction|do-not-proceed|insufficient-evidence>
  summary: <ONE_PARAGRAPH>
  confidence: <high|medium|low>
  decided_at: <ISO_8601_TIMESTAMP>

evidence:
  hypotheses_tested: <COUNT>
  hypotheses_supported: <COUNT>
  baseline_established: <true|false>
  baseline_summary: <DESCRIPTION_OR_NULL>

functional_candidates:
  - id: <FC_ID>
    statement: <WHAT_THE_SYSTEM_MUST_DO>
    evidence_ref: <STUDY_SECTION>
    confidence: <high|medium|low>

nfr_candidates:
  - id: <NFR_ID>
    category: <performance|security|privacy|rai|data-integrity|reliability|maintainability>
    statement: <CONSTRAINT_OR_QUALITY_ATTRIBUTE>
    evidence_ref: <STUDY_SECTION>
    source: <feasibility|catalog|privacy-planner|rai-planner>

constraints:
  - id: <CONSTRAINT_ID>
    summary: <WHAT_LIMITS_THE_SOLUTION>
    category: <data|access|legal|technical|cost>
    blocking: <true|false>

gaps:
  - id: <GAP_ID>
    summary: <WHAT_PREVENTED_A_STRONGER_CONCLUSION>
    remediation: <WHAT_WOULD_CLOSE_IT>

cross_agent_refs:
  privacy_plan_ref: <PATH_OR_NULL>
  rai_plan_ref: <PATH_OR_NULL>
  adr_refs: [<PATH>]

prd_consumer_notes: <CONSUMER_NOTES>
```

### Why `nfr_candidates` carries a `category`

This is the mechanism behind the design's most valuable claim: the handoff pulls data engineering and data science into non-functional disciplines they routinely skip.

The categories map to work already happening elsewhere in the repo: `privacy` to `privacy-planner`, `rai` to `rai-planner`, `performance` to `performance-slo-planner`, `data-integrity` to `ds-dataops` invariants. The handoff surfaces them as candidate requirements rather than letting them evaporate at the end of a feasibility study.

### Emission is conditional

The payload is produced at Recommend-phase exit **only when the verdict permits forward movement**. A `do-not-proceed` verdict emits the study and the gaps, not requirement candidates.

### Consumer-side work

`requirements-author` PRD Assess currently checks for `BRD_TO_PRD_HANDOFF_V1`. Accepting a second payload type is an additive change to one Assess-phase step, not a redesign.

**Open for the owner of that skill:** whether to formalize this payload or treat the handoff as conversational. The formal payload is proposed because it makes the NFR carry-forward checkable rather than dependent on the user remembering to mention it.

---

## 3. Agent Identity

| Property           | Value                                                               |
|--------------------|---------------------------------------------------------------------|
| Name               | `Data Workstream Coach`                                             |
| Path               | `.github/agents/data-science/data-workstream-coach.agent.md`        |
| Foundation skill   | `.github/skills/data-science/data-workstream-foundation/SKILL.md`   |
| State              | `.copilot-tracking/ds/{project-slug}/session-state.md`              |
| Disclaimer heading | `## Data-Science Coaching` in `disclaimer-language.instructions.md` |

**Naming rationale.** "Workstream" reflects the corrected research finding that the data scientist owns a workstream forking from the BRD-derived project description and feeding the PRD (not a project, not a phase). "Coach" signals the `dt-coach` archetype rather than a planner, which sets accurate user expectations about gates and completion.

**Job routing lives in the foundation skill**, following `dt-coach` rather than the planner identity-instructions pattern. This keeps the agent body thin and makes the routing protocol loadable on demand rather than resident.

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

---

## 4. ERD Rendering

### Resolution: render from the catalog, do not parse source files

The review flagged that ERD support would require SQL DDL, Prisma, and SQLAlchemy parsers, plus cardinality inference without database introspection. That work disappears if the ERD renders from the catalog's `entities` and `relationships` blocks, which already carry names, join keys, and explicit cardinality.

**The catalog is the parse target.** Establishing entities and relationships is cataloging work the data scientist does with domain experts, exactly the CSE Data Discovery activity that calls for an ERD. Inferring it from DDL would be less accurate anyway, since DDL rarely encodes the semantic relationships that matter.

### Contract to `architecture-diagrams`

The skill gains one input type. Its existing four-step contract holds: discovery, parsing, relationship mapping, generation, with the catalog frontmatter as a structured input requiring no new parser.

| Existing behavior                      | ERD addition                                            |
|----------------------------------------|---------------------------------------------------------|
| Parses IaC to find components          | Reads catalog `entities`                                |
| Maps component relationships           | Reads catalog `relationships` with declared cardinality |
| Renders ASCII or Mermaid by preference | Adds Mermaid `erDiagram` output                         |
| Format preference in state             | Unchanged                                               |

Mermaid's `erDiagram` syntax expresses cardinality natively, so notation is a rendering concern rather than an inference problem.

**Relationship confidence renders visibly.** Inferred and assumed relationships are marked in the diagram so a reviewer can see what has been confirmed. This is why `confidence` is a catalog field.

---

## 5. Scanner `--data` Mode

Extends `scan_sensitive_content.py`. Preserves current behavior for ADR callers; activates additional rules only under `--data`.

### Rule set

**Column-name detection, denylist against structured input only.**

The current scanner avoids name heuristics because prose produces false positives. Catalog frontmatter and schema definitions are structured, so the noise problem does not apply. This rule activates only under `--data`.

| Confidence | Column-name patterns                                                                                                                                                                   |
|------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `high`     | `ssn`, `social_security`, `national_id`, `passport`, `tax_id`, `drivers_license`, `credit_card`, `card_number`, `cvv`, `account_number`, `routing_number`                              |
| `warn`     | `dob`, `date_of_birth`, `birth_date`, `email`, `phone`, `address`, `postal`, `zip`, `patient_id`, `member_id`, `mrn`, `full_name`, `first_name`, `last_name`, `salary`, `compensation` |

Matched case-insensitively with word-boundary and underscore-separator tolerance so `patientId`, `patient_id`, and `PatientID` all match.

**Explicitly excluded** to control false positives: `customer_id`, `order_id`, `user_id`, `batch_size`, `order_date`, `created_at`, and any name whose only sensitive-adjacent token is `id` on a non-personal entity. Generic surrogate keys are not disclosure risks.

**Connection strings and credentials (`high`).**

| Category                  | Shape                                                                                  |
|---------------------------|----------------------------------------------------------------------------------------|
| `connection_string`       | `Server=`, `Data Source=`, `Initial Catalog=`, `User Id=`, `Password=` key-value pairs |
| `jdbc_odbc_uri`           | `jdbc:`, `odbc:` URI prefixes                                                          |
| `db_uri_with_credentials` | `postgres://`, `mysql://`, `mongodb://`, `redis://` containing a userinfo segment      |
| `sas_token`               | Query strings containing `sig=` alongside `se=` and `sp=`                              |
| `storage_key`             | `AccountKey=` followed by a base64-shaped value                                        |
| `bearer_token`            | `Authorization: Bearer` followed by a token-shaped value                               |

**Sample-row detection (`warn`).** Markdown table rows or JSON arrays under a heading or key matching `sample`, `example`, or `preview` are flagged advisory. A structural signal that a row of real data may have been pasted; not confidently distinguishable from synthetic data, so it does not block alone.

**Non-US identifier and phone shapes (`high`).** Extends the existing US-only patterns: UK National Insurance, Canadian SIN, E.164 international phone format. Enumerated per locale as needed rather than attempted generically.

**Customer and tenant identifiers (configurable).** Engagement-specific, so a `--denylist <path>` argument accepts a caller-supplied term list. Terms match at `high` confidence. This keeps customer names out of the shared ruleset.

### Behavior

Any `high` finding sets non-zero exit and blocks the write, matching the current contract. `warn` findings surface for review without blocking. The existing `_redact()` masking and JSON finding shape are reused unchanged.

**On block**, the agent reports the finding category and masked preview, then requires explicit user confirmation that content has been redacted before retrying. Automatic masking is not offered: the user must see what was flagged.

---

## Still Requiring a Decision

### Collection migration

`collections/data-science.collection.yml` lists five agents and one prompt that this design absorbs. Three options:

| Option         | Effect                                                               |
|----------------|----------------------------------------------------------------------|
| Delete         | Clean, breaking for anyone invoking them directly                    |
| Deprecate      | Mark `maturity: deprecated`, keep working, remove in a later release |
| Keep alongside | The unified agent is additive; specialists remain for direct use     |

Deprecation is the conventional middle path and the manifest schema already supports the `deprecated` maturity value. This is a product decision, not a technical one.

### Smaller items

| Item                          | Status                                                                                                                                                                                                 |
|-------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Notebook-to-package threshold | Suggest 15 lines of transformation logic in one cell, matching the existing `gen-jupyter-notebook` cell-length convention. Repeated execution detected by cell duplication rather than execution count |
| Privacy threshold             | Suggest `classification.sensitivity` of `restricted`, or `contains_personal_data: true` combined with an unset `dpia_ref`                                                                              |
| Catalog enrichment trigger    | User-driven. The agent may notice an uncatalogued source and offer, but never enriches silently                                                                                                        |
| Experiment skill scope        | New skill under `.github/skills/data-science/`, referenced by the existing `experiment-designer` agent. The agent file gains a reference; its scope does not narrow                                    |
| Feasibility output template   | The twelve CSE sections are the template. Recommend phase adds verdict, evidence summary, and the handoff payload                                                                                      |

---

<!-- markdownlint-disable MD036 -->

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
