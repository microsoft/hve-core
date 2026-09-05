---
title: DS_CATALOG_V1 DCAT crosswalk
description: Non-binding mapping from the native catalog contract to selected DCAT, DCTERMS, and PROV terms
---

## Status

This crosswalk supports future export design. `DS_CATALOG_V1` is YAML, while DCAT conformance requires an RDF description. The mapping does not rename native fields, vendor an upstream shape, or claim DCAT, DCAT-AP, DCMI, or PROV conformance.

## Mapping

| Native field                               | Nearest external term                            | Fidelity | Export note                                                       |
|--------------------------------------------|--------------------------------------------------|----------|-------------------------------------------------------------------|
| Catalog document                           | `dcat:Catalog`                                   | exact    | One engagement catalog maps to one catalog resource               |
| `engagement`                               | `dcterms:title`                                  | exact    | Catalog title                                                     |
| `generated_at`                             | `dcterms:issued`                                 | exact    | Initial publication time                                          |
| `last_enriched`                            | `dcterms:modified`                               | exact    | Latest enrichment time                                            |
| `entities[]`                               | `dcat:Dataset`                                   | exact    | One entity maps to one dataset resource                           |
| `entities[].id`                            | IRI and `dcterms:identifier`                     | exact    | Export must mint a stable IRI                                     |
| `entities[].name`                          | `dcterms:title`                                  | exact    | Customer-readable name                                            |
| `entities[].description`                   | `dcterms:description`                            | exact    | Description                                                       |
| `entities[].source.system`                 | `dcterms:source` or `dcterms:publisher`          | partial  | Source system is not always a publishing organization             |
| `entities[].source.location`               | `dcat:accessURL` or `dcat:downloadURL`           | partial  | Requires a distribution and may not be a URL                      |
| `entities[].source.format`                 | `dcterms:format` or `dcat:mediaType`             | exact    | Applies to a distribution                                         |
| `entities[].source.access_confirmed`       | No direct term                                   | none     | Engagement-operational state remains native                       |
| `entities[].tier`                          | No direct term                                   | none     | DataOps tier remains native                                       |
| `entities[].grain`                         | No direct term                                   | none     | Retain in description or an export extension                      |
| `entities[].volume.period_covered`         | `dcterms:temporal`                               | exact    | Temporal coverage                                                 |
| `entities[].volume.update_frequency`       | `dcterms:accrualPeriodicity`                     | exact    | Native readable name remains unchanged                            |
| `entities[].profile_ref`                   | `dcat:qualifiedRelation` with an export role     | partial  | Related artifact pointer                                          |
| `entities[].classification.sensitivity`    | `dcterms:accessRights`                           | partial  | Export requires an appropriate controlled vocabulary              |
| `entities[].lineage.derived_from`          | `prov:wasDerivedFrom`                            | exact    | Provenance relation                                               |
| `entities[].lineage.transform_ref`         | `prov:wasGeneratedBy`                            | partial  | Native value is a code reference rather than a PROV activity      |
| `relationships[]`                          | `dcat:qualifiedRelation` and `dcat:Relationship` | partial  | Association-node pattern fits, but payload fields remain native   |
| Relationship endpoints                     | `dcterms:relation`                               | partial  | Export profile must define endpoint roles                         |
| Relationship cardinality, keys, confidence | No direct term                                   | none     | Load-bearing native fields require an export profile or extension |
| `coverage`                                 | No direct term                                   | none     | Engagement progress remains native                                |

The `from_minimum` and `to_minimum` endpoint values share the cardinality row: they are load-bearing native facts with no direct external term, so an export profile or extension must carry them.

## Sources

* W3C, [Data Catalog Vocabulary (DCAT) Version 3](https://www.w3.org/TR/vocab-dcat-3/), W3C Recommendation, 2024-08-22
* W3C, [PROV-O: The PROV Ontology](https://www.w3.org/TR/prov-o/), W3C Recommendation, 2013-04-30
* DCMI, [Metadata Terms](https://www.dublincore.org/specifications/dublin-core/dcmi-terms/), DCMI Recommendation
