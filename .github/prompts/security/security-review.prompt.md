---
name: security-review
agent: Security Reviewer
description: "Runs an OWASP vulnerability assessment against the current codebase - Brought to you by microsoft/hve-core"
argument-hint: "[scope=path/to/dir] [mode={audit|diff|plan}] [targetSkill={owasp-top-10|owasp-llm|owasp-agentic|owasp-infrastructure}]"
---

# Vulnerability Scan

> [!CAUTION]
> This prompt is an **assistive tool only** and does not replace professional security tooling (SAST, DAST, SCA, penetration testing, compliance scanners) or qualified human review. All AI-generated vulnerability findings **must** be reviewed and validated by qualified security professionals before use. AI outputs may contain inaccuracies, miss critical threats, or produce recommendations that are incomplete or inappropriate for your environment.

## Inputs

* ${input:mode:audit}: (Optional, defaults to audit) Scanning mode: `audit`, `diff`, or `plan`.
* ${input:targetSkill}: (Optional) Single OWASP skill to assess. Bypasses codebase profiling when provided. Available skills: `owasp-agentic`, `owasp-llm`, `owasp-top-10`, `owasp-infrastructure`.
* ${input:scope}: (Optional) Specific directories or paths to focus on. When omitted, assesses the full codebase.
* ${input:plan}: (Optional) Implementation plan document path. Inferred from attached files or conversation context when not provided.

## Requirements

1. Route `${input:mode}` to the agent's corresponding mode. When omitted, default to `audit`.
2. When `${input:scope}` is provided, limit analysis to files within the specified directories or paths.
3. When `${input:targetSkill}` is provided, bypass codebase profiling and assess only the specified skill.
4. When `${input:plan}` is provided and mode is `plan`, pass the document path to the agent for plan-mode analysis.
