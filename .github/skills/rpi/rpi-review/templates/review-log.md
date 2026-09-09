<!-- markdownlint-disable-file -->
# Review: {{task_name}}

## Executive Summary

* Assessment: {{plain_language_proposed_acceptance_result_and_assessed_scope}}
* Why this matters: {{practical_effect_on_the_users_goal}}
* Builder execution: {{Complete_Partial_or_Blocked}}
* Proposed review execution: {{Complete_Partial_or_Blocked}}
* Proposed outcome: {{Conformant_Conformant_with_justified_divergence_Defects_found_Residual_work_or_Not_accepted}}
* Validation coverage: {{validation_summary}}
* Confidence and limitations: {{confidence_and_material_limits}}

The assessment above is the builder's proposal. Parent Decision Record contains the current final decision and next actions, or states that decisions are pending.

## What You May Not Know

{{material_behavior_change_justified_divergence_or_evidence_limit_the_reader_could_otherwise_miss_or_none}}

## Findings and Proposed Routes

Order findings by severity and impact. If none are supported, state that no substantive findings were identified within the assessed boundary and retain any coverage limitations. Do not create a placeholder finding.

<!-- rpi:review id=RV-001 -->
### RV-001 [{{Critical_High_Medium_or_Low}}]: {{finding_title}}

{{plain_language_description_of_the_gap_and_its_consequence}}

* Related scope: {{Pxx_or_Pxx_Txx_requirement_or_acceptance_id}}
* Expected behavior: {{binding_requirement_or_accepted_direction}}
* Observed behavior and evidence: {{what_the_supplied_evidence_establishes_with_paths_and_headings_or_symbols}}
* Impact: {{why_it_matters}}
* Resolution condition: {{observable_result_or_missing_evidence_that_would_address_the_finding}}
* Proposed destination: {{rpi_implement_rpi_plan_rpi_research_or_follow_up}}
* Smallest useful next action: {{action}}

{{supporting_detail_or_illustrative_example_only_when_needed_to_understand_this_finding}}

## Parent Decision Record

<!-- The selected review worker leaves this section unchanged. The primary review parent owns it. -->

### Current Disposition

* Based on events: {{latest_RD_event_ids_or_pending_initialization}}
* Review execution: {{Complete_Partial_Blocked_or_pending}}
* Final outcome: {{canonical_outcome_or_pending_parent_decision_with_plain_language_reason}}
* Finding decisions and next actions: {{RV_ids_dispositions_destinations_owners_and_next_actions_or_none}}
* Decisions still needed: {{undecided_RV_ids_and_outcome_effect_or_none}}

This summary is derived from Decision History, not a second decision record. The latest event for each subject governs; refresh this summary after appending decisions and on recovery.

### Decision History

Append events in order. Never rewrite or delete an earlier row. The latest event for a subject is current.

| Event      | Subject                                                   | Decision source       | Status or value                                         | Proposed destination | Final destination | Owner     | More information needed  | Smallest next action | Rationale                     |
|------------|-----------------------------------------------------------|-----------------------|---------------------------------------------------------|----------------------|-------------------|-----------|--------------------------|----------------------|-------------------------------|
| {{RD-001}} | {{participation_walkthrough_execution_outcome_or_RV_xxx}} | {{user_agent_system}} | {{current_value_or_accepted_rejected_deferred_changed}} | {{none_or_route}}    | {{none_or_route}} | {{owner}} | {{none_or_evidence_gap}} | {{action}}           | {{parent_decision_rationale}} |

## Validation Evidence

| Command     | Scope                                | Status                                      | Summary                                        |
|-------------|--------------------------------------|---------------------------------------------|------------------------------------------------|
| {{command}} | {{changed_files_package_or_project}} | {{Passed / Failed / Skipped / Unavailable}} | {{important_output_summary_or_skip_rationale}} |

## Risks, Blockers, and Residual Work

* Blockers: {{none_or_blocker_with_affected_marker_and_next_action}}
* Remaining active work: {{none_or_remaining_Pxx_or_Pxx_Txx_with_reason_and_next_action}}
* Residual work: {{none_or_distinct_follow_up_item_with_scope_reason_and_owner}}

## Review Record

### Scope and Evidence

* Task ID: {{task_id}}
* Review date: {{YYYY-MM-DD}}
* Review scope: {{full_task_or_bounded_pxx_or_pxx_txx_scope}}
* Assessed boundary: {{requirements_scope_architecture_acceptance_dependencies_and_evidence_boundary_summary}}
* Review depth and provenance: {{standard_or_deep}}; {{default_or_explicit_user_request}}
* Review worker: {{stable_name_or_general_purpose_with_selection_basis}}
* Builder candidate identity: {{task_id_scope_and_artifact_revision_or_hash}}
* Builder execution: {{started_Complete_Partial_Blocked_or_Blocked_not_dispatched_unavailable}}
* Plan: .copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md
* Plan critique: .copilot-tracking/reviews/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan-critique.md
* Changes: .copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md
* Other evidence considered: {{research_or_validation_evidence}}

### Opening Review State

* Interpreted review goal: {{evidence_based_review_goal}}
* Review scope: {{full_task_or_bounded_pxx_or_pxx_txx_scope}}
* Evidence readiness: {{available_artifacts_and_readiness}}
* Acceptance basis: {{requirements_acceptance_criteria_critique_or_other_basis}}
* First comparison boundary: {{initial_evidence_comparison_and_limit}}
* Active read-only boundaries: {{review_record_and_evidence_only_authority}}
* Authority split: builder owns review evidence and proposed routes; parent owns final outcome, route dispositions, and continuation
* Initial blockers: {{none_or_active_blocker_with_next_action}}

### Acceptance and Change Coverage

| Requirement or scope                                   | Implementation and validation evidence                | Assessment                  | Finding or rationale                         |
|--------------------------------------------------------|-------------------------------------------------------|-----------------------------|----------------------------------------------|
| {{requirement_id_Pxx_Pxx_Txx_or_material_plan_update}} | {{paths_headings_symbols_and_supplied_check_results}} | {{Met_Gap_or_Not_assessed}} | {{RV_id_or_supported_reconciliation_reason}} |

Cover every material requirement and in-scope completion claim, grouping rows only when their evidence and assessment are shared. Include implementation-time plan updates and confirmed decisions. Keep detailed gaps in their findings instead of repeating them here.

### Critique and Follow-Up Assessment

* Latest critique dispositions: {{coverage_summary}}
* Material revisions: {{discovery_plan_detail_reconciliation_and_fresh_planning_and_critique_coverage}}
* Dependent-work pause assessment: {{no_early_resumption_or_gap}}
* Justification assessment: {{supported_or_unresolved_rationale}}

| Follow-up item   | Why outside immediate scope | Owner or next action     | Assessment and route                          |
|------------------|-----------------------------|--------------------------|-----------------------------------------------|
| {{item_or_none}} | {{reason}}                  | {{owner_or_next_action}} | {{resolved_open_or_distinct_follow_up_route}} |

Unresolved plan follow-up items remain distinct follow-up work. Do not treat them as defects or add them to active `Pxx` or `Pxx-Txx` implementation, completion, or acceptance scope.

### Builder Self-Check

* [ ] Every supplied requirement, acceptance criterion, in-scope marker, material update, critique disposition, validation result, blocker, remaining item, and plan follow-up has an assessment or explicit gap.
* [ ] Findings are substantive, evidence-grounded, severity-graded, and use stable `RV-xxx` IDs with expected and observed behavior, a resolution condition, and one proposed route each.
* [ ] Execution status, proposed outcome, validation coverage, limitations, and proposed routes are complete and internally consistent.
* [ ] The summary is scoped and advisory, findings keep their supporting context together, and acceptance coverage distinguishes demonstrated gaps from unassessed behavior.
* [ ] Standard review completely assessed the material boundary while omitting restatement, cosmetic feedback, exhaustive strengths, low-impact suggestions, and continual narration; deep review remained inside the supplied boundary.
* [ ] The selected review worker did not edit Parent Decision Record, ask the user, mutate source or parent state, dispatch another worker, execute validation, or invoke a destination.
* Checked boundary: {{requirements_markers_updates_validation_follow_ups_and_gaps}}
* Missing or limited evidence: {{none_or_exact_unassessed_boundary}}
