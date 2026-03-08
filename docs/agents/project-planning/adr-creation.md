---
title: ADR Creation Coach
description: Socratic coaching agent that guides architecture decision records through structured reasoning
sidebar_position: 3
author: Microsoft
ms.date: 2026-03-07
ms.topic: tutorial
---

The ADR Creation Coach guides users through architecture decision documentation using a Socratic coaching approach. Rather than filling templates directly, the agent asks probing questions, challenges assumptions, and helps users articulate their reasoning before producing a structured architecture decision record.

> [!TIP]
> Use the ADR Creation Coach when you need to evaluate and document a technology choice, design pattern selection, or infrastructure approach. The agent works best when you arrive with a decision topic but haven't fully committed to a solution.

## Coaching Workflow

The agent follows a 4-phase coaching process that progressively builds toward a documented decision:

### Phase 1: Discovery

The agent asks clarifying questions to understand the decision landscape: what problem needs solving, what constraints exist, who the decision affects, and what has already been tried. This phase establishes the scope and stakes of the decision.

### Phase 2: Research

The agent guides evaluation of alternatives through structured comparison. It prompts users to consider trade-offs, risks, and alignment with existing architecture. The agent may research the codebase to surface relevant patterns or dependencies.

### Phase 3: Analysis

The agent helps formulate the decision with supporting rationale. This includes articulating why the chosen option was selected, what alternatives were rejected and why, and what consequences the team accepts.

### Phase 4: Documentation

The agent produces the ADR using the template at `docs/templates/adr-template-solutions.md` (191 lines with bracketed placeholders). The final document follows the naming convention `YYYY-MM-DD-descriptive-topic-v01.md` and is placed in `docs/decisions/`.

## Session Persistence

Working drafts are stored at `.copilot-tracking/adrs/{{topic-name}}-draft.md` during the coaching process. This allows multi-session workflows where users can step away and return to continue reasoning through a decision. The final ADR is written to `docs/decisions/` only after all four phases complete.

## Template Approach

The ADR Creation Coach uses a reference-as-guide approach rather than direct template filling. The template at `docs/templates/adr-template-solutions.md` provides section structure and bracketed placeholders, but the agent populates content from the coaching conversation rather than asking users to fill fields directly.

## Socratic Coaching vs Template Filling

The key distinction of this agent is its coaching philosophy:

| Behavior               | Description                                                                          |
|------------------------|--------------------------------------------------------------------------------------|
| Challenges assumptions | Asks "why" and "what if" rather than accepting initial framing                       |
| Explores trade-offs    | Guides users through multi-dimensional evaluation of options                         |
| Progressive research   | Investigates the codebase during the conversation to ground reasoning in actual code |
| Guided discovery       | Helps users reach their own conclusions rather than prescribing answers              |

This approach produces ADRs with stronger rationale sections because the reasoning is developed through dialogue rather than retrofitted after a decision.

## How to Use

### Option 1: Prompt Shortcut

```text
I need to decide between PostgreSQL and CosmosDB for our event store.
The system currently uses Azure SQL in src/data/repositories/ and
handles ~5,000 events/second with append-only writes.
Evaluate:
- Write throughput and partitioning strategies for event sourcing
- Cost modeling at our current scale and projected 10x growth
- Migration complexity from the existing Azure SQL schema
- Operational overhead (backups, monitoring, failover)
Output the ADR using the template at docs/templates/adr-template-solutions.md.
```

```text
Document our decision to adopt a microservices architecture for the
order processing domain. The monolith is in src/api/ and we've
identified 4 bounded contexts from the domain model.
Focus on:
- Service boundary definitions aligned with bounded contexts
- Inter-service communication patterns (sync REST vs async messaging)
- Data ownership and eventual consistency trade-offs
- Deployment complexity increase vs team autonomy gains
Include rejected alternatives: modular monolith and serverless decomposition.
```

### Option 2: Direct Agent

Start a Copilot Chat session and mention the agent:

```text
@adr-creation Evaluate caching strategies for our API gateway layer.
The gateway in src/gateway/ currently has no caching and handles
2,000 requests/second with 80% read traffic to the product catalog.
Research:
- Redis vs Azure Cache for Redis vs CDN edge caching
- Cache invalidation approaches for our event-driven update model
- Latency and cost impact at current and projected traffic levels
- Consistency guarantees required by downstream consumers
Constraints: must integrate with our existing Azure infrastructure
and support multi-region deployment by Q3.
```

The agent begins with Discovery phase questions before progressing through Research, Analysis, and Documentation.

### Option 3: Resume Session

Reference an existing draft to continue a multi-session ADR:

```text
@adr-creation Resume my ADR draft for the caching strategy decision.
I've gathered the performance benchmarks you requested. Redis
showed 0.3ms p99 latency vs 1.2ms for our current direct DB calls.
Continue from the Analysis phase with this new evidence.
```

The agent detects the draft at `.copilot-tracking/adrs/` and picks up from the last completed phase.

## Example Prompt

```text
I need to evaluate message broker options for our order processing
pipeline. The pipeline currently uses synchronous HTTP calls between
3 services in src/services/ and we're hitting reliability issues
under peak load (order-service, inventory-service, notification-service).
Compare:
- Azure Service Bus (premium tier with partitioned queues)
- RabbitMQ (self-hosted on AKS with quorum queues)
- Apache Kafka (Azure Event Hubs with Kafka protocol)
Evaluation criteria:
- Throughput at 10,000 messages/second with 1KB average payload
- Ordering guarantees for order state transitions
- Dead-letter handling and retry patterns
- Operational cost on our existing Azure infrastructure
- Team familiarity (we currently use Azure Service Bus for notifications)
Output the ADR to docs/decisions/ using the standard template.
Include a comparison matrix in the Alternatives section.
```

## Tips

* ✅ Arrive with a decision topic but remain open to alternatives the agent surfaces
* ✅ Answer coaching questions thoroughly for stronger rationale sections
* ✅ Use the resume option to continue multi-session ADR development
* ✅ Review the draft at `.copilot-tracking/adrs/` before finalizing to `docs/decisions/`
* ❌ Do not skip the Discovery phase by jumping straight to a conclusion
* ❌ Do not provide single-word answers to coaching questions (depth drives quality)
* ❌ Do not expect the agent to make the decision for you (it coaches, not prescribes)
* ❌ Do not edit the draft file manually during an active coaching session

## Common Pitfalls

| Pitfall                                | Solution                                                                     |
|----------------------------------------|------------------------------------------------------------------------------|
| Narrow framing with only two options   | Let the agent suggest additional alternatives during the Research phase      |
| Weak rationale sections in output      | Engage deeply with the "why" questions during the Analysis phase             |
| Decision topic too broad               | Scope to a single decision (e.g., "database choice" not "full architecture") |
| Draft not found on resume              | Verify the topic name matches the file at `.copilot-tracking/adrs/`          |
| Template placeholders remain in output | Re-run Phase 4 with the agent to populate remaining bracketed sections       |

## Next Steps

1. Review your ADR draft and approve it for placement in `docs/decisions/`
2. See [Project Planning Agents](README.md) for the full agent catalog

> [!TIP]
> Run `/clear` before starting a new ADR topic. Each coaching session builds cumulative context, and mixing topics produces unfocused rationale sections.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
