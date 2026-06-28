<!-- markdownlint-disable-file -->
# Planning Log: {{task_name}}

**Related Plan**: `.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.instructions.md`

## Discrepancy Log

### Unaddressed Research Items

* DR-01: {{research_item_not_in_plan}}
  * Source: {{research_file_full_path}} (Lines {{line_start}}-{{line_end}})
  * Reason: {{why_excluded}}
  * Impact: {{low_medium_or_high}}

### Plan Deviations from Research

* DD-01: {{deviation_description}}
  * Research recommends: {{research_recommendation}}
  * Plan implements: {{plan_approach}}
  * Rationale: {{why_deviated}}

### Reference Integrity

* RI-01: {{reference_integrity_issue}}
  * Source: {{source_file}}
  * Citation: {{citation_or_reference}}
  * Impact: {{impact}}

## Validator Findings

* VF-01: {{validator_finding_summary}}
  * Severity: {{Critical_or_High_or_Medium_or_Low}}
  * Location: {{artifact_path}} (Lines {{line_start}}-{{line_end}})
  * Action: {{required_fix_or_follow_up}}

## Validation Coverage

* Coverage: {{coverage_summary}}
* Requirement Alignment: {{requirements_traced_to_plan_or_details}}
* Detail-Line Verification: {{detail_line_references_verified}}
* Final Validation Phase: {{final_validation_status_and_follow_up}}
* Scratch Evidence: {{scratch_path_or_none}} - {{summary_or_link}}

## Implementation Paths Considered

### Selected: {{selected_path_title}}

* Approach: {{description}}
* Rationale: {{why_selected}}
* Evidence: {{reference_full_path}} (Lines {{line_start}}-{{line_end}})

### IP-01: {{alternate_path_title}}

* Approach: {{description}}
* Trade-offs: {{benefits_and_drawbacks}}
* Rejection rationale: {{why_not_selected}}

## Suggested Follow-On Work

* WI-01: {{title}} - {{description}} ({{priority}})
  * Source: {{where_identified}}
  * Dependency: {{dependency_or_none}}
  * Deferred Work Evidence: {{source_evidence_or_none}}
