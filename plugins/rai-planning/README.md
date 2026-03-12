<!-- markdownlint-disable-file -->
# RAI Planning

Responsible AI assessment, sensitive uses screening, and standards-aligned impact analysis

> **⚠️ Experimental** — This collection is experimental. Contents and behavior may change or be removed without notice.

## Install

```bash
copilot plugin install rai-planning@hve-core
```

## Agents

| Agent       | Description                                                                                                                                                                                                                                                                                                                  |
|-------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| rai-planner | Responsible AI assessment agent with 6-phase conversational workflow. Evaluates AI systems against Microsoft RAI Standard v2 and NIST AI RMF 1.0. Produces sensitive uses screening, RAI security model, impact assessment, control surface catalog, and dual-format backlog handoff. - Brought to you by microsoft/hve-core |

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

