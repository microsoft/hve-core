---
title: "Shared Work Handoff: {{handoff_id}}"
description: Bounded repository-readable context with independent named-consumer continuation
handoff_id: "{{handoff_id}}"
format_version: 1
content_revision: 1
event_sequence: 0
created_at: "{{iso_8601_timestamp}}"
updated_at: "{{iso_8601_timestamp}}"
expires_at: "{{iso_8601_timestamp}}"
publisher: "{{publisher_identity}}"
disclosure_audience: "{{all_repository_readers_including_public_when_applicable}}"
intended_relevance: "{{owning_team_or_component}}"
continuation_recipients:
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
* Component or paths: {{explicit_bounded_component_or_paths}}
* Context owner: {{owner_identity}}
* Out of scope: {{explicit_exclusions}}
* Current status: {{status}}
* Confidence: {{confidence_and_basis}}
* Next action: {{single_next_action_or_no_continuation_applicable}}
* Review horizon: {{review_horizon}}

## Source Baseline

* Work item or issue: {{resolvable_pointer_or_none}}
* Verified backlink identity and store scope: {{handoff_id_and_approved_store_scope_or_none}}
* Pinned publication reference and content revision: {{verified_reference_and_revision_or_not_yet_published}}
* Current bounded locator: {{explicit_locator_and_shared_reference_or_none}}
* Backlink disclosure and tracker approval: {{separate_approval_status_or_not_requested}}
* Observed source revision: {{source_revision_or_unknown}}
* Source state: {{clean_dirty_or_unknown}}
* Uncommitted source scope: {{bounded_summary_or_none}}

For Git work, the observed source revision is the commit the work describes before the handoff publication commit exists. It does not identify uncommitted changes or predict the later commit and blob that publish this handoff.

Backlinks are optional, audience-reviewed suggestions only after verified publication. Keep provider coordinates and revision evidence in the adapter block; portable slots may reference their evidence keys. A local preview has no publication link. Pinned evidence requires a separate current-status check before continuation; a tracker write requires its own approval and backlog controls.

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

## Continuation Baselines

Record each consumer's source comparison, baseline choice, and selected revision in their response event and derived consumer projection, not as a global choice. When source state is not `unchanged`, that recipient explicitly chooses before acceptance. Acceptance does not change the source branch or make either state canonical. Read-only use has no applicable continuation baseline.

## Acceptance Criteria and Constraints

* Acceptance criteria: {{concise_acceptance_criteria}}
* Approval constraints: {{human_or_repository_approval_constraints}}
* Policy constraints: {{security_privacy_accessibility_or_other_constraints}}

## Confirmed Decisions

* Decision: {{minimized_decision}}
* Applies to: {{bounded_component_paths_or_work_item}}
* Decision owner: {{owner_identity}}
* Authority and status: {{local_proposed_or_canonical_with_approval_basis}}
* Canonical or evidence pointer: {{safe_resolvable_pointer_or_unknown}}

### Alternatives Considered

Optional; repeat only for supplied, safe decision evidence. Preserve unknown historical rationale as `unknown`; do not reconstruct private reasoning traces.

* Option: {{alternative}}
* Disposition: {{rejected_deferred_or_not_investigated}}
* Known reason: {{minimized_reason_or_unknown}}
* Deciding constraint: {{constraint_or_unknown}}
* Evidence or canonical pointer: {{safe_pointer_or_none}}

## Blockers

* {{blocker_or_none}}

## Evidence and Validation

* Evidence: {{resolvable_minimized_pointer}}
* Validation: {{resolvable_check_and_result}}

## Publication Projection

* Publication state: `prepared`
* Effective content revision: `none`
* Effective event sequence: `0`
* Authority: `continuation-context`

After first finalization, content revision is `1` and publication state is `shared`. Publication state never aggregates acceptance, rejection, or adoption. Repository visibility is the disclosure boundary; intended-team metadata is not an ACL. Reading creates no response or acceptance.

## Consumer Projections

Repeat for each named consumer/content-revision key, deriving values from verified events rather than trusting authored state.

* Consumer identity: {{named_recipient}}
* Content revision: {{verified_content_revision}}
* State: `{{unaccepted_accepted_rejected_awaiting-clarification_adopted_closed-without-adoption}}`
* Acceptance event sequence: {{sequence_or_none}}
* Source comparison: `{{unchanged_advanced_diverged_unknown_or_not_applicable}}`
* Baseline choice: `{{observed-source_current-source_or_not_applicable}}`
* Selected source revision: {{revision_or_none}}
* Disposition event sequence and canonical pointer: {{sequence_and_pointer_or_none}}

New content starts fresh keys; response-only appends preserve other consumers. Terminal evidence stays historical. Expiry, invalidity, ambiguity, stale revision, missing evidence, and unresolved conflict block continuation without rewriting history.

## Publication History

Retain one minimized snapshot per content publication. Bind each snapshot to verified publication evidence through its adapter evidence key; do not validate old events with the current roster or self-asserted roles.

### Content Publication {{content_revision}}

* Content revision and publication event sequence: {{revision_and_sequence}}
* Publication evidence key: {{exact_adapter_evidence_key}}
* Eligible recipients: {{named_recipients_or_none}}
* Publisher: {{publisher_identity}}
* Canonical owner: {{owner_identity}}
* Resolver: {{resolver_identity_or_none}}
* Disposition permissions: {{actors_and_allowed_dispositions}}
* Disclosure audience and policy constraints: {{approved_audience_and_constraints}}
* Authority provenance: {{minimized_verified_basis_and_exact_evidence_keys}}
* Predecessor policy authorizing publication: {{prior_revision_or_verified_initial_authority}}

A removed consumer or replaced owner retains only historical authority for the earlier revision. Later enrollment cannot legitimize an earlier event. Missing required historical evidence is a verification failure that blocks mutation, not a finding of unauthorized identity. Unsupported formats remain historical-only without automatic migration.

## Events

Use only `published`, `accepted`, `rejected`, `clarification-requested`, `superseded`, `withdrawn`, `adopted`, or `closed-without-adoption`. Add one event per heading in sequence order. A prepared event has no lifecycle effect until finalization verifies it on the selected shared reference.

### Event {{sequence_number}}

* Type: `{{event_type}}`
* Actor: {{actor_identity}}
* Actor role: {{actor_role}}
* Authority basis: {{authority_basis}}
* Consumer subject: {{named_consumer_for_consumer_events_omit_for_publication_events}}
* Occurred at: {{iso_8601_timestamp}}
* Content revision and publication evidence key: {{revision_and_key}}
* Expected predecessor content revision: {{revision_or_none}}
* Expected predecessor event sequence: {{sequence_or_zero}}
* Expected predecessor provider revision: {{opaque_predecessor_revision_or_none}}
* Source comparison: `{{unchanged_advanced_diverged_or_unknown}}`
* Continuation baseline choice: `{{observed-source_current-source_not-required_or_unresolved}}`
* Selected source revision: `{{selected_revision_not_required_or_unresolved}}`
* Resulting publication or consumer state: `{{scoped_resulting_state}}`
* Canonical pointer: {{required_for_adopted_otherwise_none}}
* Superseding handoff: {{required_for_superseded_otherwise_none}}
* Reason: {{minimized_reason}}

A finalized event records handoff state, not canonical repository authority. Consumer subject is separate from the acting canonical owner; omit it on publication events. Acceptance binds the subject, verified content revision, source comparison, and selected baseline/revision. Normal review, ownership, and approval rules govern adoption into canonical artifacts.

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
* Publication evidence map: {{content_revision_and_evidence_key_to_exact_verified_shared_reference_commit_and_blob}}
* Historical authority evidence map: {{authority_evidence_key_to_exact_verified_provider_reference_or_none}}

Do not embed the finalized receipt for this file's current blob. Verify its publication evidence key out of band during finalization or read. Later publications may retain that exact historical provider reference once observed. Resolve historical evidence only by the declared exact reference, never broader search. Finalization returns its receipt out of band or recomputes it from the selected shared reference.
