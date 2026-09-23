<!-- markdownlint-disable-file -->
# RPI Plan Critique: {{task_name}}

## Metadata

* Task ID: {{task_id}}
* Critique date: {{YYYY-MM-DD}}
* Plan: .copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md
* Invocation outcome: {{completed_or_preflight_limitation_or_host_failure_or_unknown}}
* Assessment execution/availability: {{Complete_Partial_Blocked_or_not_produced_or_unknown}}
* Critique depth: {{standard_or_deep}}
* Depth provenance: {{default_or_explicit_user_request}}
* Attempt slot consumed: yes
* Attempt ID and kind: {{unique_attempt_id_and_initial_revision_closure_recovery_infrastructure_retry_or_human}}
* Candidate identity and saved hash boundary: {{revision_hash_and_reservation_metadata_boundary}}
* Revision closure: {{not_applicable_or_immediate_predecessor_adjacent_hashes_latest_delta_affected_ids_full_or_targeted_basis_and_targeted_root_complete_full_assessment_with_intermediate_results}}
* Current-run provenance: {{immediate_planner_activation_or_standalone_initial_reservation}}
* Original attempt and recovery approval: {{not_applicable_or_original_pointer_and_task_specific_consent}}
* Prior attempt and reconciliation pointers: {{all_applicable_attempts_and_late_evidence_or_none}}
* Human assessor provenance: {{not_applicable_or_human_supplied_identity_role_independence_confirmation_date_and_specific_authorization}}

<!-- For no assessment, record the limitation and unavailable verdict rather than fabricated coverage or findings. Infrastructure classification belongs to the planning parent. Only a human may author or attest a human assessment. -->

## Inputs and Criterion Boundary

* Task context and caller requirements: {{requirements_or_context_summary}}
* Research and evidence considered: {{workspace_relative_evidence_paths}}
* Decisions, dependencies, task Goals, and task Requirements considered: {{decision_dependency_goal_and_requirement_summary}}
* Assessment boundary: {{full_candidate_or_targeted_delta_coverage_and_what_the_critique_can_and_cannot_conclude}}

## Coverage Assessment

<!-- In standard mode, aggregate fully covered IDs where practical and give individual rows to Partial or Missing coverage and material concerns. In deep mode, expand traceability when it helps resolve substantive concerns. -->

| Requirement, research, phase, or task ID | Coverage                       | Evidence or concern     |
|------------------------------------------|--------------------------------|-------------------------|
| {{requirement_research_or_pxx_txx_id}}   | {{Covered_Partial_or_Missing}} | {{evidence_or_concern}} |

## Verdict

* Verdict: {{Pass_Revise_Blocked_or_unavailable_when_no_assessment}}
* Rationale: {{concise_evidence_based_rationale}}
* Hash covered by this assessment: {{saved_candidate_hash_or_unavailable}}
* Closure chain: {{not_applicable_or_root_complete_full_assessment_and_ordered_adjacent_hash_result_and_disposition_pointers}}

## Findings

<!-- rpi:critique id=PC-001 -->
### PC-001 [{{Critical_High_Medium_or_Low}}]: {{finding_title}}

* Related IDs: {{requirement_research_phase_or_task_ids}}
* Evidence: {{plain_text_workspace_relative_path_or_supplied_context}}
* Concern: {{substantive_gap_or_credibility_issue}}
* Impact: {{why_the_gap_matters}}
* Smallest useful change: {{minimal_plan_detail_decision_or_research_action}}
* Action owner: {{planning_parent_user_or_other_named_owner}}
* Exact resolving evidence: {{specific_artifact_state_or_validation_that_proves_resolution}}
* Decision route: {{direct_planner_correction_or_significant_divergent_user_decision}}

## Strengths and Residual Risk

* {{concise_credible_coverage_or_explicitly_accepted_residual_risk}}

## Questions or Blocking Evidence Gaps

* {{none_or_decision_critical_question_or_missing_evidence}}

## Limitations

* {{unavailable_evidence_or_assessment_boundary_limitation}}

## Recommended Next Action

* Highest-impact finding: {{PC_xxx_or_none}}
* Action owner: {{planning_parent, user, or none}}
* Smallest next action: {{direct_revision_phase_revision_decision_question_or_finalization}}
* User response required: {{yes_only_for_a_decision_critical_unresolved_choice, otherwise_no}}
