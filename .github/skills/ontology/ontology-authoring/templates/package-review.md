---
description: Final ontology package validation, semantic change, and handoff review
---

# Package Review: {{project_name}}

## Review Scope

* Package digest: {{sha256}}
* Design approval ID and digest: {{approval_id_and_sha256}}
* Review generated at: {{ISO_8601_timestamp}}
* Reviewer: {{contributor_and_role}}

## Validation Reports

| Report ID     | Kind                                                      | Status                                      | Path                        | Generated at           | Summary     |
|---------------|-----------------------------------------------------------|---------------------------------------------|-----------------------------|------------------------|-------------|
| {{report_id}} | {{syntax_conformance_policy_competency_or_semantic_diff}} | {{pending_passed_failed_or_not_applicable}} | {{workspace_relative_path}} | {{ISO_8601_timestamp}} | {{summary}} |

## Semantic Changes

| Change ID     | Kind                           | Subject                | Before                  | After                     | Evidence and decision IDs |
|---------------|--------------------------------|------------------------|-------------------------|---------------------------|---------------------------|
| {{change_id}} | {{addition_removal_or_change}} | {{term_or_mapping_id}} | {{prior_value_or_none}} | {{current_value_or_none}} | {{ids}}                   |

## Completeness and Limitations

* Missing required or applicable artifacts: {{none_or_roles}}
* Failed reports: {{none_or_report_ids}}
* Stale approvals: {{none_or_approval_ids}}
* Unresolved candidates: {{candidate_ids_or_none}}
* Rights or provenance gaps: {{none_or_gap_ids}}
* Known limitations: {{limitations_or_none}}

## Implement Gate and Handoff

* Implement approval: {{approval_id_and_status}}
* No-deployment attestation: {{artifact_id_and_digest}}
* Deploy handoff status: {{deferred_or_ready}}
* Deploy handoff target: 033 Fabric Ontology Edge AI Agent
* Deployment occurred: {{false}}
* Next eligible action: {{revise_approve_or_handoff}}