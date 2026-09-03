---
description: Design gate ontology specification for approved semantic compilation
---

# Ontology Specification: {{project_name}}

## Design Authority

* Status: {{draft_approved_rejected_or_stale}}
* Research approval ID: {{approval_id}}
* Approved base IRI: {{absolute_base_iri}}
* Semantic policy artifact and digest: {{path_and_sha256}}
* Prepared at: {{ISO_8601_timestamp}}

## Competency Scope

{{supported_questions_decisions_and_explicit_non_goals}}

## Terms

| Term ID     | Kind                       | Approved IRI     | Preferred label | Aliases             | Definition     | Provenance                    |
|-------------|----------------------------|------------------|-----------------|---------------------|----------------|-------------------------------|
| {{term_id}} | {{class_or_property_kind}} | {{absolute_iri}} | {{label}}       | {{aliases_or_none}} | {{definition}} | {{evidence_and_decision_ids}} |

## Relationships and Constraints

| ID                   | Subject or target | Predicate or path                     | Object or constraint     | Authority              | Provenance                    |
|----------------------|-------------------|---------------------------------------|--------------------------|------------------------|-------------------------------|
| {{specification_id}} | {{term_id}}       | {{permitted_predicate_or_shape_path}} | {{target_or_constraint}} | {{ontology_or_shapes}} | {{evidence_and_decision_ids}} |

## Package Inputs

* Mapping record: {{path_and_digest}}
* Competency questions: {{path_and_digest}}
* Approved sampled instances: {{path_and_digest_or_not_applicable}}
* Decisions: {{decision_ids}}
* Candidates excluded from approved graphs: {{candidate_ids_or_none}}
* Known limitations: {{limitations_or_none}}

## Design Approval

* Approval record: {{approval_id_or_pending}}
* Input digests: {{sha256_values}}
* Next eligible action: {{revise_approve_or_begin_implement}}
