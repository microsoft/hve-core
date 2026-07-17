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

### Key Decisions and Consequences

* {{material_decision_and_its_practical_consequence}}

### What You May Not Know

* {{important_context_dependency_risk_or_constraint_and_why_it_matters}}

### Unresolved Decisions or Blockers

* {{none_or_unresolved_decision_or_blocker_with_owner_or_next_action}}

For detail, see [Sources](#sources), [Scope and Non-Goals](#scope-and-non-goals), [Phase Checklist](#phase-checklist), [Decision Register](#decision-register), and [Handoff](#handoff).

<!-- Add a Further Reading subsection only when an evidence-backed authoritative external link materially improves understanding. -->
<!-- Use optional underline only when renderer support is confirmed and essential emphasis requires it: {{renderer_supported_underline_open}}**{{essential_text}}**{{renderer_supported_underline_close}}. Otherwise, use **{{essential_text}}**. -->

## Sources

* {{source_path_or_caller_context}}: {{how_this_evidence_informs_the_plan}}

## Scope and Non-Goals

### In Scope

* {{in_scope_outcome}}

### Non-Goals

* {{out_of_scope_item}}

## Functional Requirements

* {{functional_requirement_id}}: {{observable_behavior_capability_workflow_step_user_action_or_system_response}}
  * Observable acceptance criteria: {{acceptance_criterion_id}}

## Non-Functional Requirements

* {{non_functional_requirement_id}}: {{measurable_quality_property}}
  * Objective threshold or evaluation condition: {{objective_threshold_or_evaluation_condition}}
  * Operating condition or verification approach, if needed: {{concise_condition_or_objective_verification}}
  * Observable acceptance criteria: {{acceptance_criterion_id}}

## Acceptance Criteria

* {{acceptance_criterion_id}}: {{observable_acceptance_criterion}}

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

## Decision Register

| Decision     | Status                    | Evidence or rationale     | Owner or next action     |
|--------------|---------------------------|---------------------------|--------------------------|
| {{decision}} | {{decided_open_deferred}} | {{evidence_or_rationale}} | {{owner_or_next_action}} |

## Amendment Register

### AM-001: {{amendment_title}}

* Trigger: {{why_the_plan_changed}}
* Affected scope: {{phase_or_task_ids}}
* Updated plan or detail: {{what_changed}}
* Rationale: {{evidence_or_decision}}

## Critique Disposition

| Critique finding  | Disposition                    | Plan response or residual risk |
|-------------------|--------------------------------|--------------------------------|
| {{finding_title}} | {{accepted_resolved_deferred}} | {{response_or_risk}}           |

## Handoff

* Implementation artifact: .copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md
* Ready phase or task: {{next_pxx_or_pxx_txx}}
* Remaining decision or blocker: {{none_or_description}}
