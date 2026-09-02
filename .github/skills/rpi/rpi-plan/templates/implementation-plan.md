<!-- markdownlint-disable-file -->
# RPI Plan: {{task_name}}

## Task Metadata

* Task ID: {{task_id}}
* Task slug: {{task_slug}}
* Plan date: {{YYYY-MM-DD}}

## Executive Summary

* Bottom line: {{approachable_evidence_based_explanation_of_what_the_plan_will_implement}}
* Why this matters: {{practical_effect_on_the_users_goal}}
* Planning result: {{complete_partial_blocked_or_needs_clarification_with_plain_language_reason}}
* Confidence and uncertainty: {{confidence_level_what_is_supported_and_what_remains_uncertain}}

### What You May Not Know

* {{important_context_dependency_risk_or_constraint_and_why_it_matters}}

<!-- Add a Further Reading subsection only when an evidence-backed authoritative external link materially improves understanding. -->
<!-- Use optional underline only when renderer support is confirmed and essential emphasis requires it: {{renderer_supported_underline_open}}**{{essential_text}}**{{renderer_supported_underline_close}}. Otherwise, use **{{essential_text}}**. -->

## User Decisions and Requirements

### Confirmed User Direction

Keep this as a concise freeform list. Preserve the user's meaning and add source pointers only when useful.

* {{user_decision_or_requirement_with_optional_source_pointer}}

### Planning Decisions and Feedback

<!-- Group one decision by default. Combine decisions only when they share a choice, evidence, and consequences or must be resolved together. -->

| Group  | Decision or feedback item | Status                                                     | Owner                                         | Rationale or input needed          | Evidence           | Planning impact                      |
|--------|---------------------------|------------------------------------------------------------|-----------------------------------------------|------------------------------------|--------------------|--------------------------------------|
| {{D1}} | {{item}}                  | {{confirmed/proposed/deferred/unresolved/input requested}} | {{user/agent/evidence/constraint/downstream}} | {{rationale_or_specific_question}} | {{source_or_none}} | {{requirements_phases_or_readiness}} |

## Planning Readiness and Next Step

| Field                            | Record                                                                                         |
|----------------------------------|------------------------------------------------------------------------------------------------|
| Planning execution and readiness | {{Complete/Partial/Blocked/Needs clarification and Ready/Not ready/Blocked with reason}}       |
| Decision participation           | {{user-owned/agent-owned/user-retained with mode and provenance}}                              |
| Blockers                         | {{none_or_current_blockers}}                                                                   |
| Latest critique                  | .copilot-tracking/reviews/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan-critique.md with {{verdict}} |
| Relevant research                | {{research_path_or_not_applicable_with_reason}}                                                |
| Plan                             | .copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md                                   |
| Phase details                    | .copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-phase-details.md                        |
| Changes-record role              | .copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md is implementation evidence   |
| Continuation owner               | {{user/rpi-quick/manual RPI Agent/confirmed automatic RPI Agent}}                              |
| Required gates or confirmations  | {{passed_pending_or_failed_gates}}                                                             |
| Next action                      | {{implementation_advisory_automatic_transition_waiting_decision_or_blocker_action}}            |

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

## Non-Functional Requirements

The planner synthesizes and maintains these current requirements from the user list and evidence.

* {{measurable_quality_property}}
  * Objective threshold or evaluation condition: {{objective_threshold_or_evaluation_condition}}
  * Operating condition or verification approach, if needed: {{concise_condition_or_objective_verification}}

## Acceptance Criteria

The planner maintains acceptance criteria here as the canonical verification record rather than repeating them under requirements.

* Criterion: {{observable_acceptance_criterion}}
  * Related requirement or plan item: {{requirement_or_pxx_reference}}
  * Verification: {{observable_check_or_evidence}}

## Risks and Open Questions

| Priority  | Type                                    | Risk, question, or planning item | Impact     | Smallest action or evidence needed | Owner                       |
|-----------|-----------------------------------------|----------------------------------|------------|------------------------------------|-----------------------------|
| {{H/M/L}} | {{risk/open question/further planning}} | {{item}}                         | {{impact}} | {{next_action_or_evidence}}        | {{user/planner/downstream}} |

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

## Sources

* {{source_path_or_caller_context}}: {{how_this_evidence_informs_the_plan}}

## Critique Disposition

Record the latest critique findings, their disposition, and any explicitly accepted residual risk. Keep this section outside user decisions and current planning synthesis.

| Critique run and finding | Disposition                                        | Plan response or residual risk |
|--------------------------|----------------------------------------------------|--------------------------------|
| {{CR_xxx_finding_key}}   | {{resolved_superseded_accepted_with_risk_or_open}} | {{response_or_risk}}           |

## Artifact Self-Check

* [ ] Executive Summary, confirmed direction, grouped decisions, readiness, goals, scope, requirements, risks, phases, and dependencies are understandable without reading Sources or Critique Disposition.
* [ ] Planning decision participation and provenance are recorded; user-owned and user-retained groups have persisted answers, while agent-owned groups have evidence-backed rationales or honest blockers.
* [ ] Functional and non-functional requirements are current, and Acceptance Criteria is their single verification record.
* [ ] Every `Pxx` and `Pxx-Txx` marker has matching phase details, dependencies, expected results, validation expectations, and completion evidence.
* [ ] Risks, open questions, blockers, critique findings, and accepted residual risks have owners and next actions.
* [ ] Planning execution, readiness, continuation owner, gates, next action, and implementation paths are complete and consistent.
* [ ] Follow-Up Items remain outside active plan completion and acceptance claims.
* Checked sections: {{list_of_checked_sections}}
* Missing or limited sections: {{missing_or_limited_sections_or_none}}

## Follow-Up Items

* None

<!-- When an implementation-discovered item is added, replace `None` with the item, why it is outside immediate scope, and its owner or next action. Do not add it to active Pxx or Pxx-Txx completion or acceptance claims. -->

## Handoff

* Authoritative implementation handoff: Planning Readiness and Next Step
