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

## Phase Checklist

<!-- Add the overall diagram once the phases are stable and before critique. Show the components, files, contracts, tests, or behaviors the plan changes and how they relate. Reuse its node IDs in every phase diagram. -->

```mermaid
flowchart LR
    {{node_id}}["{{component_file_contract_or_behavior}}"]
    {{node_id}} -->|{{relationship}}| {{other_node_id}}
    classDef new stroke-dasharray: 5 5
    class {{node_ids_that_do_not_exist_yet}} new
```

<!-- rpi:phase id=P01 -->
### [ ] P01: {{phase_name}}

Goals:
* {{coherent_behavior_or_outcome_this_phase_establishes_and_why_it_matters}}

Dependencies:
* {{phase_dependencies_or_none}}

<!-- Copy the overall diagram and highlight only the nodes this phase changes. Leave the rest unstyled so the reader can locate the phase within the whole. -->

```mermaid
flowchart LR
    {{same_nodes_and_edges_as_the_overall_diagram}}
    classDef phase fill:#fff3bf,stroke:#f08c00,stroke-width:2px
    class {{node_ids_this_phase_changes}} phase
```

<!-- rpi:task id=P01-T01 -->
#### [ ] P01-T01: {{task_name}}

Goals:
* {{observable_behavior_capability_or_state_this_task_establishes}}

Requirements:
* {{requirement_ids_from_this_plan_or_a_linked_PRD_BRD_or_ADR_when_available}}
* {{binding_condition_or_contract_with_a_fenced_code_block_when_the_shape_is_contractual}}

Details:
* {{evidence_backed_context_approach_boundary_test_expectation_or_repository_check_the_implementer_needs}}

References:
* [{{workspace/relative/path}}]({{path_relative_to_this_plan_file}}): {{why_it_is_relevant}}
* [.copilot-tracking/research/{{YYYY-MM-DD}}/{{task_slug}}-research.md](../../research/{{YYYY-MM-DD}}/{{task_slug}}-research.md):
  * {{finding_or_decision_and_the_section_that_holds_it}}

Dependencies:
* {{task_dependencies_or_none}}

<!-- Implementation may insert a `Guidance:` block immediately after `Details:` in a later task when earlier work created something that task needs and the plan did not already name it. -->
<!-- Open decisions for a task belong in Planning Decisions and Feedback; risks and questions belong in Risks and Open Questions. Name the affected Pxx-Txx in those rows instead of adding per-task status blocks. -->
<!-- Wrap code, commands, symbols, and not-yet-created paths in backticks. Link existing files and folders with the workspace-relative path as the link text and a path relative to this plan file as the destination. -->

## User Decisions and Requirements

### Confirmed User Direction

Keep this as a concise freeform list. Preserve the user's meaning and add source pointers only when useful.

* {{user_decision_or_requirement_with_optional_source_pointer}}

### Planning Decisions and Feedback

<!-- Group one decision by default. Combine decisions only when they share a choice, evidence, and consequences or must be resolved together. -->

| Group  | Decision or feedback item | Status                                                     | Owner                                         | Rationale or input needed          | Evidence           | Planning impact                                |
|--------|---------------------------|------------------------------------------------------------|-----------------------------------------------|------------------------------------|--------------------|------------------------------------------------|
| {{D1}} | {{item}}                  | {{confirmed/proposed/deferred/unresolved/input requested}} | {{user/agent/evidence/constraint/downstream}} | {{rationale_or_specific_question}} | {{source_or_none}} | {{affected_Pxx_Txx_requirements_or_readiness}} |

## Planning Readiness and Next Step

| Field                            | Record                                                                                                                                                              |
|----------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Planning execution and readiness | {{Complete/Partial/Blocked/Needs clarification and Ready/Not ready/Blocked with reason}}                                                                            |
| Decision participation           | {{user-owned/agent-owned/user-retained with mode and provenance}}                                                                                                   |
| Planning delegation              | {{adaptive/never/always with caller or default provenance}}                                                                                                         |
| Blockers                         | {{none_or_current_blockers}}                                                                                                                                        |
| Latest critique                  | [.copilot-tracking/reviews/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan-critique.md](../../reviews/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan-critique.md) with {{verdict}} |
| Relevant research                | {{research_link_or_not_applicable_with_reason}}                                                                                                                     |
| Plan                             | `.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md`                                                                                                      |
| Changes-record role              | `.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md` is implementation evidence                                                                      |
| Continuation owner               | {{user/rpi-quick/manual RPI Agent/confirmed automatic RPI Agent}}                                                                                                   |
| Required gates or confirmations  | {{passed_pending_or_failed_gates}}                                                                                                                                  |
| Next action                      | {{implementation_advisory_automatic_transition_waiting_decision_or_blocker_action}}                                                                                 |

<!-- Link the critique and research rows once those files exist; keep a not-yet-created path in backticks. -->

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

* FR-{{nnn}}: {{observable_behavior_capability_workflow_step_user_action_or_system_response}}

## Non-Functional Requirements

The planner synthesizes and maintains these current requirements from the user list and evidence.

* NFR-{{nnn}}: {{measurable_quality_property}}
  * Objective threshold or evaluation condition: {{objective_threshold_or_evaluation_condition}}
  * Operating condition or verification approach, if needed: {{concise_condition_or_objective_verification}}

## Risks and Open Questions

| Priority  | Type                                    | Risk, question, or planning item | Affected work            | Impact     | Smallest action or evidence needed | Owner                       |
|-----------|-----------------------------------------|----------------------------------|--------------------------|------------|------------------------------------|-----------------------------|
| {{H/M/L}} | {{risk/open question/further planning}} | {{item}}                         | {{Pxx_Txx_or_plan_wide}} | {{impact}} | {{next_action_or_evidence}}        | {{user/planner/downstream}} |

## Dependencies

* {{dependency_or_prerequisite}}: {{why_it_matters}}

## Sources

* [{{workspace/relative/path}}]({{path_relative_to_this_plan_file}}): {{how_this_evidence_informs_the_plan}}
* {{caller_context_or_external_source}}: {{how_this_evidence_informs_the_plan}}

<!-- Goals, Scope and Non-Goals, Functional Requirements, Non-Functional Requirements, Risks and Open Questions, Dependencies, and Sources may be omitted when they would hold no content. Do not leave placeholder rows. -->

## Critique Disposition

Record the latest critique findings, their disposition, and any explicitly accepted residual risk. Keep this section outside user decisions and current planning synthesis.

* Critique candidate identity: {{task_id_and_plan_revision_or_hash}}
* Critique depth and provenance: {{standard_or_deep}}; {{default_or_explicit_user_request}}
* Critique execution: {{not_run_started_complete_partial_or_blocked}}
* Single invocation consumed: {{yes_or_no}}

| Critique run and finding | Disposition                                        | Action owner                   | Exact resolving evidence                | Decision route                                     | Plan response or residual risk |
|--------------------------|----------------------------------------------------|--------------------------------|-----------------------------------------|----------------------------------------------------|--------------------------------|
| {{PC_xxx_finding_key}}   | {{resolved_superseded_accepted_with_risk_or_open}} | {{planning_parent_user_other}} | {{artifact_state_validation_or_answer}} | {{direct_correction_or_significant_user_decision}} | {{response_or_risk}}           |

## Artifact Self-Check

* [ ] Executive Summary, What You May Not Know, and the Phase Checklist come first and are understandable without reading the supporting sections.
* [ ] Confirmed direction, grouped decisions, readiness, goals, scope, requirements, risks, and dependencies are current and consistent with the Phase Checklist.
* [ ] Planning decision participation and provenance are recorded; user-owned and user-retained groups have persisted answers, while agent-owned groups have evidence-backed rationales or honest blockers.
* [ ] Planning delegation and provenance are recorded; adaptive, never, or always behavior was followed without overriding phase boundaries.
* [ ] Functional and non-functional requirements are current, and every `FR-nnn` and `NFR-nnn` is cited by at least one task's Requirements.
* [ ] Every `Pxx` has Goals, Dependencies, and a phase diagram that highlights its part of the overall diagram. Every `Pxx-Txx` has Goals, Requirements, Details, References, and Dependencies.
* [ ] Task Goals describe observable behavior, capability, or state without prescribing unsupported implementation steps. Details and References ground the implementer; examples are illustrative unless a requirement or contract makes them binding.
* [ ] Open decisions, risks, and questions live in their tables with the affected `Pxx-Txx` named; no task carries a separate status block.
* [ ] Code, commands, and symbols use backticks. Existing files and folders are Markdown links whose text is the workspace-relative path and whose destination resolves from this plan file.
* [ ] The overall Phase Checklist diagram exists, every phase diagram reuses its node IDs, and both reflect the current phases.
* [ ] Risks, open questions, blockers, critique findings, and accepted residual risks have owners and next actions.
* [ ] Critique depth and provenance are recorded; at most one invocation was dispatched, and all findings are disposed without a retry or closure critique.
* [ ] Planning execution, readiness, continuation owner, gates, next action, and implementation paths are complete and consistent.
* [ ] Follow-Up Items remain outside active plan completion and acceptance claims.
* Checked sections: {{list_of_checked_sections}}
* Missing or limited sections: {{missing_or_limited_sections_or_none}}

## Follow-Up Items

* None

<!-- When an implementation-discovered item is added, replace `None` with the item, why it is outside immediate scope, and its owner or next action. Do not add it to active Pxx or Pxx-Txx completion or acceptance claims. -->

## Handoff

* Authoritative implementation handoff: Planning Readiness and Next Step
