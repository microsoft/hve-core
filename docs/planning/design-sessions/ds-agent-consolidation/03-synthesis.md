---
title: "Method 3 Synthesis: DS Agent Consolidation"
description: Superseded synthesis themes for the Data Workstream Coach consolidation
sidebar_position: 4
author: Microsoft
ms.date: 2026-08-03
ms.topic: reference
---

> [!WARNING]
> **Superseded.** These themes predate six of the seven findings in [the research record](./02-research.md).
>
> Use [the consolidated design](data-workstream-coach-design) for the current design.

**Project:** ds-agent-consolidation  
**Method:** 3 (Input Synthesis)  
**Date:** 2026-07-31  
**Status:** Themes validated by project lead

---

## Evidence Base

Sources feeding this synthesis:

* Direct expertise of lead dev (primary SME; Method 2 skipped with rationale)
* Live asset inventory: 5 agents, 1 prompt, 3 skills, 2 collections in `.github/agents/data-science/` and `data-science.collection.yml`
* Differentiation analysis: per-asset assessment of what each adds beyond native GHCP
* CSE playbook live audit: `ml-and-ai-projects/` section, `ml-fundamentals-checklist/`
* Confirmed playbook license: MIT (content embedding permitted with attribution)

---

## Synthesis Themes

### Theme 1: The Platform Gap

HVE Core's DS agents do things native Copilot genuinely cannot: machine-readable schema contracts, deterministic output chaining, structured phase workflows with exit criteria. But the boundary between HVE-added value and native platform capability has never been drawn deliberately. Agents grew independently; no one pruned what the platform overtook.

**Root tension:** HVE adds real value in orchestration and convention enforcement, but the surface area looks indistinguishable from "write me some Python" to a new user.

**How Might We:** How might we make the boundary between HVE-added value and native Copilot capability explicit and maintainable over time?

---

### Theme 2: Invisible Engagement Standards

The CSE playbook's `ml-and-ai-projects` section has exactly the right structure for a data science engagement: feasibility evidence, data quality governance, evaluation metrics, model baseline, experimentation setup, production readiness, and RAI review. None of it surfaces in the data scientist's current workflow. It's knowledge that exists in a URL nobody visits.

**Root tension:** The standards exist and are well-designed; the problem is entirely one of surfacing and timing: getting the right checklist item in front of the data scientist at the moment it's relevant, not as a separate compliance step.

**Confirmed gap:** None of the five high-value ML playbook artifacts exist anywhere in the current HVE Core DS collection:

* Envisioning Summary ❌
* ML Fundamentals Checklist ❌
* Feasibility Study ❌
* DS Testing conventions (partial) ⚠️
* RAI review integration (exists but not wired to DS workflow) ⚠️

**How Might We:** How might we embed CSE ML engagement standards into the data scientist's natural workflow so compliance is a byproduct rather than an interruption?

---

### Theme 3: Fragmented Knowledge, No Orchestration Layer

RAI lives in one collection corner. Testing lives in one agent. Data inventory doesn't exist. Synthesis doesn't exist. Each DS agent is an island with no shared context, no session continuity, and no engagement-level awareness. The data scientist assembles the engagement picture entirely in their own head.

**Root tension:** The existing agents have genuine value (especially schema contracts, chaining awareness, and phase-driven workflows), but none of them know they're part of a larger engagement story.

**Architecture implication:** Skill-based approach preferred over agent proliferation. A `data-science` skill family (mirroring how `security` works) backed by a single unified agent as orchestration layer, with RAI as a first-class bundled dependency in the collection.

**How Might We:** How might we give data scientists a single coherent entry point that surfaces the right knowledge and generates the right artifacts at each stage of an ML engagement, without requiring them to know the architecture?

---

## Candidate Skill Family

Emerging from synthesis:

| Skill               | Source                                       | Action              |
|---------------------|----------------------------------------------|---------------------|
| `ds-fundamentals`   | CSE playbook `ml-and-ai-projects/` (MIT)     | Build new           |
| `ds-data-inventory` | Datasheets for Datasets (Gebru et al., open) | Build new           |
| `ds-simulation`     | Existing `synth-data-generate.prompt.md`     | Extend              |
| `ds-testing`        | Existing `test-streamlit-dashboard.agent.md` | Refactor to skill   |
| `rai-standards`     | Already in collection                        | Wire as dependency  |
| `rai-planner`       | Already in collection                        | Promote to required |

---

## Method 3 Readiness Check

| Dimension                | Status           | Notes                                                                                |
|--------------------------|------------------|--------------------------------------------------------------------------------------|
| Research Fidelity        | ⚠️ Single-source | SME expertise only; no external practitioner validation yet                          |
| Stakeholder Completeness | ✅                | Primary user (data scientist) clearly defined with behavioral insight                |
| Pattern Robustness       | ✅                | Three themes consistent across asset inventory, playbook audit, and direct expertise |
| Actionability            | ✅                | Each HMW maps to a concrete design direction                                         |
| Team Alignment           | ✅                | Themes confirmed by project lead                                                     |

**Single-source flag:** Research fidelity is the known weak point (per Method 1 backpressure analysis). Architecture should support easy future correction by making skill constraints externally editable without rebuilding the agent.

---

<!-- markdownlint-disable MD036 -->

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
