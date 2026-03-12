<!-- markdownlint-disable-file -->
# Security Planning

Security plan creation, incident response, and risk assessment

> [!CAUTION]
> The security agents and prompts in this collection are **assistive tools only**. They do not replace professional security tooling (SAST, DAST, SCA, penetration testing, compliance scanners) or qualified human review. All AI-generated security artifacts **must** be reviewed and validated by qualified security professionals before use. AI outputs may contain inaccuracies, miss critical threats, or produce recommendations that are incomplete or inappropriate for your environment.

## Overview

Create comprehensive security plans, incident response procedures, and risk assessments for cloud and hybrid environments.

This collection includes agents and prompts for:

- **Security Plan Creation** — Generate threat models and security architecture documents
- **Incident Response** — Build incident response runbooks and playbooks
- **Risk Assessment** — Evaluate security risks with structured assessment frameworks
- **Root Cause Analysis** — Structured RCA templates and guided analysis workflows

## Install

```bash
copilot plugin install security-planning@hve-core
```

## Agents

| Agent                 | Description                                                                                                      |
|-----------------------|------------------------------------------------------------------------------------------------------------------|
| security-plan-creator | Expert security architect for creating comprehensive cloud security plans - Brought to you by microsoft/hve-core |

## Commands

| Command           | Description                                                                                                     |
|-------------------|-----------------------------------------------------------------------------------------------------------------|
| incident-response | Incident response workflow for Azure operations scenarios - Brought to you by microsoft/hve-core                |
| risk-register     | Creates a concise and well-structured qualitative risk register using a Probability × Impact (P×I) risk matrix. |

## Instructions

| Instruction       | Description                                                                                                                                                                                                                                                 |
|-------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| hve-core-location | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

