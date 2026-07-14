<!-- markdownlint-disable-file -->
# RPI Changes: {{task_name}}

## Metadata

* Task ID: {{task_id}}
* Related plan: .copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md
* Phase details: .copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-phase-details.md
* Implementation date: {{YYYY-MM-DD}}

## Execution Status

* Status: {{Complete_Partial_or_Blocked}}
* Completed phases and tasks: {{Pxx_and_Pxx_Txx_list}}
* Remaining phases and tasks: {{none_or_Pxx_and_Pxx_Txx_list}}

## Execution Summary

{{outcome_and_actual_progress_across_completed_phases_and_tasks}}

## Changes

<!-- rpi:change id=CHG-001 -->
### CHG-001: {{change_title}}

* Related task: {{Pxx_Txx}}
* Files: {{workspace_relative_paths}}
* Change: {{what_changed}}
* Completion evidence: {{evidence}}
* Validation: {{run_passed_failed_skipped_or_unavailable}}

## Divergences

<!-- rpi:divergence id=DIV-001 -->
### DIV-001: {{divergence_title}}

* Related task: {{Pxx_or_Pxx_Txx}}
* Linked amendment: AM-001
* Trigger and evidence: {{why_divergence_was_needed}}
* Actual change: {{what_differed}}
* Impact: {{scope_acceptance_or_dependency_impact}}
* Critique disposition: {{Pass_Revise_or_Blocked_after_fresh_critique}}
* Critique evidence: {{PC_xxx_or_critique_artifact_pointer}}

## Validation Record

| Check | Scope | Status | Evidence or reason |
|-------|-------|--------|--------------------|
| {{check}} | {{scope}} | {{Passed_Failed_Skipped_or_Unavailable}} | {{evidence_or_reason}} |

## Blockers

* {{none_or_blocker_with_affected_pxx_or_pxx_txx_and_next_action}}

## Follow-On Work

* {{none_or_distinct_follow_on_item_with_reason_and_owner}}

## Handoff

* Review record: .copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/{{task_slug}}-review.md
* Open blocker or residual work: {{none_or_description}}
