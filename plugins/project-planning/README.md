<!-- markdownlint-disable-file -->
# Project Planning

PRDs, BRDs, ADRs, and architecture diagrams

## Overview

Create architecture decision records, requirements documents, and diagrams — all through guided AI workflows.

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

| Agent                        | Description                                                                                                                                                                                                |
|------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| agile-coach                  | Conversational agent that helps create or refine goal-oriented user stories with clear acceptance criteria for any tracking tool - Brought to you by microsoft/hve-core                                    |
| product-manager-advisor      | Product management advisor for requirements discovery, validation, and issue creation                                                                                                                      |
| ux-ui-designer               | UX research specialist for Jobs-to-be-Done analysis, user journey mapping, and accessibility requirements                                                                                                  |
| adr-creation                 | Interactive AI coaching for collaborative architectural decision record creation with guided discovery, research integration, and progressive documentation building - Brought to you by microsoft/edge-ai |
| arch-diagram-builder         | Architecture diagram builder agent that builds high quality ASCII-art diagrams - Brought to you by microsoft/hve-core                                                                                      |
| brd-builder                  | Business Requirements Document builder with guided Q&A and reference integration                                                                                                                           |
| system-architecture-reviewer | System architecture reviewer for design trade-offs, ADR creation, and well-architected alignment - Brought to you by microsoft/hve-core                                                                    |
| rpi-agent                    | Autonomous RPI orchestrator running Research → Plan → Implement → Review → Discover phases, using specialized subagents when task difficulty warrants them - Brought to you by microsoft/hve-core          |
| prd-builder                  | Product Requirements Document builder with guided Q&A and reference integration                                                                                                                            |
| meeting-analyst              | Meeting transcript analyzer that extracts product requirements for PRD creation via work-iq-mcp - Brought to you by microsoft/hve-core                                                                     |
| researcher-subagent          | Research subagent using search tools, read tools, fetch web page, github repo, and mcp tools                                                                                                               |
| plan-validator               | Validates implementation plans against research documents, updating the Planning Log Discrepancy Log section with severity-graded findings - Brought to you by microsoft/hve-core                          |
| phase-implementor            | Executes a single implementation phase from a plan with full codebase access and change tracking - Brought to you by microsoft/hve-core                                                                    |
| rpi-validator                | Validates a Changes Log against the Implementation Plan, Planning Log, and Research Documents for a specific plan phase - Brought to you by microsoft/hve-core                                             |
| implementation-validator     | Validates implementation quality against architectural requirements, design principles, and code standards with severity-graded findings - Brought to you by microsoft/hve-core                            |

## Instructions

| Instruction       | Description                                                                                                                                                                                                                                                 |
|-------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| hve-core-location | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |
| story-quality     | Shared story quality conventions for work item creation and evaluation across agents and workflows                                                                                                                                                          |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

