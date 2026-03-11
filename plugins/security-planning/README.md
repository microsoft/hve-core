<!-- markdownlint-disable-file -->
# Security Planning

Security plan creation, incident response, and risk assessment

> **⚠️ Experimental** — This collection is experimental. Contents and behavior may change or be removed without notice.

## Install

```bash
copilot plugin install security-planning@hve-core
```

## Agents

| Agent            | Description                                                                                                                                                            |
|------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| security-planner | Phase-based security planner that produces risk surfaces, standards mappings, and backlog handoff artifacts with AI/ML component detection and RAI Planner integration |

## Commands

| Command                | Description                                                                                                     |
|------------------------|-----------------------------------------------------------------------------------------------------------------|
| security-plan-from-prd | Initiate security planning from PRD/BRD artifacts using the Security Planner agent in scoping mode              |
| security-capture       | Initiate security planning from existing notes or knowledge using the Security Planner agent in capture mode    |
| incident-response      | Incident response workflow for Azure operations scenarios - Brought to you by microsoft/hve-core                |
| risk-register          | Creates a concise and well-structured qualitative risk register using a Probability × Impact (P×I) risk matrix. |

## Instructions

| Instruction         | Description                                                                                                                                                                                                                                                 |
|---------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| identity            | Security Planner identity, six-phase orchestration, state management, and session recovery protocols - Brought to you by microsoft/hve-core                                                                                                                 |
| operational-buckets | Operational bucket definitions with component classification guidance and cross-cutting security concerns - Brought to you by microsoft/hve-core                                                                                                            |
| standards-mapping   | Embedded OWASP, NIST, and CIS security standards with researcher subagent delegation for WAF/CAF runtime lookups - Brought to you by microsoft/hve-core                                                                                                     |
| risk-surface        | STRIDE-based risk surface analysis per operational bucket with threat table format and data flow analysis - Brought to you by microsoft/hve-core                                                                                                            |
| backlog-handoff     | Dual-format backlog handoff for ADO and GitHub with content sanitization, autonomy tiers, and work item templates - Brought to you by microsoft/hve-core                                                                                                    |
| hve-core-location   | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

