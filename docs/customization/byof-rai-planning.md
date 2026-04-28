---
title: "Bring Your Own Framework: RAI Planning"
description: Quickstart for importing a custom Responsible AI framework into the RAI Planner using the Framework Skill pattern
author: Microsoft
ms.date: 2026-04-22
ms.topic: how-to
keywords:
  - rai planner
  - responsible ai
  - framework skill
  - byof
  - custom framework
estimated_reading_time: 6
---

## When to Use This

The RAI Planner ships with NIST AI RMF 1.0 trustworthiness characteristics as the default Framework Skill. Use a Bring-Your-Own-Framework (BYOF) workflow when you need to:

* Add an internal Responsible AI standard (org policy, board-approved principle set, regulator-issued requirement).
* Override the NIST default with a tailored revision (region-specific characteristics, narrower trustworthiness scope).
* Stage a draft framework for review before the planner consumes it.
* Layer a principle-shape document (for example a Responsible Engineering Principles PDF) on top of the default characteristics.

This page is the RAI-specific quickstart. For the host-neutral contract, schema, and discovery semantics, read [Bring Your Own Framework](bring-your-own-framework) first. For the authoring workflow that drives Prompt Builder, read [Authoring Framework Skills with Prompt Builder](authoring-framework-skills).

## Prerequisites

* Clone-based installation of hve-core. The extension surface does not allow writing under `.github/skills/`.
* PowerShell 7+ with the `powershell-yaml` module.
* The RAI Planner agent loaded in your chat host.
* Familiarity with the framework you intend to import (source URL, characteristic or principle ids, version).

## RAI Phase Labels

The RAI Planner uses these phase labels in `phaseMap` keys. They mirror the six phases described in `.github/instructions/rai-planning/rai-identity.instructions.md`.

| Phase label           | RAI phase | Purpose                                                                                        |
|-----------------------|-----------|------------------------------------------------------------------------------------------------|
| `scoping`             | Phase 1   | AI system scoping inputs, stakeholder mapping, intended-use captures.                          |
| `risk-classification` | Phase 2   | Risk indicators, prohibited-use gate inputs, depth-tier evidence.                              |
| `standards-mapping`   | Phase 3   | Trustworthiness characteristics or framework principles mapped to AI components and behaviors. |
| `security-model`      | Phase 4   | AI-specific threat categories, dual threat ID inputs, concern-level criteria.                  |
| `impact-assessment`   | Phase 5   | Control surface entries, evidence register prompts, tradeoff considerations.                   |
| `handoff`             | Phase 6   | Items surfaced in the dual-format backlog handoff and review summary.                          |

A Framework Skill does not need to populate every phase. Most RAI Framework Skills populate `standards-mapping` (characteristics or principles), `impact-assessment` (controls and tradeoffs), and `handoff` (review-summary inputs). Risk-indicator overrides populate `risk-classification`.

## additionalRoot Wiring

The RAI Planner discovers Framework Skills under `.github/skills/rai-planning/` by default. To register a Framework Skill that lives elsewhere on disk, add it to RAI state:

```yaml
frameworks:
  - id: <framework-id>
    additionalRoot: /srv/org-frameworks
    includeDrafts: true   # only while status: draft
    replaceDefaults: false
```

Set `replaceDefaults: true` to drop the NIST AI RMF 1.0 default for that id. Without it, built-ins are searched first and shadow your override (first-seen-wins discovery). For a custom risk-indicator set, also set `replaceDefaultIndicators: true` so Phase 2 uses your indicators in place of the NIST defaults.

`includeDrafts: true` opts the planner into loading `status: draft` Framework Skills. Drop the flag once you flip the manifest to `status: published`.

## Authoring Workflow

Run the RAI Planner and answer "yes" when Phase 1 asks whether you want to import a custom framework. The planner routes to [Prompt Builder](../../.github/agents/hve-core/prompt-builder.agent.md) and the [`framework-skill-interface` skill](../../.github/skills/shared/framework-skill-interface/SKILL.md), which collect the source, draft `index.yml`, generate per-item files, and run validation.

You can also invoke Prompt Builder directly: `@prompt-builder import the framework at <url> as an rai-planning Framework Skill at <path>`.

For the full authoring workflow (Discover, Draft, Generate, Validate, Review, Promote) and three example Prompt Builder prompts, read [Authoring Framework Skills with Prompt Builder](authoring-framework-skills).

## Example Mapping: NIST AI RMF as a Framework Skill

The default RAI Framework Skill packages the NIST AI RMF 1.0 trustworthiness characteristics. The mapping looks like this:

* `framework: nist-ai-rmf`
* `version: "1.0"`
* `domain: rai-planning`
* `itemKind: characteristic` (a principle-shape with associated subcategory pointers).
* `phaseMap.standards-mapping` lists the seven trustworthiness characteristics: Valid and Reliable, Safe, Secure and Resilient, Accountable and Transparent, Explainable and Interpretable, Privacy-Enhanced, Fair with Harmful Bias Managed.
* `phaseMap.impact-assessment` lists the same characteristic ids so Phase 5 can build the control surface and tradeoff entries from the same items.
* `metadata.authority: NIST`, `metadata.license: US-Gov-Public-Domain`, `metadata.attributionRequired: false`.
* `metadata.disclaimer` (optional) holds framework-specific technical caveats only. Domain-level legal-review boilerplate is sourced verbatim from [`disclaimer-language.instructions.md`](../../.github/instructions/shared/disclaimer-language.instructions.md). See [Disclaimer Language](disclaimer-language) for the contract.

To author a parallel principles-only Framework Skill (for example, an internal Responsible Engineering Principles document), use `itemKind: principle`, set `metadata.redistribution.idsAndUrlsOnly: true` when the source license restricts verbatim redistribution, and keep per-item `body`, `text`, and `description` fields under 200 characters with links out to the source.

## Validation

Run all three commands after any RAI Framework Skill authoring or revision pass:

* `npm run lint:frontmatter` validates the manifest against `framework-skill-manifest.schema.json` and per-item schemas.
* `npm run validate:skills` validates the optional `SKILL.md` when one ships with the Framework Skill.
* `npm run test:ps -- -TestPath scripts/tests/linting/` runs the FSI lint suite (governance currency, redistribution coherence, skill-reference resolution).

Then run a fresh RAI session through Phase 3 and confirm your characteristic or principle ids appear in `rai-standards-mapping.md`. For a risk-indicator override, confirm Phase 2 surfaces your indicators in the risk classification screening summary.

## See Also

* [Bring Your Own Framework](bring-your-own-framework) for the host-neutral contract.
* [Authoring Framework Skills with Prompt Builder](authoring-framework-skills) for the import workflow and example prompts.
* [Bring Your Own Framework: Security (SSSC Planner)](byof-security) for the SSSC quickstart parallel.
* [Disclaimer Language](disclaimer-language) for the centralized disclaimer source-of-truth.
* RAI Planner instructions: `.github/instructions/rai-planning/rai-identity.instructions.md`, `.github/instructions/rai-planning/rai-standards.instructions.md`.
