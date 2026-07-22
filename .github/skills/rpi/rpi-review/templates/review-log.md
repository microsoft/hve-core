<!-- markdownlint-disable-file -->
# Review: {{task_name}}

## Scope and Evidence

* Task ID: {{task_id}}
* Review date: {{YYYY-MM-DD}}
* Review scope: {{full_task_or_bounded_pxx_or_pxx_txx_scope}}
* Plan: .copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md
* Phase details: .copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-phase-details.md
* Plan critique: .copilot-tracking/reviews/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan-critique.md
* Changes: .copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md
* Other evidence considered: {{research_validation_or_bounded_lens_evidence}}

## Opening Review State

* Interpreted review goal: {{evidence_based_review_goal}}
* Review scope: {{full_task_or_bounded_pxx_or_pxx_txx_scope}}
* Evidence readiness: {{available_artifacts_and_readiness}}
* Acceptance basis: {{requirements_acceptance_criteria_critique_or_other_basis}}
* First comparison boundary: {{initial_evidence_comparison_and_limit}}
* Active read-only boundaries: {{review_record_and_evidence_only_authority}}
* Initial blockers: {{none_or_active_blocker_with_next_action}}

## Execution Status

* Execution status: {{Complete_Partial_or_Blocked}}

## Plan-to-Change Reconciliation

| Current plan scope | Descriptive changes-record summary | Current-state reconciliation | Gap or rationale |
|--------------------|------------------------------------|------------------------------|------------------|
| {{Pxx_Pxx_Txx_or_Follow_Up_Items}} | {{completed_work_or_plan_update_heading}} | {{Reconciled_Partial_or_Missing}} | {{gap_or_rationale}} |

## Completed Work Assessment

| Related marker | Files | What changed and why | Completion evidence | Validation | Assessment |
|----------------|-------|----------------------|---------------------|------------|------------|
| {{Pxx_or_Pxx_Txx}} | {{workspace_relative_paths}} | {{summary}} | {{evidence}} | {{status_and_evidence}} | {{reconciled_or_gap}} |

## Implementation-Time Plan and Detail Update Assessment

| Affected area or marker | What changed and why | Triggering evidence and user decision | Reconciliation performed | Planning and critique state | Assessment |
|-------------------------|----------------------|---------------------------------------|--------------------------|----------------------------|------------|
| {{plan_section_Pxx_Pxx_Txx_or_Follow_Up_Items}} | {{summary}} | {{evidence_and_user_decision_or_none}} | {{current_state_sections_reconciled}} | {{not_needed_or_PC_xxx_and_readiness_state}} | {{reconciled_or_gap}} |

## Critique and Material Revision Assessment

* Latest critique dispositions: {{coverage_summary}}
* Material revisions: {{discovery_plan_detail_reconciliation_and_fresh_planning_and_critique_coverage}}
* Dependent-work pause assessment: {{no_early_resumption_or_gap}}
* Justification assessment: {{supported_or_unresolved_rationale}}

## Plan Follow-Up Assessment

| Follow-up item | Why outside immediate scope | Owner or next action | Assessment and route |
|----------------|------------------------------|----------------------|----------------------|
| {{item_or_none}} | {{reason}} | {{owner_or_next_action}} | {{resolved_open_or_distinct_follow_up_route}} |

Unresolved plan follow-up items remain distinct follow-up work. Do not treat them as defects or add them to active `Pxx` or `Pxx-Txx` implementation, completion, or acceptance scope.

## Findings

<!-- rpi:review id=RV-001 -->
### RV-001 [{{Critical_High_Medium_or_Low}}]: {{finding_title}}

* Related scope: {{Pxx_or_Pxx_Txx}}
* Evidence: {{plain_text_workspace_relative_path_or_summary}}
* Impact: {{why_it_matters}}
* Destination: {{rpi_implement_rpi_plan_rpi_research_or_follow_up}}
* Smallest useful next action: {{action}}

## Defects

* {{none_or_rv_xxx_defect_with_destination_rpi_implement}}

## Residual Work

* {{none_or_distinct_follow_up_item_with_scope_and_reason}}

## Blockers and Remaining Work

* Blockers: {{none_or_blocker_with_affected_marker_and_next_action}}
* Remaining active work: {{none_or_remaining_Pxx_or_Pxx_Txx_with_reason_and_next_action}}

## Validation Evidence

| Command     | Scope                                | Status                                      | Summary                                        |
|-------------|--------------------------------------|---------------------------------------------|------------------------------------------------|
| {{command}} | {{changed_files_package_or_project}} | {{Passed / Failed / Skipped / Unavailable}} | {{important_output_summary_or_skip_rationale}} |

## Outcome

* Outcome: {{Conformant_Conformant_with_justified_divergence_Defects_found_Residual_work_or_Not_accepted}}
* Outcome rationale: {{evidence_based_rationale}}

## Closeout Routing Record

<!-- Persist outcome and route facts only. The rpi-review reference owns rendered closeout prose. -->

| Finding class | Destination | Owner or next action |
|---------------|-------------|----------------------|
| Implementation defect | {{rpi_implement_or_none}} | {{owner_or_smallest_action}} |
| Decision gap or invalid assumption | {{rpi_plan_or_none}} | {{owner_or_smallest_action}} |
| Material evidence gap | {{rpi_research_or_none}} | {{owner_or_smallest_action}} |
| Non-blocking residual work | {{distinct_follow_up_or_none}} | {{owner_or_smallest_action}} |

* Execution status: {{Complete_Partial_or_Blocked}}
* Outcome: {{Conformant_Conformant_with_justified_divergence_Defects_found_Residual_work_or_Not_accepted}}
* Validation coverage: {{validation_summary}}
* Blockers: {{none_or_blocker_summary}}
