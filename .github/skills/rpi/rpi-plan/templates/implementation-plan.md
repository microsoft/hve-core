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

<!-- Add the change map once the phases are stable and before the critique runs. Follow Change map in references/planning.md: one question in at most about 10 parts and 4 boxes, arrows from the part that acts with active verbs, boxes as layers from left to right, a clause and a tag on every new or changed part, border marks, and no fills, fonts, init line, front matter, edge IDs, or backticks inside labels. Run its check list. A plan that changes one or two parts and no connections replaces the map with one sentence naming them. -->

### Before

<!-- Optional. Keep Before only when the plan changes how parts connect: it removes a part or a connection, or replaces one path with another. Show only the parts that change and the parts they connect to, in After's boxes with After's part IDs. Tag the parts the plan changes or removes, and leave out the parts it adds. Otherwise delete this section. -->

```mermaid
flowchart LR
    accTitle: Before: {{what_the_map_shows_today}}
    accDescr: {{one_sentence_description_of_the_starting_point}}
    subgraph {{box_id}}["`<code>{{workspace/relative/path}}</code>`"]
        {{part_id}}["`<code>{{part_that_stays_the_same}}</code>`"]
        {{changed_part_id}}["`**<code>{{part_the_plan_changes}}</code>**
        changed · {{Pxx}}`"]
        {{removed_part_id}}["`**<code>{{part_the_plan_removes}}</code>**
        removed · {{Pxx}}`"]
    end
    {{part_id}} -->|{{active_verb}}| {{changed_part_id}}
    {{changed_part_id}} -->|{{active_verb}}| {{removed_part_id}}
    classDef changed stroke-width:3px
    classDef removed stroke-dasharray: 2 3,stroke-width:2px
    class {{changed_part_ids}} changed
    class {{removed_part_ids}} removed
```

### After

<!-- Show the result of all phases. Tag new and changed parts beside the unchanged parts they connect to, and leave out removed parts and obsolete arrows. Point each arrow from the part that acts to the part it acts on, labeled with an active verb. Use flowchart TB only for stacked layers with short box titles. -->

```mermaid
flowchart LR
    accTitle: After: {{what_the_map_shows_once_every_phase_lands}}
    accDescr: {{one_sentence_description_of_the_result}}
    subgraph {{box_id}}["`<code>{{workspace/relative/path}}</code>`"]
        {{part_id}}["`<code>{{part_that_stays_the_same}}</code>`"]
        {{changed_part_id}}["`**<code>{{changed_part}}</code>**
        {{what_it_does_after_the_change}}
        changed · {{Pxx}}`"]
    end
    subgraph {{new_box_id}}["`<code>{{new/workspace/relative/path}}</code>
    new file · {{Pxx}}`"]
        {{new_part_id}}["`**{{new_part_name}}**
        {{what_it_does}}
        new · {{Pxx}}`"]
    end
    {{part_id}} -->|{{active_verb}}| {{changed_part_id}}
    {{changed_part_id}} -->|{{active_verb}}| {{new_part_id}}
    classDef new stroke-dasharray: 6 4,stroke-width:2px
    classDef changed stroke-width:3px
    class {{new_box_id}},{{new_part_id}} new
    class {{changed_part_ids}} changed
```

Key: arrows point from a part to what it uses; dotted arrows, tests and docs; dashed border, new; thick border, changed; dotted border, removed, in Before only; each tag names the phases that make the change.

{{two_or_three_sentences_walking_the_main_path_in_arrow_order_naming_the_changed_parts_and_their_phases}}

<!-- rpi:phase id=P01 -->
### [ ] P01: {{phase_name}}

Goals:
* {{coherent_behavior_or_outcome_this_phase_establishes_and_why_it_matters}}

Dependencies:
* {{phase_dependencies_or_none}}

Changes in the map: {{plain_words_naming_the_parts_this_phase_adds_changes_or_removes}}

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

<!-- Optional: add this block after the table for each decision that needs the user's input, using the row's D number; the row stays the record of status, owner, evidence, and impact. Mark one option `(recommended)` only when evidence supports it. Delete the block, or its context line, when no decision needs the user's input; leave no placeholders. -->

#### {{D1}}: {{short_decision_title}}

{{one_line_question}}

* A: {{option_and_its_consequence}}
* B: {{option_and_its_consequence}}

{{optional_context}}

## Planning Readiness and Next Step

| Field                            | Record                                                                                                                                                                                            |
|----------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Planning execution and readiness | {{Complete/Partial/Blocked/Needs clarification and Ready/Not ready/Blocked with reason}}                                                                                                          |
| Decision participation           | {{user-owned/agent-owned/user-retained with mode and provenance}}                                                                                                                                 |
| Blockers                         | {{none_or_current_blockers}}                                                                                                                                                                      |
| Latest critique                  | [.copilot-tracking/reviews/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan-critique.md](../../reviews/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan-critique.md) with {{verdict}}, or `skipped` with provenance |
| Relevant research                | {{research_link_or_not_applicable_with_reason}}                                                                                                                                                   |
| Plan                             | `.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md`                                                                                                                                    |
| Changes-record role              | `.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md` is implementation evidence                                                                                                    |
| Continuation owner               | {{user/manual RPI Agent/confirmed automatic RPI Agent}}                                                                                                                                           |
| Required gates or confirmations  | {{passed_pending_or_failed_gates}}                                                                                                                                                                |
| Next action                      | {{implementation_advisory_automatic_transition_waiting_decision_or_blocker_action}}                                                                                                               |

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

Record the critique setting, status, verdict, finding dispositions, and any explicitly accepted residual risk. Keep this section outside user decisions and current planning synthesis.

* Critique setting and provenance: {{standard_deep_or_skip}}; {{default_explicit_user_request_or_parent_session}}
* Critique status: {{not_run_started_skipped_or_Complete_Partial_Blocked_or_not_produced}}
* Latest critique and verdict: {{critique_path_with_Pass_Revise_Blocked_or_unavailable_or_not_applicable_when_skipped}}
* Earlier critiques: {{none_or_earlier_critique_paths}}
* Limitations: {{none_or_run_limitation_interruption_kind_and_next_action}}

<!-- When the critique result exists, add a row per finding as open, then update each row as its correction lands. Keep every finding row. A follow-up critique adds rows or updates dispositions without deleting earlier findings. -->

| Critique run and finding | Disposition                                        | Action owner                   | Exact resolving evidence                | Decision route                                     | Plan response or residual risk |
|--------------------------|----------------------------------------------------|--------------------------------|-----------------------------------------|----------------------------------------------------|--------------------------------|
| {{PC_xxx_finding_key}}   | {{resolved_superseded_accepted_with_risk_or_open}} | {{planning_parent_user_other}} | {{artifact_state_validation_or_answer}} | {{direct_correction_or_significant_user_decision}} | {{response_or_risk}}           |

## Artifact Self-Check

* [ ] Executive Summary, What You May Not Know, and the Phase Checklist come first and are understandable without reading the supporting sections.
* [ ] Confirmed direction, grouped decisions, readiness, goals, scope, requirements, risks, and dependencies are current and consistent with the Phase Checklist.
* [ ] Planning decision participation and provenance are recorded; user-owned and user-retained groups have persisted answers, while agent-owned groups have evidence-backed rationales or honest blockers.
* [ ] Functional and non-functional requirements are current, and every `FR-nnn` and `NFR-nnn` is cited by at least one task's Requirements.
* [ ] Every `Pxx` has Goals, Dependencies, and a `Changes in the map:` line that matches the tags naming it. Every `Pxx-Txx` has Goals, Requirements, Details, References, and Dependencies.
* [ ] Task Goals describe observable behavior, capability, or state without prescribing unsupported implementation steps. Details and References ground the implementer; examples are illustrative unless a requirement or contract makes them binding.
* [ ] Open decisions, risks, and questions live in their tables with the affected `Pxx-Txx` named; no task carries a separate status block.
* [ ] Code, commands, and symbols use backticks. Existing files and folders are Markdown links whose text is the workspace-relative path and whose destination resolves from this plan file.
* [ ] The change map answers one question in at most about 10 parts and 4 boxes, with unchanged parts only where a changed part connects to them, or the plan changes one or two parts and no connections and names them in one sentence instead.
* [ ] Every arrow has an active verb and points from the part that acts, and boxes show where changes land, ordered so arrows run one way. Before appears only because connections change, in After's boxes with After's part IDs, and After shows the intended result of all phases.
* [ ] Every new, changed, or removed part has its border class and a tag naming real phases, and each new or changed part has a bold name and one short clause. Each diagram has `accTitle` and `accDescr` and no fills, fonts, `%%{init}%%` line, front matter, edge IDs, or backticks inside labels. The key and walk-through follow After, and rendering in light and dark was checked, or the preview limitation is recorded.
* [ ] Risks, open questions, blockers, critique findings, and accepted residual risks have owners and next actions.
* [ ] The critique setting and provenance are recorded. The critique ran on the implementation-ready plan or was skipped by user or parent direction, and every `PC-xxx` has a disposition or accepted residual risk.
* [ ] Readiness does not rely on a critique that returned no result.
* [ ] Planning execution, readiness, continuation owner, gates, next action, and implementation paths are complete and consistent.
* [ ] Follow-Up Items remain outside active plan completion and acceptance claims.
* Checked sections: {{list_of_checked_sections}}
* Missing or limited sections: {{missing_or_limited_sections_or_none}}

## Follow-Up Items

* None

<!-- When an implementation-discovered item is added, replace `None` with the item, why it is outside immediate scope, and its owner or next action. Do not add it to active Pxx or Pxx-Txx completion or acceptance claims. -->

## Handoff

* Authoritative implementation handoff: Planning Readiness and Next Step
