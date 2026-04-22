---
title: "Bring Your Own Framework: Security (SSSC Planner)"
description: Quickstart for importing a custom security framework into the SSSC Planner using the Framework Skill pattern
author: Microsoft
ms.date: 2026-04-19
ms.topic: how-to
keywords:
  - sssc planner
  - security framework
  - framework skill
  - byof
  - custom framework
estimated_reading_time: 6
---

## When to Use This

The SSSC Planner ships with built-in Framework Skills (NIST SSDF, OpenSSF Scorecard, S2C2F, SLSA, CISA SSCM, Sigstore, SBOM, OpenSSF Best Practices Badge, plus capability inventories). Use a Bring-Your-Own-Framework (BYOF) workflow when you need to:

* Add an internal security standard (org policy, regulator-issued control set).
* Override a built-in with a tailored revision.
* Stage a draft framework for review before the planner consumes it.

This page is the SSSC-specific quickstart. For the host-neutral contract, schema, and discovery semantics, read [Bring Your Own Framework](bring-your-own-framework.md) first.

## Prerequisites

* Clone-based installation (BYOF requires authoring files outside the extension surface).
* PowerShell 7+ with the `powershell-yaml` module.
* Familiarity with the framework you intend to import (source URL, control identifiers, version).

## SSSC Phase Labels

The SSSC Planner uses these phase labels in `phaseMap` keys:

| Phase label         | SSSC phase | Purpose                                                   |
|---------------------|------------|-----------------------------------------------------------|
| `assessment`        | Phase 2    | Capability inventory and current-state assessment items.  |
| `standards-mapping` | Phase 3    | Framework controls mapped to in-scope capabilities.       |
| `gap-analysis`      | Phase 4    | Items used to drive gap categorization and effort sizing. |
| `backlog`           | Phase 5    | Items that produce work-item drafts.                      |
| `handoff`           | Phase 6    | Items surfaced in the dual-format backlog handoff.        |

A Framework Skill does not need to populate every phase. Most Framework Skills populate `standards-mapping`, `gap-analysis`, and `backlog`; capability inventories populate `assessment` only.

## Quickstart

### 1. Decide Where the Framework Skill Lives

Pick one:

| Location           | Path                                                  | Notes                                         |
|--------------------|-------------------------------------------------------|-----------------------------------------------|
| In-repo, published | `.github/skills/security/<framework-id>/`             | Discovered automatically.                     |
| In-repo, drafts    | `.copilot-tracking/framework-imports/<framework-id>/` | Register with `additionalRoot` in SSSC state. |
| Org-shared         | Any path on disk                                      | Register with `additionalRoot` in SSSC state. |

### 2. Author the Framework Skill

Run the SSSC Planner and answer "yes" when Phase 1 asks whether you want to import a custom framework. The planner routes to the [Prompt Builder](../agents/) agent and the `framework-skill-interface` skill, which:

1. Collect the framework source (URL, PDF, or pasted spec).
2. Use the Researcher Subagent to extract control structure.
3. Generate `index.yml` with `domain: security`, an appropriate `itemKind`, and `status: draft`.
4. Write per-item YAML files under `items/`.
5. Run schema and structural validation.

You can also invoke this directly: `@prompt-builder import the framework at <url> as a security Framework Skill at <path>`.

### 3. Register the Framework Skill with SSSC

If the Framework Skill lives outside `.github/skills/security/`, add it to SSSC state:

```yaml
frameworks:
  - id: <framework-id>
    additionalRoot: /srv/org-frameworks
    includeDrafts: true   # only while status: draft
    replaceDefaults: false
```

`includeDrafts: true` opts the planner into loading `status: draft` Framework Skills for that id. Drop the flag once you flip the manifest to `status: published`.

### 4. Smoke-Test Discovery

```powershell
Import-Module ./scripts/lib/Modules/FrameworkSkillDiscovery.psm1
Get-FrameworkSkill -Domain security -AdditionalRoots @('/srv/org-frameworks') -IncludeDrafts |
    Where-Object { $_.framework -eq '<framework-id>' }
```

The cmdlet should return one entry. If it does not, run `Test-FrameworkSkillInterface <path>` for diagnostics.

### 5. Run SSSC Phase 3

Start a fresh SSSC session (or resume an existing plan) and let it advance to Phase 3: Standards Mapping. The planner enumerates `Get-FrameworkSkill -Domain security` with your `additionalRoot`, loads your items per `phaseMap.standards-mapping`, and writes them into `standards-mapping.md`. Verify your control ids appear.

### 6. Promote to Published

After review:

1. Edit `index.yml`: change `status: draft` to `status: published`.
2. Drop `includeDrafts: true` from SSSC state.
3. Re-run validation and a fresh SSSC discovery to confirm.

## Replacing a Built-In Framework

To override (e.g.) `nist-ssdf` with an org revision:

1. Author the replacement under an additional root with `framework: nist-ssdf`.
2. Set `replaceDefaults: true` on its `frameworkRef` in SSSC state. The planner drops the built-in for that id.
3. Confirm via Phase 3 output that your version's items appear.

Without `replaceDefaults: true`, the built-in shadows your override (first-seen-wins discovery: built-ins are searched first).

## Validation Checklist

Run before each SSSC session that depends on the Framework Skill:

* `npm run lint:frontmatter`: manifest schema.
* `npm run validate:skills`: Framework Skill structure if a `SKILL.md` is present.
* `Test-FrameworkSkillInterface <path>`: full Framework Skill structural check.
* SSSC dry-run through Phase 3: confirm items appear in `standards-mapping.md`.

## See Also

* [Bring Your Own Framework](bring-your-own-framework.md): host-neutral contract.
* [`framework-skill-interface` skill](../../.github/skills/shared/framework-skill-interface/SKILL.md): authoring details.
* SSSC Planner instructions: `.github/instructions/security/sssc-identity.instructions.md`, `sssc-standards.instructions.md`.
