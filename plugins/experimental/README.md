<!-- markdownlint-disable-file -->
# Experimental

Experimental and preview artifacts not yet promoted to stable collections

> **⚠️ Experimental** — This collection is experimental. Contents and behavior may change or be removed without notice.

## Overview

Experimental and preview artifacts not yet promoted to stable collections. Items in this collection may change or be removed without notice.

This collection includes agents, skills, and instructions for:

- **PowerPoint Builder** — Creates, updates, and manages PowerPoint slide decks using YAML-driven content with python-pptx
- **Video to GIF** — Convert video files to animated GIF format

## Install

```bash
copilot plugin install experimental@hve-core
```

## Agents

| Agent            | Description                                                                                                                                                                                                                                                                                                                  |
|------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| pptx             | Creates, updates, and manages PowerPoint slide decks using YAML-driven content with python-pptx                                                                                                                                                                                                                              |
| pptx-subagent    | Executes PowerPoint skill operations including content extraction, YAML creation, deck building, and visual validation                                                                                                                                                                                                       |
| rai-planner      | Responsible AI assessment agent with 6-phase conversational workflow. Evaluates AI systems against Microsoft RAI Standard v2 and NIST AI RMF 1.0. Produces sensitive uses screening, RAI security model, impact assessment, control surface catalog, and dual-format backlog handoff. - Brought to you by microsoft/hve-core |
| security-planner | Phase-based security planner that produces security models, standards mappings, and backlog handoff artifacts with AI/ML component detection and RAI Planner integration                                                                                                                                                     |

## Commands

| Command                | Description                                                                                                     |
|------------------------|-----------------------------------------------------------------------------------------------------------------|
| incident-response      | Incident response workflow for Azure operations scenarios - Brought to you by microsoft/hve-core                |
| risk-register          | Creates a concise and well-structured qualitative risk register using a Probability × Impact (P×I) risk matrix. |
| security-capture       | Initiate security planning from existing notes or knowledge using the Security Planner agent in capture mode    |
| security-plan-from-prd | Initiate security planning from PRD/BRD artifacts using the Security Planner agent in scoping mode              |

## Instructions

| Instruction           | Description                                                                                                                                                                                                                                                 |
|-----------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| pptx                  | Shared conventions for PowerPoint Builder agent, subagent, and powerpoint skill                                                                                                                                                                             |
| rai-backlog-handoff   | RAI review and backlog handoff for Phase 6: review rubric, RAI scorecard, dual-format backlog generation                                                                                                                                                    |
| rai-identity          | RAI Planner identity, 6-phase orchestration, state management, and session recovery - Brought to you by microsoft/hve-core                                                                                                                                  |
| rai-impact-assessment | RAI impact assessment for Phase 5: control surface taxonomy, evidence register, tradeoff documentation, and work item generation                                                                                                                            |
| rai-security-model    | RAI security model analysis for Phase 4: AI STRIDE extensions, dual threat IDs, ML STRIDE matrix, and security model merge protocol                                                                                                                         |
| rai-sensitive-uses    | Sensitive Uses assessment for Phase 2: screening categories, restricted uses gate, and depth tier assignment                                                                                                                                                |
| rai-standards         | Embedded RAI standards for Phase 3: Microsoft RAI Standard v2 principles and NIST AI RMF subcategory mappings                                                                                                                                               |
| rai-capture-coaching  | Exploration-first questioning techniques for RAI capture mode adapted from Design Thinking research methods - Brought to you by microsoft/hve-core                                                                                                          |
| backlog-handoff       | Dual-format backlog handoff for ADO and GitHub with content sanitization, autonomy tiers, and work item templates - Brought to you by microsoft/hve-core                                                                                                    |
| identity              | Security Planner identity, six-phase orchestration, state management, and session recovery protocols - Brought to you by microsoft/hve-core                                                                                                                 |
| operational-buckets   | Operational bucket definitions with component classification guidance and cross-cutting security concerns - Brought to you by microsoft/hve-core                                                                                                            |
| security-model        | STRIDE-based security model analysis per operational bucket with threat table format and data flow analysis - Brought to you by microsoft/hve-core                                                                                                          |
| standards-mapping     | Embedded OWASP, NIST, and CIS security standards with researcher subagent delegation for WAF/CAF runtime lookups - Brought to you by microsoft/hve-core                                                                                                     |
| hve-core-location     | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |

## Skills

| Skill        | Description                                                                                                                                   |
|--------------|-----------------------------------------------------------------------------------------------------------------------------------------------|
| powerpoint   | PowerPoint slide deck generation and management using python-pptx with YAML-driven content and styling - Brought to you by microsoft/hve-core |
| video-to-gif | Video-to-GIF conversion skill with FFmpeg two-pass optimization - Brought to you by microsoft/hve-core                                        |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

