<!-- markdownlint-disable-file -->
# Accessibility

Accessibility planning, surface assessment, conformance mapping, and backlog generation against WCAG, ARIA APG, and cognitive accessibility standards

> [!CAUTION]
> The accessibility agents and instructions in this collection are **assistive tools only**. They do not provide legal, regulatory, or compliance advice and do not replace professional accessibility review boards, WCAG conformance auditors, certified accessibility specialists, legal counsel, or other qualified human reviewers. All AI-generated accessibility artifacts **must** be reviewed and validated by qualified accessibility professionals before use. AI outputs may contain inaccuracies, miss critical conformance gaps, or produce recommendations that are incomplete or inappropriate for your environment.

## Overview

Accessibility planning, surface assessment, conformance mapping, and prioritized backlog generation against WCAG 2.2, ARIA Authoring Practices Guide, and cognitive accessibility standards.

> [!CAUTION]
> The accessibility agents and instructions in this collection are **assistive tools only**. They do not provide legal, regulatory, or compliance advice and do not replace professional accessibility review boards, WCAG conformance auditors, certified accessibility specialists, legal counsel, or other qualified human reviewers. All AI-generated accessibility artifacts **must** be reviewed and validated by qualified accessibility professionals before use. AI outputs may contain inaccuracies, miss critical conformance gaps, or produce recommendations that are incomplete or inappropriate for your environment.

This collection includes agents and instructions for:

- **Accessibility Planning** - Six-phase conversational workflow producing surface assessment, standards mapping, gap analysis, and dual-format backlog handoff
- **WCAG 2.2 Conformance Mapping** - Map active surfaces to applicable Success Criteria with conformance-level scoping (A, AA, AAA)
- **ARIA Pattern Adoption** - Identify custom widget patterns from the ARIA Authoring Practices Guide and emit per-pattern requirements
- **Cognitive Accessibility** - Apply COGA-derived guidance for plain language, predictable navigation, and reduced cognitive load
- **VPAT Skeleton Emission** - Generate VPAT 2.5 skeletons keyed to the active conformance target
- **Active Rules Export** - Emit `active-rules.json` for downstream consumption by UX, PRD, code review, and documentation agents

Supporting subagents included:

- **Accessibility Researcher Subagent** - Research subagent for accessibility-specific evidence gathering across surface inventories, framework manifests, and external WCAG/ARIA references

Framework Skills included (Wave 1):

- **WCAG 2.2** - W3C Web Content Accessibility Guidelines 2.2 Success Criteria as machine-readable per-criterion YAML
- **ARIA APG** - W3C ARIA Authoring Practices Guide patterns and widget conformance criteria
- **Cognitive Accessibility** - COGA-derived cognitive accessibility guidance for plain-language, predictability, and low-friction interaction
- **Capability Inventory: Web** - Web surface capability inventory consumed by the Accessibility Planner during surface assessment, gap analysis, and backlog generation
- **Capability Inventory: Content** - Document and content surface capability inventory consumed by the Accessibility Planner during surface assessment, gap analysis, and backlog generation
- **Framework Skill** - Authoring guide for Framework Skills — host-agent-neutral packaging format for framework specifications

## Install

```bash
copilot plugin install accessibility@hve-core
```

## Agents

| Agent                             | Description                                                                                                                                                                                                                                                                |
|-----------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| accessibility-planner             | Guides users through a six-phase assessment of their product's accessibility posture against WCAG 2.2, ARIA APG, cognitive accessibility, and surface capability inventories, producing a prioritized backlog and consumer-ready active rules and journey overlays.        |
| accessibility-researcher-subagent | Performs live accessibility specification lookups (W3C WCAG 2.2 Understanding/Techniques, W3C ARIA APG, ACT Rules, EN 301 549, Section 508, EAA) and returns structured research findings to the parent Accessibility Planner agent - Brought to you by microsoft/hve-core |

## Instructions

| Instruction                                    | Description                                                                                                                                                                                                                                                 |
|------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| accessibility-identity.instructions            | Identity, six-phase orchestration, state.json contract, skill-loading log, session recovery, and question cadence for the Accessibility Planner agent.                                                                                                      |
| accessibility-risk-classification.instructions | Accessibility risk classification model with binary/categorical indicators, depth tiering, and gate rules consumed by Phase 2 surface assessment.                                                                                                           |
| accessibility-surface-assessment.instructions  | Phase 2 surface assessment contract — discovers capability inventory skills under .github/skills/accessibility/capability-inventory-* and populates state.capabilityInventory.                                                                              |
| accessibility-standards.instructions           | Phase 3 standards mapping contract — discovers framework skills under .github/skills/accessibility/ and reads only the controls scoped to the active phase.                                                                                                 |
| accessibility-gap-analysis.instructions        | Phase 4 gap comparison, adoption categorization, and effort sizing for Accessibility Planner — references framework skills as the comparison source.                                                                                                        |
| accessibility-backlog.instructions             | Phase 5 dual-format work item generation with templates, priority derivation, and VPAT skeleton emission for Accessibility Planner.                                                                                                                         |
| accessibility-handoff.instructions             | Phase 6 review-handoff protocol with active-rules.json export, persona overlays, and dual-format output for Accessibility Planner.                                                                                                                          |
| disclaimer-language.instructions               | Centralized disclaimer language for AI-assisted planning agents requiring professional review acknowledgment                                                                                                                                                |
| evidence-citation.instructions                 | Canonical evidence-citation row format for FSI-consuming planner agents — uniform `path (Lines start-end)` references across RAI, Security, SSSC, Accessibility, Sustainability, and Requirements planning                                                  |
| hve-core-location.instructions                 | Important: hve-core is the repository containing this instruction file; Guidance: if a referenced prompt, instructions, agent, or script is missing in the current directory, fall back to this hve-core location by walking up this file's directory tree. |
| planner-priority-rules.instructions            | Shared priority derivation rules for HVE Core planner agents — categorical Concern Level model, four-tier priority ladder, tie-break rules, and forbidden numeric-priority constructs                                                                       |

## Skills

| Skill                        | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
|------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| wcag-2-2                     | W3C Web Content Accessibility Guidelines 2.2 Framework Skill providing all 87 success criteria across conformance levels A, AA, and AAA as machine-readable per-criterion YAML for the Accessibility Planner agent — Brought to you by microsoft/hve-core.                                                                                                                                                                                                                                                                                                                          |
| aria-apg                     | W3C ARIA Authoring Practices Guide composite-widget patterns Framework Skill providing per-pattern keyboard models, focus-management strategies, role/state/property contracts, and WCAG 2.2 cross-walks as machine-readable per-pattern YAML for the Accessibility Planner agent — Brought to you by microsoft/hve-core.                                                                                                                                                                                                                                                           |
| cognitive-a11y               | Cognitive accessibility Framework Skill packaging W3C COGA, plain-language, and cognitive-load heuristics as machine-readable per-control YAML for the Accessibility Planner agent - Brought to you by microsoft/hve-core.                                                                                                                                                                                                                                                                                                                                                          |
| capability-inventory-web     | Web-surface capability inventory Framework Skill enumerating automated accessibility scanners static analyzers and assistive-tech manual review touchpoints used by the Accessibility Planner agent during web-surface assessment - Brought to you by microsoft/hve-core.                                                                                                                                                                                                                                                                                                           |
| capability-inventory-content | Content capability inventory Framework Skill enumerating prose linters readability metrics and human-review touchpoints used by the Accessibility Planner agent during cognitive-accessibility assessment - Brought to you by microsoft/hve-core.                                                                                                                                                                                                                                                                                                                                   |
| framework-skill-interface    | Authoring guide for Framework Skills — the host-agent-neutral packaging format for framework specifications (controls, criteria, principles, capabilities) consumed by HVE Core planners and reviewers. Use when importing a third-party framework (NIST, CIS, OWASP, internal org spec) into a domain skills directory, when extending an existing Framework Skill, or when validating a manifest. Pairs with the Prompt Builder agent and Researcher Subagent — this skill provides the contract; the agents drive the authoring workflow. - Brought to you by microsoft/hve-core |

---

> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)

