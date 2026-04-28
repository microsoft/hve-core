---
title: "Requirements Builder: One Agent for PRDs, BRDs, and Beyond"
description: Announcing the unified Requirements Builder — a single FSI-backed agent that replaces the legacy prd-builder and brd-builder with a six-phase pipeline and pluggable document frameworks
author: Microsoft
ms.date: 2026-04-23
ms.topic: concept
sidebar_position: 3
keywords:
  - requirements builder
  - prd
  - brd
  - framework skill
  - fsi
  - project planning
estimated_reading_time: 5
---

## What changed

The `prd-builder` and `brd-builder` agents have been unified into a single [`requirements-builder`](../agents/project-planning/requirements-builder.md) agent. Instead of two near-identical agents with hard-coded templates, the new agent runs a single six-phase pipeline (identity → intake → template-selection → drafting → review → handoff) and loads document styles as [Framework Skill Interface (FSI)](framework-skill-interfaces.md) framework skills under `.github/skills/requirements/`.

The legacy `prd-builder` and `brd-builder` agents remain in the repo as small deprecation stubs that point users to the unified agent. No automation that referenced their output paths needs to change.

## Why this matters

Three pain points motivated the unification:

1. **Drift between twin agents.** The PRD and BRD builders had a shared 7-phase workflow but diverged over time in template details, recovery protocols, and session shape. Bug fixes had to be applied in both places.
2. **No path for new document styles.** Adding an MRD, FRD, SRS, or internal-template variant meant a new agent file and a new session directory. There was no plug-in point.
3. **Custom templates fell off a cliff.** Users with their own org templates had no managed path to load them; they either edited the agent or worked around it.

The FSI-backed split solves all three. The agent stays generic. Document styles are data: discoverable, validated, version-pinned, and pluggable.

## What's in v1

Two framework skills ship under `.github/skills/requirements/`:

* `requirements-prd`: PRD authoring. Output: `docs/prds/<slug>.md`. Audience: product, engineering. Depth tiers: light, standard, deep.
* `requirements-brd`: BRD authoring. Output: `docs/brds/<slug>-brd.md`. Audience: business, sponsor, exec. Depth tiers: standard, deep. Carries BR-ID traceability.

Both are marked `maturity: experimental` and follow the same FSI manifest contract used by the security domain's framework skills. They are discovered through the same `Get-FrameworkSkill -Domain requirements` call and surface in the agent's framework gate as a single multi-select with safe defaults pre-checked.

## What stayed the same

* Final output paths: `docs/prds/<slug>.md` and `docs/brds/<slug>-brd.md`.
* Downstream slash-commands: `security-plan-from-prd`, `sssc-from-prd`, `rai-plan-from-prd`, `sustainability-from-prd`, `ado-prd-to-wit`, `jira-prd-to-wit`.
* Calling agents: `product-manager-advisor` and `meeting-analyst` now route to Requirements Builder; their handoff payloads pre-populate intake.

## What's new

* Single state directory: `.copilot-tracking/requirements-sessions/{slug}/` for all requirements work, regardless of document style.
* Multi-document sessions: pick `requirements-brd` *and* `requirements-prd` at the gate and draft both in one session with shared intake evidence.
* Append-only `skills-loaded.log` records every framework skill load with `skillId`, `version`, `sha256`, `phase`, and timestamp; provides the same audit trail the SSSC and RAI planners already provide.
* **sha256-pinned disclaimer** in `meta.disclaimerVersion`, re-rendered only when the shared `disclaimer-language.instructions.md` source changes.
* **Custom templates** get a managed promotion path: the agent recommends authoring them as first-class FSI framework skills via Prompt Builder. For one-shot use, the template is accepted as `provenance: user-supplied-template, unmanaged` and clearly marked in the draft.

## Migrating in-flight work

* Existing `.copilot-tracking/prd-sessions/{slug}/` and `.copilot-tracking/brd-sessions/{slug}/` directories are **read-only**.
* Open `requirements-builder` with the same slug; the agent reads the legacy directory as intake evidence and writes new artifacts under `requirements-sessions/{slug}/`.
* No file moves required. Final document paths are unchanged.

## Adding your own document style

The plug-in point is `.github/skills/requirements/<framework-id>/` with the standard FSI manifest shape. The full authoring loop is documented in [Authoring Framework Skills with Prompt Builder](../customization/authoring-framework-skills.md). The same loop that imports an OWASP Top 10 or NIST SSDF spec for the security planners imports an MRD or org-specific requirements template for the Requirements Builder.

## Related reading

* [Requirements Builder agent guide](../agents/project-planning/requirements-builder.md)
* [Project Planning Agents](../agents/project-planning/README.md)
* [Framework Skills: How HVE Core Loads Any Standard as Data](framework-skill-interfaces.md)

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
