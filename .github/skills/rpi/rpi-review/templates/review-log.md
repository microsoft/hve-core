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

## Execution Status

* Execution status: {{Complete_Partial_or_Blocked}}

## Plan-to-Change Reconciliation

| Plan scope         | Change evidence               | Reconciliation status             | Gap or rationale     |
|--------------------|-------------------------------|-----------------------------------|----------------------|
| {{Pxx_or_Pxx_Txx}} | {{CHG_xxx_or_other_evidence}} | {{Reconciled_Partial_or_Missing}} | {{gap_or_rationale}} |

## Critique and Divergence Assessment

* Critique dispositions: {{coverage_summary}}
* Amendments and divergences: {{coverage_summary}}
* Justification assessment: {{supported_or_unresolved_rationale}}

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

## Validation Evidence

| Command     | Scope                                | Status                                      | Summary                                        |
|-------------|--------------------------------------|---------------------------------------------|------------------------------------------------|
| {{command}} | {{changed_files_package_or_project}} | {{Passed / Failed / Skipped / Unavailable}} | {{important_output_summary_or_skip_rationale}} |

## Outcome

* Outcome: {{Conformant_Conformant_with_justified_divergence_Defects_found_Residual_work_or_Not_accepted}}
* Outcome rationale: {{evidence_based_rationale}}

## Next Owner

* {{rpi_implement_rpi_plan_rpi_research_or_distinct_follow_up_owner}}
