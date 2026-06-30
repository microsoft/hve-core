---
applyTo: '.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md'
---
<!-- markdownlint-disable-file -->
# Implementation Plan: {{task_name}}

## Overview

{{task_overview_sentence}}

## Objectives

### User Requirements

* {{user_stated_goal}} - Source: {{caller_stated_requirement_source_or_evidence}}

### Derived Objectives

* {{planner_identified_goal}} - Derived from: {{research_findings_or_reasoning}}

## Context Summary

### Project Files

* {{full_file_path}} - {{file_relevance_description}}

### References

* {{reference_full_file_path_or_url}} - {{reference_description}}

### Standards References

* {{instruction_full_file_path}} - {{instruction_description}}

## Risks and Mitigations

* {{material_risk}} - Likelihood: {{low_medium_high_or_unknown}} - Impact: {{low_medium_high_or_scope}} - Priority: {{likelihood_impact_basis_or_model_reference}} - Status: {{resolved_mitigated_deferred_blocker}} - Rationale: {{rationale}}

## Implementation Checklist

### [ ] Implementation Phase 1: {{phase_1_name}}

<!-- parallelizable: {{true_or_false}} -->

* [ ] Step 1.1: {{specific_action_1_1}}
  * Details: `.copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-details.md` (Lines {{line_start}}-{{line_end}})
* [ ] Step 1.2: {{specific_action_1_2}}
  * Details: `.copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-details.md` (Lines {{line_start}}-{{line_end}})
* [ ] Step 1.3: Validate phase changes
  * Run {{phase_validation_command_or_skip_reason}}

### [ ] Implementation Phase N: Validation

<!-- parallelizable: false -->

* [ ] Step N.1: Run full project validation
  * {{full_lint_command}}
  * {{full_build_command}}
  * {{full_test_command}}
* [ ] Step N.2: Fix minor validation issues
  * {{minor_fix_iteration_guidance}}
* [ ] Step N.3: Report blocking issues
  * {{blocking_issue_reporting_guidance}}

## Planning Log

See `.copilot-tracking/plans/logs/{{YYYY-MM-DD}}/{{task_slug}}-log.md` for discrepancy tracking, validator findings, implementation paths considered, and suggested follow-on work.

## Dependencies

* {{required_tool_or_framework}}

## Success Criteria

* {{overall_completion_indicator}} - Traces to: {{research_item_or_user_requirement}}
