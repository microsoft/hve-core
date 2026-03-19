<!-- markdownlint-disable-file -->
# RAI Planning

Responsible AI assessment, sensitive uses screening, and standards-aligned impact analysis

> **⚠️ Experimental** — This collection is experimental. Contents and behavior may change or be removed without notice.

> [!CAUTION]
> The RAI agents and prompts in this collection are **assistive tools only**. They do not replace qualified responsible AI review, ethics board oversight, or established organizational RAI governance processes. All AI-generated RAI assessments, impact analyses, and recommendations **must** be reviewed and validated by qualified professionals before use. AI outputs may contain inaccuracies, miss sensitive use categories, or produce recommendations that are incomplete or inappropriate for your context.

## Overview

Assess AI systems for responsible AI risks using structured standards-aligned analysis, sensitive uses screening, and impact assessment.

> [!CAUTION]
> The RAI agents and prompts in this collection are **assistive tools only**. They do not replace qualified human review, organizational RAI review boards, or regulatory compliance programs. All AI-generated RAI artifacts **must** be reviewed and validated by qualified professionals before use. AI outputs may contain inaccuracies, miss critical risks, or produce recommendations that are incomplete or inappropriate for your context.

This collection includes agents and prompts for:

- **RAI Assessment** — Conduct structured responsible AI assessments aligned to Microsoft RAI Standard v2 and NIST AI RMF
- **Sensitive Uses Screening** — Screen AI systems against 8 sensitive use categories and restricted use gates
- **Impact Analysis** — Evaluate fairness, reliability, privacy, security, inclusiveness, transparency, and accountability impacts
- **Security Model Analysis** — Identify AI-specific threats using extended STRIDE methodology with ML-specific attack patterns
- **Backlog Handoff** — Generate prioritized RAI work items in ADO or GitHub formats

## Prerequisites

The RAI Planner works as a standalone agent but produces the best results when paired with the **Security Planner** collection. Running a security assessment first provides threat context that enriches RAI impact analysis.

## Interaction Model

The RAI Planner follows a Sequential interaction model (Model A) with the Security Planner:

1. **Security Planner** runs first and detects AI components during Phase 1
2. **Security Planner** completes its security assessment and hands off to the RAI Planner
3. **RAI Planner** inherits threat context and performs RAI-specific analysis

The RAI Planner can also run independently using `capture`, `prd`, or `resume` entry modes.

## Install

```bash
copilot plugin install rai-planning@hve-core
```

## Agents

| Agent               | Description                                                                                                                                                                                                                                                                                                                  |
|---------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| rai-planner         | Responsible AI assessment agent with 6-phase conversational workflow. Evaluates AI systems against Microsoft RAI Standard v2 and NIST AI RMF 1.0. Produces sensitive uses screening, RAI security model, impact assessment, control surface catalog, and dual-format backlog handoff. - Brought to you by microsoft/hve-core |
| researcher-subagent | Research subagent using search tools, read tools, fetch web page, github repo, and mcp tools                                                                                                                                                                                                                                 |

## Commands

| Command                     | Description                                                                                                                              |
|-----------------------------|------------------------------------------------------------------------------------------------------------------------------------------|
| rai-capture                 | Initiate a responsible AI assessment from existing knowledge using the RAI Planner agent in capture mode                                 |
| rai-plan-from-prd           | Initiate a responsible AI assessment from PRD/BRD artifacts using the RAI Planner agent in from-prd mode                                 |
| rai-plan-from-security-plan | Initiate a responsible AI assessment from a completed Security Plan using the RAI Planner agent in from-security-plan mode (recommended) |

## Instructions

| Instruction           | Description                                                                                                                                                                                                                                                 |
|-----------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| rai-identity          | RAI Planner identity, 6-phase orchestration, state management, and session recovery - Brought to you by microsoft/hve-core                                                                                                                                  |
| rai-standards         | Embedded RAI standards for Phase 3: Microsoft RAI Standard v2 principles and NIST AI RMF subcategory mappings                                                                                                                                               |
| rai-sensitive-uses    | Sensitive Uses assessment for Phase 2: screening categories, restricted uses gate, and depth tier assignment                                                                                                                                                |
| rai-security-model    | RAI security model analysis for Phase 4: AI STRIDE extensions, dual threat IDs, ML STRIDE matrix, and security model merge protocol                                                                                                                         |
| rai-impact-assessment | RAI impact assessment for Phase 5: control surface taxonomy, evidence register, tradeoff documentation, and work item generation                                                                                                                            |
| rai-backlog-handoff   | RAI review and backlog handoff for Phase 6: review rubric, RAI scorecard, dual-format backlog generation                                                                                                                                                    |
| rai-capture-coaching  | Exploration-first questioning techniques for RAI capture mode adapted from Design Thinking research methods - Brought to you by microsoft/hve-core                                                                                                          |
| hve-core-location     | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

