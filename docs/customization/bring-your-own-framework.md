---
title: Bring Your Own Framework
description: Package any framework specification (controls, criteria, principles, capabilities) as a Framework Skill that HVE Core host agents can discover and consume
author: Microsoft
ms.date: 2026-04-19
ms.topic: how-to
keywords:
  - framework skill
  - fsb
  - byof
  - custom framework
  - planner extensibility
estimated_reading_time: 8
---

## What a Framework Skill Is

A Framework Skill packages a single framework specification: a set of controls, criteria, principles, or capabilities: as machine-readable YAML that any HVE Core host agent can enumerate and consume. The pattern is host-neutral: the same Framework Skill shape serves planners (SSSC, RAI), reviewers, importers, or any future agent that needs structured framework data.

Use a Framework Skill when you need to:

* Import a published framework (NIST SP 800-218, CIS Benchmarks, OWASP Top 10, an internal org standard) into a host agent.
* Replace or extend a built-in framework with an org-specific revision.
* Stage a draft framework for review before promoting it to production.

For domain-specific quickstarts, see:

* [Bring Your Own Framework: Security (SSSC Planner)](byof-security.md)

## Framework Skill Layout

Framework Skills live under a domain root. The conventional repo location is `.github/skills/<domain>/<framework-id>/`, but host agents that accept `-AdditionalRoots` (see [Discovery](#discovery)) can load Framework Skills from any directory you control: org-shared paths, `.copilot-tracking/framework-imports/`, a sibling repo.

```text
<root>/<framework-id>/
├── SKILL.md            # Optional: human-facing skill page (recommended for built-ins)
├── index.yml           # REQUIRED: manifest validated against framework-skill-manifest.schema.json
└── items/              # Per-item YAML files; one file per id listed in phaseMap
    ├── <id>.yml
    └── ...
```

`controls/<id>.yml` is accepted as a back-compat alias for `items/<id>.yml`. New Framework Skills should use `items/`. `<framework-id>` and `<domain>` are lower-kebab; `domain` is inferred from the parent directory when omitted from the manifest.

## Manifest Contract

`index.yml` is validated by `scripts/linting/schemas/framework-skill-manifest.schema.json` (draft-2020-12, `additionalProperties: false`).

| Field       | Required | Notes                                                                                                                              |
|-------------|----------|------------------------------------------------------------------------------------------------------------------------------------|
| `framework` | yes      | Lower-kebab identifier matching the directory name.                                                                                |
| `version`   | yes      | Free-form version string (semver, framework-native revision, date).                                                                |
| `phaseMap`  | yes      | Map of host-defined phase labels → ordered list of item ids. Phase names are opaque strings owned by the consuming agent.          |
| `domain`    | no       | Lower-kebab domain label. Inferred from parent directory when omitted.                                                             |
| `itemKind`  | no       | Hint describing item file shape (`control`, `criterion`, `principle`, `capability`, etc.). Default `control` is a host convention. |
| `status`    | no       | `draft` or `published` (default `published`). Hosts skip drafts unless explicitly opted in. New imports SHOULD start as `draft`.   |
| `metadata`  | no       | Free-form provenance (`source`, `imported_by`, `imported_at`, `review_required`).                                                  |

Phase labels in `phaseMap` are owned by the consuming host agent. The schema does not enumerate them: each host (SSSC, RAI, a reviewer) declares its accepted phase labels in its identity instructions.

## Authoring Workflow

Drive authoring through the [Prompt Builder](../agents/) agent and the `framework-skill-interface` skill at `.github/skills/shared/framework-skill-interface/SKILL.md`. The skill documents the contract; Prompt Builder orchestrates research (via the Researcher Subagent), drafting, evaluation, and validation.

Typical flow:

1. Ask Prompt Builder to import the framework: provide source URL, target domain, and (if known) the host agent's expected phase labels.
2. Researcher Subagent retrieves and structures the framework's items.
3. Prompt Builder writes `index.yml` and `items/<id>.yml` files. New imports start with `status: draft`.
4. Validate: `npm run lint:frontmatter`, `npm run validate:skills`.
5. Smoke-test discovery against the host agent (see [Discovery](#discovery)).
6. Promote `status: draft` → `status: published` after review.

## Discovery

Host agents discover Framework Skills via the `Get-FrameworkSkill` cmdlet in `scripts/lib/Modules/FrameworkSkillDiscovery.psm1`:

```powershell
Import-Module ./scripts/lib/Modules/FrameworkSkillDiscovery.psm1
Get-FrameworkSkill -Domain security
Get-FrameworkSkill -Domain security -AdditionalRoots @('/srv/org-frameworks', '.copilot-tracking/framework-imports')
Get-FrameworkSkill -Domain security -IncludeDrafts
```

Behavior:

* Built-in `.github/skills/<domain>/` is searched first, then each path in `-AdditionalRoots` in order.
* Duplicate framework ids resolve on a first-seen-wins basis, so built-ins shadow externals unless you reorder roots.
* `status: draft` Framework Skills are excluded by default. Pass `-IncludeDrafts` (or set `frameworkRef.includeDrafts: true` in host state) to load them.
* Unparsable manifests are skipped silently; run `Test-FrameworkSkillInterface <path>` to surface errors.

## Replacing Built-In Frameworks

To override a shipped Framework Skill (e.g. a custom org revision of `nist-ssdf`):

1. Author the replacement Framework Skill under an additional root with the same `framework` id.
2. Reorder discovery so your root precedes the built-in: pass `-AdditionalRoots` first OR set `replaceDefaults: true` in the host's `frameworkRef` to drop built-ins for that id.
3. Validate via the host agent's planning artifact (e.g. SSSC `standards-mapping.md`) to confirm your items appear.

## Adopting Framework Skills in a New Host Agent

The sections above target end users who author or replace Framework Skills. This section targets contributors building a *new* host agent (a planner, reviewer, or any phased workflow) that wants to consume Framework Skills. The contract is small and deliberately host-neutral: every existing host (the SSSC Planner, the RAI Planner, the Code Review Standards reviewer) implements the same five obligations.

1. **Declare a phase vocabulary in the agent's identity instructions.** Pick opaque string labels that match the agent's workflow (`assessment`, `standards-mapping`, `pre-diff`, `triage`, etc.). The schema does not constrain them; the agent owns their meaning. Document the accepted labels so Framework Skill authors know which keys to populate in `phaseMap`. Mismatched phase labels surface as missing items at discovery time, not as schema errors.
2. **Pick or define an `itemKind`.** Reuse `control` (security planners), `criterion` (review checklists), `principle`, `capability`, or invent one. Each new `itemKind` requires a per-item schema under `scripts/linting/schemas/` and a wiring entry in `npm run validate:skills` so per-item files get structural validation. Reusing an existing `itemKind` lets the new host consume Framework Skills already shipped for another host.
3. **Call the discovery module.** Import `scripts/lib/Modules/FrameworkSkillDiscovery.psm1` and use `Get-FrameworkSkill -Domain <domain>` to enumerate Framework Skills, then `Resolve-FrameworkSkillPhaseItem` to map a phase label to per-item file paths.
   The host decides which `-AdditionalRoots` to register (typically a `.copilot-tracking/` path the user controls) and whether to pass `-IncludeDrafts`.
   Do not re-implement discovery: it has been hardened against duplicate ids, missing files, and unparsable manifests.
4. **Persist a `state.frameworks[]` array per the shared shape.**
   The SSSC Planner's `state.json` schema models each loaded Framework Skill as `{ id, version, skillPath, disabled?, disabledReason?, disabledAtPhase?, suppressedControls?[] }`.
   New hosts that adopt the same shape get the opt-out and per-control suppression patterns described in the [SSSC Planner Framework Opt-Out](../security/sssc-planner-opt-out.md) doc for free, plus a uniform audit trail.
   Hosts that omit opt-out semantics still benefit from `disabled` being absent: the shape degrades cleanly when the field is omitted.
5. **Honor `status`, `applicability`, `equivalentImplementations`, and `alternativeGroup` in the agent's scoring or rendering pass.** Skip drafts unless the user explicitly opted in. Score `applicability.naWhen` matches as `n/a` against `state.projectContext`. Treat any `equivalentImplementations` member as full credit. Mark unused `alternativeGroup` peers as `n/a` once any peer is verified. These are Framework-Skill-author signals; ignoring them produces false gaps.

A new host agent that satisfies these five obligations inherits everything else automatically: the Framework Skill Pester suite covers its Framework Skills, `Test-FrameworkSkillInterface` validates manifests, the Prompt Builder + Researcher Subagent authoring loop produces drafts that work without modification, and end users author or replace Framework Skills using the workflow described above. The agent itself stays generic, and frameworks remain data.

For a worked example of the pattern applied beyond planners (code review, documentation rubrics, incident-response runbooks, onboarding curricula), see the [Framework Skills announcement](../announcements/framework-skill-interfaces.md#beyond-planners-the-code-review-agents).

## Validation Checklist

Before merging or sharing a Framework Skill:

* `npm run lint:frontmatter`: manifest schema validation.
* `npm run validate:skills`: SKILL.md structure (only for Framework Skills with a SKILL.md).
* `npm run lint:md`: markdown quality on any SKILL.md.
* Host smoke test: load the Framework Skill through the consuming agent and verify items resolve in the relevant phase.

## See Also

* [`framework-skill-interface` skill](../../.github/skills/shared/framework-skill-interface/SKILL.md): full authoring contract.
* [Authoring Custom Skills](skills.md): general skill conventions.
* [Bring Your Own Framework: Security](byof-security.md): SSSC Planner quickstart.
