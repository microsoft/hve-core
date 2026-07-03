---
title: BRD & PRD Builders
description: Twin agents for creating business and product requirements documents through guided Q&A
sidebar_position: 2
author: Microsoft
ms.date: 2026-06-29
ms.topic: tutorial
---

The BRD Builder and PRD Builder share a common architecture for producing requirements documents through structured question-and-answer sessions. Both are driven by the `requirements-author` skill, which loads each phase's guidance on demand. The BRD Builder runs a three-phase lifecycle focused on business justification, and the PRD Builder runs a seven-phase lifecycle focused on product specifications with measurable requirements.

> [!TIP]
> Use the BRD Builder when capturing business objectives, stakeholder needs, and project justification. Use the PRD Builder when defining product features, acceptance criteria, and measurable requirements.

## Workflows

The two agents follow distinct lifecycles defined by the `requirements-author` skill. Each phase loads its section of that skill before phase work begins.

### BRD Builder: Three-Phase Lifecycle

| Phase    | Description                                                                                     |
|----------|-------------------------------------------------------------------------------------------------|
| Discover | Establish business context, stakeholder scope, and problem framing, then hold the Discover gate |
| Define   | Author testable, traceable requirements and gather quality evidence for the Define gate         |
| Govern   | Finalize, approve, and produce the BRD-to-PRD handoff under supersession lineage                |

### PRD Builder: Seven-Phase Lifecycle

| Phase     | Description                                                              |
|-----------|--------------------------------------------------------------------------|
| Assess    | Decide whether enough context exists to name and create PRD files        |
| Discover  | Establish title, problem, and basic scope through focused questions      |
| Create    | Generate the PRD file and state file once title/context is clear         |
| Build     | Gather detailed functional and non-functional requirements iteratively   |
| Integrate | Incorporate references, documents, and external materials with citations |
| Validate  | Confirm completeness and quality before approval                         |
| Finalize  | Deliver the complete, actionable PRD and emit the completion summary     |

The agents detect existing session files and resume from the last completed phase, supporting pause-and-resume workflows across conversations.

## Shared Features

### Session Persistence

Both agents store session state as JSON files, enabling multi-session workflows:

* BRD sessions: `.copilot-tracking/brd-sessions/`
* PRD sessions: `.copilot-tracking/prd-sessions/`

Session files track phase progress, gathered requirements, and document state. When a new conversation starts, the agent detects existing session files and offers to resume.

### Output Modes

Both agents support output modes for reviewing document content:

| Mode             | Description                         |
|------------------|-------------------------------------|
| `summary`        | Progress update with next questions |
| `section [name]` | Single named section view           |
| `full`           | Complete document rendering         |
| `diff`           | Changes since the last major update |

### Template-Driven Generation

Both agents use templates to structure their output, ensuring consistent section coverage across documents. Both load their canonical templates from the `requirements-author` skill: the BRD Builder uses `.github/skills/project-planning/requirements-author/templates/brd/brd-full.md`, and the PRD Builder uses `.github/skills/project-planning/requirements-author/templates/prd/prd-full.md`.

### Quality Controls

* Emoji refinement checklist for tracking section completion
* Conflict resolution hierarchy: user input > template guidance > agent defaults
* Cross-referencing between gathered requirements and codebase analysis

## Key Differences

| Aspect            | BRD Builder                                               | PRD Builder                                               |
|-------------------|-----------------------------------------------------------|-----------------------------------------------------------|
| Agent file        | `.github/agents/project-planning/brd-builder.agent.md`    | `.github/agents/project-planning/prd-builder.agent.md`    |
| Lifecycle         | Three-phase (Discover, Define, Govern)                    | Seven-phase (Assess through Finalize)                     |
| Template strategy | `requirements-author` skill (`templates/brd/brd-full.md`) | `requirements-author` skill (`templates/prd/prd-full.md`) |
| Focus             | Business justification and stakeholder scope              | Product specifications with measurable requirements       |
| Session directory | `.copilot-tracking/brd-sessions/`                         | `.copilot-tracking/prd-sessions/`                         |

The PRD Builder's longer lifecycle reflects its deeper requirement-building, integration, and validation phases for handling detailed product specifications.

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
Output using the canonical BRD template from `.github/skills/project-planning/requirements-author/templates/brd/brd-full.md`.
Save session state to .copilot-tracking/brd-sessions/ for multi-session work.
```

```text
Resume my BRD session for the inventory management project. I've
completed stakeholder interviews and have new data:
- Warehouse ops team processes 3,000 SKUs daily with 15% error rate
- Current system downtime costs $12K/hour during peak season
- Three vendor proposals are in evaluation
Continue from the Define phase with this evidence.
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
* ✅ Use output modes (`summary`, `section [name]`, `full`, `diff`) to review progress during long sessions
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
| Template sections feel generic   | Provide domain-specific details during the requirement-building phase for richer content  |
| Document conflicts with codebase | Let the Integrate phase run to cross-reference; resolve flagged conflicts before Validate |

## Next Steps

1. Feed your completed BRD or PRD into the [ADR Creator](adr-creation) for architectural decisions
2. See [Project Planning Agents](README.md) for the full agent catalog

> [!TIP]
> Both agents work best when you provide a clear project name at invocation. The agents can derive a working title from context, but explicit scope accelerates the Assess phase.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
