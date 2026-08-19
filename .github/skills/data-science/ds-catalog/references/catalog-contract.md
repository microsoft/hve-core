---
title: DS_CATALOG_V1 contract
description: Authoritative field, identity, compatibility, and narrative rules for the native data catalog contract
---

## Contract identity

`DS_CATALOG_V1` is a project-owned YAML-frontmatter contract embedded in a durable Markdown catalog. It is a discovery record, not a publication format or a producer-consumer data contract. It can record incomplete access and uncertain relationships honestly.

The parsed frontmatter is authoritative for machine facts. Narrative sections explain those facts and provide customer context; they do not redefine IDs, endpoints, cardinality, confidence, classifications, or coverage.

## Compatibility policy

`DS_CATALOG_V1` is the initial schema identity. It is a complete first definition, not a compatibility boundary carried over from an earlier release, so no migration path or legacy acceptance mode exists.

Consumers accept a catalog only when `catalog_version` is exactly `DS_CATALOG_V1`. Additive optional fields are compatible. Removing a required field, changing an enum, or changing a field's meaning requires a new contract version.

Unknown fields are rejected so misspellings do not silently become machine facts. Consumers preserve the source artifact and report unsupported versions rather than guessing.

## Entity records

Every entity has a stable kebab-case `id` and a customer-readable `name`. The ID survives display-name, source-location, profile, and tier changes. Never reuse an ID for another concept.

Required entity concerns are:

* Description and grain
* Source system, location reference, format, and access confirmation
* Recorded tier
* Volume estimate, covered period, and update frequency
* Optional pointer to a dated per-dataset profile
* Classification, standards citations, and optional DPIA reference
* Lineage pointers and transformation reference
* Open questions

A missing `profile_ref` is valid. A stale pointer becomes an open question and is not replaced with copied profile content.

## Privacy vocabulary

The classification object uses all five citation-field names published by `privacy-standards`:

* `gdpr_article`
* `ccpa_section`
* `nist_pf_category`
* `nistir8062_objective`
* `owasp_privacy_id`

Values are standards references supplied by the owning privacy workflow, or `null` when no mapping exists. The local operational fields `sensitivity`, `contains_personal_data`, `data_categories`, and `dpia_ref` support engagement routing; they are not presented as a standard taxonomy.

## Relationship identity and join keys

Every relationship has a stable ID matching `rel-[a-z0-9-]+`. Assign the ID once and retain it when confidence, basis, or key details change. Retire an obsolete relationship by removing it only when retained repository history is sufficient for the engagement's audit needs; never reuse its ID.

`from` and `to` resolve entity IDs. `cardinality` is declared, never inferred by a renderer. `confidence` states evidence quality:

* `confirmed`: verified by an authoritative source or domain owner
* `inferred`: supported by technical evidence but not yet confirmed
* `assumed`: proposed from workshop or design context without technical confirmation

`join_keys.from_field` and `join_keys.to_field` each accept either one string or an array. Both sides use the same representation and arrays have equal nonzero length. Array position defines each composite-key pair.

Join keys record the declared field names used to relate two entities. They do not declare primary keys, foreign keys, uniqueness, or any other database constraint role, so consumers render them role-neutrally.

## Endpoint multiplicity

`cardinality` records maximum multiplicity only. `from_minimum` and `to_minimum` are required and record the minimum multiplicity of each endpoint using `zero` or `one`.

Each endpoint value describes that endpoint's own side of the relationship, matching entity-relationship convention: `from_minimum` is the minimum number of `from` entities related to one `to` entity, and `to_minimum` is the minimum number of `to` entities related to one `from` entity. `zero` makes that side optional; `one` makes it mandatory.

The maximum on each side is derived from `cardinality`:

| `cardinality`  | `from` maximum | `to` maximum |
|----------------|----------------|--------------|
| `one-to-one`   | one            | one          |
| `one-to-many`  | one            | many         |
| `many-to-many` | many           | many         |

A renderer combines each endpoint's declared minimum with its derived maximum and never infers optionality. Omitting either field, supplying only one side, or supplying a value outside `zero|one` is invalid.

## Coverage reconciliation

Coverage counts are derived from records:

* `entities_catalogued` equals the entity count.
* `entities_access_confirmed` counts entities with confirmed access.
* `entities_classified` counts entities whose `sensitivity` is not `none` or whose privacy citation fields contain at least one non-null value.
* `relationships_confirmed` and `relationships_inferred` count their matching confidence values. Assumed relationships remain visible but have no separate legacy coverage counter in V1.

The validator rejects mismatched counts.

## Human-readable body

After the frontmatter, retain these sections:

1. Overview and engagement context
2. Entity summary
3. Entity relationship diagram or a pointer to it, always accompanied by its text equivalent
4. Per-entity detail
5. Coverage summary
6. Open questions and access gaps
7. Data-Science Coaching disclaimer footer

### Diagram text equivalent

A rendered diagram is never the only representation of the declared relationships. Every catalog that carries a diagram, or a pointer to one, also carries a relationship table conveying the same facts in text.

The table records one row per declared relationship, with the endpoints, the cardinality, the endpoint minimums, the join keys, and the confidence. Parity runs both ways: every relationship shown in the diagram appears as a row, and every row appears in the diagram.

This keeps the catalog readable when the diagram cannot be seen or rendered, and it keeps the declared model available to readers who consume the document as text.

## Attached dataset profiles

A catalog entity describes what something is and how it relates to other things. A dataset profile describes one dataset's columns and their observed shape. The profile is an attachment reachable from the entity through `profile_ref`, not a competing record. Keep column-level detail in the profile and keep identity, relationships, and lineage in the catalog.

### Semantic roles

A column's semantic role is what it does analytically, which is distinct from its storage type. Use exactly these values so downstream consumers can rely on them:

| Role       | Meaning                                          |
|------------|--------------------------------------------------|
| `id`       | Identifies a record or references another entity |
| `time`     | Carries an event or observation timestamp        |
| `metric`   | A measured quantity suitable for aggregation     |
| `category` | A bounded set of discrete values                 |
| `text`     | Free-form text not intended as a category        |
| `boolean`  | A two-state flag                                 |
| `derived`  | Computed from other columns rather than sourced  |
| `unknown`  | Role not yet established                         |

A column's role is a claim about meaning, so an unresolved role stays `unknown` rather than being guessed from its type.

### Profile record shape

A profile carries the dataset identity, when it was generated, its source, the sample size the observations rest on, and a record per column:

| Field                                             | Meaning                                                                                                         |
|---------------------------------------------------|-----------------------------------------------------------------------------------------------------------------|
| `name`                                            | Column name as it appears in the source                                                                         |
| `inferred_type`                                   | Storage or parsed type                                                                                          |
| `semantic_role`                                   | One of the roles above                                                                                          |
| `non_null_count`, `missing_pct`, `distinct_count` | Completeness and cardinality observations                                                                       |
| `example_values`                                  | A small illustrative sample, capped at roughly five values                                                      |
| `stats`                                           | Type-appropriate summary: range and central tendency for numeric, top values for categorical, span for temporal |
| `quality_notes`                                   | Observed issues and the assumptions made about them                                                             |

Alongside the columns, a profile records candidate keys, the primary time column when one exists, columns grouped by role, candidate targets when relevant, and quality flags.

### Sample-derived values are provisional

Every observation computed from a sample is provisional and must be labelled as such. A uniqueness observation over a sample suggests a candidate key; it does not establish one. Promote a candidate to a declared key only through the relationship and identity rules above, which require confirmation rather than observation.

Cap illustrative values deliberately. A profile is metadata about a dataset, and a profile carrying enough example rows to reconstruct sensitive content has become a copy of the data rather than a description of it. Apply the same sensitivity classification to a profile that applies to its entity.

### Declared objectives

When the engagement has stated analytical intent, record it beside the profile: the objective type, the business questions behind it, the metrics that matter, and what success would look like. Declared intent is what lets a later analysis prioritize; without it, every column looks equally important.

The footer is the canonical Data-Science Coaching disclaimer published by `disclaimer-language.instructions.md`. Reproduce it verbatim as the last section of every customer-facing catalog, including the template and the complete example.

Generate tables and diagrams from frontmatter. When narrative and machine facts disagree, correct the narrative or update frontmatter through an explicit enrichment decision.
