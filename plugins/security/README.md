<!-- markdownlint-disable-file -->
# Security

Security review, planning, incident response, risk assessment, and vulnerability analysis

> [!CAUTION]
> The security agents and prompts in this collection are **assistive tools only**. They do not replace professional security tooling (SAST, DAST, SCA, penetration testing, compliance scanners) or qualified human review. All AI-generated security artifacts **must** be reviewed and validated by qualified security professionals before use. AI outputs may contain inaccuracies, miss critical threats, or produce recommendations that are incomplete or inappropriate for your environment.

## Overview

Security review, planning, incident response, risk assessment, vulnerability analysis, supply chain security, and responsible AI assessment for cloud and hybrid environments.

> [!CAUTION]
> The security agents and prompts in this collection are **assistive tools only**. They do not replace professional security tooling (SAST, DAST, SCA, penetration testing, compliance scanners) or qualified human review. All AI-generated security artifacts **must** be reviewed and validated by qualified security professionals before use. AI outputs may contain inaccuracies, miss critical threats, or produce recommendations that are incomplete or inappropriate for your environment.

## Included Artifacts

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Chat Agents

| Name                      | Description                                                                                                                                                                 |
|---------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **codebase-profiler**     | Scans the repository to build a technology profile and select applicable security skills                                                                                    |
| **finding-deep-verifier** | Deep adversarial verification of FAIL and PARTIAL findings for a single security skill                                                                                      |
| **rai-planner**           | Responsible AI assessment planner evaluating against NIST AI RMF 1.0, producing an RAI security model, impact assessment, control surface catalog, and backlog handoff      |
| **report-generator**      | Collates verified security skill findings into a comprehensive vulnerability report                                                                                         |
| **researcher-subagent**   | Research subagent using search, read, web-fetch, GitHub repo, and MCP tools                                                                                                 |
| **security-planner**      | Phase-based security planner producing security models, standards mappings, and backlog handoffs with AI/ML detection and RAI Planner integration                           |
| **security-reviewer**     | Security skill assessment orchestrator for codebase profiling and vulnerability reporting                                                                                   |
| **skill-assessor**        | Assesses a single security skill against the codebase and returns structured findings                                                                                       |
| **sssc-planner**          | Six-phase repository supply chain security assessment against OpenSSF Scorecard, SLSA, Sigstore, and SBOM standards, producing a prioritized backlog of reusable workflows. |

### Prompts

| Name                            | Description                                                                                                                                  |
|---------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------|
| **incident-response**           | Run an incident response workflow for Azure operations scenarios                                                                             |
| **rai-capture**                 | Start responsible AI assessment planning from existing knowledge using the RAI Planner agent in capture mode                                 |
| **rai-plan-from-prd**           | Start responsible AI assessment planning from PRD/BRD artifacts using the RAI Planner agent in from-prd mode                                 |
| **rai-plan-from-security-plan** | Start responsible AI assessment planning from a completed Security Plan using the RAI Planner agent in from-security-plan mode (recommended) |
| **risk-register**               | Create a qualitative risk register using a Probability × Impact (P×I) matrix                                                                 |
| **security-capture**            | Start security planning from existing notes using the Security Planner agent (capture mode)                                                  |
| **security-plan-from-prd**      | Start security planning from PRD/BRD artifacts using the Security Planner agent (from-prd mode)                                              |
| **security-review**             | Run an OWASP vulnerability assessment against the current codebase                                                                           |
| **security-review-llm**         | Run OWASP LLM and Agentic vulnerability assessments with codebase profiling                                                                  |
| **security-review-sbd**         | Run a Secure by Design principles assessment per UK and Australian government guidance                                                       |
| **security-review-web**         | Run an OWASP Top 10 web vulnerability assessment without codebase profiling                                                                  |
| **sssc-capture**                | Start supply chain security planning from existing knowledge using the SSSC Planner agent in capture mode                                    |
| **sssc-from-brd**               | Start supply chain security planning from BRD artifacts using the SSSC Planner agent in from-brd mode                                        |
| **sssc-from-prd**               | Start supply chain security planning from PRD artifacts using the SSSC Planner agent in from-prd mode                                        |
| **sssc-from-security-plan**     | Extend a Security Planner assessment with supply chain coverage using the SSSC Planner agent in from-security-plan mode                      |

### Instructions

| Name                                     | Description                                                                                                                                                                                                                                                                  |
|------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **rai-planning/rai-backlog-handoff**     | RAI review and backlog handoff for Phase 6: review rubric, RAI review summary, dual-format backlog generation                                                                                                                                                                |
| **rai-planning/rai-capture-coaching**    | Exploration-first questioning techniques for RAI capture mode adapted from Design Thinking research methods                                                                                                                                                                  |
| **rai-planning/rai-identity**            | RAI Planner identity, 6-phase orchestration, state management, and session recovery                                                                                                                                                                                          |
| **rai-planning/rai-impact-assessment**   | RAI impact assessment for Phase 5: control surface taxonomy, evidence register, tradeoff documentation, and work item generation                                                                                                                                             |
| **rai-planning/rai-planner-telemetry**   | RAI Planner telemetry overlay applying telemetry-foundations vocabulary to RAI plan artifacts                                                                                                                                                                                |
| **rai-planning/rai-risk-classification** | Risk classification screening for Phase 2: prohibited uses gate, risk indicator assessment, and depth tier assignment                                                                                                                                                        |
| **rai-planning/rai-security-model**      | RAI security model analysis for Phase 4: AI STRIDE extensions, dual threat IDs, ML STRIDE matrix, and security model merge protocol                                                                                                                                          |
| **rai-planning/rai-standards**           | Embedded RAI standards for Phase 3: NIST AI RMF 1.0 trustworthiness characteristics, subcategory mappings, and framework isolation architecture                                                                                                                              |
| **security/backlog-handoff**             | Dual-format backlog handoff for ADO and GitHub with content sanitization, autonomy tiers, and work item templates                                                                                                                                                            |
| **security/identity**                    | Security Planner identity, six-phase orchestration, state management, and session recovery protocols                                                                                                                                                                         |
| **security/operational-buckets**         | Operational bucket definitions with component classification guidance and cross-cutting security concerns                                                                                                                                                                    |
| **security/security-model**              | STRIDE-based security model analysis per operational bucket with threat table format and data flow analysis                                                                                                                                                                  |
| **security/security-planner-telemetry**  | Security Planner telemetry overlay applying telemetry-foundations vocabulary to security plan artifacts                                                                                                                                                                      |
| **security/sssc-assessment**             | Phase 2 supply chain assessment protocol with the 27 combined capabilities inventory for SSSC Planner.                                                                                                                                                                       |
| **security/sssc-backlog**                | Phase 5 dual-format work item generation with templates and priority derivation for SSSC Planner.                                                                                                                                                                            |
| **security/sssc-gap-analysis**           | Phase 4 gap comparison, adoption categorization, and effort sizing for SSSC Planner.                                                                                                                                                                                         |
| **security/sssc-handoff**                | Phase 6 backlog handoff protocol with Scorecard projections and dual-format output for SSSC Planner.                                                                                                                                                                         |
| **security/sssc-identity**               | SSSC Planner identity and orchestration: six-phase workflow, state.json schema, session recovery, and question cadence                                                                                                                                                       |
| **security/sssc-planner-telemetry**      | SSSC Planner telemetry overlay applying telemetry-foundations vocabulary to SSSC plan artifacts                                                                                                                                                                              |
| **security/sssc-standards**              | Phase 3 OpenSSF Scorecard, SLSA v1.0, OpenSSF Best Practices Badge, Sigstore (cosign), and NTIA SBOM minimum elements standards mapping for SSSC Planner.                                                                                                                    |
| **security/standards-mapping**           | Embedded OWASP and NIST security standards with researcher subagent delegation for CIS, WAF, CAF, and other runtime lookups                                                                                                                                                  |
| **shared/coaching-patterns**             | Shared exploration-first coaching patterns for planning agents (RAI, security, SSSC) adapted from Design Thinking research methods                                                                                                                                           |
| **shared/disclaimer-language**           | Centralized disclaimer language for AI-assisted planning agents requiring professional review acknowledgment                                                                                                                                                                 |
| **shared/hve-core-location**             | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree.                  |
| **shared/planner-identity-base**         | Shared identity scaffold for phase-based planning agents (SSSC, RAI, Security, Accessibility) covering state-file convention, six-phase orchestration template, state protocol, resume protocol, question cadence mechanics, optional disclaimer cadence, and error handling |

### Skills

| Name                          | Description                                                                                                                                                                                                                                                                                      |
|-------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **backlog-templates**         | Shared work-item templates and conventions for ADO and GitHub backlog handoff across the RAI, Security, SSSC, and Accessibility planners                                                                                                                                                         |
| **owasp-agentic**             | OWASP Agentic Security Top 10 knowledge base for identifying, assessing, and remediating AI agent system security risks.                                                                                                                                                                         |
| **owasp-cicd**                | OWASP CI/CD Top 10 knowledge base for identifying, assessing, and remediating CI/CD pipeline security risks.                                                                                                                                                                                     |
| **owasp-infrastructure**      | OWASP Infrastructure Top 10 knowledge base for identifying, assessing, and remediating internal IT infrastructure security risks.                                                                                                                                                                |
| **owasp-llm**                 | OWASP Top 10 for LLM Applications (2025) knowledge base for identifying, assessing, and remediating large language model security risks.                                                                                                                                                         |
| **owasp-mcp**                 | OWASP MCP Top 10 knowledge base for identifying, assessing, and remediating Model Context Protocol security risks.                                                                                                                                                                               |
| **owasp-top-10**              | OWASP Top 10 for Web Applications (2025) knowledge base for identifying, assessing, and remediating web application security risks.                                                                                                                                                              |
| **pr-reference**              | Generates PR reference XML with commit history and unified diffs between branches, with extension and path filtering. Use when creating pull request descriptions, preparing code reviews, analyzing branch changes, discovering work items from diffs, or generating structured diff summaries. |
| **secure-by-design**          | Secure by Design principles knowledge base for assessing security-first design, development, and deployment across the software lifecycle.                                                                                                                                                       |
| **security-reviewer-formats** | Format specifications and data contracts for the security reviewer orchestrator and its subagents.                                                                                                                                                                                               |
| **telemetry-foundations**     | Declarative OpenTelemetry-aligned telemetry vocabulary and instrumentation conventions for traces, metrics, logs, and PII handling                                                                                                                                                               |

<!-- END AUTO-GENERATED ARTIFACTS -->

## Install

```bash
copilot plugin install security@hve-core
```

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

