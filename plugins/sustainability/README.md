<!-- markdownlint-disable-file -->
# Sustainability

Sustainability planning, workload assessment, standards mapping, gap analysis, and backlog generation against Green Software Foundation SCI/Patterns/Principles, Sustainable Web Design, Web Sustainability Guidelines, and the Azure Well-Architected Sustainability pillar

> [!CAUTION]
> The sustainability agents and instructions in this collection are **assistive tools only**. They produce directional sustainability estimates, not audited disclosures. They do not provide legal, regulatory, or compliance advice and do not replace qualified sustainability professionals or applicable disclosure-framework counsel (CSRD/ESRS, SEC climate rules, GHG Protocol, TCFD, ISO 14064/14067). Requests to generate text for CSRD or ESRS disclosures, SEC climate filings, GHG Protocol corporate inventories, TCFD reports, or ISO 14064/ISO 14067 attestations fall outside this planner's scope. All AI-generated sustainability artifacts **must** be reviewed by a qualified sustainability professional before external use.

## Overview

Sustainability planning, workload assessment, standards mapping, gap analysis, and prioritized backlog generation against Green Software Foundation SCI/Patterns/Principles, Sustainable Web Design, Web Sustainability Guidelines, and the Azure Well-Architected Sustainability pillar.

> [!CAUTION]
> The sustainability agents and instructions in this collection are **assistive tools only**. They produce directional sustainability estimates, not audited disclosures. They do not provide legal, regulatory, or compliance advice and do not replace qualified sustainability professionals or applicable disclosure-framework counsel (CSRD/ESRS, SEC climate rules, GHG Protocol, TCFD, ISO 14064/14067). Requests to generate text for CSRD or ESRS disclosures, SEC climate filings, GHG Protocol corporate inventories, TCFD reports, or ISO 14064/ISO 14067 attestations fall outside this planner's scope. All AI-generated sustainability artifacts **must** be reviewed by a qualified sustainability professional before external use.

This collection includes agents and instructions for:

- **Sustainability Planning** - Six-phase conversational workflow producing workload assessment, standards mapping, gap analysis, and dual-format backlog handoff
- **SCI Estimation** - Capture deterministic, estimated, heuristic, and user-declared inputs to the Software Carbon Intensity formula and emit `sci-budgets/*.yml` skeletons keyed to active workloads
- **Green Software Adoption** - Map active workloads to GSF Principles and to the Azure Well-Architected Sustainability pillar
- **Web Sustainability Mapping** - Cross-walk web surfaces against Sustainable Web Design (SWD) and Web Sustainability Guidelines (WSG) controls
- **Active Controls Export** - Emit `active-controls.json` for downstream consumption by Security, SSSC, RAI, and code-review agents
- **Out-of-Band Disclosure Refusal** - Halt and redirect any request to generate CSRD/ESRS/SEC/GHG/TCFD/ISO 14064/14067 disclosure text

Supporting subagents included:

- **Sustainability Researcher Subagent** - Research subagent for license interrogation and standards-discovery topics across GSF, SWD, WSG, and Azure Well-Architected references

Framework Skills included:

- **GSF SCI** - Green Software Foundation Software Carbon Intensity specification (ISO 21031 reference-only) packaged as machine-readable per-control YAML
- **GSF Principles** - Green Software Foundation core principles as machine-readable items
- **GSF Principles** - Green Software Foundation Principles as per-principle controls
- **Sustainable Web Design (SWD)** - SWD v4 controls for low-carbon web design and content delivery
- **Web Sustainability Guidelines (WSG)** - W3C Web Sustainability Guidelines as per-guideline controls
- **Azure Well-Architected Sustainability** - Azure WAF Sustainability pillar recommendation groups
- **Sustainability Capability Inventory** - Workload capability inventory consumed by the Sustainability Planner during workload assessment, gap analysis, and backlog generation
- **Framework Skill** - Authoring guide for Framework Skills — host-agent-neutral packaging format for framework specifications

## Install

```bash
copilot plugin install sustainability@hve-core
```

## Agents

| Agent                              | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
|------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| sustainability-planner             | Guides users through a six-phase assessment of their workload's sustainability posture against Green Software Foundation principles, the Software Carbon Intensity (SCI) specification, the Sustainable Web Design model, the Web Sustainability Guidelines, and the Azure Well-Architected Sustainability pillar, producing a prioritized backlog and SCI budget skeletons referencing reusable workflows from hve-core and microsoft/physical-ai-toolchain. |
| sustainability-researcher-subagent | Domain-scoped researcher for runtime VERIFY-FETCH lookups of sustainability standards and SCI variable references; not user-invocable                                                                                                                                                                                                                                                                                                                         |

## Commands

| Command                           | Description                                                                                                          |
|-----------------------------------|----------------------------------------------------------------------------------------------------------------------|
| sustainability-capture            | Start a new sustainability assessment via guided conversation using the Sustainability Planner agent in capture mode |
| sustainability-from-brd           | Start a sustainability assessment from existing BRD artifacts using the Sustainability Planner agent                 |
| sustainability-from-prd           | Start a sustainability assessment from existing PRD artifacts using the Sustainability Planner agent                 |
| sustainability-from-security-plan | Extend a Security Planner assessment with sustainability coverage using the Sustainability Planner agent             |

## Instructions

| Instruction                                     | Description                                                                                                                                                                                                                                                 |
|-------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| sustainability-identity.instructions            | Identity, six-phase orchestration, state.json contract, append-only skills-loaded log, session recovery, disclaimer rendering, and out-of-band disclosure refusal for the Sustainability Planner agent.                                                     |
| sustainability-risk-classification.instructions | Sustainability risk classification model — binary/categorical/continuous indicators with tier-up rule for Sustainability Planner.                                                                                                                           |
| sustainability-workload-assessment.instructions | Phase 2 workload assessment contract — discovers capability skills under .github/skills/sustainability/ and populates state.workloadAssessment.                                                                                                             |
| sustainability-standards.instructions           | Phase 3 standards mapping contract — discovers framework skills under .github/skills/sustainability/ and populates state.standardsMapping.activeControls[].                                                                                                 |
| sustainability-gap-analysis.instructions        | Phase 4 gap analysis contract — cross-walks capability covers[] against control automatableBy[] and records SCI inputs with measurementClass.                                                                                                               |
| sustainability-backlog.instructions             | Phase 5 dual-format work item generation with SCI budget skeletons and mandatory footer disclaimer for Sustainability Planner.                                                                                                                              |
| sustainability-handoff.instructions             | Phase 6 review and handoff with active-controls.json, sci-budgets, LICENSING.md and reciprocal handoff recommendations for Sustainability Planner.                                                                                                          |
| disclaimer-language.instructions                | Centralized disclaimer language for AI-assisted planning agents requiring professional review acknowledgment                                                                                                                                                |
| evidence-citation.instructions                  | Canonical evidence-citation row format for FSI-consuming planner agents — uniform `path (Lines start-end)` references across RAI, Security, SSSC, Accessibility, Sustainability, and Requirements planning                                                  |
| hve-core-location.instructions                  | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |
| planner-priority-rules.instructions             | Shared priority derivation rules for HVE Core planner agents — categorical Concern Level model, four-tier priority ladder, tie-break rules, and forbidden numeric-priority constructs                                                                       |

## Skills

| Skill                     | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
|---------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| azure-waf-sustainability  | Azure Well-Architected Framework Sustainability checklist controls for the Sustainability Planner agent                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| capability-inventory      | Workload archetype capability inventory cross-walking sustainability framework controls for the Sustainability Planner agent                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| gsf-principles            | Green Software Foundation Principles of Green Software (8 principles) for the Sustainability Planner agent                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| gsf-sci                   | Green Software Foundation Software Carbon Intensity (SCI) v1.0 specification as machine-readable Framework Skill items for the Sustainability Planner agent - Brought to you by microsoft/hve-core.                                                                                                                                                                                                                                                                                                                                                                                 |
| swd                       | Sustainable Web Design (SWD) v4 estimating-digital-emissions methodology controls for the Sustainability Planner agent                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| wsg                       | W3C Web Sustainability Guidelines (WSG 1.0) success criteria for the Sustainability Planner agent                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| framework-skill-interface | Authoring guide for Framework Skills — the host-agent-neutral packaging format for framework specifications (controls, criteria, principles, capabilities) consumed by HVE Core planners and reviewers. Use when importing a third-party framework (NIST, CIS, OWASP, internal org spec) into a domain skills directory, when extending an existing Framework Skill, or when validating a manifest. Pairs with the Prompt Builder agent and Researcher Subagent — this skill provides the contract; the agents drive the authoring workflow. - Brought to you by microsoft/hve-core |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

