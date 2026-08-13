---
name: ds-feasibility
description: "Author and validate durable data and ML feasibility studies using the Feasibility Study Interchange Profile, constrained YAML authority, UUID URN identity, lifecycle lineage, and evidence traceability. Use when assessing whether available data and technical evidence support a proposed outcome."
license: CC-BY-4.0
user-invocable: false
metadata:
  authors: "Microsoft (planning synthesis)"
  spec_version: "1.0"
  last_updated: "2026-08-03"
  content_based_on: "https://specif.de/; https://docs.oasis-open-projects.org/oslc-op/rm/v2.1/os/; https://www.w3.org/TR/prov-o/; https://www.dublincore.org/specifications/dublin-core/dcmi-terms/; https://www.rfc-editor.org/rfc/rfc9562.html; https://json-schema.org/draft/2020-12/"
---

# Data and ML Feasibility Workflow

## Goal

Produce one durable Markdown feasibility study that remains useful to people and can be consumed later by a Functional Planner. One constrained YAML block owns machine facts; narrative sections preserve evidence, interpretation, and context.

## Flow

1. Confirm the proposed outcome, decision boundary, study scope, and durable output path.
2. Allocate UUIDv4 URNs for the study concept, study revision, each item concept, each item revision, and each relation. Never derive identity from a title, class, path, or content.
3. Capture candidate capabilities, constraints, assumptions, findings, risks, dependencies, decisions, evidence, gaps, and non-goals. Preserve uncertainty and source-authored criteria without promoting every item to a requirement.
4. Record lifecycle and provenance. Reclassification keeps conceptual identity and creates a new revision. Split, merge, derivation, withdrawal, and supersession retain explicit lineage.
5. Write or update the single named `FEASIBILITY-STUDY-INTERCHANGE` YAML block. Narrative can explain machine facts but cannot redefine them.
6. Validate constrained YAML, JSON Schema 2020-12 structure, semantic closure, revision lineage, tombstones, and narrative anchors with `scripts/validate_feasibility.py`.
7. Present the recommendation and unresolved review gaps. Preserve the study as read-only evidence for downstream consumers.
8. After the study is final, emit the sibling feasibility-to-PRD handoff described in [feasibility-to-prd-handoff.md](references/feasibility-to-prd-handoff.md). Regenerate it after any material study revision.

## Inputs

* Problem definition, desired outcome, and decision the study must support
* Data access, discovery, architecture, exploration, preprocessing, and experiment evidence
* Source-authored acceptance criteria, when known
* Risk, privacy, Responsible AI, performance, and operational evidence
* Prior study revision and item identity registry, when revising an existing study

## Success criteria

* Exactly one named constrained YAML block declares `profile: feasibility-study-interchange` and `profile_version: 1.0.0`.
* Study, item, relation, and revision IDs are RFC 9562 UUID URNs. Conceptual and revision IDs are unique and never reused.
* Item class, status, alias, planning relevance, relations, provenance, confidence, review, and location remain separate fields.
* Revision lineage is closed and acyclic. Current revisions appear in the revision registry.
* Withdrawn and superseded items remain as complete tombstones. Split, merge, supersession, and derivation targets resolve.
* Every item has one matching narrative anchor, and narrative has no unknown item anchor.
* Missing criteria remain explicit. The workflow does not invent acceptance criteria.
* Each confirmed Recommend exit produces a handoff carrying the verdict, evidence, constraints, gaps, and the `study_revision_id` it was generated from.

## Constraints

* The study does not assign `FR-###` or `NFR-###`. `display_ref` uses the study-local, type-neutral `FS-###` alias only.
* The study's constrained YAML block remains the authority for every machine fact. The handoff is a derived summary that never redefines a study fact; a disagreement resolves in favor of the study.
* The handoff carries no version constant and no content hash. Recognition uses `kind`, and freshness is judged from `study_revision_id`.
* Downstream Functional Planner adoption is a separate workstream. This package does not claim current direct compatibility with Functional Planner.
* Downstream consumers remain read-only toward the study. They own their UUID-to-requirement mapping and traceability views.
* Do not claim SpecIF, OSLC RM, ReqIF, PROV, DCMI, or JSON-LD conformance. The profile maps selected concepts without implementing those complete standards.
* Keep YAML JSON-compatible: string keys, JSON scalar values, arrays, and objects only. Do not use aliases, anchors, merge keys, custom tags, timestamps as native YAML objects, or ordering-dependent meaning.

## Stop rules

* Stop at a hard decision boundary when the problem or desired outcome remains ambiguous.
* Stop and record `needs_review` when criteria, evidence, lifecycle disposition, or relation meaning cannot be established from sources.
* Stop before changing a conceptual ID because a title, class, status, alias, or location changed. Create a new revision instead.
* Stop before deleting a withdrawn or superseded concept. Retain a tombstone with reason, effective time, last revision, and explicit successor state.
* Stop before any downstream writeback to the study. Record mappings in downstream-owned artifacts.

## Package resources

| Resource                                                                  | Use                                                                                                             |
|---------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------|
| [interchange-profile.md](references/interchange-profile.md)               | Read for authority, constrained YAML, identity, lifecycle, compatibility, and producer rules                    |
| [standards-crosswalk.md](references/standards-crosswalk.md)               | Read for SpecIF, OSLC RM, PROV, and DCMI mappings and non-conformance boundaries                                |
| [provenance.md](references/provenance.md)                                 | Read for source licensing, attribution, and profile independence                                                |
| [feasibility-to-prd-handoff.md](references/feasibility-to-prd-handoff.md) | Read for the sibling handoff's emission trigger, field set, verdict presence rules, and regeneration obligation |
| [feasibility-study.md](templates/feasibility-study.md)                    | Copy when starting a study                                                                                      |
| [valid-study.md](examples/valid-study.md)                                 | Read as a valid profile fixture with revision, evidence, and dependency relations                               |
| `assets/feasibility-study-interchange-1.0.0.schema.json`                  | Use as the local structural JSON Schema 2020-12 profile                                                         |
| `scripts/validate_feasibility.py`                                         | Execute with `uv run python scripts/validate_feasibility.py <study.md>` before publishing a revision            |

## Attribution

The Feasibility Study Interchange Profile, schema, template, examples, and validator are independently authored repository content licensed CC BY 4.0.

Selected concepts are mapped to open specifications for interoperability vocabulary only. No upstream schema, example, or substantial prose is reproduced. See [provenance.md](references/provenance.md).

