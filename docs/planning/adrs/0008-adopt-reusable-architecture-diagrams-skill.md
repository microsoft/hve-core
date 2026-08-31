---
id: "0008"
title: "Adopt a reusable architecture-diagrams skill for IaC-derived diagrams"
description: "Adopt a single reusable architecture-diagrams skill as the shared capability for turning infrastructure-as-code sources into ASCII block diagrams or Mermaid flowcharts, invokable from any HVE-Core agent or chat context with the caller choosing the output format."
author: "HVE Core Maintainers"
ms.date: "2026-06-19"
ms.topic: "reference"
status: "accepted"
proposed_date: "2026-06-17"
accepted_date: "2026-06-18"
deciders:
  - "HVE Core Maintainers"
consulted:
  - "HVE Core Contributors"
  - "HVE-Core agent authors"
informed:
  - "hve-core users"
  - "extension consumers"
effort: "S"
tags:
  - "skill"
  - "architecture"
  - "diagrams"
  - "reuse"
  - "tooling"
affected_components:
  - ".github/skills/hve-core/architecture-diagrams/SKILL.md"
  - ".github/agents/project-planning/adr-creation.agent.md"
  - ".github/agents/project-planning/brd-builder.agent.md"
  - ".github/agents/project-planning/prd-builder.agent.md"
  - ".github/agents/project-planning/network-isa95-planner.agent.md"
  - ".github/agents/project-planning/system-architecture-reviewer.agent.md"
supersedes: null
superseded-by: null
related: []
asr_triggers: []
decisionMetadata:
  driverToTriggerMap:
    "Token optimization": "On-demand skill loading keeps each agent's base context lean."
    "Reuse across agents": "A single shared skill is invoked by every consuming agent instead of duplicating logic."
    "Clean multi-agent integration": "Any agent or chat session invokes the skill without bespoke wiring."
    "Format-agnosticism": "The caller chooses ASCII or Mermaid output; neither is forced as a default."
---

## Context

Multiple HVE-Core agents need to turn infrastructure-as-code sources
(Terraform, Bicep, ARM, shell, Kubernetes, Docker/Compose) into architecture
and network diagrams. Authoring that logic inline inside each agent duplicates
conventions and inflates every agent's base context with diagram instructions
that are only occasionally used. We need a single, format-agnostic capability
that any agent (or a bare chat session) can invoke on demand, where the caller
chooses ASCII or Mermaid output and neither is forced as a default.

The framing for this decision came directly from the requesting session:

> "Let's make a quick ADR for the new Arch Diagram skills based on this work."
>
> Drivers are token optimization plus cross-agent reuse; constraints are clean multi-agent integration plus format-agnosticism.
>
> "look at the other ADRs and mirror them."

## Decision Drivers

* Token optimization
* Reuse across agents
* Clean multi-agent integration
* Format-agnosticism

## Considered Options

* Reusable shared skill (chosen): one `architecture-diagrams` skill loaded on demand and invoked by any agent or chat context.
* Dedicated diagram agent: a standalone agent that owns diagram generation as a conversational workflow.
* Inline per-agent diagram logic: each agent embeds its own diagram instructions and conventions.

## Decision Outcome

We adopt a reusable `architecture-diagrams` skill at [.github/skills/hve-core/architecture-diagrams/SKILL.md](https://github.com/microsoft/hve-core/blob/main/.github/skills/hve-core/architecture-diagrams/SKILL.md) as the shared capability for IaC-derived diagrams.

| Decision driver               | Reusable shared skill | Dedicated diagram agent | Inline per-agent logic |
|-------------------------------|-----------------------|-------------------------|------------------------|
| Token optimization            | Yes                   | Partial                 | No                     |
| Reuse across agents           | Yes                   | Partial                 | No                     |
| Clean multi-agent integration | Yes                   | Partial                 | Partial                |
| Format-agnosticism            | Yes                   | Yes                     | Partial                |

Chosen option: **"Reusable shared skill"**, because it is the only option that
keeps base-context token cost low while making a single diagram capability
reusable across every consuming agent and a bare chat session.

### Y-Statement

In the context of generating architecture and network diagrams from
infrastructure-as-code across multiple HVE-Core agents, facing duplicated
diagram logic and base-context token bloat, we decided for a reusable
architecture-diagrams skill invokable from any agent or chat context and
against a dedicated diagram agent or inline per-agent logic, to achieve
token-efficient on-demand loading, cross-agent reuse, and caller-chosen
ASCII/Mermaid output, accepting that skills cannot drive multi-step interactive
flows and that a shared skill is a single point of change rippling to all
consumers.

### Consequences

* Good, because base-context token cost stays low: diagram instructions load only when a diagram is actually needed.
* Good, because the skill is a single source of truth for diagram conventions, reused across agents.
* Good, because any agent or a bare chat session can invoke the capability without duplicating logic.
* Good, because output format is caller-chosen, keeping the skill flexible across ASCII and Mermaid targets.
* Neutral, because consuming agents must know the skill exists and explicitly invoke it; it is not implicitly applied.
* Bad, because skills cannot orchestrate the multi-step interactive diagram refinement a dedicated agent could.
* Bad, because a shared skill is a single point of change whose edits ripple to all consuming agents.

## Diagram (ASCII)

```text
+-----------------------------+
|     Consuming agents        |
+-----------------------------+
| adr-creation                |
| brd-builder                 |
| prd-builder                 |
| network-isa95-planner       |
| system-architecture-reviewer|
+-----------------------------+
              |
              | read_file + invoke (ASCII or Mermaid, caller-chosen)
              v
+-----------------------------+
| architecture-diagrams skill |
| (.github/skills/hve-core/)  |
+-----------------------------+
              |
              | Discovery -> Parsing -> Relationship mapping -> Generation
              v
+-----------------------------+
|  ASCII block diagram   OR   |
|  Mermaid flowchart          |
+-----------------------------+
```

## Risks and Mitigations

* Risk: a shared skill is a single point of change whose edits ripple to all consuming agents. Mitigation: keep the skill's authoring contract stable and version-controlled, and review changes against all known consumers before merging.
* Risk: skills cannot drive multi-step interactive refinement, so complex diagrams may require manual iteration by the caller. Mitigation: scope the skill to deterministic single-pass generation and let the calling agent own any conversational refinement loop.
* Risk: consuming agents must explicitly invoke the skill, so adoption can
  drift if new agents reimplement diagram logic inline. Mitigation: document the
  skill as the canonical path in agent authoring guidance and reference it from
  the consuming agents.

## Rollback / Exit Strategy

If this decision is reversed, the rollback path is:

1. Remove invocations of the `architecture-diagrams` skill from the consuming agents.
2. Reintroduce diagram logic inline in the agents that still require it, or replace the skill with a dedicated diagram agent.
3. Remove the skill at [.github/skills/hve-core/architecture-diagrams/SKILL.md](https://github.com/microsoft/hve-core/blob/main/.github/skills/hve-core/architecture-diagrams/SKILL.md) once no consumer references it.
4. Document the reversal in a superseding ADR that links back to this one and sets `superseded-by` here.

No data migration is required; removing the skill leaves existing content untouched.

## Affected Components

* .github/skills/hve-core/architecture-diagrams/SKILL.md
* .github/agents/project-planning/adr-creation.agent.md
* .github/agents/project-planning/brd-builder.agent.md
* .github/agents/project-planning/prd-builder.agent.md
* .github/agents/project-planning/network-isa95-planner.agent.md
* .github/agents/project-planning/system-architecture-reviewer.agent.md

## More Information

The skill consumes infrastructure source files and produces either an ASCII
block diagram or a Mermaid flowchart at the caller's choice. The capability
lives at [.github/skills/hve-core/architecture-diagrams/SKILL.md](https://github.com/microsoft/hve-core/blob/main/.github/skills/hve-core/architecture-diagrams/SKILL.md). Current consumers are
[.github/agents/project-planning/adr-creation.agent.md](https://github.com/microsoft/hve-core/blob/main/.github/agents/project-planning/adr-creation.agent.md),
[.github/agents/project-planning/brd-builder.agent.md](https://github.com/microsoft/hve-core/blob/main/.github/agents/project-planning/brd-builder.agent.md),
[.github/agents/project-planning/prd-builder.agent.md](https://github.com/microsoft/hve-core/blob/main/.github/agents/project-planning/prd-builder.agent.md),
[.github/agents/project-planning/network-isa95-planner.agent.md](https://github.com/microsoft/hve-core/blob/main/.github/agents/project-planning/network-isa95-planner.agent.md), and
[.github/agents/project-planning/system-architecture-reviewer.agent.md](https://github.com/microsoft/hve-core/blob/main/.github/agents/project-planning/system-architecture-reviewer.agent.md), each of which reads the
skill on demand and requests its preferred output format. This is an
informational, forward-looking adoption: it establishes the shared skill as the
canonical path for IaC-derived diagrams without requiring migration of existing
content.

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
