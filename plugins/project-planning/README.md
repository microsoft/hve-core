<!-- markdownlint-disable-file -->
# Project Planning

PRDs, BRDs, ADRs, and architecture diagrams

## Overview

Create architecture decision records (MADR v4 + Y-Statement) with phase-gated coaching, ASR-trigger validation, supersession lineage, and per-project templates. Build PRDs, BRDs, and architecture diagrams through guided AI workflows. Evaluate AI-powered systems against Responsible AI standards and run STRIDE-based security model analysis with automated backlog generation.

## Included Artifacts

<!-- BEGIN AUTO-GENERATED ARTIFACTS -->

### Chat Agents

| Name                             | Description                                                                                                                                                                                              |
|----------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **adr-creation**                 | ADR Creator: phase-gated creator producing standards-aligned Architecture Decision Records (Frame, Decide, Govern), with state recovery, Researcher Subagent delegation, and dual-format backlog handoff |
| **agile-coach**                  | Creates and refines goal-oriented user stories with clear acceptance criteria for any tracking tool                                                                                                      |
| **arch-diagram-builder**         | Architecture diagram builder that produces high-quality ASCII-art diagrams                                                                                                                               |
| **brd-builder**                  | Business Requirements Document builder with guided Q&A and reference integration                                                                                                                         |
| **implementation-validator**     | Validates implementation quality against architectural requirements, design principles, and code standards with severity-graded findings                                                                 |
| **meeting-analyst**              | Meeting transcript analyzer that extracts product requirements for PRD creation via work-iq-mcp                                                                                                          |
| **network-isa95-planner**        | ISA-95-aligned network planning for secure edge Kubernetes to Azure connectivity and remediation roadmaps                                                                                                |
| **phase-implementor**            | Executes a single implementation phase from a plan with full codebase access and change tracking                                                                                                         |
| **plan-validator**               | Validates implementation plans against research documents with severity-graded findings                                                                                                                  |
| **prd-builder**                  | Product Requirements Document builder with guided Q&A and reference integration                                                                                                                          |
| **product-manager-advisor**      | Product management advisor for requirements discovery, validation, and issue creation                                                                                                                    |
| **rai-planner**                  | Responsible AI assessment planner evaluating against NIST AI RMF 1.0, producing an RAI security model, impact assessment, control surface catalog, and backlog handoff                                   |
| **researcher-subagent**          | Research subagent using search, read, web-fetch, GitHub repo, and MCP tools                                                                                                                              |
| **rpi-agent**                    | Autonomous RPI orchestrator running Research → Plan → Implement → Review → Discover phases with specialized subagents                                                                                    |
| **rpi-validator**                | Validates a Changes Log against the Implementation Plan, Planning Log, and Research Documents for a specific plan phase                                                                                  |
| **security-planner**             | Phase-based security planner producing security models, standards mappings, and backlog handoffs with AI/ML detection and RAI Planner integration                                                        |
| **sssc-planner**                 | Six-phase repository supply chain security assessment against OpenSSF Scorecard, SLSA, Sigstore, and SBOM standards, producing a prioritized backlog of reusable workflows.                              |
| **system-architecture-reviewer** | System architecture reviewer for design trade-offs, ADR creation, and well-architected alignment                                                                                                         |
| **ux-ui-designer**               | UX research specialist for Jobs-to-be-Done analysis, user journey mapping, and accessibility requirements                                                                                                |

### Prompts

| Name                            | Description                                                                                                                                     |
|---------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------|
| **incident-response**           | Incident response workflow for Azure operations scenarios                                                                                       |
| **rai-capture**                 | Initiate responsible AI assessment planning from existing knowledge using the RAI Planner agent in capture mode                                 |
| **rai-plan-from-prd**           | Initiate responsible AI assessment planning from PRD/BRD artifacts using the RAI Planner agent in from-prd mode                                 |
| **rai-plan-from-security-plan** | Initiate responsible AI assessment planning from a completed Security Plan using the RAI Planner agent in from-security-plan mode (recommended) |
| **risk-register**               | Creates a concise and well-structured qualitative risk register using a Probability × Impact (P×I) risk matrix.                                 |
| **security-capture**            | Initiate security planning from existing notes or knowledge using the Security Planner agent in capture mode                                    |
| **security-plan-from-prd**      | Initiate security planning from PRD/BRD artifacts using the Security Planner agent in from-prd mode                                             |
| **sssc-capture**                | Initiate supply chain security planning from existing knowledge using the SSSC Planner agent in capture mode                                    |
| **sssc-from-brd**               | Initiate supply chain security planning from existing BRD artifacts using the SSSC Planner agent in from-brd mode                               |
| **sssc-from-prd**               | Initiate supply chain security planning from existing PRD artifacts using the SSSC Planner agent in from-prd mode                               |
| **sssc-from-security-plan**     | Extend a Security Planner assessment with supply chain coverage using the SSSC Planner agent in from-security-plan mode                         |

### Instructions

| Name                                     | Description                                                                                                                                                                                                                                                 |
|------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **project-planning/adr-byo-template**    | BYO ADR template contract: 2-layer config resolution, .adr-config.yml schema, template frontmatter contract, and adopt-template lifecycle for the ADR Creator                                                                                               |
| **project-planning/adr-handoff**         | ADR Creator Govern-phase handoff protocol: compact summary template, peer-agent routing heuristics, and dual-format (ADO + GitHub) work item templates                                                                                                      |
| **project-planning/adr-identity**        | ADR Creator identity, three-phase state machine, six-step per-turn protocol, autonomy tiers, and canonical state.json schema for Architecture Decision Record authoring sessions                                                                            |
| **project-planning/adr-standards**       | Embedded ADR standards: MADR v4.0.0 template (CC0), Y-Statement formula, status taxonomy, naming rules, ASR trigger schema, and Microsoft-attributed paraphrases for ADR Creator sessions                                                                   |
| **rai-planning/rai-backlog-handoff**     | RAI review and backlog handoff for Phase 6: review rubric, RAI review summary, dual-format backlog generation                                                                                                                                               |
| **rai-planning/rai-capture-coaching**    | Exploration-first questioning techniques for RAI capture mode adapted from Design Thinking research methods                                                                                                                                                 |
| **rai-planning/rai-identity**            | RAI Planner identity, 6-phase orchestration, state management, and session recovery                                                                                                                                                                         |
| **rai-planning/rai-impact-assessment**   | RAI impact assessment for Phase 5: control surface taxonomy, evidence register, tradeoff documentation, and work item generation                                                                                                                            |
| **rai-planning/rai-risk-classification** | Risk classification screening for Phase 2: prohibited uses gate, risk indicator assessment, and depth tier assignment                                                                                                                                       |
| **rai-planning/rai-security-model**      | RAI security model analysis for Phase 4: AI STRIDE extensions, dual threat IDs, ML STRIDE matrix, and security model merge protocol                                                                                                                         |
| **rai-planning/rai-standards**           | Embedded RAI standards for Phase 3: NIST AI RMF 1.0 trustworthiness characteristics, subcategory mappings, and framework isolation architecture                                                                                                             |
| **security/backlog-handoff**             | Dual-format backlog handoff for ADO and GitHub with content sanitization, autonomy tiers, and work item templates                                                                                                                                           |
| **security/identity**                    | Security Planner identity, six-phase orchestration, state management, and session recovery protocols                                                                                                                                                        |
| **security/operational-buckets**         | Operational bucket definitions with component classification guidance and cross-cutting security concerns                                                                                                                                                   |
| **security/security-model**              | STRIDE-based security model analysis per operational bucket with threat table format and data flow analysis                                                                                                                                                 |
| **security/sssc-assessment**             | Phase 2 supply chain assessment protocol with the 27 combined capabilities inventory for SSSC Planner.                                                                                                                                                      |
| **security/sssc-backlog**                | Phase 5 dual-format work item generation with templates and priority derivation for SSSC Planner.                                                                                                                                                           |
| **security/sssc-gap-analysis**           | Phase 4 gap comparison, adoption categorization, and effort sizing for SSSC Planner.                                                                                                                                                                        |
| **security/sssc-handoff**                | Phase 6 backlog handoff protocol with Scorecard projections and dual-format output for SSSC Planner.                                                                                                                                                        |
| **security/sssc-identity**               | Identity and orchestration instructions for the SSSC Planner agent. Contains six-phase workflow, state.json schema, session recovery, and question cadence.                                                                                                 |
| **security/sssc-standards**              | Phase 3 OpenSSF Scorecard, SLSA v1.0, OpenSSF Best Practices Badge, Sigstore (cosign), and NTIA SBOM minimum elements standards mapping for SSSC Planner.                                                                                                   |
| **security/standards-mapping**           | Embedded OWASP and NIST security standards with researcher subagent delegation for CIS, WAF, CAF, and other runtime lookups                                                                                                                                 |
| **shared/coaching-patterns**             | Shared exploration-first coaching patterns for planning agents (RAI, security, SSSC) adapted from Design Thinking research methods                                                                                                                          |
| **shared/disclaimer-language**           | Centralized disclaimer language for AI-assisted planning agents requiring professional review acknowledgment                                                                                                                                                |
| **shared/hve-core-location**             | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |
| **shared/story-quality**                 | Shared story quality conventions for work item creation and evaluation across agents and workflows                                                                                                                                                          |

### Skills

| Name           | Description                                                                                                                                                                                                                                                                             |
|----------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **adr-author** | Authoring skill for Architecture Decision Records (ADRs) supporting capture, from-planner-handoff, and adopt-template entry modes with selectable Y-Statement or MADR v4.0.0 output templates, supersession lineage, and ASR trigger evaluation - Brought to you by microsoft/hve-core. |

<!-- END AUTO-GENERATED ARTIFACTS -->

## Install

```bash
copilot plugin install project-planning@hve-core
```

## Agents

| Agent                        | Description                                                                                                                                                                                              |
|------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| agile-coach                  | Creates and refines goal-oriented user stories with clear acceptance criteria for any tracking tool                                                                                                      |
| product-manager-advisor      | Product management advisor for requirements discovery, validation, and issue creation                                                                                                                    |
| ux-ui-designer               | UX research specialist for Jobs-to-be-Done analysis, user journey mapping, and accessibility requirements                                                                                                |
| adr-creation                 | ADR Creator: phase-gated creator producing standards-aligned Architecture Decision Records (Frame, Decide, Govern), with state recovery, Researcher Subagent delegation, and dual-format backlog handoff |
| arch-diagram-builder         | Architecture diagram builder that produces high-quality ASCII-art diagrams                                                                                                                               |
| brd-builder                  | Business Requirements Document builder with guided Q&A and reference integration                                                                                                                         |
| network-isa95-planner        | ISA-95-aligned network planning for secure edge Kubernetes to Azure connectivity and remediation roadmaps                                                                                                |
| system-architecture-reviewer | System architecture reviewer for design trade-offs, ADR creation, and well-architected alignment                                                                                                         |
| rpi-agent                    | Autonomous RPI orchestrator running Research → Plan → Implement → Review → Discover phases with specialized subagents                                                                                    |
| prd-builder                  | Product Requirements Document builder with guided Q&A and reference integration                                                                                                                          |
| meeting-analyst              | Meeting transcript analyzer that extracts product requirements for PRD creation via work-iq-mcp                                                                                                          |
| rai-planner                  | Responsible AI assessment planner evaluating against NIST AI RMF 1.0, producing an RAI security model, impact assessment, control surface catalog, and backlog handoff                                   |
| security-planner             | Phase-based security planner producing security models, standards mappings, and backlog handoffs with AI/ML detection and RAI Planner integration                                                        |
| sssc-planner                 | Six-phase repository supply chain security assessment against OpenSSF Scorecard, SLSA, Sigstore, and SBOM standards, producing a prioritized backlog of reusable workflows.                              |
| researcher-subagent          | Research subagent using search, read, web-fetch, GitHub repo, and MCP tools                                                                                                                              |
| plan-validator               | Validates implementation plans against research documents with severity-graded findings                                                                                                                  |
| phase-implementor            | Executes a single implementation phase from a plan with full codebase access and change tracking                                                                                                         |
| rpi-validator                | Validates a Changes Log against the Implementation Plan, Planning Log, and Research Documents for a specific plan phase                                                                                  |
| implementation-validator     | Validates implementation quality against architectural requirements, design principles, and code standards with severity-graded findings                                                                 |

## Commands

| Command                     | Description                                                                                                                                     |
|-----------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------|
| security-plan-from-prd      | Initiate security planning from PRD/BRD artifacts using the Security Planner agent in from-prd mode                                             |
| security-capture            | Initiate security planning from existing notes or knowledge using the Security Planner agent in capture mode                                    |
| incident-response           | Incident response workflow for Azure operations scenarios - Brought to you by microsoft/hve-core                                                |
| risk-register               | Creates a concise and well-structured qualitative risk register using a Probability × Impact (P×I) risk matrix.                                 |
| rai-capture                 | Initiate responsible AI assessment planning from existing knowledge using the RAI Planner agent in capture mode                                 |
| rai-plan-from-prd           | Initiate responsible AI assessment planning from PRD/BRD artifacts using the RAI Planner agent in from-prd mode                                 |
| rai-plan-from-security-plan | Initiate responsible AI assessment planning from a completed Security Plan using the RAI Planner agent in from-security-plan mode (recommended) |
| sssc-capture                | Initiate supply chain security planning from existing knowledge using the SSSC Planner agent in capture mode                                    |
| sssc-from-prd               | Initiate supply chain security planning from existing PRD artifacts using the SSSC Planner agent in from-prd mode                               |
| sssc-from-brd               | Initiate supply chain security planning from existing BRD artifacts using the SSSC Planner agent in from-brd mode                               |
| sssc-from-security-plan     | Extend a Security Planner assessment with supply chain coverage using the SSSC Planner agent in from-security-plan mode                         |

## Instructions

| Instruction                          | Description                                                                                                                                                                                                                                                 |
|--------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| adr-byo-template.instructions        | BYO ADR template contract: 2-layer config resolution, .adr-config.yml schema, template frontmatter contract, and adopt-template lifecycle for the ADR Creator - Brought to you by microsoft/hve-core                                                        |
| adr-handoff.instructions             | ADR Creator Govern-phase handoff protocol: compact summary template, peer-agent routing heuristics, and dual-format (ADO + GitHub) work item templates - Brought to you by microsoft/hve-core                                                               |
| adr-identity.instructions            | ADR Creator identity, three-phase state machine, six-step per-turn protocol, autonomy tiers, and canonical state.json schema for Architecture Decision Record authoring sessions - Brought to you by microsoft/hve-core                                     |
| adr-standards.instructions           | Embedded ADR standards: MADR v4.0.0 template (CC0), Y-Statement formula, status taxonomy, naming rules, ASR trigger schema, and Microsoft-attributed paraphrases for ADR Creator sessions - Brought to you by microsoft/hve-core                            |
| rai-backlog-handoff.instructions     | RAI review and backlog handoff for Phase 6: review rubric, RAI review summary, dual-format backlog generation                                                                                                                                               |
| rai-identity.instructions            | RAI Planner identity, 6-phase orchestration, state management, and session recovery - Brought to you by microsoft/hve-core                                                                                                                                  |
| rai-impact-assessment.instructions   | RAI impact assessment for Phase 5: control surface taxonomy, evidence register, tradeoff documentation, and work item generation - Brought to you by microsoft/hve-core                                                                                     |
| rai-risk-classification.instructions | Risk classification screening for Phase 2: prohibited uses gate, risk indicator assessment, and depth tier assignment - Brought to you by microsoft/hve-core                                                                                                |
| rai-security-model.instructions      | RAI security model analysis for Phase 4: AI STRIDE extensions, dual threat IDs, ML STRIDE matrix, and security model merge protocol - Brought to you by microsoft/hve-core                                                                                  |
| rai-standards.instructions           | Embedded RAI standards for Phase 3: NIST AI RMF 1.0 trustworthiness characteristics, subcategory mappings, and framework isolation architecture - Brought to you by microsoft/hve-core                                                                      |
| rai-capture-coaching.instructions    | Exploration-first questioning techniques for RAI capture mode adapted from Design Thinking research methods - Brought to you by microsoft/hve-core                                                                                                          |
| identity.instructions                | Security Planner identity, six-phase orchestration, state management, and session recovery protocols - Brought to you by microsoft/hve-core                                                                                                                 |
| operational-buckets.instructions     | Operational bucket definitions with component classification guidance and cross-cutting security concerns - Brought to you by microsoft/hve-core                                                                                                            |
| standards-mapping.instructions       | Embedded OWASP and NIST security standards with researcher subagent delegation for CIS, WAF, CAF, and other runtime lookups - Brought to you by microsoft/hve-core                                                                                          |
| security-model.instructions          | STRIDE-based security model analysis per operational bucket with threat table format and data flow analysis - Brought to you by microsoft/hve-core                                                                                                          |
| backlog-handoff.instructions         | Dual-format backlog handoff for ADO and GitHub with content sanitization, autonomy tiers, and work item templates - Brought to you by microsoft/hve-core                                                                                                    |
| sssc-identity.instructions           | Identity and orchestration instructions for the SSSC Planner agent. Contains six-phase workflow, state.json schema, session recovery, and question cadence.                                                                                                 |
| sssc-assessment.instructions         | Phase 2 supply chain assessment protocol with the 27 combined capabilities inventory for SSSC Planner.                                                                                                                                                      |
| sssc-standards.instructions          | Phase 3 OpenSSF Scorecard, SLSA v1.0, OpenSSF Best Practices Badge, Sigstore (cosign), and NTIA SBOM minimum elements standards mapping for SSSC Planner.                                                                                                   |
| sssc-gap-analysis.instructions       | Phase 4 gap comparison, adoption categorization, and effort sizing for SSSC Planner.                                                                                                                                                                        |
| sssc-backlog.instructions            | Phase 5 dual-format work item generation with templates and priority derivation for SSSC Planner.                                                                                                                                                           |
| sssc-handoff.instructions            | Phase 6 backlog handoff protocol with Scorecard projections and dual-format output for SSSC Planner.                                                                                                                                                        |
| coaching-patterns.instructions       | Shared exploration-first coaching patterns for planning agents (RAI, security, SSSC) adapted from Design Thinking research methods - Brought to you by microsoft/hve-core                                                                                   |
| disclaimer-language.instructions     | Centralized disclaimer language for AI-assisted planning agents requiring professional review acknowledgment                                                                                                                                                |
| hve-core-location.instructions       | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |
| story-quality.instructions           | Shared story quality conventions for work item creation and evaluation across agents and workflows                                                                                                                                                          |

## Skills

| Skill      | Description                                                                                                                                                                                                                                                                             |
|------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| adr-author | Authoring skill for Architecture Decision Records (ADRs) supporting capture, from-planner-handoff, and adopt-template entry modes with selectable Y-Statement or MADR v4.0.0 output templates, supersession lineage, and ASR trigger evaluation - Brought to you by microsoft/hve-core. |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

