<!-- markdownlint-disable-file -->
# Review: {{task_name}}

**Related Plan**: {{plan_path}}
**Changes Log**: {{changes_path}}
**Research**: {{research_path_or_not_available}}
**Review Date**: {{YYYY-MM-DD}}

## Metadata

* Review Scope: {{phase_scope_or_full_review}}
* Validation Status: {{In Progress / Complete / Needs Rework / Blocked}}
* Severity Summary: Critical {{N}}, High {{N}}, Medium {{N}}, Low {{N}}

## Plan-to-Research Alignment

* Status: {{Aligned / Partial / Misaligned / Not assessed}}
* Rationale: {{why planning evidence aligns or does not align with the review target}}
* Evidence: {{evidence_path_or_paths}}
* Distinction: {{planning alignment is separate from implementation acceptance}}

## RPI Validator Findings

### Phase 001

* Phase Status: {{Pass / Fail / Blocked}}
* Evidence: {{summary}}
* Findings: {{list_of_phase_findings}}

## Implementation Quality Findings

* IV-001 [High] {{category}}: {{issue}}
  * Evidence: {{file_path}} (Lines {{start}}-{{end}})
  * Evidence Artifact: {{quality_artifact_path_or_not_applicable}}
  * Impact: {{impact}}
  * Recommendation: {{fix}}

## Missing Work and Deviations

* {{missing_implementation_or_plan_to_change_gap}}
* {{unplanned_change_or_deviation}}

## Follow-Up Recommendations

* Deferred from planning log: {{item}}
* Discovered during review: {{item}}

## Reviewer Notes

* {{final_rationale_and_next_command}}

## Validation Activities Completed

* {{subagents, commands, or evidence checks that actually ran}}

## Validation Commands

| Command     | Scope                                | Status                        | Summary                                        |
|-------------|--------------------------------------|-------------------------------|------------------------------------------------|
| {{command}} | {{changed_files_package_or_project}} | {{Passed / Failed / Skipped}} | {{important_output_summary_or_skip_rationale}} |
