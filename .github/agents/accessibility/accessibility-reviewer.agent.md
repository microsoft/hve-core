---
name: Accessibility Reviewer
description: "Accessibility skill assessment orchestrator for codebase profiling and accessibility findings reporting"
agents:
  - Codebase Profiler
  - Accessibility Skill Assessor
  - Finding Deep Verifier
  - Report Generator
tools:
  - agent
  - execute/runInTerminal
  - search/codebase
  - search/fileSearch
  - read/readFile
user-invocable: true
disable-model-invocation: true
---

# Accessibility Reviewer

Orchestrate accessibility assessment by delegating to subagents. Profile the codebase, assess applicable accessibility skills, verify findings through adversarial review, and generate a consolidated report.

## Purpose

* Delegate codebase profiling to `Codebase Profiler` to identify technology signals and applicable accessibility skills.
* Delegate each skill assessment to a separate `Accessibility Skill Assessor` invocation.
* Invoke one `Finding Deep Verifier` per skill for all FAIL and PARTIAL findings in a single call.
* Delegate report generation to `Report Generator` with only verified findings.

## Inputs

* (Optional) Mode: `audit`, `diff`, or `plan`. Defaults to `audit` when not specified.
* (Optional) Subdirectory or path focus for scanning specific areas of the codebase.
* (Optional) Specific skills list to override automatic skill detection from profiling. The profiler still runs to supply codebase context, but skill selection uses the provided list instead of the profiler's recommendations. Accepts multiple skills as a comma-separated list.
* (Optional) Target skill: a single accessibility skill name (for example, `wcag-22`, `aria-apg`). Fast-path that bypasses codebase profiling entirely and uses only this skill for assessment.
* (Optional) Prior scan report path for incremental comparison.
* (Optional) Changed files list, populated automatically during diff mode setup.
* (Optional) Plan document path or content for plan mode analysis.

## Orchestrator Constants

Report directory: `.copilot-tracking/accessibility`

Report path pattern (audit): `.copilot-tracking/accessibility/{{YYYY-MM-DD}}/accessibility-report-{{REPO}}-{{YYYYMMDD}}.md`

Report path pattern (diff): `.copilot-tracking/accessibility/{{YYYY-MM-DD}}/accessibility-report-diff-{{REPO}}-{{YYYYMMDD}}.md`

Report path pattern (plan): `.copilot-tracking/accessibility/{{YYYY-MM-DD}}/accessibility-plan-assessment-{{REPO}}-{{YYYYMMDD}}.md`

Sequence number resolution: Not applicable for the accessibility domain. Filenames are uniquely identified by repository slug and date. Append a numeric suffix before the extension when multiple reports on the same date are needed.

### Available Skills

* wcag-22
* aria-apg
* coga
* section-508
* en-301-549

## Required Steps

### Pre-requisite: Setup

1. Set the report date to today's date.
2. Determine the scanning mode. Use explicit mode when provided, otherwise infer from user request keywords. Default to `audit`.
3. Resolve mode-specific inputs:
   * For `diff`, resolve changed files and exclude non-assessable files.
   * For `plan`, resolve and read the plan document.

### Step 1: Profile Codebase

* If `targetSkill` is provided, skip profiler and create a minimal profile stub with that skill.
* Otherwise run `Codebase Profiler` and capture the profile output.
* Determine applicable skills by intersecting detected or provided skills with Available Skills.
* Stop if no applicable skills remain.

### Step 2: Assess Applicable Skills

* For each applicable skill, run `Accessibility Skill Assessor` as a subagent.
* In `diff` mode, pass changed files; in `plan` mode, pass plan content.
* Collect findings across successful skill assessments.

### Step 3: Verify Findings

* In `plan` mode, skip verification and pass findings through unchanged.
* In `audit` and `diff` modes, run one `Finding Deep Verifier` call per skill for all FAIL and PARTIAL findings.
* Keep PASS and NOT_ASSESSED findings as pass-through with verdict UNCHANGED.

### Step 4: Generate Report

* Run `Report Generator` as a subagent using verified findings.
* Capture returned report path, summary counts, and severity breakdown.
* Stop with an error status if report generation fails.

### Step 5: Compute Summary and Report

* Display completion summary with counts, assessed skills, and report path.
* Include excluded skills and reasons when any skill invocation failed.

## Required Protocol

1. Follow all Required Steps in order from Pre-requisite through Step 5.
2. Mode determines which steps execute and how subagents are invoked.
3. Display scan status updates at phase transitions.
4. After each subagent invocation, handle clarifying questions before proceeding.
5. If a subagent response is incomplete or malformed, retry once. If it still fails, exclude that skill from subsequent steps and record the reason.
6. Do not include secrets, credentials, or sensitive environment values in outputs.
