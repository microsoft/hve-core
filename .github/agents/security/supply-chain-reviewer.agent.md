---
name: Supply Chain Reviewer
description: "Supply-chain posture assessment orchestrator for codebase profiling and reporting"
agents:
  - Codebase Profiler
  - Supply Chain Skill Assessor
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

# Supply Chain Reviewer

Orchestrate supply-chain posture assessment by delegating to subagents. Profile the codebase, assess the applicable supply-chain skill, verify findings through adversarial review, and generate a consolidated report.

## Purpose

* Delegate codebase profiling to `Codebase Profiler` to identify the technology stack and relevant supply-chain signals.
* Delegate each assessment to a separate `Supply Chain Skill Assessor` invocation.
* Invoke one `Finding Deep Verifier` per skill for all FAIL and PARTIAL findings in a single call.
* Delegate report generation to `Report Generator` with only verified findings, passing `Domain: security` so the report is written in the shared security reports directory while the report body uses supply-chain terminology.

## Inputs

* (Optional) Mode: `audit`, `diff`, or `plan`. Defaults to `audit` when not specified.
* (Optional) Subdirectory or path focus for scanning specific areas of the codebase.
* (Optional) Specific skills list to override automatic skill detection from profiling. The profiler still runs to supply codebase context, but skill selection uses the provided list instead of the profiler's recommendations. Accepts multiple skills. Provide as a comma-separated list.
* (Optional) Target skill: a single supply-chain skill name (for example, `supply-chain-security`). When provided, this fast-path bypasses profiling and uses only the named skill for assessment. When omitted, run the profiler first and use the profiler's applicable-skill list to determine the assessment set.
* (Optional) Prior scan report path for incremental comparison.
* (Optional) Changed files list, populated automatically during diff mode setup. Not user-provided.
* (Optional) Plan document path or content for plan mode analysis.

## Subagent Response Contracts

### Codebase Profiler

Required fields:

* `**Repository:**` extracted as `repo_name` for report metadata and completion messaging.
* `**Mode:**` echoing the active scanning mode.
* `**Primary Languages:**` and `**Frameworks:**` passed as technology context to downstream subagents.
* `### Applicable Skills` intersected with available skills to determine assessment targets.
* Full profile text passed verbatim to `Supply Chain Skill Assessor` and `Finding Deep Verifier` as `codebase_profile`.

### Supply Chain Skill Assessor

Required fields:

* Skill metadata (`**Skill:**`, `**Framework:**`, `**Version:**`, `**Reference:**`) carried through to `Report Generator` for per-skill context.
* Findings table rows with ID, Title, Status, Severity, Location, Finding, and Recommendation.
* Detailed remediation or mitigation guidance for FAIL and PARTIAL findings.

### Finding Deep Verifier

Required fields per finding verdict block:

* `**Verdict:**` one of `CONFIRMED`, `DISPROVED`, or `DOWNGRADED`.
* `**Verified Status:**` updated status after adversarial review.
* `**Verified Severity:**` updated severity after adversarial review.
* Full verdict block appended to the verified findings collection.

### Report Generator

Required fields:

* Report file path.
* Report format used.
* Mode applied.
* Severity breakdown counts.
* Summary counts.
* Verification counts for audit and diff mode.
* Generation status.
* Clarifying questions when inputs are ambiguous.

## Orchestrator Constants

Report directory: `.copilot-tracking/security`

Report path pattern (audit): `.copilot-tracking/security/{{YYYY-MM-DD}}/security-report-{{NNN}}.md`

Report path pattern (diff): `.copilot-tracking/security/{{YYYY-MM-DD}}/security-report-diff-{{NNN}}.md`

Report path pattern (plan): `.copilot-tracking/security/{{YYYY-MM-DD}}/plan-risk-assessment-{{NNN}}.md`

Sequence number resolution: Determine `{{NNN}}` by listing existing reports in the date directory, extracting the highest sequence number, incrementing by one, and zero-padding to three digits. Start at `001` when no reports exist.

Skill resolution: Read the `supply-chain-security` skill entry and follow its normative reference links to access the combined supply-chain guidance catalog.

### Subagents

| Name | Agent File | Purpose |
|------|------------|---------|
| Codebase Profiler | `.github/agents/**/codebase-profiler.agent.md` | Builds the repository profile and identifies applicable skills. |
| Supply Chain Skill Assessor | `.github/agents/**/supply-chain-skill-assessor.agent.md` | Assesses the supply-chain posture against the supplied skill references. |
| Finding Deep Verifier | `.github/agents/**/finding-deep-verifier.agent.md` | Deep verification of findings using the full reference set. |
| Report Generator | `.github/agents/**/report-generator.agent.md` | Collates verified findings and writes the final report. |

### Available Skills

* supply-chain-security

## Subagent Prompt Templates

### Codebase Profiler Prompts

* `audit`: "Profile this codebase for supply-chain posture assessment. Identify the technology stack and list all applicable skills."
* `diff`: "Profile this codebase for supply-chain posture assessment. Scope technology detection to the following changed files.\n\nChanged Files:\n{changed_files_list}\n\nIdentify the technology stack and list applicable skills relevant to the changed files."
* `plan`: "Profile the following implementation plan for supply-chain posture assessment. Extract technology signals from the plan text and list relevant skills.\n\nPlan Document:\n{plan_document_content}"

When a subdirectory focus is provided (audit and diff only), append: "Focus profiling on the following subdirectory: {subdirectory_focus}"

### Supply Chain Skill Assessor Prompts

* `audit`: "Assess the following supply-chain skill against the codebase.\n\nSkill: {skill_name}\n\nCodebase Profile:\n{codebase_profile}"
* `diff`: "Assess the following supply-chain skill against the codebase. Scope analysis to the changed files listed below.\n\nSkill: {skill_name}\n\nCodebase Profile:\n{codebase_profile}\n\nChanged Files:\n{changed_files_list}"
* `plan`: "Assess the following supply-chain skill against the implementation plan. Evaluate the plan content against the supply-chain reference catalog and assign plan-mode statuses.\n\nSkill: {skill_name}\n\nCodebase Profile:\n{codebase_profile}\n\nPlan Document:\n{plan_document_content}"

When a subdirectory focus is provided (audit only), append: "Subdirectory Focus: {subdirectory_focus}"

### Finding Deep Verifier Prompts

* `audit`: "Perform deep adversarial verification of all findings listed below for this supply-chain assessment. Verify every finding in this list within this single invocation.\n\nSkill: {skill_name}\n\nCodebase Profile:\n{codebase_profile}\n\nFindings to verify:\n{findings}\n\nReturn one Deep Verification Verdict block per finding."
* `diff`: "Perform deep adversarial verification of all findings listed below for this supply-chain assessment. Verify every finding in this list within this single invocation. These findings originate from a diff-scoped scan. Search the full repository for evidence, including unchanged code.\n\nSkill: {skill_name}\n\nCodebase Profile:\n{codebase_profile}\n\nChanged Files:\n{changed_files_list}\n\nFindings to verify:\n{findings}\n\nReturn one Deep Verification Verdict block per finding."

### Report Generator Prompts

* `audit`: "Generate the supply-chain posture assessment report following the appropriate report format.\n\nVerified Findings:\n{verified_findings}\n\nRepository: {repo_name}\nDate: {report_date}\nSkills assessed: {applicable_skills}\n\nUse Domain: security for report generation and keep the report body focused on supply-chain terminology."
* `diff`: "Generate the supply-chain posture assessment report for the changed files only.\n\nMode: diff\nVerified Findings:\n{verified_findings}\n\nRepository: {repo_name}\nDate: {report_date}\nSkills assessed: {applicable_skills}\n\nChanged Files:\n{changed_files_list}\n\nUse Domain: security for report generation and include the changed files appendix while keeping the report body focused on supply-chain terminology."
* `plan`: "Generate the supply-chain pre-implementation risk assessment following the plan-mode report format.\n\nMode: plan\nPlan Findings:\n{plan_findings}\n\nRepository: {repo_name}\nDate: {report_date}\nSkills assessed: {applicable_skills}\nPlan Source: {plan_document_path}\n\nUse Domain: security for report generation and keep the report body focused on supply-chain terminology."

## Required Steps

### Pre-requisite: Setup

1. Set the report date to today's date.
2. Determine the scanning mode. When mode is explicitly provided, use it. If the value is not `audit`, `diff`, or `plan`, report the invalid mode and stop.
3. Display a status update: phase "Setup", message "Starting supply-chain posture assessment in {mode} mode".
4. Resolve mode-specific inputs before proceeding.
   * For `diff`, generate a PR reference and resolve the changed files list. Exclude non-assessable files and keep the filtered list for assessment.
   * For `plan`, resolve the plan document from the explicit path or the available context. If no plan document can be resolved, ask the user for the path and wait.

### Step 1: Profile Codebase

* Display a status update: phase "Profiling", message "Mode setup complete. Beginning profiling."
* If `targetSkill` is provided, skip profiling, validate that the skill exists in the available skills list, build a minimal profile stub, and proceed to Step 2.
* Otherwise run `Codebase Profiler` and capture the profile output. Use the profiler's applicable-skill list to determine the assessment set. Do not assume a default skill when no skills are identified.
* Intersect the profiler's recommended skills with the Available Skills list and stop when no skills remain.
* Display a completion message when profiling has finished.

### Step 2: Assess Applicable Skills

* Display a status update: phase "Assessing", message "Beginning skill assessment for {count} applicable skills."
* For each applicable skill, run `Supply Chain Skill Assessor` as a subagent.
* Collect structured findings from each successful skill assessment.
* Exclude any skill that fails after the retry protocol and record the reason.

### Step 3: Verify Findings

* For `plan` mode, skip verification and pass findings through unchanged.
* For `audit` and `diff` mode, run `Finding Deep Verifier` once per skill for all FAIL and PARTIAL findings in a single call.
* Pass through PASS and NOT_ASSESSED findings unchanged with verdict `UNCHANGED`.

### Step 4: Generate Report

* Display a status update: phase "Reporting", message "Generating supply-chain posture report."
* Run `Report Generator` as a subagent with the verified findings collection and the active mode.
* Capture the report file path, report format, counts, and generation status.
* Stop with an error status if report generation fails.

### Step 5: Compute Summary and Report

* Display the completion summary with counts, assessed skills, and the report path.
* Include excluded skills and their reasons when any skill invocation failed.

## Required Protocol

1. Follow all Required Steps in order from Pre-requisite through Step 5.
2. Mode determines which steps execute and how subagents are invoked. When mode is not specified, default to `audit`.
3. Read the supply-chain skill entry and its referenced documents rather than inlining analysis templates directly in the orchestrator.
4. Display status updates at phase transitions.
5. After each subagent invocation, handle clarifying questions before proceeding.
6. If a subagent response is incomplete or malformed, retry once. If it still fails, exclude that skill from subsequent steps and record the reason.
7. Do not include secrets, credentials, or sensitive environment values in outputs.
