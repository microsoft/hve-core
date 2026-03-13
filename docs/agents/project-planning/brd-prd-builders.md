---
title: BRD & PRD Builders
description: Twin agents for creating business and product requirements documents through guided Q&A
sidebar_position: 2
author: Microsoft
ms.date: 2026-03-07
ms.topic: tutorial
---

The BRD Builder and PRD Builder share a common architecture for producing requirements documents through structured question-and-answer sessions. Both agents guide users through seven phases to create comprehensive, template-driven documents. The BRD focuses on business justification and the PRD on product specifications with measurable requirements.

> [!TIP]
> Use the BRD Builder when capturing business objectives, stakeholder needs, and project justification. Use the PRD Builder when defining product features, acceptance criteria, and measurable requirements.

## Shared Workflow

Both agents follow the same 7-phase workflow, with one naming difference at Phase 4:

| Phase | Step           | Description                                                                                                 |
|-------|----------------|-------------------------------------------------------------------------------------------------------------|
| 1     | Assess         | Evaluate existing context, detect prior sessions, determine if enough information exists to proceed         |
| 2     | Discover       | Gather project scope, stakeholder information, and domain context through targeted questions                |
| 3     | Create         | Analyze codebase artifacts and establish the document structure from the template                           |
| 4     | Elicit / Build | Extract detailed requirements through iterative Q&A (BRD: "Elicit Requirements"; PRD: "Build Requirements") |
| 5     | Integrate      | Cross-reference requirements against codebase findings and resolve conflicts                                |
| 6     | Validate       | Review the complete document for consistency, completeness, and alignment                                   |
| 7     | Finalize       | Produce the final document with all sections populated and reviewed                                         |

Each phase builds on the previous one. The agents detect existing session files and resume from the last completed phase, supporting pause-and-resume workflows across conversations.

## Shared Features

### Session Persistence

Both agents store session state as JSON files, enabling multi-session workflows:

* BRD sessions: `.copilot-tracking/brd-sessions/`
* PRD sessions: `.copilot-tracking/prd-sessions/`

Session files track phase progress, gathered requirements, and document state. When a new conversation starts, the agent detects existing session files and offers to resume.

### Output Modes

Both agents support four output modes for reviewing document content:

| Mode    | Description                 |
|---------|-----------------------------|
| Full    | Complete document rendering |
| Delta   | Changes since last output   |
| Section | Single section view         |
| Status  | Phase progress summary      |

### Template-Driven Generation

Both agents use templates to structure their output, ensuring consistent section coverage across documents. The BRD Builder references an external template at `docs/templates/brd-template.md`, while the PRD Builder embeds its template inline within the agent definition.

### Quality Controls

* Emoji refinement checklist for tracking section completion
* Conflict resolution hierarchy: user input > template guidance > agent defaults
* Cross-referencing between gathered requirements and codebase analysis

## Key Differences

| Aspect             | BRD Builder                                            | PRD Builder                                            |
|--------------------|--------------------------------------------------------|--------------------------------------------------------|
| Agent file         | `.github/agents/project-planning/brd-builder.agent.md` | `.github/agents/project-planning/prd-builder.agent.md` |
| File size          | 195 lines                                              | 766 lines                                              |
| Template strategy  | External (`docs/templates/brd-template.md`)            | Inline (embedded in agent)                             |
| Template sections  | 14                                                     | 17                                                     |
| Phase 4 name       | Elicit Requirements                                    | Build Requirements                                     |
| Recovery protocols | Minimal                                                | Extensive                                              |
| Session directory  | `.copilot-tracking/brd-sessions/`                      | `.copilot-tracking/prd-sessions/`                      |

The PRD Builder's larger file size reflects its extensive inline template and detailed recovery protocols for handling interrupted sessions.

## How to Use

> [!TIP]
> Select the agent using the agent picker in the Copilot Chat pane before entering a prompt.

### Option 1: Prompt Shortcut

**BRD Builder:**

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
Output using the BRD template at docs/templates/brd-template.md.
Save session state to .copilot-tracking/brd-sessions/ for multi-session work.
```

```text
Resume my BRD session for the inventory management project. I've
completed stakeholder interviews and have new data:
- Warehouse ops team processes 3,000 SKUs daily with 15% error rate
- Current system downtime costs $12K/hour during peak season
- Three vendor proposals are in evaluation
Continue from the Elicit Requirements phase with this evidence.
```

**PRD Builder:**

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
Acceptance criteria: dashboard load time under 3 seconds for 90th percentile,
data freshness within 15 minutes of source system updates.
```

```text
Resume my PRD session for the notification system. The Discover phase
identified 3 notification channels (push, email, in-app) and I've now
clarified the priority order with stakeholders:
1. In-app alerts (MVP, needed for Q2 launch)
2. Push notifications (Q3 follow-up)
3. Email digests (Q4, low priority)
Continue building requirements with this phased delivery model.
```

### Option 2: Direct Agent

Select the BRD Builder or PRD Builder using the agent picker in the Copilot Chat pane, then describe your requirements:

```text
Create a business requirements document for consolidating
our 3 data platforms (Azure SQL, CosmosDB, and PostgreSQL on AKS) into
a unified data layer. The current architecture is spread across
infra/sql/, infra/cosmos/, and k8s/postgres/.
Scope:
- Business drivers: operational cost reduction and simplified compliance
- Current state analysis across all 3 platforms
- Migration risk assessment for each platform's workload
- ROI projections over 12 and 24 months
- Stakeholder sign-off criteria for go/no-go decision
```

```text
Define product requirements for a self-service analytics
portal replacing the current manual reporting workflow. The BI team
currently spends 20 hours/week generating reports from src/reports/.
Requirements focus:
- User personas: sales managers, operations leads, executive dashboard viewers
- Data sources: Azure Synapse warehouse, Salesforce CRM, Jira project tracking
- Visualization types: KPI cards, trend charts, filterable data tables
- Access control: Azure AD integration with role-based dashboard visibility
- Performance: sub-3-second load for dashboards with up to 1M rows
```

Both agents begin with the Assess phase, checking for existing sessions and evaluating available context before proceeding to questions.

### Option 3: Resume Session

Continue an interrupted session by referencing the project and providing new context:

```text
Resume my BRD for the customer portal migration. Since our
last session I've confirmed the budget allocation ($150K for FY26) and
identified the technical lead for each of the 4 workstreams.
Continue from where we left off in the Integrate phase.
```

The agent detects session files at `.copilot-tracking/brd-sessions/` or `.copilot-tracking/prd-sessions/` and picks up from the last completed phase.

## Example Prompt

```text
Create a PRD for the real-time notification system. The system replaces
the batch email process in src/notifications/batch-sender.py that runs
nightly and generates ~4,000 notifications per cycle.
Target users: enterprise account managers who monitor up to 50 client
accounts and need alerts within 30 seconds of triggering events.
Define requirements for:
- Push notifications via Azure Notification Hubs (iOS, Android, web)
- Email digests aggregated hourly with configurable frequency per user
- In-app alert center with read/unread state and notification preferences
- Event taxonomy: billing alerts, SLA breaches, account status changes
Acceptance criteria:
- Delivery latency under 30 seconds for push and in-app channels
- 99.9% uptime SLA for the notification gateway
- User preference changes take effect within 60 seconds
- Audit trail for all notifications sent (compliance requirement)
Output the PRD with measurable requirements in every section.
```

## Tips

* ✅ Provide a clear project name or scope at invocation to accelerate the Assess phase
* ✅ Answer iterative questions thoroughly; the agent builds sections as information accumulates
* ✅ Use output modes (Full, Delta, Section, Status) to review progress during long sessions
* ✅ Let the agent cross-reference requirements against codebase artifacts for consistency
* ❌ Do not skip the Discover phase by providing all requirements up front (the agent needs context)
* ❌ Do not edit session files in `.copilot-tracking/` manually during an active session
* ❌ Do not combine BRD and PRD creation in the same session (use separate conversations)
* ❌ Do not ignore conflict resolution prompts (user input overrides template defaults)

## Common Pitfalls

| Pitfall                          | Solution                                                                                  |
|----------------------------------|-------------------------------------------------------------------------------------------|
| Agent asks too many questions    | Provide a detailed scope at invocation to skip obvious scoping questions                  |
| Session not detected on resume   | Verify session files exist at `.copilot-tracking/brd-sessions/` or `prd-sessions/`        |
| Incomplete sections in output    | Use the Section output mode to identify gaps, then answer follow-up questions             |
| Template sections feel generic   | Provide domain-specific details during the Elicit/Build phase for richer content          |
| Document conflicts with codebase | Let the Integrate phase run to cross-reference; resolve flagged conflicts before Validate |

## Next Steps

1. Feed your completed BRD or PRD into the [ADR Creation Coach](adr-creation.md) for architectural decisions
2. See [Project Planning Agents](README.md) for the full agent catalog

> [!TIP]
> Both agents work best when you provide a clear project name at invocation. The agents can derive a working title from context, but explicit scope accelerates the Assess phase.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
