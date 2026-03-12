---
title: Agent Architecture
description: Technical architecture of the RAI Planner agent including state management, instruction file references, interaction model, and session recovery
sidebar_position: 3
sidebar_label: Agent Architecture
keywords:
  - RAI Planner
  - agent architecture
  - state management
  - NIST AI RMF
tags:
  - rai-planning
  - architecture
  - reference
author: Microsoft
ms.date: 2025-07-14
ms.topic: reference
estimated_reading_time: 7
---

## Architecture Diagram

```mermaid
flowchart TD
  subgraph Agent ["RAI Planner Agent"]
    RP["rai-planner.agent.md"]
    RS["Researcher Subagent"]
    RP -->|"delegates framework lookups"| RS
  end

  subgraph State ["Assessment State"]
    SJ["state.json"]
    AF["Phase Artifacts"]
    SJ -->|"references"| AF
  end

  subgraph Instructions ["Instruction Files"]
    I1["rai-identity"]
    I2["rai-standards"]
    I3["rai-sensitive-uses"]
    I4["rai-risk-surface"]
    I5["rai-impact-assessment"]
    I6["rai-backlog-handoff"]
  end

  RP -->|"reads/writes"| SJ
  RP -->|"generates"| AF
  RP -->|"follows"| I1
  RP -->|"follows"| I2
  RP -->|"follows"| I3
  RP -->|"follows"| I4
  RP -->|"follows"| I5
  RP -->|"follows"| I6
```

The RAI Planner agent definition lives at `.github/agents/rai-planning/rai-planner.agent.md`. Six instruction files under `.github/instructions/rai-planning/` provide domain-specific guidance, auto-applied via `applyTo` patterns when working within `.copilot-tracking/rai-plans/`.

| Instruction file                        | Domain                                                                                 |
|-----------------------------------------|----------------------------------------------------------------------------------------|
| `rai-identity.instructions.md`          | Agent identity, orchestration, state management, session recovery                      |
| `rai-standards.instructions.md`         | Microsoft RAI Standard v2, NIST AI RMF subcategories, regulatory cross-references      |
| `rai-sensitive-uses.instructions.md`    | Sensitive uses categories, restricted uses gate, vulnerable populations                |
| `rai-risk-surface.instructions.md`      | AI-specific threat taxonomy, `RAI-T-{CATEGORY}-{NNN}` format, likelihood-impact matrix |
| `rai-impact-assessment.instructions.md` | Control surface evaluation, evidence register, principle tradeoff analysis             |
| `rai-backlog-handoff.instructions.md`   | Dual-format backlog handoff, content sanitization, autonomy tiers                      |

## State Management

All assessment state persists under `.copilot-tracking/rai-plans/{project-slug}/`. The `state.json` file tracks phase progress, entry mode, and assessment metadata.

### State Fields

| Field                       | Type           | Purpose                                                     |
|-----------------------------|----------------|-------------------------------------------------------------|
| `projectSlug`               | string         | Kebab-case project identifier                               |
| `raiPlanFile`               | string         | Path to the RAI plan markdown file                          |
| `currentPhase`              | number         | Current phase (1-6)                                         |
| `entryMode`                 | string         | `capture`, `from-prd`, or `from-security-plan`              |
| `securityPlanRef`           | string or null | Path to security plan state when using `from-security-plan` |
| `assessmentDepth`           | string         | `standard` or `deep` assessment tier                        |
| `sensitiveUsesComplete`     | boolean        | Whether Phase 2 screening is complete                       |
| `sensitiveUsesCategories`   | array          | Identified sensitive uses categories                        |
| `restrictedUsesCleared`     | boolean        | Whether restricted uses gate has been passed                |
| `standardsMapped`           | boolean        | Whether Phase 3 mapping is complete                         |
| `raiRiskSurfaceStarted`     | boolean        | Whether Phase 4 analysis has begun                          |
| `raiThreatCount`            | number         | Running count of identified RAI threats                     |
| `impactAssessmentGenerated` | boolean        | Whether Phase 5 assessment is complete                      |
| `evidenceRegisterComplete`  | boolean        | Whether evidence register is finalized                      |
| `handoffGenerated`          | boolean        | Whether Phase 6 backlog handoff is complete                 |
| `gateResults`               | object         | Phase 2 gate outcomes for sensitive and restricted uses     |
| `scoredDimensions`          | object         | Phase 6 scorecard: five dimensions, total, and outcome      |
| `referencesProcessed`       | array          | Files that have been read and incorporated                  |
| `nextActions`               | array          | Pending action items for the current phase                  |
| `userPreferences`           | object         | User-specified preferences for interaction and output       |

### Six-Step State Protocol

Every conversation turn follows this protocol:

| Step | Action    | Description                                                   |
|------|-----------|---------------------------------------------------------------|
| 1    | READ      | Load `state.json` at conversation start                       |
| 2    | VALIDATE  | Confirm state integrity and check for missing fields          |
| 3    | DETERMINE | Identify current phase and next actions from state            |
| 4    | EXECUTE   | Perform phase work (questions, analysis, artifact generation) |
| 5    | UPDATE    | Update `state.json` with results                              |
| 6    | WRITE     | Persist updated `state.json` to disk                          |

## Interaction Model

The agent asks up to 7 focused questions per turn, using emoji checklists to track progress within each phase.

| Marker | Meaning                                            |
|--------|----------------------------------------------------|
| ❓      | Pending: question not yet answered                 |
| ✅      | Complete: answer received and recorded             |
| ❌      | Blocked or skipped: user indicated "skip" or "n/a" |

Each turn begins by showing the current phase checklist status. When all questions for a phase reach ✅ or ❌, the agent summarizes findings and asks for explicit confirmation before advancing.

> [!NOTE]
> The agent never advances to the next phase without user confirmation. This ensures the user maintains control over assessment pacing and can revisit questions before moving forward.

## Session Resume Protocol

When returning to an existing RAI assessment, the agent follows a four-step resume protocol:

1. Read `state.json` from the project slug directory
2. Display current phase progress and checklist status
3. Summarize what was completed and what remains
4. Continue from the last incomplete action

### Post-Summarization Recovery

When conversation context is compacted, a five-step recovery process reconstructs state:

1. Read `state.json` for project slug and current phase
2. Read the RAI plan markdown file referenced in `raiPlanFile`
3. Reconstruct context from existing artifacts (system definition pack, sensitive uses screening, standards mapping, risk surface addendum, control surface catalog)
4. Identify the next incomplete task within the current phase
5. Resume with a brief summary of recovered state and the next action

## Operational Constraints

* All files are created under `.copilot-tracking/rai-plans/{project-slug}/`
* The agent never modifies application source code
* Embedded standards (Microsoft RAI Standard v2, NIST AI RMF 1.0) are referenced from the rai-standards instruction file
* Additional framework lookups (WAF, CAF, ISO 42001, EU AI Act details) are delegated to the Researcher Subagent
* In `from-security-plan` mode, security plan artifacts are read-only

## Related Files

| File                                                                 | Purpose                           |
|----------------------------------------------------------------------|-----------------------------------|
| `.github/agents/rai-planning/rai-planner.agent.md`                   | Agent definition                  |
| `.github/instructions/rai-planning/*.instructions.md`                | Phase-specific instruction files  |
| `.github/prompts/rai-planning/rai-capture.prompt.md`                 | Capture mode entry prompt         |
| `.github/prompts/rai-planning/rai-plan-from-prd.prompt.md`           | PRD-seeded entry prompt           |
| `.github/prompts/rai-planning/rai-plan-from-security-plan.prompt.md` | Security plan-seeded entry prompt |
| `.copilot-tracking/rai-plans/{project-slug}/state.json`              | Assessment state                  |

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
