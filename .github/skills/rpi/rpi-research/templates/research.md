<!-- markdownlint-disable-file -->
# Task Research: {{task_slug}}

## Scope and Success Criteria

* Scope: {{task_boundary_relevant_files_constraints_and_exclusions}}
* Assumptions: {{assumptions_to_verify}}
* Success criteria:
  * Evidence is grounded in actual code, docs, or tooling results.
  * Alternatives are compared with trade-offs.
  * Open gaps are explicit and actionable.

## Research Executed

* Questions investigated: {{research_questions}}
* Sources checked: {{files_search_terms_docs_tools}}
* Subagent outputs: `.copilot-tracking/research/subagents/YYYY-MM-DD/<topic>-research.md` and any inline research notes recorded in the primary artifact.

## Key Discoveries

* {{finding_1}}
* {{finding_2}}
* {{finding_3}}

## Technical Scenarios and Alternatives

### Selected: {{selected_approach}}

* Approach: {{selected_approach_description}}
* Rationale: {{evidence_based_rationale}}
* Implementation impact: {{files_components_or_workflow_impact}}

### Alternative: {{alternative_approach}}

* Approach: {{alternative_description}}
* Trade-offs: {{benefits_and_costs}}
* Rejection rationale: {{why_not_selected}}

## Open Questions and Risks

* Blocking: {{blocking_question_or_none}}
* Important: {{important_follow_up_or_none}}
* Follow-up: {{non_blocking_follow_up_or_none}}

## Planning Handoff

* Recommended next step: `/rpi-plan`
* Primary evidence file: `.copilot-tracking/research/YYYY-MM-DD/{{task_slug}}-research.md`
* Notes for planning: {{planning_notes}}
