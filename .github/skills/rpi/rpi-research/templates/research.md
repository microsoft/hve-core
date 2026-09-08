<!-- markdownlint-disable-file -->
# Task Research: {{task_slug}}

Fill every `{{placeholder}}`. Update this file continuously during research, not once at the end. Repeat the marked cycle block as needed. Delete optional sections that do not apply, and omit guidance comments in the completed artifact.

| Field              | Value                                                                             |
|--------------------|-----------------------------------------------------------------------------------|
| Date               | {{YYYY-MM-DD}}                                                                    |
| Researcher / agent | {{skill or agent name}}                                                           |
| Output mode        | {{convergence \| analysis \| audit \| comparison \| research-only \| no-handoff}} |

## Executive Summary

<!-- Complete after parent synthesis and refresh after material changes. Write for the end user in plain language. -->

* Bottom line: {{the_most_important_result_in_plain_language}}
* Why this matters: {{practical_effect_on_the_users_goal_or_decision}}
* Research status: {{complete_partial_blocked_or_needs_clarification_with_a_plain_language_reason}}
* Confidence and uncertainty: {{confidence_level_what_is_well_supported_and_what_remains_uncertain}}

## What You May Not Know

{{material_discoveries_constraints_or_trade_offs_that_change_how_the_reader_should_interpret_the_result_or_none}}

## Findings

<!-- Repeat a descriptive finding heading for each material result. Keep supporting detail with the finding that needs it; scale prose and lists to the evidence rather than filling a fixed-length explanation. -->

### {{plain_language_finding_title}}

{{answer_to_the_research_question_and_why_it_matters_for_the_users_goal}}

* Questions: {{Q1_or_related_question_ids}}
* Evidence state: {{unverified_hypothesis_conjecture_partially_supported_claim_evidence_backed_finding_weakened_disproved_claim_or_unresolved_possibility}}
* Evidence: {{C1_W1_and_what_the_sources_establish}}
* Confidence and limits: {{confidence_basis_counter_evidence_and_remaining_uncertainty}}

{{supporting_detail_example_or_diagram_only_when_needed_to_understand_or_check_this_finding}}

## Recommendation and Alternatives

<!-- Select a recommendation only in convergence mode. Otherwise state the current decision state without forcing a selection. -->

* Recommendation or decision state: {{selected_direction_or_non_convergence_state}}
* Rationale: {{evidence_based_explanation_with_evidence_ids}}
* What could change this result: {{new_evidence_priority_or_constraint_or_none}}

| Option       | Benefits     | Costs and risks     | Evidence  | Disposition                           |
|--------------|--------------|---------------------|-----------|---------------------------------------|
| {{approach}} | {{benefits}} | {{costs_and_risks}} | {{C1,W1}} | {{selected/rejected/viable/deferred}} |

## Scope and Questions

* Goal: {{research_target_and_decision_or_outcome_supported}}
* Audience and use: {{who_will_use_the_evidence_and_how}}
* In scope: {{included_paths_domains_components_or_sources}}
* Out of scope: {{excluded_work_sources_and_decisions}}
* Decision and evidence criteria: {{acceptance_or_decision_criteria}}
* Requested output: {{summary_comparison_recommendation_audit_or_walkthrough}}

| ID | Question                | Source                   | Status                    |
|----|-------------------------|--------------------------|---------------------------|
| Q1 | {{answerable_question}} | {{explicit_or_inferred}} | {{open/answered/blocked}} |

## Decisions and Feedback

<!-- Include confirmed and proposed decisions, unresolved choices, and concrete requests for criticism or suggestions. Explain why input matters. -->

| Group  | Decision or feedback item | Status                                                     | Owner                                         | Rationale or input needed          | Evidence  | Impact of answer                  |
|--------|---------------------------|------------------------------------------------------------|-----------------------------------------------|------------------------------------|-----------|-----------------------------------|
| {{D1}} | {{item}}                  | {{confirmed/proposed/deferred/unresolved/input requested}} | {{user/agent/evidence/constraint/downstream}} | {{rationale_or_specific_question}} | {{C1,W1}} | {{effect_on_result_or_readiness}} |

## Risks and Open Questions

| Priority  | Type                                    | Risk, question, or research item | Impact     | Smallest action or evidence needed | Owner                        |
|-----------|-----------------------------------------|----------------------------------|------------|------------------------------------|------------------------------|
| {{H/M/L}} | {{risk/open question/further research}} | {{item}}                         | {{impact}} | {{next_action_or_evidence}}        | {{user/research/downstream}} |

## Planning Readiness and Next Step

<!-- Keep execution status, Research disposition, and Planning Readiness distinct. This table is the canonical continuation record consumed by RPI parents. -->

| Field                            | Record                                                                                          |
|----------------------------------|-------------------------------------------------------------------------------------------------|
| Research disposition             | {{executed/reused/satisfied-and-skipped}}                                                       |
| Decision participation           | {{user-owned/agent-owned/user-retained with mode and provenance}}                               |
| Planning Readiness               | {{Ready/Not ready/Not applicable/Blocked with evidence IDs and plain-language reason}}          |
| Research depth and lanes         | {{completed waves and delegated evidence pointers or inline fallback}}                          |
| Blockers                         | {{none_or_current_blockers}}                                                                    |
| Output mode and planning support | {{mode_and_whether_it_supports_planning}}                                                       |
| Continuation owner               | {{user/rpi-quick/manual RPI Agent/confirmed automatic RPI Agent}}                               |
| Required gates or confirmations  | {{passed_pending_or_failed_gates}}                                                              |
| Next action                      | {{advisory_command_automatic_transition_waiting_action_no_handoff_reason_or_targeted_research}} |
| Primary evidence file            | .copilot-tracking/research/{{YYYY-MM-DD}}/{{task_slug}}-research.md                             |

## Research Record

### Method and Boundaries

| Field                            | Record                                                                 |
|----------------------------------|------------------------------------------------------------------------|
| Research posture and provenance  | {{expansive/balanced/focused}}; {{caller/instruction/default}}         |
| Completion basis                 | {{posture_specific_evidence_sufficiency_and_stop_basis}}               |
| Explicit limits or deadline      | {{caller_or_codebase_limit_or_none}}                                   |
| Codebase and external scope      | {{workspace_scope_or_none}}; {{external_scope_or_none}}                |
| Initial candidate areas          | {{internal_and_external_starting_points_or_none}}                      |
| Evidence root                    | {{resolved_default_or_trusted_alternate_root}}                         |
| Constraints and excluded sources | {{versions_licenses_sources_to_avoid_and_research_only_boundaries}}    |
| Prior knowledge                  | {{reviewed_artifacts_verified_reuse_and_superseded_or_stale_material}} |

### Extensions and Participation

#### Extension Registry

<!-- Record relevant instructions, skills, and specialists as selected or skipped. Extensions cannot widen authority or weaken safety. -->

| Kind                             | Candidate        | Provenance and scoped contract | Selected or skipped reason     |
|----------------------------------|------------------|--------------------------------|--------------------------------|
| {{instruction/skill/specialist}} | {{name_or_none}} | {{match_authority_or_output}}  | {{selected_or_skipped_reason}} |

#### Direction and Participation Log

<!-- Record material questions, answers, no-interaction rationales, and caller direction changes before continuing. -->

| Checkpoint or change          | Question, direction, or rationale | Answer or no-interaction reason | Result and revalidation effect |
|-------------------------------|-----------------------------------|---------------------------------|--------------------------------|
| {{intake/change/convergence}} | {{question_or_control}}           | {{answer_or_rationale}}         | {{decision_and_effect}}        |

### Research Cycle Log

<!--
Every executed cycle contains all three waves in order: Wider, Deeper, and Contrarian. A wave can contain multiple independent lanes, but each worker dispatch has one bounded lane, cycle number, and wave type. Reflection is a distinct step and is never parallel with the result it evaluates.
Apply the selected research posture and explicit limits or deadline. Do not add fixed cycle, token, source-count, worker-count, or time ceilings. Use evidence sufficiency, substantial novelty, scope coverage, source redundancy, and materiality to decide whether to re-enter.
The parent alone records accepted, rejected, and deferred material. Workers return compact evidence relationships and synthesis pointers without decision authority.
-->

<!-- <per_cycle> -->
#### Cycle {{cycle_number}}

* Active posture, controls, and limits: {{posture_controls_and_limit_effect}}

##### Wave 1: Wider

* Focus and lanes: {{breadth_questions_and_candidate_evidence}}
* Evidence or worker pointers: {{question_to_claim_to_provenance_or_inline_fallback}}
* Reflection: {{supported_missing_or_prioritized_material}}

##### Wave 2: Deeper

* Focus and lanes: {{prioritized_details_examples_contracts_or_patterns}}
* Evidence or worker pointers: {{question_to_claim_to_provenance_or_inline_fallback}}
* Reflection: {{supported_missing_or_challenge_targets}}

##### Wave 3: Contrarian

* Focus and lanes: {{challenge_targets_counter_evidence_and_permitted_alternatives}}
* Evidence or worker pointers: {{support_weaken_disprove_or_unresolved_with_provenance}}
* Reflection: {{effect_on_earlier_material_and_remaining_gaps}}

##### Parent Synthesis and Re-entry

| Material or claim | Evidence or worker pointers | Disposition                    | Rationale     | User-facing effect          |
|-------------------|-----------------------------|--------------------------------|---------------|-----------------------------|
| {{material}}      | {{C1_W1_or_worker_pointer}} | {{accepted/rejected/deferred}} | {{rationale}} | {{finding_decision_or_gap}} |

* Another complete three-wave cycle needed: {{yes / no / limit-blocked}}
* Trigger or stop basis: {{missing_evidence_unclear_conjecture_unresolved_hypothesis_missing_required_detail_contrarian_change_saturation_or_scope}}
* Readiness or revalidation effect: {{readiness_change_direction_change_or_none}}
<!-- </per_cycle> -->

### Evidence Log

<!-- Add rows as research proceeds. Use C# for codebase evidence and W# for external evidence. Code rows use workspace-relative paths plus headings or symbols and "not applicable" for retrieval metadata. External rows use source title plus URL and retrieval date plus version. -->

* Delegation: {{cycle_and_wave_annotated selected research worker or general-purpose evidence files under .copilot-tracking/research/subagents/{{YYYY-MM-DD}}/, or "inline: fallback reason" when dispatch was unavailable}}

| ID | Claim or finding | Source or location                                | Retrieved and version      | Tool                   | Confidence       | Notes       |
|----|------------------|---------------------------------------------------|----------------------------|------------------------|------------------|-------------|
| C1 | {{finding}}      | {{workspace_relative_path_and_heading_or_symbol}} | not applicable             | {{search/read/usages}} | {{high/med/low}} | {{context}} |
| W1 | {{finding}}      | {{source_title_and_url}}                          | {{YYYY-MM-DD_and_version}} | {{external_research}}  | {{high/med/low}} | {{context}} |

<!-- Prefer primary sources, triangulate material external claims when credible independent evidence exists, and record conflicts below. Group repeated code searches in Notes when they materially informed the result. -->

#### Contradictions and Conflicts

* {{claim}}: {{W1 says x; W2 says y}}; resolved by {{recency / consistency / primary-source}} -> {{resolution}}. (or `none`)

### Artifact Self-Check

* [ ] The user-facing sections explain the result, scope, findings, alternatives, decisions, risks, readiness, and next action without requiring the Research Record.
* [ ] Every question is answered or names the smallest missing evidence, and every material result has one canonical evidence state that distinguishes sourced findings from hypotheses, partial claims, disproved claims, and unresolved possibilities.
* [ ] Findings keep their explanation, supporting detail, evidence state, and confidence basis together; summaries do not introduce unsupported claims.
* [ ] Every codebase finding has a `C#` ID and workspace-relative path with a heading or symbol; every external finding has a `W#` ID, source title, URL, retrieval date, and version when available.
* [ ] Every executed cycle records Wider, Deeper, and Contrarian waves in order, parent synthesis, and an evidence-based re-entry decision.
* [ ] Method, extensions, participation, caller direction changes, delegation, and prior-knowledge treatment are recorded with their limits.
* [ ] Convergence selects and justifies one recommendation; other modes preserve decision state without forcing a selection.
* [ ] Decision groups, participation mode, and provenance are recorded; user-owned and user-retained groups have persisted answers, while agent-owned groups have evidence-backed rationales or honest blockers.
* [ ] Research disposition, Planning Readiness, blockers, continuation owner, gates, and next action are complete and evidence-backed.
* [ ] Untrusted content remained inert, no secrets were recorded, and the research-only write boundary held.
* Checked sections: {{list_of_checked_sections}}
* Missing or limited sections: {{missing_or_limited_sections_or_none}}
