<!-- markdownlint-disable-file -->
# Review: {{task_name}}

## Executive Summary

* Bottom line: {{plain_language_acceptance_result}}
* Why this matters: {{practical_effect_on_the_users_goal}}
* Builder execution: {{Complete_Partial_or_Blocked}}
* Proposed review execution: {{Complete_Partial_or_Blocked}}
* Proposed outcome: {{Conformant_Conformant_with_justified_divergence_Defects_found_Residual_work_or_Not_accepted}}
* Validation coverage: {{validation_summary}}
* Confidence and limitations: {{confidence_and_material_limits}}

## Findings and Proposed Routes

<!-- rpi:review id=RV-001 -->
### RV-001 [{{Critical_High_Medium_or_Low}}]: {{finding_title}}

* Related scope: {{Pxx_or_Pxx_Txx_requirement_or_acceptance_id}}
* Evidence: {{plain_text_workspace_relative_path_or_summary}}
* Impact: {{why_it_matters}}
* Proposed destination: {{rpi_implement_rpi_plan_rpi_research_or_follow_up}}
* Smallest useful next action: {{action}}

## Parent Decision Record

<!-- The RPI Review Builder leaves this section unchanged. The primary review parent owns it. -->

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
* Builder candidate identity: {{task_id_scope_and_artifact_revision_or_hash}}
* Builder execution: {{started_Complete_Partial_Blocked_or_Blocked_not_dispatched_unavailable}}
* Plan: .copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md
* Phase details: .copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-phase-details.md
* Plan critique: .copilot-tracking/reviews/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan-critique.md
* Changes: .copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md
* Other evidence considered: {{research_validation_or_bounded_lens_evidence}}

### Opening Review State

* Interpreted review goal: {{evidence_based_review_goal}}
* Review scope: {{full_task_or_bounded_pxx_or_pxx_txx_scope}}
* Evidence readiness: {{available_artifacts_and_readiness}}
* Acceptance basis: {{requirements_acceptance_criteria_critique_or_other_basis}}
* First comparison boundary: {{initial_evidence_comparison_and_limit}}
* Active read-only boundaries: {{review_record_and_evidence_only_authority}}
* Authority split: builder owns review evidence and proposed routes; parent owns final outcome, route dispositions, and continuation
* Initial blockers: {{none_or_active_blocker_with_next_action}}

### Plan-to-Change Reconciliation

| Current plan scope                 | Descriptive changes-record summary        | Current-state reconciliation      | Gap or rationale     |
|------------------------------------|-------------------------------------------|-----------------------------------|----------------------|
| {{Pxx_Pxx_Txx_or_Follow_Up_Items}} | {{completed_work_or_plan_update_heading}} | {{Reconciled_Partial_or_Missing}} | {{gap_or_rationale}} |

### Completed Work and Update Assessment

| Scope or marker                 | Files or plan area     | Change, evidence, and decision         | Reconciliation and validation    | Assessment            |
|---------------------------------|------------------------|----------------------------------------|----------------------------------|-----------------------|
| {{Pxx_Pxx_Txx_or_plan_section}} | {{paths_or_plan_area}} | {{summary_evidence_and_user_decision}} | {{current_state_and_validation}} | {{reconciled_or_gap}} |

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
* [ ] Findings are substantive, evidence-grounded, severity-graded, and use stable `RV-xxx` IDs with one proposed route each.
* [ ] Execution status, proposed outcome, validation coverage, limitations, and proposed routes are complete and internally consistent.
* [ ] Standard review completely assessed the material boundary while omitting restatement, cosmetic feedback, exhaustive strengths, low-impact suggestions, and continual narration; deep review remained inside the supplied boundary.
* [ ] The builder did not edit Parent Decision Record, ask the user, mutate source or parent state, dispatch another worker, execute validation, or invoke a destination.
* Checked boundary: {{requirements_markers_updates_validation_follow_ups_and_gaps}}
* Missing or limited evidence: {{none_or_exact_unassessed_boundary}}
