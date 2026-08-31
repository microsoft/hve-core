---
title: "Shared Work Handoff: {{handoff_id}}"
description: Minimized continuation context for an explicitly named audience
handoff_id: "{{handoff_id}}"
semantic_revision: 1
created_at: "{{iso_8601_timestamp}}"
updated_at: "{{iso_8601_timestamp}}"
expires_at: "{{iso_8601_timestamp}}"
publisher: "{{publisher_identity}}"
intended_recipients:
  - "{{recipient_identity}}"
canonical_owner: "{{canonical_owner_identity}}"
conflict_resolver: "{{conflict_resolver_identity_or_none}}"
sensitivity: "{{classification}}"
retention: "{{retention_requirement}}"
authority: continuation-context
superseding_handoff: "{{handoff_id_or_none}}"
---

## Scope

* Objective: {{minimized_objective}}
* In scope: {{bounded_scope}}
* Out of scope: {{explicit_exclusions}}
* Current status: {{status}}
* Confidence: {{confidence_and_basis}}
* Next action: {{single_next_action}}
* Review horizon: {{review_horizon}}

## Source Baseline

* Work item or issue: {{resolvable_pointer_or_none}}
* Observed source revision: {{source_revision_or_unknown}}
* Source state: {{clean_dirty_or_unknown}}
* Uncommitted source scope: {{bounded_summary_or_none}}

For Git work, the observed source revision is the commit the work describes before the handoff publication commit exists. It does not identify uncommitted changes or predict the later commit and blob that publish this handoff.

## RPI Continuation

Use this section when any selected source is an RPI artifact. Otherwise record `Not applicable` and why.

* Journey summary: {{minimized_rpi_journey_summary_or_not_applicable}}
* Current pause point: {{mode_phase_and_task_or_not_applicable}}
* Completed scope: {{completed_modes_phases_and_tasks}}
* Remaining scope: {{remaining_modes_phases_and_tasks}}
* Exact next RPI action: {{explicit_invocation_and_source_set}}

### Mode History

| RPI mode | Minimized prompt intent | Outcome and status | Artifact pointer       |
|----------|-------------------------|--------------------|------------------------|
| {{mode}} | {{safe_intent_summary}} | {{outcome_status}} | {{resolvable_pointer}} |

### Supplied Context

| Source class                                      | Pointer or safe label     | Recipient availability                        | Safe background and contribution | Sensitivity handling              |
|---------------------------------------------------|---------------------------|-----------------------------------------------|----------------------------------|-----------------------------------|
| {{private_working_shared_repository_or_external}} | {{pointer_or_safe_label}} | {{publisher-only_shared_external_or_missing}} | {{why_it_matters}}               | {{excluded_or_minimized_content}} |

### Issues and Learnings

| Kind                  | Minimized detail | Disposition or continuation effect   | Evidence pointer               |
|-----------------------|------------------|--------------------------------------|--------------------------------|
| {{issue_or_learning}} | {{safe_summary}} | {{resolved_blocked_or_applies_next}} | {{resolvable_pointer_or_none}} |

### Phase Map

| Phase                 | Purpose          | Status                                     | Completion meaning                 | Evidence pointer       |
|-----------------------|------------------|--------------------------------------------|------------------------------------|------------------------|
| {{phase_id_and_name}} | {{phase_intent}} | {{not_started_active_complete_or_blocked}} | {{observable_completion_criteria}} | {{resolvable_pointer}} |

Do not include raw prompt or session bodies, chain-of-thought, private developer details, PII, secrets, or confidential source content. Represent private working artifacts with safe labels and sufficient summaries, not private paths. Shared repository artifacts must be recipient-resolvable. External resources may remain contextualized pointers. A selected source missing during preparation blocks the handoff.

## Continuation Baseline

* Source comparison: `{{unchanged_advanced_diverged_or_unknown}}`
* Continuation baseline choice: `{{observed-source_current-source_or_unresolved}}`
* Selected source revision: `{{selected_revision_or_unresolved}}`

When source state is not `unchanged`, the recipient chooses the continuation baseline before acceptance. Acceptance does not change the source branch or make either state canonical.

## Acceptance Criteria and Constraints

* Acceptance criteria: {{concise_acceptance_criteria}}
* Approval constraints: {{human_or_repository_approval_constraints}}
* Policy constraints: {{security_privacy_accessibility_or_other_constraints}}

## Confirmed Decisions

* {{decision_with_resolvable_canonical_pointer}}

## Blockers

* {{blocker_or_none}}

## Evidence and Validation

* Evidence: {{resolvable_minimized_pointer}}
* Validation: {{resolvable_check_and_result}}

## Lifecycle Projection

* Effective state: `prepared`
* Effective semantic revision: `1`
* Effective event sequence: `0`
* Acceptance revision: `none`
* Terminal disposition: `none`
* Authority: `continuation-context`

This projection is derived from finalized events. Expiry, invalidation, ambiguity, missing acceptance, stale revision, and unresolved conflict are gate outcomes rather than events.

## Events

Use only `published`, `accepted`, `rejected`, `clarification-requested`, `superseded`, `withdrawn`, `adopted`, or `closed-without-adoption`. Add one event per heading in sequence order. A prepared event has no lifecycle effect until finalization verifies it on the selected shared reference.

### Event {{sequence_number}}

* Type: `{{event_type}}`
* Actor: {{actor_identity}}
* Actor role: {{actor_role}}
* Authority basis: {{authority_basis}}
* Occurred at: {{iso_8601_timestamp}}
* Expected semantic revision: {{semantic_revision}}
* Expected predecessor provider revision: {{opaque_predecessor_revision_or_none}}
* Source comparison: `{{unchanged_advanced_diverged_or_unknown}}`
* Continuation baseline choice: `{{observed-source_current-source_not-required_or_unresolved}}`
* Selected source revision: `{{selected_revision_not_required_or_unresolved}}`
* Resulting state: `{{resulting_state}}`
* Canonical pointer: {{required_for_adopted_otherwise_none}}
* Superseding handoff: {{required_for_superseded_otherwise_none}}
* Reason: {{minimized_reason}}

A finalized event records handoff state, not canonical repository authority. Normal review, ownership, and approval rules govern adoption into code, documentation, ADRs, or other canonical artifacts.

## Repository Adapter

This block is provider metadata, not part of the portable envelope.

* Adapter ID: `repository-files`
* Target path: `.hve/handoffs/{{handoff_id}}.md`
* Selected shared reference: `{{explicit_branch_tag_or_commit}}`
* Source branch: `{{explicit_source_branch_or_not_applicable}}`
* Observed current source commit ID: `{{current_source_commit_id_or_unknown}}`
* Expected predecessor commit ID: `{{commit_id_or_none}}`
* Expected predecessor blob ID: `{{blob_id_or_none}}`
* Prior finalized receipt: `{{opaque_prior_receipt_or_none}}`

Do not embed the finalized receipt for this file's current blob. Finalization returns that receipt out of band or recomputes it from the selected shared reference.
