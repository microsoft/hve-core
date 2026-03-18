---
name: security-review
agent: Security Reviewer
description: "Runs an OWASP vulnerability assessment against the current codebase - Brought to you by microsoft/hve-core"
argument-hint: "[mode={audit|diff|plan}] [targetSkill={owasp-agentic|owasp-llm|owasp-top-10}] [scope=...]"
---

# Vulnerability Scan

> [!CAUTION]
> This prompt is an **assistive tool only** and does not replace professional security tooling (SAST, DAST, SCA, penetration testing, compliance scanners) or qualified human review. All AI-generated vulnerability findings **must** be reviewed and validated by qualified security professionals before use. AI outputs may contain inaccuracies, miss critical threats, or produce recommendations that are incomplete or inappropriate for your environment. Plan-mode findings are theoretical assessments of proposed architecture and carry additional uncertainty; they are not confirmed vulnerabilities.

## Inputs

* ${input:mode:audit}: (Optional, defaults to audit) Scanning mode:
  * `audit`: Full deep dive of the entire codebase or scope.
  * `diff`: Scan only newly added or changed code.
  * `plan`: Identify potential vulnerabilities from an implementation plan.
* ${input:targetSkill}: (Optional) Single OWASP skill to assess. When provided, bypasses codebase profiling and uses only this skill. Available skills: `owasp-agentic`, `owasp-llm`, `owasp-top-10`.
* ${input:scope}: (Optional) Specific directories or paths to focus on. When omitted, the scanner assesses the full codebase. Use `${input:targetSkill}` to select a specific OWASP skill instead of relying on automatic detection.
* ${input:plan}: (Optional) Implementation plan document path or inline description. Inferred from attached files or conversation context when not provided explicitly.

## Requirements

### Mode and Scope Interaction

* When `${input:scope}` is provided, limit analysis to files within the specified directories or paths across all modes.
* When `${input:scope}` is omitted, the scanner assesses the full codebase.

### Target Skill Override

* When `${input:targetSkill}` is provided, bypass codebase profiling entirely and assess only the specified skill.
* Validate the skill name against the available skills list. If it does not match, inform the user of valid options.
* `${input:targetSkill}` works with all three modes (audit, diff, plan).
* When combined with `${input:scope}`, the target skill controls skill selection and scope controls directory focus.
* When `${input:targetSkill}` is omitted, the existing profiling-based skill detection applies unchanged.

### Audit Mode

* Scans the entire codebase (or scope-filtered subset) using the full assessment and verification workflow.

### Diff Mode

* Limits analysis to newly added or changed code relative to the default branch.
* Auto-detects the baseline by comparing the current branch against the default branch. No explicit base reference is required.
* When combined with scope, further filters changed-code findings to matching frameworks.
* Verification still applies against the full repository, not just changed files.
* The report indicates coverage is limited to changed code.

### Plan Mode

* Analyzes an implementation plan document for theoretical vulnerabilities instead of scanning code.
* Profiling identifies applicable skills from technologies described in the plan rather than detected in the codebase.
* Assessment evaluates plan content against vulnerability reference checklists.
* Verification is skipped since no source code exists to verify against.
* The report uses a plan-stage format with risk ratings and mitigation guidance.
* Plan-mode findings are theoretical and carry a stronger "not a substitute for professional review" qualifier.

### Report Differences

* Audit mode produces the standard report format.
* Diff mode produces a report scoped to changed code with a coverage qualifier.
* Plan mode produces a plan-stage report with risk ratings and mitigation guidance in place of code-level findings.
