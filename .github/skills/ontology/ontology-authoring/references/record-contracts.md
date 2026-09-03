---
title: Ontology lifecycle record contracts
description: Authority and rendering map for ontology lifecycle templates
ms.date: 2026-09-03
ms.topic: reference
---

## Purpose

Lifecycle templates make state and package evidence reviewable by people. They
do not replace the state schema, package manifest schema, normalized evidence,
semantic policy, Turtle ontology, or SHACL shapes.

Copy the selected template into the active validated project root, replace every
placeholder, remove authoring guidance, and record the rendered artifact and its
SHA-256 in state. Never edit a generated authority artifact through its review
projection.

## Authority map

| Template                                     | Rendered concern                                    | Canonical authority                                          |
|----------------------------------------------|-----------------------------------------------------|--------------------------------------------------------------|
| `templates/confirmed-context.md`             | Confirmed business context                          | State `context` object                                       |
| `templates/source-inventory.md`              | Source manifest and limitations                     | State `sourceInventory` and normalized evidence              |
| `templates/research-design-brief.md`         | Research gate brief                                 | Approved brief artifact and Research approval                |
| `templates/design-ontology-specification.md` | Design gate specification                           | Approved specification, semantic policy, and Design approval |
| `templates/mappings.md`                      | Source-to-term mappings                             | Mapping records and source-node provenance                   |
| `templates/decisions.md`                     | Accepted, rejected, and superseded decisions        | State `decisions` collection                                 |
| `templates/candidates.md`                    | Unresolved proposals and validation gaps            | State `candidates` collection                                |
| `templates/competency-questions.md`          | Questions and expected outcomes                     | Approved competency records and applicable checks            |
| `templates/provenance.md`                    | Artifact and source lineage                         | State artifacts, evidence records, and checksums             |
| `templates/rights.md`                        | Source rights and usage limits                      | Rights record approved for the package                       |
| `templates/approvals.md`                     | Gate decisions and input digests                    | State `approvals` and `gates` collections                    |
| `templates/package-manifest.md`              | Human review of package membership                  | Validated `package-manifest.schema.json` JSON instance       |
| `templates/package-review.md`                | Final reports, semantic diff, and handoff readiness | Validation reports, package digest, and Implement approval   |

## Rendering rules

* Preserve stable IDs, paths, checksums, timestamps, statuses, attribution, and
  provenance exactly as recorded by deterministic capabilities.
* Use `Not applicable` only when the owning contract permits it. Use `Unknown`
  or an explicit gap when evidence is unavailable.
* Keep unresolved candidates separate from accepted decisions and approved RDF.
* Link source claims to evidence document and source node IDs. Do not reopen a
  source merely to enrich presentation.
* Represent a rejected or stale gate as rejected or stale. Never soften it to
  pending or approved.
* Remove rows that are explicitly optional and inapplicable. Do not remove
  required sections or use blank cells to imply completion.
* Render dates and timestamps in ISO 8601 form.
* Do not retain any `{{placeholder}}` in a persisted rendered record.

## Review boundary

Reviewers may comment on a projection, but accepted corrections must flow
through the owning state or deterministic artifact operation. Regenerate the
projection afterward so its checksum and content agree with authority.

The templates contain repository-original structures and wording. They do not
reproduce external standards text.
