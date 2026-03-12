---
title: Why RAI Planning?
description: How structured Responsible AI assessment catches risks that traditional security planning misses and why it matters for AI systems
sidebar_position: 2
sidebar_label: Why RAI Planning?
keywords:
  * responsible AI
  * AI risk
  * bias
  * fairness
  * NIST AI RMF
tags:
  * rai-planning
  * responsible-ai
  * concepts
author: Microsoft
ms.date: 2025-07-14
ms.topic: concept
estimated_reading_time: 6
---

## A Different Kind of Risk

Traditional security planning focuses on how adversaries exploit systems. Injection attacks, broken access control, cryptographic failures: these are threats where an attacker deliberately subverts intended behavior. Security assessments excel at finding and mitigating these risks.

AI systems introduce a fundamentally different risk category. A model can produce biased outputs, make opaque decisions that affect people's lives, or amplify existing societal inequities, all while functioning exactly as designed. No attacker is required. The system itself is the risk surface.

## The Core Insight

Security planning asks: "How can this system be attacked?"

RAI planning asks: "How can this system cause harm, even when working correctly?"

Both questions matter. They require different analytical frameworks, different threat taxonomies, and different mitigation strategies. Running a security assessment alone leaves the AI-specific risk surface unexamined.

## How Each Phase Addresses AI Risk

### Phase 1: AI System Scoping

Establishes what the AI system does, who it affects, and where it operates. Identifies all AI and ML components, their data inputs, and the decisions they influence. Without clear boundaries, risk assessment cannot be comprehensive.

### Phase 2: Sensitive Uses Assessment

Screens the system against Microsoft's sensitive uses categories, including applications in healthcare, criminal justice, employment, and education where AI decisions carry elevated consequences. Catches restricted use scenarios that require organizational escalation before development continues.

### Phase 3: RAI Standards Mapping

Maps each AI component against the six Microsoft RAI principles and NIST AI RMF subcategories. Identifies which principles apply to which components and what regulatory obligations exist. This mapping becomes the evaluation framework for Phases 4 and 5.

### Phase 4: RAI Risk Surface Analysis

Applies AI-specific threat analysis across seven categories: data poisoning, model evasion, prompt injection, output manipulation, bias amplification, privacy leakage, and misuse escalation. These categories reflect how AI systems fail, not how traditional applications are exploited.

### Phase 5: RAI Impact Assessment

Evaluates whether adequate controls exist for each identified threat. Documents evidence of mitigations already in place and identifies gaps. Analyzes tradeoffs where RAI principles compete, such as transparency versus privacy or fairness across different demographic groups.

### Phase 6: Review and Handoff

Produces a quantified scorecard across five dimensions and converts gaps into actionable backlog items. The score determines whether the system proceeds, requires conditions, or needs remediation.

## Quality Comparison

| Dimension | Ad-hoc assessment | RAI Planner |
|---|---|---|
| Threat coverage | Varies by assessor expertise | Seven AI-specific threat categories applied systematically |
| Standards traceability | Often informal or missing | Each finding mapped to RAI principles and NIST AI RMF subcategories |
| Sensitive uses screening | Frequently overlooked | Mandatory Phase 2 gate with restricted uses escalation |
| Reproducibility | Depends on individual documentation | Structured state, artifacts, and scoring produce consistent results |
| Backlog integration | Manual translation to work items | Automated generation with autonomy tiers and dual-platform support |
| Security plan continuity | Separate process, no shared context | `from-security-plan` mode inherits AI components and threat sequences |

## Learning Curve

You do not need RAI expertise to start. The agent guides the assessment conversationally, asking focused questions and explaining concepts as they arise.

| Step | Activity |
|---|---|
| First session | Run in `capture` mode on a project you know well. Answer the questions naturally and review the generated artifacts. |
| Second session | Try `from-security-plan` mode after completing a security plan. Notice how AI component data carries forward automatically. |
| Third session | Review the scorecard and backlog output. Use the generated work items to drive actual mitigations. |
| Ongoing | The structured artifacts serve as living documentation. Return to update assessments as the AI system evolves. |

## Choosing Your Approach

| Factor | `capture` | `from-prd` | `from-security-plan` |
|---|---|---|---|
| Starting context | None; full interview from scratch | PRD or BRD artifacts in `.copilot-tracking/` | Completed security plan with AI components |
| AI component discovery | Manual during Phase 1 questions | Extracted from product documentation | Pre-populated from security plan state |
| Threat ID continuity | Starts at `RAI-T-{CATEGORY}-001` | Starts at `RAI-T-{CATEGORY}-001` | Continues from security plan threat count |
| Time to Phase 2 | Longest: full scoping interview | Medium: confirm and refine extracted scope | Shortest: verify pre-populated data |
| Best for | Exploratory assessments, standalone AI projects | Projects with existing product documentation | The recommended workflow after security planning |

See [Entry Modes](entry-modes) for step-by-step instructions on starting each mode.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
