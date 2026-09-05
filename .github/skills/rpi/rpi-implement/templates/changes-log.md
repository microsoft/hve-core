<!-- markdownlint-disable-file -->
# RPI Changes: {{task_name}}

## Metadata

* Task ID: {{task_id}}
* Related plan: [.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md](../../plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md)
* Implementation date: {{YYYY-MM-DD}}

<!-- Wrap code, commands, and symbols in backticks. Link existing files and folders with the workspace-relative path as the link text and a path relative to this file as the destination; repository files are three levels up. Keep a not-yet-created path in backticks. -->

## Execution Status

* Status: {{Complete_Partial_or_Blocked}}
* Declared invocation scope: {{full_plan_Pxx_or_Pxx_Txx}}
* Completed scope markers: {{Pxx_and_Pxx_Txx_completed_within_declared_scope}}
* All remaining active-plan markers: {{none_or_Pxx_and_Pxx_Txx_including_later_work_outside_declared_scope}}
* Status basis: {{why_the_declared_scope_is_complete_partial_or_blocked}}

## Execution Summary

{{outcome_and_actual_progress_across_completed_phases_and_tasks}}

## Completed Work

Use a descriptive subheading for each completed-work item. Do not assign a per-entry formal ID.

### {{completed_work_heading}}

* Related phase or task: {{Pxx_or_Pxx_Txx}}
* Files:
  * [{{workspace/relative/path}}]({{path_relative_to_this_file}})
* What changed and why: {{change_and_reason}}
* Completion evidence: {{evidence}}
* Validation: {{run_passed_failed_skipped_or_unavailable}}

## Implementation-Time Plan Updates

Use a descriptive subheading for each update. The plan remains the current-state authority; this record retains rationale and evidence history.

### {{plan_or_detail_update_heading}}

* Affected plan area or markers: {{plan_section_Pxx_Pxx_Txx_or_Follow_Up_Items}}
* What changed: {{current_plan_change_such_as_a_Guidance_block_added_to_a_later_task}}
* Why: {{rationale}}
* Triggering evidence: {{evidence}}
* User answer or decision: {{none_or_confirmed_user_intent}}
* Reconciliation performed: {{current_sections_task_blocks_markers_diagrams_dependencies_summary_or_follow_up_items_reconciled}}
* Planning and critique state: {{not_needed_or_awaiting_or_current_readiness_with_PC_xxx_when_material}}

For a follow-up-only update, record why the item is outside immediate scope and its owner or next action here and in `## Follow-Up Items`. Keep it outside active `Pxx` and `Pxx-Txx` implementation, completion, and acceptance claims.

## Validation Record

| Check     | Scope     | Status                                   | Evidence or reason     |
|-----------|-----------|------------------------------------------|------------------------|
| {{check}} | {{scope}} | {{Passed_Failed_Skipped_or_Unavailable}} | {{evidence_or_reason}} |

## Pre-Review Reconciliation

* Plan markers and task-local context: {{current_or_gap}}
* Completed-work evidence and handoff prose: {{current_or_gap}}
* Validation, blockers, remaining work, and follow-up items: {{current_or_gap}}
* Review readiness: {{ready_or_not_ready_with_reason}}

## Blockers

* {{none_or_blocker_with_affected_pxx_or_pxx_txx_owner_and_clearing_action}}

## Remaining Work

* {{none_or_remaining_Pxx_or_Pxx_Txx_with_reason_and_next_action}}

## Follow-Up Items

* Canonical plan list: [.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md](../../plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md), `## Follow-Up Items`
* {{none_or_follow_up_item_mirrored_from_the_plan_with_reason_and_owner_or_next_action}}

## Return-to-Caller State

* Implementation execution status: {{Complete_Partial_or_Blocked}}
* Declared scope and markers: {{full_plan_Pxx_or_Pxx_Txx_with_completed_scope_markers_and_all_remaining_active_plan_markers}}
* Validation coverage: {{validation_summary}}
* Blockers: {{none_or_blocker_summary}}
* Current plan updates: {{none_or_descriptive_update_summary}}
* Planning and critique state: {{current_ready_or_awaiting_state_with_relevant_PC_xxx_when_applicable}}
* Follow-up items: {{none_or_follow_up_summary}}
* Review readiness or no-handoff reason: {{ready_for_review_or_explicit_reason}}
* Continuation owner: {{user_for_standalone_or_parent_for_rpi_quick_or_confirmed_automatic_RPI_Agent}}
