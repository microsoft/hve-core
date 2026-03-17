<!-- markdownlint-disable-file -->
# Security

Security review, planning, incident response, risk assessment, and vulnerability analysis

> **⚠️ Experimental** — This collection is experimental. Contents and behavior may change or be removed without notice.

> [!CAUTION]
> The security agents and prompts in this collection are **assistive tools only**. They do not replace professional security tooling (SAST, DAST, SCA, penetration testing, compliance scanners) or qualified human review. All AI-generated security artifacts **must** be reviewed and validated by qualified security professionals before use. AI outputs may contain inaccuracies, miss critical threats, or produce recommendations that are incomplete or inappropriate for your environment.

## Overview

Security review, planning, incident response, risk assessment, and vulnerability analysis for cloud and hybrid environments.

This collection includes agents and prompts for:

- **Security Plan Creation** — Generate threat models and security architecture documents
- **Security Review** — Evaluate code and architecture for security vulnerabilities
- **Incident Response** — Build incident response runbooks and playbooks
- **Risk Assessment** — Evaluate security risks with structured assessment frameworks
- **Vulnerability Analysis** — Identify and prioritize security vulnerabilities
- **Root Cause Analysis** — Structured RCA templates and guided analysis workflows

## Install

```bash
copilot plugin install security@hve-core
```

## Agents

| Agent                 | Description                                                                                                                                                                        |
|-----------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| security-plan-creator | Expert security architect for creating comprehensive cloud security plans - Brought to you by microsoft/hve-core                                                                   |
| security-reviewer     | OWASP assessment orchestrator for codebase profiling and vulnerability reporting - Brought to you by microsoft/hve-core                                                            |
| codebase-profiler     | Scans the repository to build a technology profile and identify which OWASP skills apply to the codebase - Brought to you by microsoft/hve-core                                    |
| finding-deep-verifier | Deep adversarial verification of FAIL and PARTIAL findings for a single OWASP skill - Brought to you by microsoft/hve-core                                                         |
| report-generator      | Collates verified OWASP skill assessment findings and generates a comprehensive vulnerability report written to .copilot-tracking/security/ - Brought to you by microsoft/hve-core |
| skill-assessor        | Assesses a single OWASP skill against the codebase, reading vulnerability references and returning structured findings - Brought to you by microsoft/hve-core                      |

## Commands

| Command           | Description                                                                                                     |
|-------------------|-----------------------------------------------------------------------------------------------------------------|
| incident-response | Incident response workflow for Azure operations scenarios - Brought to you by microsoft/hve-core                |
| risk-register     | Creates a concise and well-structured qualitative risk register using a Probability × Impact (P×I) risk matrix. |

## Instructions

| Instruction       | Description                                                                                                                                                                                                                                                 |
|-------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| hve-core-location | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

## Skills

| Skill                     | Description                                                                                                                                                                                              |
|---------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| owasp-top-10              | OWASP Top 10 for Web Applications (2025) vulnerability knowledge base for identifying, assessing, and remediating security risks in web application environments - Brought to you by microsoft/hve-core. |
| owasp-llm                 | OWASP Top 10 for LLM Applications (2025) vulnerability knowledge base for identifying, assessing, and remediating security risks in large language model systems - Brought to you by microsoft/hve-core. |
| owasp-agentic             | OWASP Agentic Security Top 10 vulnerability knowledge base for identifying, assessing, and remediating security risks in AI agent systems - Brought to you by microsoft/hve-core.                        |
| security-reviewer-formats | Format specifications and data contracts for the security reviewer orchestrator and its subagents - Brought to you by microsoft/hve-core.                                                                |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

