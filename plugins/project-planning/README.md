<!-- markdownlint-disable-file -->
# Project Planning

PRDs, BRDs, ADRs, and architecture diagrams

## Overview

Create architecture decision records, requirements documents, and diagrams — all through guided AI workflows. Evaluate AI-powered systems against Responsible AI standards and conduct STRIDE-based security model analysis with automated backlog generation.

This collection includes agents for:

- **Agile Coach** — Create or refine goal-oriented user stories with clear acceptance criteria
- **Product Manager Advisor** — Product management advisor for requirements discovery, validation, and issue creation
- **UX/UI Designer** — UX research specialist for Jobs-to-be-Done analysis, user journey mapping, and accessibility requirements
- **Architecture Decision Records** — Create structured ADRs with solution comparison matrices
- **Architecture Diagrams** — Generate ASCII-art architecture diagrams from descriptions
- **Business Requirements Documents** — Build BRDs through guided Q&A sessions
- **System Architecture Reviewer** — System architecture reviewer for design trade-offs, ADR creation, and well-architected alignment
- **RPI Agent** — Autonomous RPI orchestrator running specialized subagents through Research, Plan, Implement, and Review phases
- **Product Requirements Documents** — Build PRDs with stakeholder-driven refinement
- **RAI Planner** — Responsible AI assessment with sensitive uses screening, security model analysis, impact assessment, and dual-format backlog handoff
- **Security Planner** — STRIDE-based security model analysis with operational bucket classification, standards mapping, and automated backlog generation
- **SSSC Planner** — Software supply-chain security assessment with gap analysis, standards mapping, and automated backlog generation

Supporting subagents included:

- **Researcher Subagent** — Research subagent using search tools, read tools, fetch web page, github repo, and MCP tools
- **Plan Validator** — Validates implementation plans against research documents with severity-graded findings
- **Phase Implementor** — Executes a single implementation phase from a plan with full codebase access and change tracking
- **RPI Validator** — Validates a Changes Log against the Implementation Plan, Planning Log, and Research Documents
- **Implementation Validator** — Validates implementation quality against architectural requirements, design principles, and code standards

## Install

```bash
copilot plugin install project-planning@hve-core
```

## Agents

| Agent                        | Description                                                                                                                                                                                                                                                                                                                  |
|------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| agile-coach                  | Conversational agent that helps create or refine goal-oriented user stories with clear acceptance criteria for any tracking tool - Brought to you by microsoft/hve-core                                                                                                                                                      |
| product-manager-advisor      | Product management advisor for requirements discovery, validation, and issue creation                                                                                                                                                                                                                                        |
| ux-ui-designer               | UX research specialist for Jobs-to-be-Done analysis, user journey mapping, and accessibility requirements                                                                                                                                                                                                                    |
| adr-creation                 | Interactive AI coaching for collaborative architectural decision record creation with guided discovery, research integration, and progressive documentation building - Brought to you by microsoft/edge-ai                                                                                                                   |
| arch-diagram-builder         | Architecture diagram builder agent that builds high quality ASCII-art diagrams - Brought to you by microsoft/hve-core                                                                                                                                                                                                        |
| brd-builder                  | Business Requirements Document builder with guided Q&A and reference integration                                                                                                                                                                                                                                             |
| system-architecture-reviewer | System architecture reviewer for design trade-offs, ADR creation, and well-architected alignment - Brought to you by microsoft/hve-core                                                                                                                                                                                      |
| rpi-agent                    | Autonomous RPI orchestrator running Research → Plan → Implement → Review → Discover phases, using specialized subagents when task difficulty warrants them - Brought to you by microsoft/hve-core                                                                                                                            |
| prd-builder                  | Product Requirements Document builder with guided Q&A and reference integration                                                                                                                                                                                                                                              |
| meeting-analyst              | Meeting transcript analyzer that extracts product requirements for PRD creation via work-iq-mcp - Brought to you by microsoft/hve-core                                                                                                                                                                                       |
| rai-planner                  | Responsible AI assessment agent with 6-phase conversational workflow. Evaluates AI systems against Microsoft RAI Standard v2 and NIST AI RMF 1.0. Produces sensitive uses screening, RAI security model, impact assessment, control surface catalog, and dual-format backlog handoff. - Brought to you by microsoft/hve-core |
| security-planner             | Phase-based security planner that produces security models, standards mappings, and backlog handoff artifacts with AI/ML component detection and RAI Planner integration                                                                                                                                                     |
| sssc-planner                 | Guides users through a six-phase assessment of their repository's supply chain security posture against OpenSSF Scorecard, SLSA, Sigstore, and SBOM standards, producing a prioritized backlog referencing reusable workflows from hve-core and microsoft/physical-ai-toolchain.                                             |
| researcher-subagent          | Research subagent using search tools, read tools, fetch web page, github repo, and mcp tools                                                                                                                                                                                                                                 |
| plan-validator               | Validates implementation plans against research documents, updating the Planning Log Discrepancy Log section with severity-graded findings - Brought to you by microsoft/hve-core                                                                                                                                            |
| phase-implementor            | Executes a single implementation phase from a plan with full codebase access and change tracking - Brought to you by microsoft/hve-core                                                                                                                                                                                      |
| rpi-validator                | Validates a Changes Log against the Implementation Plan, Planning Log, and Research Documents for a specific plan phase - Brought to you by microsoft/hve-core                                                                                                                                                               |
| implementation-validator     | Validates implementation quality against architectural requirements, design principles, and code standards with severity-graded findings - Brought to you by microsoft/hve-core                                                                                                                                              |

## Commands

| Command                     | Description                                                                                                                              |
|-----------------------------|------------------------------------------------------------------------------------------------------------------------------------------|
| security-plan-from-prd      | Initiate security planning from PRD/BRD artifacts using the Security Planner agent in from-prd mode                                      |
| security-capture            | Initiate security planning from existing notes or knowledge using the Security Planner agent in capture mode                             |
| incident-response           | Incident response workflow for Azure operations scenarios - Brought to you by microsoft/hve-core                                         |
| risk-register               | Creates a concise and well-structured qualitative risk register using a Probability × Impact (P×I) risk matrix.                          |
| rai-capture                 | Initiate a responsible AI assessment from existing knowledge using the RAI Planner agent in capture mode                                 |
| rai-plan-from-prd           | Initiate a responsible AI assessment from PRD/BRD artifacts using the RAI Planner agent in from-prd mode                                 |
| rai-plan-from-security-plan | Initiate a responsible AI assessment from a completed Security Plan using the RAI Planner agent in from-security-plan mode (recommended) |
| sssc-capture                | Start a new SSSC assessment via guided conversation using the SSSC Planner agent in capture mode                                         |
| sssc-from-prd               | Start an SSSC assessment from existing PRD artifacts using the SSSC Planner agent                                                        |
| sssc-from-brd               | Start an SSSC assessment from existing BRD artifacts using the SSSC Planner agent                                                        |
| sssc-from-security-plan     | Extend a Security Planner assessment with supply chain coverage using the SSSC Planner agent                                             |

## Instructions

| Instruction           | Description                                                                                                                                                                                                                                                 |
|-----------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| rai-backlog-handoff   | RAI review and backlog handoff for Phase 6: review rubric, RAI scorecard, dual-format backlog generation                                                                                                                                                    |
| rai-identity          | RAI Planner identity, 6-phase orchestration, state management, and session recovery - Brought to you by microsoft/hve-core                                                                                                                                  |
| rai-impact-assessment | RAI impact assessment for Phase 5: control surface taxonomy, evidence register, tradeoff documentation, and work item generation                                                                                                                            |
| rai-security-model    | RAI security model analysis for Phase 4: AI STRIDE extensions, dual threat IDs, ML STRIDE matrix, and security model merge protocol                                                                                                                         |
| rai-sensitive-uses    | Sensitive Uses assessment for Phase 2: screening categories, restricted uses gate, and depth tier assignment                                                                                                                                                |
| rai-standards         | Embedded RAI standards for Phase 3: Microsoft RAI Standard v2 principles and NIST AI RMF subcategory mappings                                                                                                                                               |
| rai-capture-coaching  | Exploration-first questioning techniques for RAI capture mode adapted from Design Thinking research methods - Brought to you by microsoft/hve-core                                                                                                          |
| identity              | Security Planner identity, six-phase orchestration, state management, and session recovery protocols - Brought to you by microsoft/hve-core                                                                                                                 |
| operational-buckets   | Operational bucket definitions with component classification guidance and cross-cutting security concerns - Brought to you by microsoft/hve-core                                                                                                            |
| standards-mapping     | Embedded OWASP, NIST, and CIS security standards with researcher subagent delegation for WAF/CAF runtime lookups - Brought to you by microsoft/hve-core                                                                                                     |
| security-model        | STRIDE-based security model analysis per operational bucket with threat table format and data flow analysis - Brought to you by microsoft/hve-core                                                                                                          |
| backlog-handoff       | Dual-format backlog handoff for ADO and GitHub with content sanitization, autonomy tiers, and work item templates - Brought to you by microsoft/hve-core                                                                                                    |
| sssc-identity         | Identity and orchestration instructions for the SSSC Planner agent. Contains six-phase workflow, state.json schema, session recovery, and question cadence.                                                                                                 |
| sssc-assessment       | Phase 2 supply chain assessment protocol with the 27 combined capabilities inventory for SSSC Planner.                                                                                                                                                      |
| sssc-standards        | Phase 3 OpenSSF Scorecard, SLSA, Best Practices Badge, Sigstore, and SBOM standards mapping for SSSC Planner.                                                                                                                                               |
| sssc-gap-analysis     | Phase 4 gap comparison, adoption categorization, and effort sizing for SSSC Planner.                                                                                                                                                                        |
| sssc-backlog          | Phase 5 dual-format work item generation with templates and priority derivation for SSSC Planner.                                                                                                                                                           |
| sssc-handoff          | Phase 6 backlog handoff protocol with Scorecard projections and dual-format output for SSSC Planner.                                                                                                                                                        |
| hve-core-location     | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |
| story-quality         | Shared story quality conventions for work item creation and evaluation across agents and workflows                                                                                                                                                          |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

