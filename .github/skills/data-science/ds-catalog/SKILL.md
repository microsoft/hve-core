---
name: ds-catalog
description: "Create and enrich durable data catalogs using the native DS_CATALOG_V1 Markdown contract, declared entity relationships, privacy citation fields, and stable relationship IDs. Use when inventorying engagement data, recording semantic relationships, or preparing a catalog for ERD rendering."
license: CC-BY-4.0
user-invocable: false
metadata:
  authors: "Microsoft (planning synthesis)"
  spec_version: "1.0"
  last_updated: "2026-08-03"
  content_based_on: "https://www.w3.org/TR/vocab-dcat-3/; https://www.w3.org/TR/prov-o/; https://www.dublincore.org/specifications/dublin-core/dcmi-terms/; https://datapackage.org/standard/table-schema/"
---

# Data Catalog Workflow

## Goal

Produce a customer-readable Markdown catalog whose YAML frontmatter is a valid `DS_CATALOG_V1` machine contract. Preserve uncertainty explicitly so inferred or assumed relationships never appear confirmed.

## Flow

1. Confirm the engagement name and the caller-approved durable output path.
2. Inventory entities at business grain. Record source access, tier, volume, profile pointer, classification, lineage, and open questions without copying column-level profile data.
3. Assign every relationship a stable `rel-*` identifier. Record endpoints, maximum cardinality, both endpoint minimums, one or more paired join-key fields, confidence, and evidence basis.
4. Reconcile coverage counts with the entity and relationship records.
5. Render the human-readable sections from the YAML facts, ending with the canonical Data-Science Coaching disclaimer footer. Narrative can explain facts but cannot redefine them.
6. Validate the artifact with `scripts/validate_catalog.py` before treating it as ready for review.

## Inputs

* Engagement context and a caller-approved output path
* Data source inventory and access status
* Business entity names, grain, and declared relationships
* Existing per-dataset profile paths, when available
* Privacy classifications or standards citations produced by the owning privacy workflow

## Success criteria

* The frontmatter declares exactly `catalog_version: DS_CATALOG_V1` and validates against `assets/ds-catalog-v1.schema.json`.
* Entity IDs and relationship IDs are unique and stable. Every endpoint and lineage reference resolves.
* Every relationship declares `cardinality` as its maximum multiplicity plus `from_minimum` and `to_minimum` as `zero` or `one`.
* Join keys use one string on both sides or paired arrays of equal length, and record field names only without primary-key, foreign-key, or uniqueness roles.
* Relationship confidence is one of `confirmed`, `inferred`, or `assumed`, and every relationship records its basis.
* Classification uses the `privacy-standards` citation-field names. The catalog does not invent standards identifiers.
* Column statistics and feature metadata remain behind `profile_ref` rather than being copied into the catalog.
* Every customer-facing catalog ends with the canonical Data-Science Coaching disclaimer footer.

## Constraints

* Treat catalog enrichment as user-driven. Offer enrichment when a source is missing, but do not change the catalog silently.
* Record source locations as paths or connection references, never embedded credentials.
* Keep DCAT alignment non-binding. The catalog is native YAML, not RDF, and makes no DCAT conformance claim.
* Keep tier recording separate from tier behavior. `ds-catalog` records the tier; `ds-dataops` owns what that tier means.
* Keep rendering separate from semantic authority. Diagram tools consume declared relationships and do not infer new ones.
* End every customer-facing catalog with the canonical Data-Science Coaching disclaimer from `disclaimer-language.instructions.md`.

## Stop rules

* Stop and request clarification when an entity grain, relationship endpoint, join-key pairing, or endpoint minimum is ambiguous.
* Stop and retain `inferred` or `assumed` confidence when evidence does not support `confirmed`.
* Stop before a durable write when the caller has not confirmed the destination.
* Stop and route privacy interpretation to `privacy-standards` or the Privacy Planner when citation values or DPIA status are unknown.

## Package resources

| Resource                                              | Use                                                                                         |
|-------------------------------------------------------|---------------------------------------------------------------------------------------------|
| [catalog-contract.md](references/catalog-contract.md) | Read for the authoritative field, identity, multiplicity, and body-generation rules         |
| [dcat-crosswalk.md](references/dcat-crosswalk.md)     | Read when planning a DCAT, DCAT-AP, or catalog-platform export                              |
| [provenance.md](references/provenance.md)             | Read for standards selection, licensing, and non-conformance boundaries                     |
| [ds-catalog-v1.md](templates/ds-catalog-v1.md)        | Copy when starting a new catalog                                                            |
| [northwind-catalog.md](examples/northwind-catalog.md) | Read as a complete valid example with scalar and composite join keys                        |
| `assets/ds-catalog-v1.schema.json`                    | Use as the structural JSON Schema for parsed frontmatter                                    |
| `scripts/validate_catalog.py`                         | Execute with `uv run python scripts/validate_catalog.py <catalog.md>` to validate a catalog |

## Attribution

The native contract, workflow, schema, template, examples, and validator are repository-original content licensed CC BY 4.0.

The crosswalk paraphrases selected concepts from W3C DCAT 3, W3C PROV-O, and Frictionless Table Schema v2. Standard names and term identifiers are factual citations, the crosswalk prose and the paired-array join-key contract are independently authored, and no upstream schema, example, table, or substantial excerpt is reproduced. Because no upstream expression is redistributed, the package remains solely CC BY 4.0. See [provenance.md](references/provenance.md).
