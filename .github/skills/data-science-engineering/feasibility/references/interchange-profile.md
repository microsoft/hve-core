---
title: Feasibility Study Interchange Profile 1.0.0
description: Authoritative constrained YAML, identity, lifecycle, traceability, compatibility, and producer rules
---

## Profile identity

The profile identifier is `feasibility-study-interchange`; the supported version is `1.0.0`. It is an independently authored application profile for one durable Markdown study. It does not create a temporary handoff payload.

Consumers reject unsupported profile versions. Additive optional fields require a reviewed profile revision because the schema rejects unknown properties. Breaking field, enum, or semantic changes require a new major profile version.

## One machine-fact authority

The Markdown study contains exactly one block between these markers:

```text
<!-- BEGIN FEASIBILITY-STUDY-INTERCHANGE -->
```yaml
profile: feasibility-study-interchange
...
```
<!-- END FEASIBILITY-STUDY-INTERCHANGE -->
```

The parsed YAML projection is authoritative for identity, revision, class, status, alias, planning relevance, relations, provenance, confidence, review, location, timestamps, and criteria state. Narrative supplies explanation and evidence interpretation. When prose conflicts with the block, correct the prose or make an explicit machine-fact revision.

## Constrained YAML

The block uses the JSON-compatible subset of YAML 1.2:

* String mapping keys with no duplicates
* Strings, numbers, booleans, `null`, arrays, and objects
* Quoted RFC 3339 timestamps so parsers retain strings
* No anchors, aliases, merge keys, custom tags, binary values, sets, or ordering-dependent meaning

The local JSON Schema validates the parsed object. The semantic validator adds rules JSON Schema cannot express.

## Identity

Use UUIDv4 by default and serialize every identifier as lowercase `urn:uuid:<uuid>`. Conceptual IDs and revision IDs have different jobs:

| Field               | Purpose                                                     |
|---------------------|-------------------------------------------------------------|
| `study_id`          | Enduring study concept identity                             |
| `study_revision_id` | Immutable identity of the current published study snapshot  |
| `item_id`           | Enduring feasibility-item concept identity                  |
| `item_revision_id`  | Immutable identity of the current item snapshot             |
| `relation_id`       | Stable identity of one typed relation assertion             |
| `display_ref`       | Study-local `FS-###` review alias, never a primary identity |
| `location`          | Mutable file-and-anchor locator                             |

Never derive UUIDv5 identity from paths, titles, classes, or content. File moves, heading changes, reclassification, alias corrections, and status changes do not change a concept ID. Authoritative changes create a new revision ID.

The `revision_registry` retains every published study and item revision. Revision IDs are globally unique, each `revision_of` target resolves within the same concept, and lineage is acyclic. Current revision IDs must be present in the registry.

## Item classes and planning relevance

Classes preserve feasibility uncertainty:

* `capability-candidate`
* `constraint`
* `assumption`
* `finding`
* `risk`
* `dependency`
* `decision`
* `evidence`
* `gap`
* `non-goal`

`planning_relevance` is separate and can be `candidate`, `context`, or `not-applicable`. A downstream planner can select capability candidates without treating every finding or risk as a work item.

Criteria state is explicit: `defined`, `partial`, `not-yet-defined`, or `not-applicable`. Empty criteria are valid only for the last two states. Producers do not infer missing criteria.

## Relations

Relations are separate records so rationale, confidence, provenance, and review state travel with the edge. Supported relation types are:

* `depends-on`, `constrains`, `satisfies`, `implements`, and `validates`
* `evidenced-by`
* `supersedes`
* `split-from` and `merged-from`
* `derived-from`
* `related-to`

Targets are conceptual item IDs. Relation meanings map to OSLC RM only when exact; profile-owned types remain profile-owned. Document hierarchy and tracker parenting are not encoded as semantic relations.

## Provenance

Study and item provenance keeps:

* `attributed_to`: a human or organizational actor label
* `source_refs`: durable source paths, URLs, or evidence identifiers
* `generated_at`: timestamp of the recorded assertion

Evidence items are ordinary typed items. `evidence_refs` point to item IDs whose class is `evidence`. `derived-from` relations and provenance source references preserve derivation without implying truth or approval.

## Lifecycle

| Event            | Required behavior                                                                                                                   |
|------------------|-------------------------------------------------------------------------------------------------------------------------------------|
| Revision         | Keep conceptual ID, allocate a new revision ID, and link it through `revision_of` and the registry                                  |
| Reclassification | Keep conceptual ID and alias; allocate a new revision ID                                                                            |
| Move             | Update `location`; identity remains unchanged                                                                                       |
| Split            | Allocate new concept IDs with `split-from` relations; retain the source as active or a complete superseded tombstone                |
| Merge            | Allocate a new concept ID by default with multiple `merged-from` relations; retain source tombstones                                |
| Derivation       | Allocate a new concept ID and use `derived-from`; preserve source study and item identity                                           |
| Withdrawal       | Keep the concept and revisions; require reason, effective time, and an explicit empty or populated successor list                   |
| Supersession     | Keep the old concept; require reason, effective time, and at least one successor; successor records the predecessor where practical |

`active`, `proposed`, `accepted`, and `rejected` records can have a null lifecycle reason and empty predecessor or successor lists. `withdrawn` and `superseded` records require complete tombstone fields. IDs are never reused.

## Narrative anchors

Every item declares `narrative_anchor` equal to the lowercase display reference, for example `fs-001`. The Markdown body has exactly one level-three heading beginning with the display reference, such as `### FS-001: Confirm source access`. The validator rejects missing, duplicate, and unknown item headings.

## Producer validation

Run validation before publishing each revision:

1. Extract exactly one named block.
2. Reject prohibited YAML constructs and duplicate keys.
3. Parse to JSON-compatible values and validate against the local 2020-12 schema.
4. Validate conceptual and revision ID uniqueness, registry closure, and acyclic revision lineage.
5. Validate relation and evidence closure, class compatibility, split and merge lineage, and tombstone completeness.
6. Validate criteria-state consistency and narrative-anchor correspondence.

A structurally valid study still requires human review of evidence truth, recommendation quality, privacy, and authorization.

