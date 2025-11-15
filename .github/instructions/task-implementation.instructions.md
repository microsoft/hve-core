---
applyTo: '**/.copilot-tracking/changes/*.md'
description: 'Required instructions for implementing task plans located in .copilot-tracking/plans and .copilot-tracking/details folders, with progressive tracking and change records - Brought to you by microsoft/edge-ai'
---
# Task Plan Implementation Instructions

Implementers must fulfill task plans instructions located in `.copilot-tracking/plans/**` by applying the paired task plan details and research references. Progress is tracked in matching change logs located in `.copilot-tracking/changes/**`.

## Scope and Purpose

* Guides the end-to-end process for turning plan checklists into committed code changes.
* Ensures change logs remain synchronized with plan progress and user-provided stop controls.

## Required Artifacts

* **Task Plan Instructions**: `.copilot-tracking/plans/<date>-<description>-plan.instructions.md`
* **Task Plan Details**: `.copilot-tracking/details/<date>-<description>-details.md`
* **Research References**: `.copilot-tracking/research/<date>-<description>-research.md`
* **Changes Log**: `.copilot-tracking/changes/<date>-<description>-changes.md`
* **Workspace Standards**: Reference the relevant guidance in `.github/instructions/**` before editing code.

## Preparation Rules

* Note any `${input:taskStop:false}` or `${input:phaseStop:true}` values supplied with the plan.
* Review the plan header, overview, and checklist structure to understand task plan phases, tasks, and dependencies.
* Inspect the existing changes log to confirm current status before making edits.
* Do **not** read entire details or research files upfront. Use the line ranges provided in each task plan entry to load only the required segments with `read_file(offset=<start>, limit=<end-start+1>)`.

## Required Protocol

Follow these steps in order until all task plan phases and tasks are complete.

1. **Select the next task**
   * Locate the first unchecked `[ ] Phase` in the task plan instructions.
   * Within that phase, choose the earliest unchecked `[ ] Task`.
   * If every task is complete, move to the completion checks section below.

2. **Load task plan details by line range**
   * Use the `(Lines X-Y)` hint from the plan to read the matching slice from the task plan details file.
   * If the slice lacks necessary context, load additional targeted ranges rather than the entire file.

3. **Verify task plan dependencies**
   * Review the `Dependencies` list for the current task details.
   * If a dependency task was previously marked complete but its outputs are missing, uncheck that dependency in the task plan instructions, append required notes to its details section, and restart the protocol using the re-opened task.

4. **Review task plan research references**
   * Use each `(Lines X-Y)` pointer in the task details’s `Research References` section to read only the specified segments from the research markdown file.
   * Expand the range only when the cited excerpt is insufficient to proceed.

5. **Gather project context and implement the task**
   * Refer to the task detail’s `Files` section for expected touchpoints and update any additional files required to meet the task detail’s `Success` criteria.
   * Read additional workspace sources as needed to confirm conventions, variable definitions, or prior implementations.
   * Apply code or content changes that satisfy the task detail’s `Success` subsection.
   * Follow repository style guides, validation workflows, and dependency management practices.
   * Perform required tooling runs (lint, validate, only run tests if specified or implementing tests) before marking the task complete.

6. **Update tracking artifacts**
   * Append entries to the changes log under **Added**, **Modified**, or **Removed**, noting relative paths and concise summaries.
   * Record any deviations from the task plan details in the relevant section of the changes log and update the task plan details file with clarifying guidance when future work is required.
   * Mark the task as `[x]` in the task plan instructions once validation passes.

7. **Respect stop controls**
   * If `${input:taskStop}` is true, pause after marking the current task plan instructions complete and await user confirmation before selecting the next task.
   * When a phase’s tasks are all `[x]`, mark the phase as complete. If `${input:phaseStop}` is true or unspecified, pause before beginning the next phase; continue immediately only when `phaseStop=false`.

8. **When stopping due to stop controls**
   * Review all changes since previously stopping due to stop controls.
   * Provide the user in the conversation a commit message between a markdown codeblock by following the instructions from #file:./commit-message.instructions.md based on all changes since previously stopping.
   * Include any additional changes that were added from the user.
   * Do not include any changes or updates to files in `.copilot-tracking` for the commit message.

9. **Repeat for remaining tasks**
   * Resume at Step 1 with the next unchecked task or phase from the task plan instructions.

## Implementation Standards

* Mirror existing patterns for architecture, data flow, and naming found in the current repository.
* Keep code self-contained, avoiding partial implementations that leave completed tasks in an indeterminate state.
* Run required validation commands (linters, validation, only run tests if specified or implementing tests) relevant to the artifacts you touched.
* Document complex logic with concise comments only when necessary for maintainers.

## Completion Checks

Implementation work is entirely complete when:

* Every task plan phase and task is marked `[x]` in the task plan instructions with aligned change log updates.
* All referenced files compile, lint, and if specified or implementing tests then test successfully.
* The changes log includes a Release Summary only after the final phase is complete.
* Outstanding follow-ups are noted in the task details file for future task plans.

## Changes Log Expectations

* Keep the changes file chronological. Add new summaries just beneath the relevant **Added**, **Modified**, or **Removed** heading after each task plan task.
* Capture links to supporting research excerpts when they inform implementation decisions.

## Changes File Template

Use this template when creating or refreshing a change log. Replace `{{ }}` placeholders accordingly and save under `.copilot-tracking/changes/` using the naming pattern `YYYYMMDD-task-description-changes.md`.

**IMPORTANT**: Update the log after every task plan task completion by appending to the **Added**, **Modified**, or **Removed** sections.
**MANDATORY**: Begin every changes file with `<!-- markdownlint-disable-file -->`.

<!-- <changes-template> -->
```markdown
<!-- markdownlint-disable-file -->
# Release Changes: {{task name}}

**Related Plan**: {{plan-file-name}}
**Implementation Date**: {{YYYY-MM-DD}}

## Summary

{{Brief description of the overall changes made for this release}}

## Changes

### Added

* {{relative-file-path}} - {{one sentence summary of what was implemented}}

### Modified

* {{relative-file-path}} - {{one sentence summary of what was changed}}

### Removed

* {{relative-file-path}} - {{one sentence summary of what was removed}}

## Release Summary

**Total Files Affected**: {{number}}

### Files Created ({{count}})

* {{file-path}} - {{purpose}}

### Files Modified ({{count}})

* {{file-path}} - {{changes-made}}

### Files Removed ({{count}})

* {{file-path}} - {{reason}}

### Dependencies & Infrastructure

* **New Dependencies**: {{list-of-new-dependencies}}
* **Updated Dependencies**: {{list-of-updated-dependencies}}
* **Infrastructure Changes**: {{infrastructure-updates}}
* **Configuration Updates**: {{configuration-changes}}

### Deployment Notes

{{Any specific deployment considerations or steps}}
```
<!-- </changes-template> -->
