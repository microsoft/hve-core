---
name: security-review-llm
agent: Security Reviewer
description: "Runs OWASP LLM and Agentic vulnerability assessments with codebase profiling for context - Brought to you by microsoft/hve-core"
argument-hint: "[scope=path/to/component]"
---

# LLM and Agentic Vulnerability Scan

> [!CAUTION]
> This prompt is an **assistive tool only** and does not replace professional security tooling (SAST, DAST, SCA, penetration testing, compliance scanners) or qualified human review. All AI-generated vulnerability findings **must** be reviewed and validated by qualified security professionals before use. AI outputs may contain inaccuracies, miss critical threats, or produce recommendations that are incomplete or inappropriate for your environment.

## Inputs

* ${input:scope}: (Optional) Specific component or directory path to focus the assessment on.

## Requirements

* Override skill selection with `owasp-llm, owasp-agentic`. The profiler still runs to supply codebase context, but skill detection is bypassed in favor of these two skills.
* When `${input:scope}` is provided, limit analysis to files within the specified directory or component.
* Run in `audit` mode using the standard assessment and verification workflow.
* Assess both skills independently through separate Skill Assessor invocations, then consolidate findings in a single report.
