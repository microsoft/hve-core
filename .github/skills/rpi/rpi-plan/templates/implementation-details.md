<!-- markdownlint-disable-file -->
# Implementation Details: {{task_name}}

## Context Reference

Sources: {{context_sources}}

Author this file first, then cite its line ranges from the implementation plan with the `Details: (Lines X-Y)` convention.

## Requirement Evidence

* User requirement source: {{requirement_source_reference}}
* Derived objective evidence: {{research_or_reasoning_reference}}

## Implementation Phase 1: {{phase_1_name}}

<!-- parallelizable: {{true_or_false}} -->

### Step 1.1: {{specific_action_1_1}}

{{specific_action_description}}

Files:

* {{file_1_full_path}} - {{file_1_description}}
* {{file_2_full_path}} - {{file_2_description}}

Discrepancy references:

* {{addresses_or_deviates_from_DR_DD_or_RI_item}}

Success criteria:

* {{completion_criteria_1}}
* {{completion_criteria_2}}

Context references:

* {{reference_full_path}} (Lines {{line_start}}-{{line_end}}) - {{section_description}}

Dependencies:

* {{previous_step_requirement_or_none}}

Validation commands:

* {{lint_build_or_test_command}} - {{scope}}

## Implementation Phase N: Validation

<!-- parallelizable: false -->

### Step N.1: Run full project validation

* {{full_lint_command}}
* {{full_build_command}}
* {{full_test_command}}

### Step N.2: Fix minor validation issues

{{minor_fix_iteration_guidance}}

### Step N.3: Report blocking issues

{{blocking_issue_reporting_guidance}}
