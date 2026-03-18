<!-- markdownlint-disable-file -->
# Security Planning

Security plan creation, incident response, and risk assessment

> **⚠️ Experimental** — This collection is experimental. Contents and behavior may change or be removed without notice.

## Overview

Create comprehensive security plans, incident response procedures, and risk assessments for cloud and hybrid environments.

> [!CAUTION]
> The security agents and prompts in this collection are **assistive tools only**. They do not replace professional security tooling (SAST, DAST, SCA, penetration testing, compliance scanners) or qualified human review. All AI-generated security artifacts **must** be reviewed and validated by qualified security professionals before use. AI outputs may contain inaccuracies, miss critical threats, or produce recommendations that are incomplete or inappropriate for your environment.

This collection includes agents and prompts for:

- **Security Plan Creation** — Generate security models and security architecture documents
- **Incident Response** — Build incident response runbooks and playbooks
- **Risk Assessment** — Evaluate security risks with structured assessment frameworks
- **Root Cause Analysis** — Structured RCA templates and guided analysis workflows
- **SSSC Planning** — Supply chain security assessment and backlog generation against OpenSSF standards

## Install

```bash
copilot plugin install security-planning@hve-core
```

## Agents

| Agent               | Description                                                                                                                                                                                                                                                                      |
|---------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| security-planner    | Phase-based security planner that produces security models, standards mappings, and backlog handoff artifacts with AI/ML component detection and RAI Planner integration                                                                                                         |
| sssc-planner        | Guides users through a six-phase assessment of their repository's supply chain security posture against OpenSSF Scorecard, SLSA, Sigstore, and SBOM standards, producing a prioritized backlog referencing reusable workflows from hve-core and microsoft/physical-ai-toolchain. |
| researcher-subagent | Research subagent using search tools, read tools, fetch web page, github repo, and mcp tools                                                                                                                                                                                     |

## Commands

| Command                 | Description                                                                                                     |
|-------------------------|-----------------------------------------------------------------------------------------------------------------|
| security-plan-from-prd  | Initiate security planning from PRD/BRD artifacts using the Security Planner agent in scoping mode              |
| security-capture        | Initiate security planning from existing notes or knowledge using the Security Planner agent in capture mode    |
| incident-response       | Incident response workflow for Azure operations scenarios - Brought to you by microsoft/hve-core                |
| risk-register           | Creates a concise and well-structured qualitative risk register using a Probability × Impact (P×I) risk matrix. |
| sssc-capture            | Start a new SSSC assessment via guided conversation using the SSSC Planner agent in capture mode                |
| sssc-from-prd           | Start an SSSC assessment from existing PRD artifacts using the SSSC Planner agent                               |
| sssc-from-brd           | Start an SSSC assessment from existing BRD artifacts using the SSSC Planner agent                               |
| sssc-from-security-plan | Extend a Security Planner assessment with supply chain coverage using the SSSC Planner agent                    |

## Instructions

| Instruction         | Description                                                                                                                                                                                                                                                 |
|---------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| identity            | Security Planner identity, six-phase orchestration, state management, and session recovery protocols - Brought to you by microsoft/hve-core                                                                                                                 |
| operational-buckets | Operational bucket definitions with component classification guidance and cross-cutting security concerns - Brought to you by microsoft/hve-core                                                                                                            |
| standards-mapping   | Embedded OWASP, NIST, and CIS security standards with researcher subagent delegation for WAF/CAF runtime lookups - Brought to you by microsoft/hve-core                                                                                                     |
| security-model      | STRIDE-based security model analysis per operational bucket with threat table format and data flow analysis - Brought to you by microsoft/hve-core                                                                                                          |
| backlog-handoff     | Dual-format backlog handoff for ADO and GitHub with content sanitization, autonomy tiers, and work item templates - Brought to you by microsoft/hve-core                                                                                                    |
| hve-core-location   | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |
| sssc-identity       | Identity and orchestration instructions for the SSSC Planner agent. Contains six-phase workflow, state.json schema, session recovery, and question cadence.                                                                                                 |
| sssc-assessment     | Phase 2 supply chain assessment protocol with the 27 combined capabilities inventory for SSSC Planner.                                                                                                                                                      |
| sssc-standards      | Phase 3 OpenSSF Scorecard, SLSA, Best Practices Badge, Sigstore, and SBOM standards mapping for SSSC Planner.                                                                                                                                               |
| sssc-gap-analysis   | Phase 4 gap comparison, adoption categorization, and effort sizing for SSSC Planner.                                                                                                                                                                        |
| sssc-backlog        | Phase 5 dual-format work item generation with templates and priority derivation for SSSC Planner.                                                                                                                                                           |
| sssc-handoff        | Phase 6 backlog handoff protocol with Scorecard projections and dual-format output for SSSC Planner.                                                                                                                                                        |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

