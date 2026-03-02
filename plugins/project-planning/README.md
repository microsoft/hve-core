<!-- markdownlint-disable-file -->
# Project Planning

PRDs, BRDs, ADRs, and architecture diagrams

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
| rpi-agent                    | Autonomous RPI orchestrator running specialized subagents through Research → Plan → Implement → Review → Discover phases - Brought to you by microsoft/hve-core                                            |
| prd-builder                  | Product Requirements Document builder with guided Q&A and reference integration                                                                                                                            |
| researcher-subagent          | Research subagent using search tools, read tools, fetch web page, github repo, and mcp tools                                                                                                               |
| plan-validator               | Validates implementation plans against research documents, updating the Planning Log Discrepancy Log section with severity-graded findings - Brought to you by microsoft/hve-core                          |
| phase-implementor            | Executes a single implementation phase from a plan with full codebase access and change tracking - Brought to you by microsoft/hve-core                                                                    |
| rpi-validator                | Validates a Changes Log against the Implementation Plan, Planning Log, and Research Documents for a specific plan phase - Brought to you by microsoft/hve-core                                             |
| implementation-validator     | Validates implementation quality against architectural requirements, design principles, and code standards with severity-graded findings - Brought to you by microsoft/hve-core                            |

## Instructions

| Instruction       | Description                                                                                                                                                                                                                                                 |
|-------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| hve-core-location | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

