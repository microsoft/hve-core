---
name: security-review-diff
agent: Security Reviewer
description: "Runs an OWASP vulnerability assessment against changed files relative to the default branch - Brought to you by microsoft/hve-core"
argument-hint: "[focus-area]"
---

# Diff Vulnerability Scan

> [!CAUTION]
> This prompt is an **assistive tool only** and does not replace professional security tooling (SAST, DAST, SCA, penetration testing, compliance scanners) or qualified human review. All AI-generated vulnerability findings **must** be reviewed and validated by qualified security professionals before use. AI outputs may contain inaccuracies, miss critical threats, or produce recommendations that are incomplete or inappropriate for your environment.

## Inputs

* ${input:focus-area}: (Optional) Specific area within changed files to prioritize during assessment.

## Requirements

* Run in `diff` mode. Assess only files changed relative to the default branch.
* Auto-detect the baseline by comparing the current branch against the default branch. No explicit base reference is required.
* Use the `pr-reference` skill to discover changed files before profiling.
* Profile the codebase and auto-select applicable OWASP skills based on the technology stack detected in changed files.
* Verification applies against the full repository, not just changed files.
* The report indicates coverage is limited to changed code.
* When `${input:focus-area}` is provided, prioritize findings in that area within the changed-file set.
