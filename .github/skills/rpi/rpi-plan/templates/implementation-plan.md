<!-- markdownlint-disable-file -->
# RPI Plan: {{task_name}}

## Task Metadata

* Task ID: {{task_id}}
* Task slug: {{task_slug}}
* Planning status: {{draft_or_ready}}
* Plan date: {{YYYY-MM-DD}}
* Phase details: .copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-phase-details.md
* Plan critique: .copilot-tracking/reviews/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan-critique.md

## Executive Summary

{{approachable_evidence_based_explanation_of_what_the_plan_will_implement_and_why_it_matters}}

### User Decisions and Requirements Highlights

* {{summary_of_a_current_user_decision_or_requirement_and_its_practical_consequence}}

### What You May Not Know

* {{important_context_dependency_risk_or_constraint_and_why_it_matters}}

### Unresolved Decisions or Blockers

* {{none_or_unresolved_proposal_or_blocker_with_owner_or_next_action}}

For current user input, see [User Decisions and Requirements](#user-decisions-and-requirements). The planner keeps the synthesized sections below current as evidence and user direction evolve.

<!-- Add a Further Reading subsection only when an evidence-backed authoritative external link materially improves understanding. -->
<!-- Use optional underline only when renderer support is confirmed and essential emphasis requires it: {{renderer_supported_underline_open}}**{{essential_text}}**{{renderer_supported_underline_close}}. Otherwise, use **{{essential_text}}**. -->

## User Decisions and Requirements

Keep this as a concise freeform list of current user decisions and requirements. Build entries from user prompts, user-pointed external documents, tasks, issues, and prior research that captures the user's task, goals, requirements, or accepted decisions. Preserve the user's meaning without forcing entries into categories. Add an optional source pointer inside an entry when it is useful. Keep unresolved proposals and blockers outside this section until the user confirms them.

* {{user_decision_or_requirement_with_optional_source_pointer}}

## Goals

The planner synthesizes and maintains these goals from the user list and evidence.

* {{goal}}

## Scope and Non-Goals

The planner synthesizes and maintains these current boundaries from the user list and evidence.

### In Scope

* {{in_scope_outcome}}

### Non-Goals

* {{out_of_scope_item}}

## Functional Requirements

The planner synthesizes and maintains these current requirements from the user list and evidence.

* {{observable_behavior_capability_workflow_step_user_action_or_system_response}}
  * Observable acceptance criteria: {{observable_acceptance_criterion}}

## Non-Functional Requirements

The planner synthesizes and maintains these current requirements from the user list and evidence.

* {{measurable_quality_property}}
  * Objective threshold or evaluation condition: {{objective_threshold_or_evaluation_condition}}
  * Operating condition or verification approach, if needed: {{concise_condition_or_objective_verification}}
  * Observable acceptance criteria: {{observable_acceptance_criterion}}

## Acceptance Criteria

The planner synthesizes and maintains these current criteria from the user list and evidence.

* {{observable_acceptance_criterion}}

## Implementation Context Record

<!-- Persist current transfer facts only. The rpi-plan reference owns rendered standalone and parent continuation guidance. -->

| Context item | Current artifact or record |
|--------------|----------------------------|
| Plan | .copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md |
| Phase details | .copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-phase-details.md |
| Latest critique | .copilot-tracking/reviews/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan-critique.md with {{Pass, Revise, Blocked, or unavailable disposition}} |
| Relevant research | {{research_path_or_not_applicable_with_reason}} |
| Changes-record role | .copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md is created or continued by implementation as its evidence record |
| Planning execution and readiness | {{execution_status_and_ready_or_not_ready_state}} |
| Continuation context | {{standalone advisory, parent return, waiting state, or no-handoff reason}} |

## Sources

* {{source_path_or_caller_context}}: {{how_this_evidence_informs_the_plan}}

## Phase Checklist

<!-- rpi:phase id=P01 -->
### [ ] P01: {{phase_name}}

* Intent: {{phase_outcome}}
* Dependencies: {{phase_dependencies_or_none}}

<!-- rpi:task id=P01-T01 -->
#### [ ] P01-T01: {{task_name}}

* Requirement and evidence: {{requirement_or_source}}
* Expected result: {{observable_result}}
* Detail section: P01-T01 in .copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-phase-details.md

## Dependencies

* {{dependency_or_prerequisite}}: {{why_it_matters}}

## Critique Disposition

Record the latest critique findings, their disposition, and any explicitly accepted residual risk. Keep this section outside user decisions and current planning synthesis.

| Critique run and finding | Disposition                                           | Plan response or residual risk |
|--------------------------|-------------------------------------------------------|--------------------------------|
| {{CR_xxx_finding_key}}   | {{resolved_superseded_accepted_with_risk_or_open}}     | {{response_or_risk}}           |

## Follow-Up Items

* None

<!-- When an implementation-discovered item is added, replace `None` with the item, why it is outside immediate scope, and its owner or next action. Do not add it to active Pxx or Pxx-Txx completion or acceptance claims. -->

## Handoff

* Implementation artifact: .copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md
* Ready phase or task: {{next_pxx_or_pxx_txx}}
* Remaining provisional question or blocker: {{none_or_description}}
