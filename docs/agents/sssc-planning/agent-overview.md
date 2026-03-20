---
title: Agent Overview
description: Architecture, state management, and operational details for the SSSC Planner agent
sidebar_position: 3
sidebar_label: Agent Overview
keywords:
  - sssc planner
  - agent architecture
  - state management
tags:
  - agents
  - security
author: Microsoft
ms.date: 2026-03-18
ms.topic: reference
estimated_reading_time: 7
---

The SSSC Planner is a phase-based conversational agent that produces supply chain security assessments, standards mappings, gap analyses, and backlog handoff artifacts. It inventories capabilities across hve-core and physical-ai-toolchain, maps them to OpenSSF standards, and generates improvement projections.

## Architecture

```mermaid
flowchart TD
  subgraph Agent
    SP["SSSC Planner"]
    RS["Researcher Subagent"]
  end

  subgraph State
    SJ["state.json"]
    PF["Plan Files"]
  end

  subgraph Instructions
    I1["sssc-identity"]
    I2["sssc-assessment"]
    I3["sssc-standards"]
    I4["sssc-gap-analysis"]
    I5["sssc-backlog"]
    I6["sssc-handoff"]
  end

  SP -->|"delegates"| RS
  SP -->|"reads/writes"| SJ
  SP -->|"generates"| PF
  SP -->|"follows"| I1 & I2 & I3 & I4 & I5 & I6
```

The agent follows six SSSC-specific instruction files, each scoped to a specific phase concern. It also references five shared instruction files from the Security Planning collection (identity, operational-buckets, standards-mapping, backlog-handoff, security-model) for cross-cutting patterns.

## State Management

All state lives in `.copilot-tracking/sssc-plans/{project-slug}/state.json`. The agent follows a six-step protocol on every turn:

| Step      | Action                                                                 |
|-----------|------------------------------------------------------------------------|
| READ      | Load the current state file                                            |
| VALIDATE  | Confirm the state schema is intact and the current phase is consistent |
| DETERMINE | Decide which phase and step to execute based on state and user input   |
| EXECUTE   | Perform the phase work (questions, analysis, artifact generation)      |
| UPDATE    | Modify the in-memory state to reflect completed work                   |
| WRITE     | Persist the updated state back to the file                             |

### State Fields

The state file tracks 17 fields across scoping, analysis, and handoff concerns.

| Field                       | Type     | Description                                                |
|-----------------------------|----------|------------------------------------------------------------|
| `projectSlug`               | string   | Kebab-case project identifier                              |
| `ssscPlanFile`              | string   | Path to the main SSSC plan markdown file                   |
| `currentPhase`              | number   | Current phase (1-6)                                        |
| `entryMode`                 | string   | `capture`, `from-prd`, `from-brd`, or `from-security-plan` |
| `scopingComplete`           | boolean  | Whether Phase 1 scoping has been completed                 |
| `assessmentComplete`        | boolean  | Whether Phase 2 capability inventory is complete           |
| `standardsMapped`           | boolean  | Whether Phase 3 standards mapping is complete              |
| `gapAnalysisComplete`       | boolean  | Whether Phase 4 gap analysis is complete                   |
| `backlogGenerated`          | boolean  | Whether Phase 5 backlog generation is complete             |
| `handoffGenerated`          | object   | `{ado: boolean, github: boolean}`                          |
| `context.techStack`         | string[] | Target repository technology stack                         |
| `context.packageManagers`   | string[] | Package managers in use                                    |
| `context.ciPlatform`        | string   | CI/CD platform (GitHub Actions, Azure Pipelines, etc.)     |
| `context.releaseStrategy`   | string   | Release strategy (tags, branches, etc.)                    |
| `context.complianceTargets` | string[] | Compliance frameworks being targeted                       |
| `referencesProcessed`       | string[] | Paths to PRD/BRD/security-plan artifacts consumed          |
| `nextActions`               | string[] | Pending actions for the current or next phase              |
| `userPreferences`           | object   | Autonomy preference: `full`, `partial`, or `manual`        |
| `ssscEnabled`               | boolean  | Whether SSSC planning is active                            |
| `securityPlannerLink`       | string   | Path to the upstream Security Planner state file           |
| `raiPlannerLink`            | string   | Path to an associated RAI Planner state file               |

## Interaction Model

The agent follows strict question rules during each phase:

| Guardrail                             | Description                                                                                        |
|---------------------------------------|----------------------------------------------------------------------------------------------------|
| 3-5 questions per turn                | Enough to make progress without overwhelming the user                                              |
| Emoji checklists                      | Questions use ❓ for pending, ✅ for answered, and ❌ for blocked items                               |
| No phase advance without confirmation | The agent summarizes phase findings and asks for explicit approval before moving to the next phase |

## Session Resume

When a conversation resumes from a prior session, the agent follows a four-step recovery protocol:

1. Read the state file from `.copilot-tracking/sssc-plans/{project-slug}/`.
2. Validate that the state schema matches the expected version.
3. Present a summary of completed phases and pending work.
4. Continue from the current phase without re-asking answered questions.

A five-step post-summarization recovery handles cases where conversation context was compacted by the chat system.

## Operational Constraints

* All generated files are placed under `.copilot-tracking/sssc-plans/{project-slug}/`.
* The agent never modifies source code or files outside its tracking directory.
* The Researcher Subagent is dispatched for WAF/CAF runtime lookups when cloud-hosted components are in scope.
* Cross-agent links (`securityPlannerLink`, `raiPlannerLink`) are populated but the agent does not force handoff to other agents.

## Related Files

| File type    | Location                                                 |
|--------------|----------------------------------------------------------|
| Agent        | `.github/agents/security-planning/sssc-planner.agent.md` |
| Prompts      | `.github/prompts/security-planning/sssc-*.prompt.md`     |
| Instructions | `.github/instructions/sssc-planning/`                    |
| State        | `.copilot-tracking/sssc-plans/{project-slug}/state.json` |

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
