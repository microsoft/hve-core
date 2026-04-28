---
title: "Authoring Framework Skills with Prompt Builder"
description: Workflow for importing a framework specification as a Framework Skill using the Prompt Builder agent, with example prompts for import, fork, and principles-only authoring scenarios
author: Microsoft
ms.date: 2026-04-22
ms.topic: how-to
keywords:
  - framework skill
  - prompt builder
  - authoring
  - byof
estimated_reading_time: 10
---

## When to Use This

The Framework Skill Interface (FSI) packages a framework specification (controls, criteria, principles, capabilities) as machine-readable YAML that any HVE Core host agent can enumerate. Two other pages cover the contract and the per-domain wiring:

* [Bring Your Own Framework](bring-your-own-framework) describes the host-neutral schema, discovery semantics, and `additionalRoot` registration.
* [Bring Your Own Framework: Security (SSSC Planner)](byof-security) and [Bring Your Own Framework: RAI Planning](byof-rai-planning) cover per-host quickstarts.

This page sits between those two layers. It documents the authoring workflow: how to drive the [Prompt Builder](../../.github/agents/hve-core/prompt-builder.agent.md) agent through draft creation, validation, review, and promotion. Use it when you have a framework source (PDF, web page, internal policy) and need a repeatable Prompt Builder recipe rather than a hand-written manifest.

## Prerequisites

* The Prompt Builder agent loaded in your chat host (referenced as `@Prompt Builder`).
* Clone-based installation of hve-core. The extension surface does not allow writing under `.github/skills/`, so authoring requires a local clone.
* PowerShell 7+ with the `powershell-yaml` module for manifest validation.
* The framework source artifact: a public URL, a downloadable PDF, an internal spec on disk, or pasted text.
* Familiarity with the target host's phase labels. SSSC Planner phases live in `.github/instructions/security/sssc-identity.instructions.md`; RAI Planner phases live in `.github/instructions/rai-planning/rai-identity.instructions.md`.

## The Prompt Builder Workflow

The [`framework-skill-interface` skill](../../.github/skills/shared/framework-skill-interface/SKILL.md) defines the contract. Prompt Builder drives a six-step workflow against that contract.

### 1. Discover

Prompt Builder reads the FSI skill page, then loads the framework source through the [Researcher Subagent](../../.github/agents/hve-core/subagents/researcher-subagent.agent.md). The subagent retrieves the source, normalizes structure (sections, control ids, version), and returns an outline. This step is read-only; nothing lands on disk until Step 2.

### 2. Draft `index.yml`

Prompt Builder writes a manifest skeleton that includes:

* `framework` (lower-kebab id matching the directory name).
* `version` (semver, framework-native revision, or date).
* `summary` (one sentence, 120 characters or fewer).
* `domain`, `itemKind`, and `status: draft`.
* `phaseMap` keyed by host phase labels.
* `metadata` with `authority`, `license`, `licenseUrl`, `attributionRequired`, and `attributionText` (when attribution is required).
* `governance` with `owners`, `review_cadence`, and `last_reviewed` (today's date).

New imports always start with `status: draft`. Hosts skip drafts unless explicitly opted in via `includeDrafts: true` on the per-id `additionalRoot` registration.

### 3. Generate per-item files

For every id listed under `phaseMap`, Prompt Builder writes a YAML file under `items/<id>.yml`. Item shape depends on `itemKind`:

* `control` items typically include `id`, `title`, `intent`, `assessment`, `references`.
* `criterion` items add a `level` field and pass-condition language.
* `principle` items hold a short statement plus rationale.
* `capability` items describe a discoverable capability surface, not a control to apply.
* `document-section` items hold templates referenced during render pipelines.

When the manifest sets `redistribution.idsAndUrlsOnly: true` or `redistribution.textVerbatim: false`, per-item `body`, `text`, and `description` fields stay short (the validator default is 200 characters); link to the source for full text.

### 4. Validate

Prompt Builder runs structural and schema validation:

* `npm run lint:frontmatter` checks manifest schema and FSI item schemas.
* `npm run validate:skills` verifies `SKILL.md` structure when one is present.
* `npm run test:ps -- -TestPath scripts/tests/linting/` runs the FSI lint suite, including governance currency, redistribution coherence, and skill-reference resolution.

Fix any reported errors before continuing. Warnings (governance overdue, missing `cleanup` on binary outputs) are advisory and do not block draft handoff.

### 5. Review

Prompt Builder pauses for human review. Confirm:

* `phaseMap` ids match the target host's phase labels.
* `metadata.license` and `metadata.attributionText` reflect the source's actual license terms.
* `governance.owners` references a real CODEOWNERS-style team or handle.
* Per-item content respects redistribution flags.
* Where applicable, the per-item `disclaimer:` field is reserved for framework-specific technical caveats only. Domain-level legal review boilerplate lives in [`disclaimer-language.instructions.md`](../../.github/instructions/shared/disclaimer-language.instructions.md) and is sourced verbatim by host agents. See [Disclaimer Language](disclaimer-language) for details.

### 6. Promote

After review, flip `status: draft` to `status: published`, refresh `governance.last_reviewed` to today's date, and rerun the validators. Drop `includeDrafts: true` from any host-state registrations that were opted into the draft.

## Example Prompts

The three prompts below cover the most common authoring scenarios: import a published spec, fork a built-in to make an org-tailored revision, and author a principles-only Framework Skill from internal policy. Each prompt names the source, the target path, the host agent, and the expected phase labels so Prompt Builder has every input it needs before drafting begins.

### Import a published framework into SSSC Planner

```text
@Prompt Builder

Import the CIS Software Supply Chain Security Guide v1.0 as a new Framework Skill for the
SSSC Planner.

Source: https://www.cisecurity.org/insights/white-papers/cis-software-supply-chain-security-guide
Target path: .github/skills/security/cis-supply-chain/
Domain: security
itemKind: control
status: draft (until human review)

Host agent: SSSC Planner. Use the SSSC phase labels:
  - assessment
  - standards-mapping
  - gap-analysis
  - backlog
  - handoff

Authoring contract: read .github/skills/shared/framework-skill-interface/SKILL.md before
drafting. Use the Researcher Subagent to retrieve the source and extract per-control items.

Required outputs:
  1. index.yml with framework, version, summary (≤120 chars), phaseMap, metadata (authority,
     license, licenseUrl, attributionRequired, attributionText), governance (owners,
     review_cadence: P180D, last_reviewed: today).
  2. items/<id>.yml for every id listed in phaseMap, validating against
     scripts/linting/schemas/planner-framework-control.schema.json.
  3. SKILL.md skill page following the conventions in sibling Framework Skills under
     .github/skills/security/.

Validation: after drafting, run `npm run lint:frontmatter`, `npm run validate:skills`, and
`npm run test:ps -- -TestPath scripts/tests/linting/`.

Stop and ask before promoting from draft to published.
```

### Fork a built-in to make an org-tailored revision

```text
@Prompt Builder

Create an org-tailored revision of the OpenSSF Scorecard Framework Skill that drops the
Webhooks check, tightens the Token-Permissions check to require workflow-level least
privilege, and adds an org-internal control "secret-scanning-allowlist".

Base: .github/skills/security/openssf-scorecard/
Target path: .github/skills/security/contoso-scorecard/
Domain: security
itemKind: control
status: draft

Host agent: SSSC Planner. Preserve the existing phaseMap shape but adjust ids per the
override list above.

Authoring contract: load .github/skills/shared/framework-skill-interface/SKILL.md.
Inherit the OpenSSF Scorecard manifest's redistribution flags (textVerbatim: true) and
update metadata.attributionText to include both "OpenSSF Scorecard — Apache-2.0" and
"Contoso internal extensions — © Contoso, Internal Use Only".

Validation:
  - npm run lint:frontmatter
  - npm run validate:skills
  - Confirm Validate-FsiContent.ps1 reports no governance-currency warnings.
```

### Author a principles-only Framework Skill from internal policy

```text
@Prompt Builder

Create a new Framework Skill that packages the Contoso "Responsible Engineering Principles"
PDF as a principle-shape Framework Skill for the RAI Planner.

Source: ./internal-docs/responsible-engineering-principles-v3.pdf (local file)
Target path: .copilot-tracking/framework-imports/contoso-responsible-engineering/
Domain: rai-planning
itemKind: principle
status: draft

Host agent: RAI Planner. Use the RAI phase labels declared in
.github/instructions/rai-planning/rai-identity.instructions.md.

Manifest requirements:
  - metadata.license: "LicenseRef-Contoso-Internal"
  - metadata.attributionRequired: false
  - metadata.redistribution.textVerbatim: false
  - metadata.redistribution.idsAndUrlsOnly: true
  - governance.owners: ["@contoso/responsible-eng"]
  - governance.review_cadence: P90D
  - governance.last_reviewed: today

Per-item files: keep body/text/description ≤200 chars (the redistribution.idsAndUrlsOnly:
true rule). Link out to the source PDF for full text.

After drafting, run `npm run validate:skills` and confirm no Test-FsiContent redistribution
warnings.
```

## Validation Checklist

Run all three commands after any FSI authoring or revision pass:

* `npm run lint:frontmatter` validates the manifest against `framework-skill-manifest.schema.json` and per-item schemas.
* `npm run validate:skills` validates the optional `SKILL.md` page when one ships with the Framework Skill.
* `npm run test:ps -- -TestPath scripts/tests/linting/` runs the full FSI lint suite (governance currency, redistribution coherence, skill-reference resolution, kind compatibility, binary-artifact warnings).

Validators write structured results under `logs/`. Read `logs/pester-summary.json` for overall pass/fail and `logs/pester-failures.json` for any failure detail.

## Promotion (draft to published)

Promotion is a small, reviewable change:

1. Open `index.yml` and change `status: draft` to `status: published`.
2. Update `governance.last_reviewed` to today's ISO date.
3. Update `governance.review_cadence` only when the bundle's review SLA changed.
4. Rerun the validation checklist above.
5. Drop `includeDrafts: true` from any host-state `additionalRoot` registrations that were opted in for the draft.
6. Open a pull request describing the framework, the source, and any redistribution constraints. Include the `THIRD-PARTY-NOTICES` regeneration when `metadata.attributionRequired: true`.

## Troubleshooting

| Symptom                                       | Likely cause                                                                      | Fix                                                                                                                                                                                                                      |
|-----------------------------------------------|-----------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Governance currency warning at lint time      | `governance.last_reviewed` missing or older than `last_reviewed + review_cadence` | Set `last_reviewed` to today and confirm the cadence reflects your review SLA.                                                                                                                                           |
| Attribution-required failure                  | `attributionRequired: true` without `attributionText`, or `attributionText` empty | Add a verbatim attribution string. Plugin generation aggregates this into `THIRD-PARTY-NOTICES`.                                                                                                                         |
| Redistribution coherence failure              | A per-item `body`, `text`, or `description` exceeds the threshold                 | When the manifest sets `redistribution.idsAndUrlsOnly: true` or `redistribution.textVerbatim: false`, shrink per-item content under 200 characters and link to the source for full text.                                 |
| Phase label not in host phaseMap              | A `phaseMap` key does not match a label the host knows                            | Check the host's identity instruction file (for example `sssc-identity.instructions.md` or `rai-identity.instructions.md`) and rename the key. Phase labels are opaque strings owned by the host, not by the FSI schema. |
| Discovery does not find the Framework Skill   | The Framework Skill lives outside `.github/skills/<domain>/` and is not opted in  | Add an `additionalRoot` entry on the host's per-id `frameworkRef` (with `includeDrafts: true` while the bundle is in draft).                                                                                             |
| `requiredSkills` lint error                   | A `ref` does not resolve to `.github/skills/<ref>/SKILL.md`                       | Verify the slug uses `<domain>/<name>` form and matches the directory name. Drop the entry when the reference is no longer needed.                                                                                       |
| Binary-artifact warning on a `pipeline` stage | A `produces[]` entry of kind `binary/*` omits `cleanup`                           | Add `cleanup: ephemeral` for intermediate render scratch or `cleanup: retained` for user-facing deliverables.                                                                                                            |

## See Also

* [Bring Your Own Framework](bring-your-own-framework) for the host-neutral contract and discovery semantics.
* [Bring Your Own Framework: Security (SSSC Planner)](byof-security) for the SSSC quickstart.
* [Bring Your Own Framework: RAI Planning](byof-rai-planning) for the RAI quickstart.
* [Disclaimer Language](disclaimer-language) for the centralized disclaimer source-of-truth.
* [Framework Skill Interfaces](../announcements/framework-skill-interfaces) for the FSI announcement and design rationale summary.
* [`framework-skill-interface` skill](../../.github/skills/shared/framework-skill-interface/SKILL.md) for the full authoring contract.
