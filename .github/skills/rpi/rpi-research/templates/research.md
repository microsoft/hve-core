<!-- markdownlint-disable-file -->
# Task Research: {{task_slug}}

Sections wrapped in `<!-- <per_alternative> -->` comments repeat, one block per evaluated alternative; aim for at least three when the design space supports it (see [../references/research.md](../references/research.md)). Omit the comments in the actual document.

## Scope and Success Criteria

* Scope: {{task_boundary_relevant_files_constraints_and_exclusions}}
* Assumptions: {{assumptions_to_verify}}
* Success criteria:
  * Evidence is grounded in actual code, docs, or tooling results.
  * Alternatives are compared with trade-offs.
  * Open gaps are explicit and actionable.

## Task Research Requests

* Explicit requests: {{explicit_user_requests}}
* Inferred research questions: {{inferred_research_questions}}
* Caller constraints and non-goals: {{research_only_no_handoff_analysis_audit_or_comparison_boundaries}}

## Research Executed

* Questions investigated: {{research_questions}}
* Sources checked: {{files_search_terms_docs_tools}}
* Subagent outputs: `.copilot-tracking/research/subagents/YYYY-MM-DD/<topic>-research.md` or `none` with fallback reason {{inline_research_fallback_reason}}.

## Evidence Log

### File Analysis

* {{workspace_relative_file_path}}
  * {{evidence_summary_with_line_ranges}}

### Code Search Results

* {{search_term}}
  * {{matches_with_paths_or_none}}

### External References

* {{tool_or_source}}
  * {{findings_or_none}}

## Key Discoveries

* {{finding_1}}
* {{finding_2}}
* {{finding_3}}

### Complete Examples (when applicable)

```{{language}}
{{illustrative_code_example_derived_from_discovered_conventions}}
```

### Configuration Examples (when applicable)

```{{format}}
{{illustrative_config_example_or_verbatim_excerpt}}
```

## Technical Scenarios and Alternatives

### Selected: {{selected_approach}}

* Approach: {{selected_approach_description}}
* Rationale: {{evidence_based_rationale}}
* Implementation impact: {{files_components_or_workflow_impact}}

File tree (when new, changed, or removed files are involved):

```text
{{file_tree_changes}}
```

Flow diagram (when a multi-component flow is involved):

```mermaid
{{mermaid_diagram}}
```

<!-- <per_alternative> -->
### Alternative: {{alternative_approach}}

* Approach: {{alternative_description}}
* Trade-offs: {{benefits_and_costs}}
* Rejection rationale: {{why_not_selected}}
<!-- </per_alternative> -->

## Open Questions and Risks

* Blocking: {{blocking_question_or_none}}
* Important: {{important_follow_up_or_none}}
* Follow-up: {{non_blocking_follow_up_or_none}}

## Potential Next Research

* {{next_research_item_or_none}}
  * Reason: {{why_it_matters}}
  * Triggering evidence: {{source_or_gap}}

## Advisory Next Step

* Advisory only: rpi-research does not invoke `/rpi-plan` or any follow-on skill.
* Acting owner: user or rpi-quick.
* Advisory recommendation: {{rpi_plan_recommendation_or_no_planning_reason}}
* Primary evidence file: `.copilot-tracking/research/YYYY-MM-DD/{{task_slug}}-research.md`
* Notes for planning: {{planning_notes}}

## Artifact Self-Check

* Checked sections: scope, task requests, research executed, evidence log, key discoveries, alternatives, open questions, potential next research, and advisory next step.
* Missing or limited sections: {{missing_or_limited_sections_or_none}}
