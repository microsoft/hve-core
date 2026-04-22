---
title: "Framework Skills: How HVE Core Loads Any Standard as Data"
description: A technical deep-dive into Framework Skills, the host-agent-neutral packaging format that lets HVE Core planners and reviewers consume any framework specification as machine-readable YAML
author: Microsoft
ms.date: 2026-04-19
ms.topic: conceptual
sidebar_position: 2
keywords:
  - framework skill
  - fsi
  - sssc planner
  - rai planner
  - planner extensibility
  - byof
estimated_reading_time: 10
---

## The problem Framework Skills solve

HVE Core ships several planning agents (the SSSC Planner, the RAI Planner, and a growing set of reviewers) that all need to reason over external specifications.
The SSSC Planner walks NIST SSDF practices, OpenSSF Scorecard checks, S2C2F maturity levels, SLSA tracks, CISA SSCM lifecycle controls, Sigstore controls, SBOM format requirements, and the OpenSSF Best Practices Badge tiers.
The RAI Planner walks NIST AI RMF subcategories. Reviewers walk OWASP Top 10s for web, LLM, MCP, agentic, CI/CD, and infrastructure.

Three observations follow from that list:

1. Every one of those frameworks is essentially a list of items (controls, checks, criteria, principles, capabilities) plus some structure on top.
2. The agents that consume them are independent: SSSC and RAI never share a planning phase, but both want the same "give me the items for this phase" affordance.
3. Users want to bring their own: an internal org standard, a regulator-issued control set, or a tailored revision of a public framework.

Hard-coding each framework into the agent that consumes it would make all three problems worse. Framework Skills solve them by giving every framework the same on-disk shape, validated by the same schema, discovered by the same PowerShell module, and consumed via the same `phaseMap` lookup. Host agents stay generic. Frameworks become data.

## What a Framework Skill looks like on disk

A Framework Skill is a directory under a domain root. The conventional repo location is `.github/skills/<domain>/<framework-id>/`, but the discovery module accepts user-supplied `-AdditionalRoots` so Framework Skills can live in `.copilot-tracking/framework-imports/`, an org-shared path, or a sibling repo.

```text
<root>/<framework-id>/
├── SKILL.md            # Optional: human-facing skill page
├── index.yml           # REQUIRED: manifest validated against framework-skill-manifest.schema.json
└── items/              # Per-item YAML files; one file per id listed in phaseMap
    ├── <id>.yml
    └── ...
```

The directory name SHOULD match the manifest's `framework` field, and both are lower-kebab.

The shape is identical whether the Framework Skill ships in-repo (like [openssf-scorecard](../../.github/skills/security/openssf-scorecard/SKILL.md)) or a user authored it last week against an internal control set.

## The manifest contract

`index.yml` is the only required file. It is validated against `scripts/linting/schemas/framework-skill-manifest.schema.json` (JSON Schema draft-2020-12, `additionalProperties: false`).

| Field       | Required | Notes                                                                                                                                           |
|-------------|----------|-------------------------------------------------------------------------------------------------------------------------------------------------|
| `framework` | yes      | Lower-kebab identifier matching the directory name.                                                                                             |
| `version`   | yes      | Free-form version string: semver, a framework-native revision, or a date.                                                                       |
| `phaseMap`  | yes      | Map of host-defined phase labels to ordered lists of item ids. Phase names are opaque strings owned by the consuming agent.                     |
| `domain`    | no       | Lower-kebab domain label. Inferred from the parent directory when omitted.                                                                      |
| `itemKind`  | no       | Hint describing item file shape (`control`, `criterion`, `principle`, `capability`). Default `control` is a host convention, not a schema rule. |
| `status`    | no       | `draft` or `published` (default `published`). Hosts skip drafts unless explicitly opted in. New imports SHOULD start as `draft`.                |
| `metadata`  | no       | Free-form provenance: `source`, `imported_by`, `imported_at`, `review_required`.                                                                |

A real manifest, for an internal spec drafted by the Prompt Builder agent:

```yaml
framework: my-internal-spec
version: "2026.1"
domain: security
itemKind: control
status: draft
phaseMap:
  standards-mapping:
    - access-control
    - audit-logging
  gap-analysis:
    - access-control
    - audit-logging
metadata:
  source: https://example.com/spec.pdf
  imported_by: prompt-builder
  imported_at: "2026-03-16T12:00:00Z"
  review_required: true
```

### Why phase labels are opaque strings

The schema deliberately does not enumerate phase names. Each consuming host agent declares its own phase vocabulary:

* The **SSSC Planner** uses `assessment`, `standards-mapping`, `gap-analysis`, `backlog`, `handoff`.
* The **RAI Planner** uses its own NIST AI RMF–shaped phases.
* A **reviewer** might use `intake`, `triage`, `report`.

The Framework Skill author chooses keys that match the host that will consume the data. The schema's job is to enforce shape; the host's job is to define meaning. This is the single design choice that lets one Framework Skill format serve every planner and reviewer in the project without a coordination meeting.

### Per-item files stay host-shaped

The shape of `items/<id>.yml` is owned by the host-agent contract for the Framework Skill's `itemKind`, not by the FSI schema. Security `itemKind: control` files validate against `planner-framework-control.schema.json`. A new domain inventing a new `itemKind` adds its own per-item schema under `scripts/linting/schemas/` and wires it into `npm run validate:skills`.

For security controls, three optional fields exist specifically to keep host planners from mis-scoring reasonable equivalents as gaps:

* `equivalentImplementations` names functional equivalents that share the underlying primitives. Detection of any equivalent earns full credit, not partial. Example: a `cosign-sign` control lists `actions/attest-build-provenance` because both produce Sigstore bundles signed by Fulcio with Rekor inclusion proofs.
* `alternativeGroup` marks the control as one member of a mutually substitutable set. Verifying any member scores the unused members `n/a`. Example: `spdx-2.3` and `cyclonedx-1.5` share `alternativeGroup.id: sbom-format`.
* `applicability` declares an axis along which the control may be out of scope. Host planners read `state.projectContext` and score `n/a` when the discriminator matches `naWhen`. Example: CISA `acquire-*` controls declare `naWhen: [self-published-oss]`.

Framework Skill authors omit these fields when a control has no equivalents, no substitutes, and applies universally. They exist because real frameworks overlap, and naive scoring punishes good engineering.

## Discovery

Host agents enumerate Framework Skills through one PowerShell module: `scripts/lib/Modules/FrameworkSkillDiscovery.psm1`.

```powershell
Import-Module ./scripts/lib/Modules/FrameworkSkillDiscovery.psm1

# Built-in Framework Skills only
Get-FrameworkSkill -RepoRoot $PWD -Domain 'security'

# Built-ins plus a user-controlled location
Get-FrameworkSkill -RepoRoot $PWD -Domain 'security' `
    -AdditionalRoots './.copilot-tracking/framework-imports/security'

# Include drafts (typically gated by a host reference flag)
Get-FrameworkSkill -RepoRoot $PWD -Domain 'security' -IncludeDrafts
```

Behavior worth knowing:

* The repo root is searched first, then each `-AdditionalRoots` path in order.
* Duplicate `framework` ids resolve first-seen-wins, so additional roots cannot silently shadow built-ins. To intentionally override a built-in, the host's reference must opt in (for example, the SSSC Planner's `replaceDefaults: true` on a `frameworkRef`).
* `status: draft` Framework Skills are excluded by default. Drafts surface only when the caller passes `-IncludeDrafts`, typically because the host's reference set `frameworkRef.includeDrafts: true`.
* Unparsable manifests are skipped silently. Pair discovery with `Test-FrameworkSkillInterface` when you need diagnostics.

A second helper, `Resolve-FrameworkSkillPhaseItem`, handles the per-phase lookup. Given a discovered Framework Skill and a phase label, it returns one record per item id with `Id`, resolved `Path` (under `items/`), and `Exists`. Missing files surface `Exists = $false` so host agents fail fast instead of silently skipping a control.

## Validation

`Test-FrameworkSkillInterface` validates a single manifest against the schema:

```powershell
Test-FrameworkSkillInterface -RepoRoot $PWD `
    -ManifestPath './.github/skills/security/my-internal-spec/index.yml'
```

It returns `[pscustomobject]@{ Valid = <bool>; Errors = <string[]> }`. `Errors` is an empty array (not `$null`) when `Valid = $true`, so `.Errors.Count` is always safe.

Repo-wide validation runs through the Framework Skill Pester suite under `scripts/tests/linting/` via `npm run test:ps`, which exercises the discovery module against every built-in Framework Skill. The standard `npm run lint:frontmatter` and `npm run validate:skills` checks also fire on every Framework Skill that ships a `SKILL.md`.

## The authoring loop

There is no dedicated importer agent. Authoring runs through the [Prompt Builder](../agents/) agent and the [`framework-skill-interface` skill](../../.github/skills/shared/framework-skill-interface/SKILL.md), which documents the contract. The skill stays passive; Prompt Builder drives the workflow:

1. Prompt Builder dispatches the Researcher Subagent to fetch the source spec and extract item identifiers.
2. The agent writes `index.yml` and per-item YAML under your chosen root, sets `status: draft`, and populates `metadata.source`, `metadata.imported_by`, `metadata.imported_at`, `metadata.review_required: true`.
3. Run `Test-FrameworkSkillInterface`, `npm run lint:frontmatter`, and `npm run validate:skills`.
4. Load the Framework Skill through the consuming agent and confirm items resolve in the relevant phase.
5. After human review, flip `status: draft` to `status: published`. Hosts then surface the Framework Skill without `-IncludeDrafts`.

`status: draft` is the safety boundary between authoring and consumption. AI-assisted imports MUST start as drafts. Hosts that surface drafts to end users SHOULD do so only when the user-supplied reference opts in explicitly.

## Excluding what doesn't apply

Discovery and `applicability` answer "what is available?" and "is this control technically in scope?" Neither answers the more political question every team eventually faces: *"we know this framework exists, we are choosing not to assess against it."* That decision belongs to the host, not the Framework Skill, and the SSSC Planner now models it explicitly.

There are two layers, and they compose:

Framework-Skill-side (`applicability`): a control author can declare an axis along which the control is structurally `n/a`. CISA `acquire-*` controls declare `naWhen: [self-published-oss]`; OSSF Scorecard's `Webhooks` check declares `naWhen: [no-webhooks]`. The Framework Skill decides this once, and every consumer benefits without negotiation. This is unchanged.

Host-side (Framework Applicability Gate): before Phase 3 standards mapping, the SSSC Planner runs a mandatory user gate.
Every framework discovered in Phase 1 must end up either enabled or marked `disabled` with a recorded reason.
State carries the decision on `frameworks[].{disabled, disabledReason, disabledAtPhase}`, and the schema requires `disabledReason` and `disabledAtPhase` whenever `disabled` is true.
The same shape supports per-control opt-outs through `frameworks[<id>].suppressedControls[]`, each entry `{id, reason, suppressedAtPhase}`.
Mid-flight opt-outs are first-class: a user who decides during Phase 4 gap analysis that a framework no longer applies sets `disabledAtPhase: "gap-analysis"` and the agent re-plans accordingly.

The downstream effect is uniform. Disabled frameworks and suppressed controls are skipped by Phase 3 loading, Phase 4 gap analysis, and Phase 5 backlog generation.
Phase 5's exclusion filter is explicit: excluded gaps must not produce work items, must not appear in priority counts, and must not be referenced from any other work item's `Source References`.
The backlog itself is silent about exclusions; the audit trail lives in the Phase 6 handoff under an **Excluded Frameworks and Controls** appendix that records each exclusion with the user-supplied reason and the phase at which it was applied.

This split keeps two concerns from collapsing into each other. Framework Skill authors do not need permission to say "this control is structurally inapplicable to OSS projects"; they encode it once and move on. Hosts do not need to fork Framework Skills or special-case items to honor "we are choosing not to do this here"; they record the decision in state and the rest of the workflow respects it. The Framework Skill stays portable. The host stays accountable.

The pattern generalizes the same way the rest of the contract does. A code review host that adopts Framework Skills gets the same two layers for free: the `mycorp-python-style` Framework Skill's `prefer-pathlib` rule may declare `applicability: { discriminator: language, naWhen: [bicep] }`, while a team that has consciously decided to skip the entire `cross-file` phase on this repo records that as a host-side suppression with a reason: visible in the review report's appendix, never silently dropped.

## Beyond planners: the code review agents

The first hosts to adopt Framework Skills were the SSSC and RAI planners, but the pattern was never security-specific. The [Code Review Standards](../../.github/agents/coding-standards/code-review-standards.agent.md) agent: and the [Code Review Full](../../.github/agents/coding-standards/code-review-full.agent.md) orchestrator that fans out to it alongside [Code Review Functional](../../.github/agents/coding-standards/code-review-functional.agent.md): is the next host where the same shape pays off.

Code Review Standards already operates on the FSI premise without using the discovery module yet. Its system prompt is explicit:

> Every standards-based finding must trace to a loaded skill. Never invent categories or standards.

Today that catalog is a hand-curated set of `.github/skills/coding-standards/` skills (Python foundational, and the language-specific instructions files under `.github/instructions/coding-standards/`). The reviewer language-detects a diff, loads the matching skills, and produces findings that quote the skill it relied on. That's a *skills-as-rulebook* pattern, exactly like SSSC's *frameworks-as-controls* pattern, just without the manifest contract on top.

Reframing the catalog as Framework Skills gives the reviewer the same three properties the planners now enjoy:

* **Phases as review passes.** A code review is a sequence of opaque-string phase labels just like a planning workflow. A natural `phaseMap` for the standards reviewer:

  ```yaml
  framework: mycorp-python-style
  version: "2026.04"
  domain: coding-standards
  itemKind: rule
  status: draft
  phaseMap:
    pre-diff:
      - file-header-required
      - module-docstring-required
    line-by-line:
      - no-broad-except
      - prefer-pathlib
      - typed-public-functions
    cross-file:
      - no-cyclic-imports
      - public-api-stability
  ```

  The reviewer walks `pre-diff` once per file, `line-by-line` against each hunk, and `cross-file` after the per-file pass completes. Phase labels stay opaque to the schema; the reviewer owns their meaning.

* **`itemKind: rule` instead of `control`.** Per-item files describe a rule: rationale, detection pattern, fix template, severity, optional language scope.
  A new `planner-rule.schema.json` (or `reviewer-rule.schema.json`) under `scripts/linting/schemas/` validates the per-item shape; the manifest schema does not change.
  The same `equivalentImplementations` and `alternativeGroup` fields that prevent double-counting in security scoring also prevent double-flagging in code review (one finding when both `prefer-pathlib` and a hypothetical `no-os-path-join` rule fire on the same line).

* **BYOR: Bring Your Own Rulebook.** A team that already maintains a written style guide imports it through Prompt Builder + Researcher Subagent, lands the Framework Skill under `.copilot-tracking/framework-imports/coding-standards/`, smoke-tests it through Code Review Standards, then promotes from `draft` to `published`.
  A regulated team adds the code-review checklist their auditor requires (SOC 2 access-control review items, PCI-DSS code-review pre-checks) as a second Framework Skill, surfaced in the same review pass.
  Neither team forks the agent.

The same applicability primitives that already exist also map cleanly: `applicability.discriminator: language` lets the Python rulebook score itself `n/a` when the diff is Bicep, without a single line of host-side language-detection logic. Today that detection lives in the agent. Under Framework Skills it lives in the Framework Skill, where the rule's author can edit it without touching agent code.

The other code-review-adjacent agents fit the same mold. `dependency-reviewer.agent.md` is one Framework Skill ("dependency hygiene rules") away from the same plug-and-play model. `doc-update-checker.agent.md` is one Framework Skill away from "did the changed code update the doc set this org requires us to maintain." `issue-triage.agent.md` is one Framework Skill away from "the labels, severity rubric, and routing rules my team actually uses."

## Any phased process is a candidate

Step back from security and code review and the FSI pattern reduces to a single observation: **any process HVE Core extends is a phased walk over a list of items, and the items are usually written down somewhere already.** Wherever that is true, a Framework Skill is the cheapest way to get the items into the agent.

A short, non-exhaustive map:

| Process knowledge base            | Likely `itemKind` | Plausible `phaseMap` keys                                 | What this lets a team do                                                                  |
|-----------------------------------|-------------------|-----------------------------------------------------------|-------------------------------------------------------------------------------------------|
| Coding standards rulebook         | `rule`            | `pre-diff`, `line-by-line`, `cross-file`                  | Plug an org or auditor style guide into the standards reviewer.                           |
| Architecture review checklist     | `criterion`       | `intake`, `analysis`, `report`                            | Run the same architecture review the firm already does on every design doc, mechanically. |
| Documentation completeness rubric | `criterion`       | `inventory`, `gap-detection`, `recommendations`           | Plug the team's doc-quality rubric into a doc-coverage agent.                             |
| Backlog-grooming policy           | `policy`          | `intake`, `triage`, `assignment`                          | Make ADO/Jira intake follow the team's actual policy without forking the agent.           |
| Pull-request acceptance checklist | `criterion`       | `pre-review`, `review`, `merge-readiness`                 | Encode the merge gate the team negotiated and have it surface on every PR.                |
| Design-thinking method library    | `method`          | `discover`, `define`, `develop`, `deliver`                | Add a method or override an HVE Core default without changing the coach.                  |
| Compliance evidence catalog       | `evidence-item`   | `collect`, `verify`, `attest`                             | Drive an evidence-collection agent off the audit's own list.                              |
| Onboarding curriculum             | `module`          | `week-1`, `week-2`, `month-1`                             | Plug the team's onboarding plan into a guidance agent that walks new hires through it.    |
| Incident-response runbook         | `step`            | `detect`, `contain`, `eradicate`, `recover`, `postmortem` | Run the team's runbook, not a generic one, when an incident agent is invoked.             |

Three properties make a process a fit:

1. **It walks a finite list of items.** Controls, rules, criteria, methods, steps: the noun changes; the cardinality is bounded.
2. **It runs in named phases.** Even a one-pass workflow is a one-key `phaseMap`. The keys belong to the host.
3. **The list changes faster than the agent does.** Whenever the list moves at the speed of the team and the agent moves at the speed of the project, Framework Skills let the two move independently.

The cost of fit is small. A new domain adds a per-item schema and a host that knows how to consume it. The manifest schema, the discovery module, the validation cmdlet, the draft-quarantine workflow, the BYOF override semantics, and the Prompt Builder + Researcher Subagent authoring loop are all reused as-is.

## What this gets you

The FSI pattern is a small contract: one manifest schema, one discovery module, one validation cmdlet: but it produces three durable properties for HVE Core:

* **New planners cost less.** A future planner adds a new domain root and its own phase vocabulary. It reuses the schema, the discovery module, the validation cmdlet, and the entire authoring loop unchanged.
* **New frameworks cost less.** Importing NIST SSDF and importing an internal control set follow the same workflow, validate against the same schema, and surface through the same cmdlet. The user does not learn a different process for each one.
* **Built-ins and BYOF behave identically.** A user-authored Framework Skill under an additional root is indistinguishable from a shipped Framework Skill to the host agent. The same `phaseMap` resolution runs over both. The same scoring rules apply. The only operational difference is who owns the file.

That last property is the one that matters most. HVE Core's planners are useful in proportion to how well they reflect the standards a team actually has to satisfy. Framework Skills make "the standard we actually have to satisfy" a file the team writes and validates, not a code change the team has to negotiate.

## See also

* [Bring Your Own Framework](../customization/bring-your-own-framework.md): host-neutral how-to.
* [Bring Your Own Framework: Security (SSSC Planner)](../customization/byof-security.md): SSSC quickstart.
* [`framework-skill-interface` skill](../../.github/skills/shared/framework-skill-interface/SKILL.md): authoring contract.
* `scripts/lib/Modules/FrameworkSkillDiscovery.psm1`: the discovery module itself.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
