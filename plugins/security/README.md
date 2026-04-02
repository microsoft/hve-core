<!-- markdownlint-disable-file -->
# Security

Security review, planning, incident response, risk assessment, and vulnerability analysis

> [!CAUTION]
> The security agents and prompts in this collection are **assistive tools only**. They do not replace professional security tooling (SAST, DAST, SCA, penetration testing, compliance scanners) or qualified human review. All AI-generated security artifacts **must** be reviewed and validated by qualified security professionals before use. AI outputs may contain inaccuracies, miss critical threats, or produce recommendations that are incomplete or inappropriate for your environment.

## Overview

Security review, planning, incident response, risk assessment, vulnerability analysis, supply chain security, and responsible AI assessment for cloud and hybrid environments.

> [!CAUTION]
> The security agents and prompts in this collection are **assistive tools only**. They do not replace professional security tooling (SAST, DAST, SCA, penetration testing, compliance scanners) or qualified human review. All AI-generated security artifacts **must** be reviewed and validated by qualified security professionals before use. AI outputs may contain inaccuracies, miss critical threats, or produce recommendations that are incomplete or inappropriate for your environment.

This collection includes agents and prompts for:

- **Security Plan Creation** — Generate threat models and security architecture documents
- **Security Review** — Evaluate code and architecture for security vulnerabilities
- **Incident Response** — Build incident response runbooks and playbooks
- **Risk Assessment** — Evaluate security risks with structured assessment frameworks
- **Vulnerability Analysis** — Identify and prioritize security vulnerabilities
- **Root Cause Analysis** — Structured RCA templates and guided analysis workflows
- **SSSC Planning** — Supply chain security assessment and backlog generation against OpenSSF standards
- **RAI Planning** — Responsible AI impact assessment and RAI backlog generation

Supporting subagents included:

- **Researcher Subagent** — Research subagent using search tools, read tools, fetch web page, github repo, and MCP tools
- **Codebase Profiler** — Scans the repository to build a technology profile and identify which OWASP skills apply
- **Finding Deep Verifier** — Deep adversarial verification of FAIL and PARTIAL findings for a single OWASP skill
- **Report Generator** — Collates verified OWASP skill assessment findings and generates a comprehensive vulnerability report
- **Skill Assessor** — Assesses a single OWASP skill against the codebase, reading vulnerability references and returning structured findings

Skills included:

- **OWASP Top 10** — OWASP Top 10 for Web Applications (2025) vulnerability knowledge base
- **OWASP LLM Top 10** — OWASP Top 10 for LLM Applications (2025) vulnerability knowledge base
- **OWASP Agentic Top 10** — OWASP Agentic Security Top 10 vulnerability knowledge base for AI agent systems
- **Security Reviewer Formats** — Format specifications and data contracts for the security reviewer orchestrator and its subagents

## Install

```bash
copilot plugin install security@hve-core
```

## Agents

| Agent                 | Description                                                                                                                                                                                                                                                                                        |
|-----------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| security-planner      | Phase-based security planner that produces security models, standards mappings, and backlog handoff artifacts with AI/ML component detection and RAI Planner integration                                                                                                                           |
| sssc-planner          | Guides users through a six-phase assessment of their repository's supply chain security posture against OpenSSF Scorecard, SLSA, Sigstore, and SBOM standards, producing a prioritized backlog referencing reusable workflows from hve-core and microsoft/physical-ai-toolchain.                   |
| rai-planner           | Responsible AI assessment agent with 5-phase conversational workflow. Evaluates AI systems against Microsoft RAI Standard v2 and NIST AI RMF 1.0. Produces RAI security model, impact assessment, control surface catalog, and dual-format backlog handoff. - Brought to you by microsoft/hve-core |
| researcher-subagent   | Research subagent using search tools, read tools, fetch web page, github repo, and mcp tools                                                                                                                                                                                                       |
| security-reviewer     | OWASP assessment orchestrator for codebase profiling and vulnerability reporting - Brought to you by microsoft/hve-core                                                                                                                                                                            |
| codebase-profiler     | Scans the repository to build a technology profile and identify which OWASP skills apply to the codebase - Brought to you by microsoft/hve-core                                                                                                                                                    |
| finding-deep-verifier | Deep adversarial verification of FAIL and PARTIAL findings for a single OWASP skill - Brought to you by microsoft/hve-core                                                                                                                                                                         |
| report-generator      | Collates verified OWASP skill assessment findings and generates a comprehensive vulnerability report written to .copilot-tracking/security/ - Brought to you by microsoft/hve-core                                                                                                                 |
| skill-assessor        | Assesses a single OWASP skill against the codebase, reading vulnerability references and returning structured findings - Brought to you by microsoft/hve-core                                                                                                                                      |

## Commands

| Command                     | Description                                                                                                                              |
|-----------------------------|------------------------------------------------------------------------------------------------------------------------------------------|
| security-capture            | Initiate security planning from existing notes or knowledge using the Security Planner agent in capture mode                             |
| security-plan-from-prd      | Initiate security planning from PRD/BRD artifacts using the Security Planner agent in from-prd mode                                      |
| incident-response           | Incident response workflow for Azure operations scenarios - Brought to you by microsoft/hve-core                                         |
| risk-register               | Creates a concise and well-structured qualitative risk register using a Probability × Impact (P×I) risk matrix.                          |
| security-review             | Runs an OWASP vulnerability assessment against the current codebase - Brought to you by microsoft/hve-core                               |
| security-review-llm         | Runs OWASP LLM and Agentic vulnerability assessments with codebase profiling for context - Brought to you by microsoft/hve-core          |
| security-review-web         | Runs an OWASP Top 10 web vulnerability assessment without codebase profiling - Brought to you by microsoft/hve-core                      |
| sssc-capture                | Start a new SSSC assessment via guided conversation using the SSSC Planner agent in capture mode                                         |
| sssc-from-prd               | Start an SSSC assessment from existing PRD artifacts using the SSSC Planner agent                                                        |
| sssc-from-brd               | Start an SSSC assessment from existing BRD artifacts using the SSSC Planner agent                                                        |
| sssc-from-security-plan     | Extend a Security Planner assessment with supply chain coverage using the SSSC Planner agent                                             |
| rai-capture                 | Initiate a responsible AI assessment from existing knowledge using the RAI Planner agent in capture mode                                 |
| rai-plan-from-prd           | Initiate a responsible AI assessment from PRD/BRD artifacts using the RAI Planner agent in from-prd mode                                 |
| rai-plan-from-security-plan | Initiate a responsible AI assessment from a completed Security Plan using the RAI Planner agent in from-security-plan mode (recommended) |

## Instructions

| Instruction                        | Description                                                                                                                                                                                                                                                 |
|------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| identity.instructions              | Security Planner identity, six-phase orchestration, state management, and session recovery protocols - Brought to you by microsoft/hve-core                                                                                                                 |
| operational-buckets.instructions   | Operational bucket definitions with component classification guidance and cross-cutting security concerns - Brought to you by microsoft/hve-core                                                                                                            |
| standards-mapping.instructions     | Embedded OWASP, NIST, and CIS security standards with researcher subagent delegation for WAF/CAF runtime lookups - Brought to you by microsoft/hve-core                                                                                                     |
| security-model.instructions        | STRIDE-based security model analysis per operational bucket with threat table format and data flow analysis - Brought to you by microsoft/hve-core                                                                                                          |
| backlog-handoff.instructions       | Dual-format backlog handoff for ADO and GitHub with content sanitization, autonomy tiers, and work item templates - Brought to you by microsoft/hve-core                                                                                                    |
| sssc-identity.instructions         | Identity and orchestration instructions for the SSSC Planner agent. Contains six-phase workflow, state.json schema, session recovery, and question cadence.                                                                                                 |
| sssc-assessment.instructions       | Phase 2 supply chain assessment protocol with the 27 combined capabilities inventory for SSSC Planner.                                                                                                                                                      |
| sssc-standards.instructions        | Phase 3 OpenSSF Scorecard, SLSA, Best Practices Badge, Sigstore, and SBOM standards mapping for SSSC Planner.                                                                                                                                               |
| sssc-gap-analysis.instructions     | Phase 4 gap comparison, adoption categorization, and effort sizing for SSSC Planner.                                                                                                                                                                        |
| sssc-backlog.instructions          | Phase 5 dual-format work item generation with templates and priority derivation for SSSC Planner.                                                                                                                                                           |
| sssc-handoff.instructions          | Phase 6 backlog handoff protocol with Scorecard projections and dual-format output for SSSC Planner.                                                                                                                                                        |
| rai-identity.instructions          | RAI Planner identity, 6-phase orchestration, state management, and session recovery - Brought to you by microsoft/hve-core                                                                                                                                  |
| rai-standards.instructions         | Embedded RAI standards for Phase 3: Microsoft RAI Standard v2 principles and NIST AI RMF subcategory mappings                                                                                                                                               |
| rai-security-model.instructions    | RAI security model analysis for Phase 4: AI STRIDE extensions, dual threat IDs, ML STRIDE matrix, and security model merge protocol                                                                                                                         |
| rai-impact-assessment.instructions | RAI impact assessment for Phase 5: control surface taxonomy, evidence register, tradeoff documentation, and work item generation                                                                                                                            |
| rai-backlog-handoff.instructions   | RAI review and backlog handoff for Phase 6: review rubric, RAI scorecard, dual-format backlog generation                                                                                                                                                    |
| rai-capture-coaching.instructions  | Exploration-first questioning techniques for RAI capture mode adapted from Design Thinking research methods - Brought to you by microsoft/hve-core                                                                                                          |
| hve-core-location.instructions     | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

## Skills

| Skill                     | Description                                                                                                                                                                                                                                                                                                                                                                                                         |
|---------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| owasp-top-10              | OWASP Top 10 for Web Applications (2025) vulnerability knowledge base for identifying, assessing, and remediating security risks in web application environments - Brought to you by microsoft/hve-core.                                                                                                                                                                                                            |
| owasp-llm                 | OWASP Top 10 for LLM Applications (2025) vulnerability knowledge base for identifying, assessing, and remediating security risks in large language model systems - Brought to you by microsoft/hve-core.                                                                                                                                                                                                            |
| owasp-agentic             | OWASP Agentic Security Top 10 vulnerability knowledge base for identifying, assessing, and remediating security risks in AI agent systems - Brought to you by microsoft/hve-core.                                                                                                                                                                                                                                   |
| security-reviewer-formats | Format specifications and data contracts for the security reviewer orchestrator and its subagents - Brought to you by microsoft/hve-core.                                                                                                                                                                                                                                                                           |
| pr-reference              | Generates PR reference XML containing commit history and unified diffs between branches with extension and path filtering. Includes utilities to list changed files by type and read diff chunks. Use when creating pull request descriptions, preparing code reviews, analyzing branch changes, discovering work items from diffs, or generating structured diff summaries. - Brought to you by microsoft/hve-core |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

