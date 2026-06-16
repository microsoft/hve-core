---
id: "0005"
title: "Adopt the SSSC Planner agent ecosystem"
description: "Adopt the SSSC Planner as a phase-gated, standards-aware planning ecosystem for HVE-Core and downstream repositories, with thin entry prompts, an orchestration agent, protocol instructions, durable supply chain security knowledge, schema validation, and shared backlog handoff."
author: "HVE Core Team"
ms.date: "2026-06-14"
ms.topic: "reference"
status: "proposed"
proposed_date: "2026-06-14"
deciders:
  - "HVE Core Maintainers"
consulted:
  - "Security Planner maintainers"
  - "HVE-Core agent authors"
  - "Downstream repository security owners"
informed:
  - "HVE-Core users"
  - "extension consumers"
  - "downstream project teams"
effort: "L"
tags:
  - "sssc"
  - "supply-chain-security"
  - "agent-ecosystem"
  - "planning"
  - "governance"
affected_components:
  - ".github/agents/security/sssc-planner.agent.md"
  - ".github/instructions/security/sssc-planner.instructions.md"
  - ".github/prompts/security/sssc-capture.prompt.md"
  - ".github/prompts/security/sssc-from-prd.prompt.md"
  - ".github/prompts/security/sssc-from-brd.prompt.md"
  - ".github/prompts/security/sssc-from-security-plan.prompt.md"
  - ".github/skills/security/supply-chain-security/SKILL.md"
  - "scripts/linting/schemas/sssc-state.schema.json"
  - "docs/planning/brds/sssc-planner-security-brd.md"
  - "docs/prds/sssc-planner.md"
  - "collections/security.collection.yml"
  - "collections/security.collection.md"
supersedes: null
superseded-by: null
related:
  - path: "docs/planning/brds/sssc-planner-security-brd.md"
    relation: "influenced-by"
    note: "Defines the business need for downstream repository supply chain security planning and non-certification boundaries."
  - path: "docs/prds/sssc-planner.md"
    relation: "influenced-by"
    note: "Defines the product scope, entry modes, phase model, downstream context fields, and v4.1 prerelease decisions."
  - path: ".github/skills/security/supply-chain-security/SKILL.md"
    relation: "informational"
    note: "Provides the durable standards and taxonomy knowledge used by the SSSC Planner."
asr_triggers:
  - kind: "security"
    evidence: "Downstream repositories can reuse HVE-Core planning assets to shape their own supply chain controls, so weak planner boundaries can create cascading security risk."
  - kind: "compliance"
    evidence: "The planner references OpenSSF Scorecard, SLSA, Sigstore, SBOM, and related standards without producing certification or audit sign-off."
  - kind: "maintainability"
    evidence: "The ecosystem spans prompts, agent instructions, reusable skills, schemas, collections, and generated handoff artifacts that must evolve coherently."
success_criteria:
  - metric: "SSSC planner entry modes preserve schema-valid state"
    target: "All supported entry modes initialize or continue state with required downstream context fields and phase gate metadata."
    measurement_window: "v4.1 prerelease validation"
    source: "scripts/linting/schemas/sssc-state.schema.json and SSSC prompt review"
  - metric: "SSSC planning outputs retain qualified-review boundaries"
    target: "Planner instructions and generated documentation continue to state that outputs are advisory and not compliance certification."
    measurement_window: "each material planner or documentation update"
    source: ".github/instructions/security/sssc-planner.instructions.md and docs/prds/sssc-planner.md"
  - metric: "Ecosystem distribution remains coherent"
    target: "Agent, prompts, instructions, skill, and collection manifests remain aligned when the SSSC Planner is packaged or updated."
    measurement_window: "each release candidate"
    source: "collections/security.collection.yml and extension/package validation outputs"
decisionMetadata:
  driverToTriggerMap:
    "Repeatable non-certification assessment": "ASR-compliance-non-certification"
    "Standards/orchestration separation": "ASR-maintainability-standards-separation"
    "Thin entry prompts": "ASR-maintainability-thin-entry-prompts"
    "Single protocol surface": "ASR-maintainability-single-protocol"
    "Coherent ecosystem packaging": "ASR-maintainability-coherent-packaging"
    "Explicit repository-local review": "ASR-security-explicit-review"
---

## Context

HVE-Core distributes reusable AI-assisted engineering assets. Downstream teams can use those
assets to assess and improve the software supply chain security posture of their own
repositories. The SSSC Planner is intended to guide that work through a structured planning
experience that is aware of supply chain security standards, explicit about human review, and
bounded by repository-local responsibility.

The planner is not a single prompt. It is an ecosystem made of entry prompts, a specialized chat
agent, phase and state instructions, a durable standards skill, schemas, generated planning
artifacts, shared backlog handoff conventions, and collection packaging. The architecture needs a
clear decision record because changes to one surface can weaken the whole planning experience.

```text
+-------------------------------+       +-------------------------------+
| Downstream repository context  |       | HVE-Core distribution context |
| tech stack, packages, CI,      |       | agents, prompts, skills,      |
| release, compliance targets    |       | instructions, collections     |
+---------------+---------------+       +---------------+---------------+
                |                                       |
                +-------------------+-------------------+
                                    |
                                    v
                     +-----------------------------+
                     | SSSC Planner ecosystem      |
                     | phase-gated advisory        |
                     | supply chain planning       |
                     +---------------+-------------+
                                     |
                                     v
                     +-----------------------------+
                     | Repository-local outcomes   |
                     | assessments, gaps, backlog, |
                     | review and handoff          |
                     +-----------------------------+
```

The associated BRD frames the business need around downstream adoption, local security
accountability, cascading misuse risk, and non-certification boundaries. The PRD refines that into
the SSSC Planner product surface for `v4.1 prerelease`, including four entry modes, six planning
phases, mandatory downstream context fields, advisory quality thresholds, opt-in artifact signing,
and reuse of shared backlog handoff.

## Decision Drivers

* Repeatable non-certification assessment
* Standards/orchestration separation
* Thin entry prompts
* Single protocol surface
* Coherent ecosystem packaging
* Explicit repository-local review

## Considered Options

### Option 1: Keep SSSC as separate prompts only

This option would implement SSSC planning as independent prompts that each contain their own phase
logic, standards summaries, state behavior, and output expectations.

### Option 2: Adopt a dedicated SSSC Planner ecosystem

This option makes the SSSC Planner a coordinated ecosystem. Prompts provide entry points, the agent
owns identity and orchestration, instructions own the phase protocol and state behavior, the skill
owns durable standards knowledge, schemas validate state, and collection manifests distribute the
complete capability.

### Option 3: Fold SSSC into the existing Security Planner

This option would make supply chain security planning a mode inside the broader Security Planner,
sharing one agent identity and one planning protocol.

### Option 4: Use external security tooling as the primary planner

This option would treat tools such as OpenSSF Scorecard, SBOM scanners, and signing tools as the
primary planning interface, with HVE-Core only documenting how to run them.

## Decision Outcome

| Decision driver                         | Option 1 | Option 2 | Option 3 | Option 4 |
|-----------------------------------------|----------|----------|----------|----------|
| Repeatable non-certification assessment | Partial  | Yes      | Partial  | Partial  |
| Standards/orchestration separation      | No       | Yes      | Partial  | No       |
| Thin entry prompts                      | No       | Yes      | No       | No       |
| Single protocol surface                 | No       | Yes      | Partial  | No       |
| Coherent ecosystem packaging            | No       | Yes      | Partial  | No       |
| Explicit repository-local review        | Partial  | Yes      | Partial  | No       |

Chosen option: Option 2, adopt a dedicated SSSC Planner ecosystem.

The SSSC Planner should be adopted as a specialized, phase-gated planning ecosystem for HVE-Core and
downstream repositories. The ecosystem keeps entry, orchestration, protocol, knowledge, validation,
distribution, and handoff responsibilities distinct while preserving a coherent user experience.

```text
+-------------------------------+
| Entry prompts                  |
| capture, from PRD, from BRD,   |
| from Security Planner          |
+---------------+---------------+
                |
                v
+-------------------------------+
| SSSC Planner agent            |
| identity, startup notice,      |
| phase orchestration, skill use |
+---------------+---------------+
                |
                v
+-------------------------------+        +-------------------------------+
| SSSC instructions             |<------>| supply-chain-security skill   |
| state, gates, artifacts,      |        | standards, capabilities,      |
| recovery, review, handoff     |        | taxonomies, priorities        |
+---------------+---------------+        +-------------------------------+
                |
                v
+-------------------------------+        +-------------------------------+
| State schema and validation   |------->| Planning artifacts            |
| entry modes, required context,|        | assessment, mapping, gaps,    |
| gates, notices, decisions     |        | backlog, handoff              |
+---------------+---------------+        +-------------------------------+
                |
                v
+-------------------------------+
| Collection and extension      |
| packaging                     |
+-------------------------------+
```

The ecosystem responsibility boundaries are:

* Entry prompts start capture, PRD-seeded, BRD-seeded, or Security Planner-seeded sessions and
  initialize state.
* SSSC Planner agent provides the user-facing identity, caution notice, phase orchestration, and
  skill-loading contract.
* SSSC instructions govern state, phase gates, artifacts, notices, recovery, cross-planner links, and
  handoff.
* The supply-chain-security skill holds durable standards knowledge, capability inventory, and
  prioritization taxonomy.
* State schema validates entry modes, required context fields, phase gate metadata, and notice
  records.
* Shared backlog handoff shapes ADO and GitHub work item output without prescribing backlog routing.
* Collections package and distribute the complete capability as a coherent unit.

## Consequences

### Positive

* The planner can guide downstream teams through supply chain security assessment without implying
  that HVE-Core certifies their repositories.
* The phase model supports controlled progression from scoping to assessment, mapping, gap analysis,
  backlog generation, and handoff.
* Standards knowledge can be updated in the skill while the agent and instructions stay focused on
  behavior, state, and user interaction.
* The ecosystem can interoperate with BRD, PRD, and Security Planner workflows through explicit entry
  modes and state links.
* Shared backlog handoff avoids creating another issue template dialect for SSSC work.

### Negative

* The ecosystem has more moving parts than a prompt-only approach, so collection and validation drift
  become real maintenance risks.
* Users may still over-trust generated findings unless notices, qualified-review language, and
  advisory ownership posture remain visible.
* The planner can identify gaps and backlog items, but it does not execute remediation or verify that
  downstream repositories have implemented controls.

### Telemetry Strategy

This ADR does not mandate a new production telemetry emitter. The SSSC Planner is a documentation
and chat-customization capability whose evidence should remain in repository-local planning state,
validation logs, generated artifacts, and review records. Future production telemetry, if introduced,
must use the shared telemetry vocabulary and document PII handling before adoption.

### Qualified Review and Non-Certification

SSSC Planner outputs are assistive planning artifacts. They do not constitute architectural approval,
security approval, compliance certification, regulatory sign-off, legal advice, or a substitute for a
qualified supply chain security review. Downstream teams remain accountable for validating findings,
selecting controls, assigning owners, and confirming remediation in their own repositories.

## Confirmation

The decision is confirmed when the `v4.1 prerelease` SSSC Planner ecosystem satisfies these checks:

* All four entry prompts route to the SSSC Planner and initialize schema-valid SSSC state for their
  supported entry modes.
* The SSSC Planner agent requires the `supply-chain-security` skill before standards-based assessment.
* SSSC instructions preserve the six-phase workflow, hard gates for phases 1, 4, and 6, and
  summary-and-advance gates for phases 2, 3, and 5.
* The state schema continues to require downstream context fields for technology stack, package
  managers, CI platform, release strategy, and compliance targets.
* Generated SSSC artifacts retain advisory and qualified-review language.
* Collection and extension validation include the agent, prompts, instructions, skill, and schema
  references needed to distribute the ecosystem.

## Pros and Cons of the Options

### Option 1: Keep SSSC as separate prompts only

* Good, because it has the smallest initial implementation surface.
* Good, because individual prompts are easy to discover and edit.
* Bad, because standards text, phase logic, and state behavior would likely diverge across prompts.
* Bad, because prompt-only planning makes recovery, validation, and cross-planner handoff harder to
  govern.

### Option 2: Adopt a dedicated SSSC Planner ecosystem

* Good, because each artifact type has a clear role and can evolve within its own boundary.
* Good, because it supports downstream repository adoption while preserving explicit human review and
  non-certification boundaries.
* Good, because the same planner can support capture, PRD, BRD, and Security Planner-seeded entry.
* Bad, because the ecosystem requires collection, schema, and documentation alignment whenever the
  planner changes.

### Option 3: Fold SSSC into the existing Security Planner

* Good, because users would have one security planning agent to select.
* Good, because SSSC findings could be presented near broader threat modeling work.
* Bad, because supply chain security has distinct standards, capability taxonomies, and handoff needs
  that would make the broader Security Planner heavier.
* Bad, because SSSC-specific downstream context fields and gates could become less visible.

### Option 4: Use external security tooling as the primary planner

* Good, because existing tools provide concrete repository signals and machine-checkable evidence.
* Good, because teams can continue to use their preferred scanners, scorecards, SBOM tools, and
  signing systems.
* Bad, because tools alone do not produce a structured planning conversation, standards mapping,
  tradeoff record, or backlog handoff.
* Bad, because this approach would not address HVE-Core's need for reusable AI-assisted planning
  assets.

## Operating Model

The adopted operating model keeps the planner advisory and repository-local.

```text
+-------------------+     +-------------------+     +-------------------+
| Phase 1           | --> | Phase 2           | --> | Phase 3           |
| Scope downstream  |     | Assess supply     |     | Map standards     |
| context           |     | chain capabilities|     | and controls      |
| Hard gate         |     | Summary gate      |     | Summary gate      |
+-------------------+     +-------------------+     +-------------------+
          |                         |                         |
          v                         v                         v
+-------------------+     +-------------------+     +-------------------+
| Phase 4           | --> | Phase 5           | --> | Phase 6           |
| Analyze gaps and  |     | Generate backlog  |     | Review and handoff|
| tradeoffs         |     | and priorities    |     | with disclaimers  |
| Hard gate         |     | Summary gate      |     | Hard gate         |
+-------------------+     +-------------------+     +-------------------+
```

The planner may recommend work items, evidence collection, and follow-up review. It does not assign
security ownership automatically, decide compliance status, or replace downstream governance bodies.
For `v4.1 prerelease`, named local security ownership remains advisory rather than a release gate.

## Rollback and Exit Strategy

If the dedicated ecosystem proves too costly to maintain, HVE-Core can deprecate the SSSC Planner
agent while retaining the `supply-chain-security` skill as reference material and moving entry prompts
back to documentation-only guidance. Any rollback must preserve existing planning artifacts and state
files as historical records, and it must avoid reusing allocated ADR IDs.

## Affected Components

* .github/agents/security/sssc-planner.agent.md
* .github/instructions/security/sssc-planner.instructions.md
* .github/prompts/security/sssc-capture.prompt.md
* .github/prompts/security/sssc-from-prd.prompt.md
* .github/prompts/security/sssc-from-brd.prompt.md
* .github/prompts/security/sssc-from-security-plan.prompt.md
* .github/skills/security/supply-chain-security/SKILL.md
* scripts/linting/schemas/sssc-state.schema.json
* docs/planning/brds/sssc-planner-security-brd.md
* docs/prds/sssc-planner.md
* collections/security.collection.yml
* collections/security.collection.md

## More Information

* `docs/planning/brds/sssc-planner-security-brd.md`
* `docs/prds/sssc-planner.md`
* `.github/agents/security/sssc-planner.agent.md`
* `.github/instructions/security/sssc-planner.instructions.md`
* `.github/prompts/security/sssc-capture.prompt.md`
* `.github/prompts/security/sssc-from-prd.prompt.md`
* `.github/prompts/security/sssc-from-brd.prompt.md`
* `.github/prompts/security/sssc-from-security-plan.prompt.md`
* `.github/skills/security/supply-chain-security/SKILL.md`
* `scripts/linting/schemas/sssc-state.schema.json`
* `collections/security.collection.yml`
* `collections/security.collection.md`

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
