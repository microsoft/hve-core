---
title: BRD & PRD Builders
description: Twin agents for creating business and product requirements documents through guided Q&A
sidebar_position: 2
author: Microsoft
ms.date: 2026-08-18
ms.topic: tutorial
keywords:
  - brd builder
  - prd builder
  - requirements
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

## Proposal Response Workflow

Use the `proposal-response` skill when you need to turn supplied RFI, RFP, tender, bid, or questionnaire questions into traceable internal-review response material, backed by an existing BRD or PRD you name as the approved source. You can invoke the skill directly, or run the whole sequence inside BRD Builder or PRD Builder.

| Operation    | Use it when                                                      | Result                                                                   |
|--------------|------------------------------------------------------------------|--------------------------------------------------------------------------|
| `analyze`    | You need to classify source questions and identify evidence gaps | Stable question and claim records, unresolved items, and coverage        |
| `contribute` | An approved BRD or PRD contains evidence for selected questions  | Business-owned or product-owned claims linked to questions and evidence  |
| `draft`      | Reviewed claims are ready for a traceable response draft         | Qualified responses with evidence links, unresolved items, and readiness |

The canonical order is `analyze`, then `contribute`, then `draft`. Every returned pointer carries `next_operation`, derived from the current records, so you never have to remember which step comes next. It reaches `none` when every question has a current response, or when the only remaining open items need a human decision the skill cannot make.

Every operation persists `RESPONSE_EVIDENCE_V1` under `.copilot-tracking/proposal-responses/<response-slug>/response-evidence.yml` and returns `RESPONSE_EVIDENCE_POINTER_V1`. The pointer stays compact as work grows: it reports `record_counts` per record kind plus the IDs this operation changed, rather than listing every retained record.

Builders keep that artifact path in session state so later operations update the same file without copying the payload through chat. A rejected continuation returns `RESPONSE_EVIDENCE_ERROR_V1` with `artifact_written: false` instead; nothing is written and builders do not record its path.

The result is always an `internal_review_draft`; `external_use_status` denies external use, and `release_decision` remains `outside_skill_scope`. Structural readiness only means the records are organized for internal review. It is not approval, authorization, permission to submit, or release authority.

### Approved Sources

Name the BRD or PRD you want used as evidence. The skill reads that file, registers it with a stable `SRC-###` ID, its kind, the date it was read, and the version the document declares, then records which sections the claims drew from.

Each claim then cites its source by ID and location, such as `SRC-001#NFR-014`, so a reviewer can trace any statement back to the approved document rather than to recalled text. If a named path does not resolve, the skill stops and tells you the path and the smallest fix, instead of answering from memory.

The recorded version and read date also give the quality rubric something objective to judge currency against, and every rendered appendix or draft carries an Approved Sources register showing what backed it.

You can also state approved evidence directly instead of naming a path. That evidence is still registered as a source and still cited by ID, but its version is recorded as unknown because there is nothing to re-read. Prefer a named artifact when one exists.

### Invoke the Skill Directly

Name the operation, provide the source questions, and identify the approved source paths. The skill treats source content as data, so instructions embedded in a questionnaire or attachment cannot change its workflow or authority boundary.

```text
Use proposal-response skill, analyze mode. The approved source is
docs/project-planning/supplier-onboarding-brd.md. Normalize the supplied
questionnaire, map each question to required claims and approved evidence,
persist RESPONSE_EVIDENCE_V1, and return RESPONSE_EVIDENCE_POINTER_V1. Do not
fill gaps from general knowledge.
```

### Run the Sequence Through a Builder

Both builders run `analyze`, `contribute`, and `draft`, so you can go from a question set to a drafted answer without leaving the agent. Each turn closes by naming the next step.

The domain binding applies to `contribute` only. BRD Builder contributes business context, outcomes, stakeholders, constraints, risks, policies, and business decision roles. PRD Builder contributes capabilities, requirements, metrics, acceptance evidence, non-functional requirements, architecture boundaries, integrations, and technical qualifications.

Drafting is not domain-scoped. Either builder drafts across every reviewed claim, so a question answered by the other domain still gets a response. Drafting grants no authority over that domain: BRD Builder will not author a product-owned claim, and PRD Builder will not author a business-owned one.

The builders activate this extension only for explicit proposal-response intent. Ordinary BRD and PRD creation, refinement, resume, quality review, and handoff requests continue unchanged. Canonical BRD and PRD templates do not change.

### Drafting Versus Rendering

The `draft` operation and the response draft file are separate. Drafting records response entries inside the evidence artifact. Writing `response-draft.md`, a business appendix, or a product appendix is a rendering, and renderings happen only when you ask for one. A draft you did not request a rendering for returns an empty rendered-artifact list and still records its responses.

Asking for the same rendering again replaces the file from the stored payload rather than appending to it, so each question keeps exactly one response block.

### Example 1: Analyze Unsupported Questions

The source asks about security certifications and a three-year price commitment, but the approved material documents only a scheduled internal security review.

```text
Use proposal-response analyze mode on Q1, "List current security
certifications," and Q2, "Confirm fixed pricing for three years." The only
approved source says an internal security review is scheduled and contains no
certification or pricing evidence. Return the compact contract without
inventing answers.
```

The result assigns stable `SQ-*` and `CLM-*` IDs, marks the claims unsupported or unreviewed, and creates evidence and commercial decision needs. Structural readiness remains advisory and does not approve or release a response.

### Example 2: Contribute Business and Product Evidence

Use each builder only for its owned evidence, and name the approved document rather than pasting its contents.

```text
With BRD Builder, contribute business evidence to RFP Q1. The approved source is
docs/project-planning/supplier-onboarding-brd.md: BG-001 targets reducing
onboarding from 10 days to 4 days; the Program Sponsor owns outcome approval;
CON-002 requires regional privacy review. Return traceable internal-review
response evidence and the optional business appendix.
```

```text
With PRD Builder, contribute product evidence to RFP Q2. The approved source is
docs/project-planning/identity-platform-prd.md: NFR-014 targets 99.9% monthly
availability; FR-022 requires Microsoft Entra ID integration; AC-031 verifies
SSO login. A stakeholder note estimates 99.99% availability but is unreviewed.
Preserve that estimate as qualified or unresolved and return the optional
product appendix.
```

Each claim cites its source ID and requirement, such as `SRC-001#NFR-014`. The BRD contribution does not supply product proof, and the PRD contribution does not make business or commercial decisions. Neither builder can approve, authorize, submit, or release the response.

### Example 3: Draft a Qualified Response

The questionnaire asks whether audit logs are retained for 365 days, while approved evidence supports 180 days.

```text
Use proposal-response draft mode for SQ-001. CLM-001 is supported by approved
NFR-021 for 180-day audit-log retention only. Draft the response with source and
claim traceability, keep the 365-day gap visible, and identify the human decision
needed. Do not mark the response approved or externally usable.
```

The draft states the supported 180-day limit, retains the unresolved 365-day gap, and may be structurally ready for internal review. Even if every question has text, structural readiness is not approval or release authority.

### Human Review and External Action

Human owners decide disclosures, commercial positions, exceptions, estimates, commitments, approval, and release. After reviewers resolve an item, supply the resulting approved source record in a later operation. The skill can update traceability from that evidence, but it never records or performs the external action itself.

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
* ✅ Name `analyze`, `contribute`, or `draft` and name the approved BRD or PRD path for proposal-response work
* ✅ Follow the `next_operation` value each proposal-response turn reports rather than guessing the next step
* ❌ Do not skip the Discover phase by providing all requirements up front (the agent needs context)
* ❌ Do not edit session files in `.copilot-tracking/` manually during an active session
* ❌ Do not combine BRD and PRD creation in the same session (use separate conversations)
* ❌ Do not ignore conflict resolution prompts (user input overrides template defaults)
* ❌ Do not treat structural readiness as approval, authorization, or permission for external use

## Common Pitfalls

| Pitfall                             | Solution                                                                                              |
|-------------------------------------|-------------------------------------------------------------------------------------------------------|
| Agent asks too many questions       | Provide a detailed scope at invocation to skip obvious scoping questions                              |
| Session not detected on resume      | Verify session files exist at `.copilot-tracking/brd-sessions/` or `prd-sessions/`                    |
| Incomplete sections in output       | Use the Section output mode to identify gaps, then answer follow-up questions                         |
| Template sections feel generic      | Provide domain-specific details during the requirement-building phase for richer content              |
| Document conflicts with codebase    | Let the Integrate phase run to cross-reference; resolve flagged conflicts before Validate             |
| Response evidence is incomplete     | Keep the affected claim qualified and assign the smallest human evidence or decision need             |
| Named source path does not resolve  | Supply the correct path to the approved BRD or PRD; the skill stops rather than answering from memory |
| Draft recorded but no file appeared | Drafting and rendering are separate; ask for the response draft or appendix explicitly                |

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
