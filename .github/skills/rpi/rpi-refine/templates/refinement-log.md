<!-- markdownlint-disable-file -->
# Refinement Review: {{task_name}}

## Executive Summary

* Assessment: {{plain_language_subtractive_assessment_and_assessed_scope}}
* Why this matters: {{practical_effect_on_complexity_maintainability_performance_or_clarity}}
* Review execution: {{Complete_Partial_or_Blocked}}
* Assessed outcome: {{Clean_Refinements_identified_Redesign_needed_Residual_cleanup_or_Not_accepted}}
* Review depth: {{surface_standard_or_deep}}
* Validation coverage: {{validation_summary}}
* Confidence and limitations: {{confidence_and_material_limits}}

The assessment above is the reviewer's proposal. Parent Decision Record contains the final decisions and next actions, or states that decisions are pending.

## What You May Not Know

{{material_assumption_shift_upgrade_opportunity_or_architectural_trade_off_the_reader_could_otherwise_miss_or_none}}

## Findings and Proposed Routes

Order findings by severity and net simplification impact. When no substantive findings exist within the assessed boundary, state that clearly without creating a placeholder finding.

<!-- rpi:refinement id=RF-001 -->
### RF-001 [{{Critical_High_Medium_or_Low}}]: {{finding_title}}

{{plain_language_explanation_of_what_can_be_removed_simplified_or_reworked_and_why}}

* Related scope: {{Pxx_Pxx_Txx_CH_xxx_or_touched_surface}}
* Dimension: {{Logic_and_branching_Error_boundaries_Performance_and_resources_Conventions_Dependencies_and_SDKs_Language_and_version_features_Assumptions_and_architecture_Tests_Future_mistake_prevention_Documents_and_domain_language_or_Infrastructure_and_configuration}}
* Current state and evidence: {{what_exists_now_with_workspace_relative_paths_and_symbols_or_headings}}
* What to remove or rework: {{concrete_removal_simplification_consolidation_or_redesign_target}}
* Impact: {{complexity_removed_failure_mode_prevented_or_performance_gained}}
* Resolution condition: {{observable_state_that_confirms_the_refinement}}
* Proposed destination: {{rpi_plan_rpi_implement_rpi_research_or_follow_up}}
* Smallest useful next action: {{action}}

{{optional_supporting_detail_or_illustrative_comparison_when_needed}}

## Parent Decision Record

<!-- Append FD-xxx events in order; never rewrite the evidence body above to fit a decision. -->

### Current Disposition

* Based on events: {{latest_FD_event_ids_or_pending_initialization}}
* Review execution: {{Complete_Partial_Blocked_or_pending}}
* Final outcome: {{canonical_outcome_or_pending_parent_decision_with_plain_language_reason}}
* Finding decisions and next actions: {{RF_ids_dispositions_destinations_owners_and_next_actions_or_none}}
* Decisions still needed: {{undecided_RF_ids_and_outcome_effect_or_none}}

This summary is derived from Decision History. The latest event for each subject governs; refresh this summary after appending decisions and on recovery.

### Decision History

Append events in order. Never rewrite or delete an earlier row. The latest event for a subject is current.

| Event      | Subject                                                   | Decision source       | Status or value                                         | Proposed destination | Final destination | Owner     | More information needed  | Smallest next action | Rationale                     |
|------------|-----------------------------------------------------------|-----------------------|---------------------------------------------------------|----------------------|-------------------|-----------|--------------------------|----------------------|-------------------------------|
| {{FD-001}} | {{participation_walkthrough_execution_outcome_or_RF_xxx}} | {{user_agent_system}} | {{current_value_or_accepted_rejected_deferred_changed}} | {{none_or_route}}    | {{none_or_route}} | {{owner}} | {{none_or_evidence_gap}} | {{action}}           | {{parent_decision_rationale}} |

## Validation Evidence

| Command     | Scope                                | Status                                      | Summary                                        |
|-------------|--------------------------------------|---------------------------------------------|------------------------------------------------|
| {{command}} | {{changed_files_package_or_project}} | {{Passed / Failed / Skipped / Unavailable}} | {{important_output_summary_or_skip_rationale}} |

## Risks, Blockers, and Residual Work

* Blockers: {{none_or_blocker_with_affected_scope_and_next_action}}
* Upgrade and modernization opportunities: {{none_or_non_breaking_language_framework_or_sdk_upgrade_offer_with_reasons}}
* Residual work: {{none_or_distinct_follow_up_item_with_scope_reason_and_owner}}

## Refinement Record

### Scope and Evidence

* Task ID: {{task_id}}
* Review date: {{YYYY-MM-DD}}
* Review scope: {{full_task_or_bounded_pxx_or_pxx_txx_scope}}
* Touched surfaces assessed: {{code_docs_domain_tests_dependencies_config_summary}}
* Review depth and provenance: {{surface_standard_or_deep}}; {{default_same_loop_significant_changes_or_explicit_user_request}}
* Review execution: {{started_Complete_Partial_or_Blocked}}
* Helper use: {{none_or_each_targeted_subagent_lookup_with_task_reasoning_effort_effort_source_and_verified_evidence}}
* Plan: .copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md
* Changes: .copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md
* Other evidence considered: {{research_changed_files_or_validation_evidence}}

### Opening Refinement State

* Interpreted refinement goal: {{subtractive_review_goal}}
* Review scope: {{full_task_or_bounded_pxx_or_pxx_txx_scope}}
* Evidence readiness: {{available_artifacts_and_changed_files}}
* Active read-only and trust boundaries: {{refinement_record_only_and_security_trust_boundary_preservation}}
* Authority: the main agent performs the refinement analysis, verifies any targeted helper lookups, and writes findings; final outcome, route dispositions, and continuation live in Parent Decision Record
* Initial blockers: {{none_or_active_blocker_with_next_action}}

### Lens Coverage and Kept-As-Is Summary

| Lens                                                | Touched areas inspected | Verified findings  | Kept-as-is rationale or unassessed boundary |
|-----------------------------------------------------|-------------------------|--------------------|---------------------------------------------|
| Logic, branching, error boundaries, and performance | {{paths_or_scope}}      | {{RF_ids_or_none}} | {{concise_note}}                            |
| Conventions, SDKs, libraries, and language versions | {{paths_or_scope}}      | {{RF_ids_or_none}} | {{concise_note}}                            |
| Assumptions, architecture, abstractions, and tests  | {{paths_or_scope}}      | {{RF_ids_or_none}} | {{concise_note}}                            |
| Documents, domain language, and infrastructure      | {{paths_or_scope}}      | {{RF_ids_or_none}} | {{concise_note}}                            |

### Reviewer Self-Check

* [ ] All touched code, tests, documents, domain language, dependencies, error boundaries, performance paths, language features, and configuration within scope were assessed or explicitly bounded.
* [ ] Every `RF-xxx` finding has net subtractive, simplifying, or defect-preventing value rather than additive ceremony.
* [ ] No input validation, path/workspace containment, authentication, authorization, secret redaction, or untrusted-content guard was classified as unneeded defensive clutter, and any security-touching refinement routes to `rpi-plan`.
* [ ] Execution status, assessed outcome, review depth, validation coverage, and `FD-xxx` parent decisions are complete and consistent.
* [ ] The review mutated no source, test, doc, config, plan, critique, research, or changes file, and verified every targeted helper lookup at its cited workspace path before recording any finding.
* Checked boundary: {{lenses_files_and_artifacts_checked}}
* Missing or limited evidence: {{none_or_exact_unassessed_boundary}}
