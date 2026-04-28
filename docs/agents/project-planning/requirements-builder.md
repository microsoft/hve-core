---
title: Requirements Builder
description: Unified six-phase agent for authoring PRDs, BRDs, and future requirements documents through Framework Skill Interface (FSI) document frameworks
sidebar_position: 2
author: Microsoft
ms.date: 2026-04-23
ms.topic: tutorial
---

The Requirements Builder is a single, unified agent for producing requirements documents (PRDs, BRDs, and future MRDs, FRDs, SRSs). It replaces the legacy `prd-builder` and `brd-builder` agents with a six-phase pipeline backed by [Framework Skill Interface (FSI)](../../announcements/framework-skill-interfaces.md) document frameworks. Each document style is a discoverable framework skill under `.github/skills/requirements/` rather than a hard-coded template baked into the agent.

> [!TIP]
> Use the Requirements Builder for any requirements artifact: PRDs, BRDs, or both in the same session. Pick document styles from the framework multi-select at the start; the agent loads only what you select.

## When to Use

* PRD: defining product features, user-facing behavior, acceptance criteria, and measurable requirements. Output: `docs/prds/<slug>.md`.
* BRD: capturing business justification, sponsor and stakeholder needs, ROI, and traceable business requirements (BR-IDs). Output: `docs/brds/<slug>-brd.md`.
* Both: author a BRD and PRD together in one session; select both frameworks at the gate and the agent drafts each in its own output path.

## Six-Phase Pipeline

| # | Phase              | Purpose                                                                                                                |
|---|--------------------|------------------------------------------------------------------------------------------------------------------------|
| 1 | Identity           | Render the Requirements Planning disclaimer; capture the project slug; run `Get-FrameworkSkill -Domain requirements`.  |
| 2 | Intake             | Conduct ≤5-question turns to capture stakeholders, evidence, scope, and entry-mode pre-population.                     |
| 3 | Template Selection | Select sections per framework using the framework's `phaseMap` and depth tiers; record opt-outs as `disabled` entries. |
| 4 | Drafting           | Generate the document body per framework into the working draft with token resolution and provenance tracking.         |
| 5 | Review             | Surface gaps, evidence completeness, and applicability mismatches; iterate until the user confirms readiness.          |
| 6 | Handoff            | Emit `active-requirements.json`, coverage disclosure, and a conditional downstream-recommendations table.              |

Each phase delegates to a dedicated `requirements-*.instructions.md` file under `.github/instructions/project-planning/`. Phase advancement requires explicit user confirmation or satisfied gating criteria.

## Framework Skills

Document styles are independent FSI framework skills discovered at runtime. v1 ships:

| Framework ID       | Document | Output path               | Audience                | Depth tiers           |
|--------------------|----------|---------------------------|-------------------------|-----------------------|
| `requirements-prd` | PRD      | `docs/prds/<slug>.md`     | Product, engineering    | light, standard, deep |
| `requirements-brd` | BRD      | `docs/brds/<slug>-brd.md` | Business, sponsor, exec | standard, deep        |

New document styles (MRD, FRD, SRS, internal templates) plug in by adding a new `.github/skills/requirements/<framework-id>/` package. No agent change required. See [Authoring Framework Skills with Prompt Builder](../../customization/authoring-framework-skills.md).

> [!NOTE]
> When you attach a custom template (markdown, docx, pptx) and ask the agent to use it, the builder recommends promoting it to a first-class FSI framework skill. For one-shot use, the template is accepted as `provenance: user-supplied-template, unmanaged` and clearly marked in the draft.

## Entry Modes

| Mode                      | Trigger                                                  | Pre-population                                                         |
|---------------------------|----------------------------------------------------------|------------------------------------------------------------------------|
| `ad-hoc`                  | Direct invocation                                        | Empty intake; conduct interview from scratch                           |
| `meeting-handoff`         | Meeting Analyst writes `intake/from-meeting-analyst.yml` | Read meeting payload; pre-populate evidence; confirm with user         |
| `product-manager-advisor` | Product Manager Advisor handoff                          | Inherit advisor's framework recommendation as the default multi-select |

All modes converge at the framework gate in Phase 1.

## Session Persistence

All state lives under `.copilot-tracking/requirements-sessions/{slug}/`:

```text
.copilot-tracking/requirements-sessions/{slug}/
├── state.json                    # validated against requirements-state.schema.json
├── skills-loaded.log             # append-only audit: skillId, version, sha256, phase
├── compaction-log.md             # written before/after every /compact
├── intake/
│   ├── stakeholders.yml
│   ├── evidence.yml
│   └── from-meeting-analyst.yml  # optional
├── drafts/                       # working copies; finals land at docs/prds/ or docs/brds/
└── handoff/
    ├── active-requirements.json
    ├── coverage-disclosure.md
    └── downstream-recommendations.md
```

Legacy `.copilot-tracking/prd-sessions/` and `.copilot-tracking/brd-sessions/` directories are **read-only**. The builder may surface their content as evidence during intake, but new sessions write only under `requirements-sessions/`.

## How to Use

> [!TIP]
> Select **Requirements Builder** using the agent picker in the Copilot Chat pane before entering a prompt.

### Single document - PRD

```text
Create a PRD for the self-service analytics dashboard. Target users are
regional sales managers who currently rely on weekly email reports from
the BI team. The existing data pipeline is in src/etl/ and writes to
Azure Synapse.
Define requirements for:
- Real-time revenue and pipeline metrics with 15-minute refresh
- Drill-down from region to territory to individual rep performance
- Export to PDF and Excel for quarterly business reviews
- Role-based access: managers see their region, directors see all regions
Acceptance criteria: dashboard load time under 3 seconds at the 90th
percentile, data freshness within 15 minutes of source updates.
```

At the framework gate, select `requirements-prd`.

### Single document - BRD

```text
Create a BRD for migrating our authentication service from ADAL to MSAL.
The current auth implementation is in src/auth/ and serves 12 internal
applications with ~8,000 daily active users.
Scope:
- Business justification for the migration (ADAL end-of-support timeline)
- Stakeholder impact across the 12 consuming applications
- Cost analysis: migration effort vs ongoing vulnerability risk
- Compliance requirements (SOC 2, FedRAMP) affected by the transition
- Success metrics: zero-downtime migration, no auth regression in any app
```

At the framework gate, select `requirements-brd`.

### Both documents in one session

```text
Author both a BRD and a PRD for the customer notification platform.
The BRD should cover sponsor justification, ROI vs the current batch
email pipeline, and stakeholder impact across the 4 consuming product
teams. The PRD should define push, email, and in-app channels with
sub-30-second delivery SLAs and per-user preference management.
```

At the framework gate, select **both** `requirements-brd` and `requirements-prd`. The agent drafts each into its own output path with shared intake evidence.

### Resume a session

```text
Resume my requirements session for the inventory management project.
I have new evidence: warehouse ops processes 3,000 SKUs daily with
15% error rate, and current downtime costs $12K/hour at peak season.
Continue from where we left off.
```

The agent reads `compaction-log.md` (when present), then `state.json`, and resumes at `meta.currentPhase` without re-prompting answered questions.

## Handoff Catalog

After Phase 6, the agent recommends downstream planners conditional on which frameworks were active and what the drafts cover:

| Target                 | When recommended                                | Slash command              |
|------------------------|-------------------------------------------------|----------------------------|
| RAI Planner            | AI/ML in scope                                  | `/rai-plan-from-prd`       |
| Security Planner       | Sensitive data, authn/authz, or untrusted input | `/security-plan-from-prd`  |
| SSSC Planner           | Any shippable software supply chain             | `/sssc-from-prd`           |
| Sustainability Planner | Workload energy, carbon, or SCI in scope        | `/sustainability-from-prd` |
| Accessibility Planner  | User-facing surface (UI, docs, voice)           | `/accessibility-capture`   |
| ADO PRD to WIT         | Materialize the PRD as Azure DevOps work items  | `/ado-prd-to-wit`          |
| Jira PRD to WIT        | Materialize the PRD as Jira issues              | `/jira-prd-to-wit`         |

Conditional logic and exact wording live in `requirements-handoff.instructions.md`.

## Tips

* ✅ Provide a clear project name or scope at invocation to accelerate Phase 1.
* ✅ Select all relevant frameworks at the gate; switching mid-session requires re-running template selection.
* ✅ Answer ≤5-question turns thoroughly; the agent uses ❓ pending, ✅ complete, ❌ blocked or skipped markers.
* ✅ Let the review phase surface gaps before signing off; coverage disclosure is part of the handoff.
* ❌ Do not edit `state.json` or `skills-loaded.log` manually during an active session.
* ❌ Do not skip the framework gate by pre-stating "I want a PRD"; the multi-select records opt-outs and provenance.
* ❌ Do not bypass the disclaimer; it is sha256-pinned in `meta.disclaimerVersion` and re-rendered on change.

## Common Pitfalls

| Pitfall                                      | Solution                                                                                     |
|----------------------------------------------|----------------------------------------------------------------------------------------------|
| Custom template not behaving as a framework  | Promote the template to an FSI framework skill via Prompt Builder; one-shot use is unmanaged |
| Legacy `prd-sessions/` work appears stalled  | Open Requirements Builder with the slug; legacy state is read-only and migrates forward      |
| Framework gate feels like too many questions | All frameworks are presented as a single multi-select with safe defaults pre-checked         |
| Disclaimer re-renders unexpectedly           | The shared disclaimer's sha256 changed; this is intentional and recorded in `state.json`     |
| Downstream planner recommendation missing    | Confirm the relevant scope was captured in `intake/evidence.yml` (e.g., AI/ML, user-facing)  |

## Migration from BRD Builder and PRD Builder

The legacy `brd-builder` and `prd-builder` agents are **deprecated** and now stub-redirect to Requirements Builder. Existing session directories under `.copilot-tracking/prd-sessions/` and `.copilot-tracking/brd-sessions/` remain readable; new sessions write under `.copilot-tracking/requirements-sessions/{slug}/`. Final output paths (`docs/prds/<slug>.md`, `docs/brds/<slug>-brd.md`) are unchanged, so all downstream prompts continue to work.

## Next Steps

1. Hand off to the [ADR Creation Coach](adr-creation.md) for architecture decisions derived from the PRD.
2. Run the [Security Planner](../security/README.md) once architecture stabilizes.
3. See [Project Planning Agents](README.md) for the full agent catalog.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
