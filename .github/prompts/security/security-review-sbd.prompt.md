---
name: security-review-sbd
agent: Security Reviewer
description: "Runs a Secure by Design principles assessment based on UK and Australian government guidance - Brought to you by microsoft/hve-core"
argument-hint: "[scope=path/to/dir]"
---

# Secure by Design Assessment

> [!CAUTION]
> This prompt is an **assistive tool only** and does not replace professional security tooling (SAST, DAST, SCA, penetration testing, compliance scanners) or qualified human review. All AI-generated findings **must** be reviewed and validated by qualified security professionals before use. AI outputs may contain inaccuracies, miss critical threats, or produce recommendations that are incomplete or inappropriate for your environment.

## Inputs

* ${input:scope}: (Optional) Specific component or directory path to focus the assessment on.

## Requirements

* Skip codebase classification and profiling entirely.
* Apply `secure-by-design` directly using the `target-skill` fast-path. This bypasses the Codebase Profiler and proceeds directly to the Skill Assessor with the `secure-by-design` skill.
* When `${input:scope}` is provided, limit analysis to files within the specified directory or component.
* Run in `audit` mode using the standard assessment and verification workflow.
