---
description: 'Phase 2 surface assessment contract — discovers capability inventory skills under .github/skills/accessibility/capability-inventory-* and populates state.capabilityInventory.'
applyTo: '**/.copilot-tracking/accessibility-plans/**'
---

# Accessibility Planner Phase 2 — Surface Assessment (Capability-Skill Consumer Contract)

This file is a **consumer contract**. The Wave 1 capability set (29 combined `capability-inventory-web` and `capability-inventory-content` capabilities) is not encoded inline. The planner discovers capability inventories by reading skills under `.github/skills/accessibility/capability-inventory-*/`. Adding or replacing an inventory requires no edits to this file.

State contract, skill-loading log, and session recovery are defined in [`#file:accessibility-identity.instructions.md`](accessibility-identity.instructions.md). Tier-driven gate rules are defined in [`#file:accessibility-risk-classification.instructions.md`](accessibility-risk-classification.instructions.md).

## Phase 2 Pre-Flight Checklist

Before scoring any capability in this phase, the planner reads the following inputs. This is the procedural enforcement of the Evidence Exhaustion Rule, applied at phase entry rather than per capability.

1. Any accessibility statement, conformance report, or VPAT linked from `README.md`, `docs/`, or product help (follow every relative or absolute repo link, including indirect chains).
2. The accessibility, inclusion, or compliance section of `README.md` and every file it links to.
3. Every file under `accessibility/` (or any directory whose name starts with `a11y` or `accessibility`), recursively.
4. Every file under `contributing/` (or `CONTRIBUTING.md` and `.github/CONTRIBUTING.md`) whose name contains `accessibility`, `a11y`, `review`, or `inclusion`.
5. `CHANGELOG.md`, grepped for the canonical artifact keyword set in the [Evidence Exhaustion Rule](#evidence-exhaustion-rule-mandatory-before-any-non-verified-verdict) item 2, and additionally for every framework name and tier name in scope (for example `WCAG`, `WCAG 2.2`, `AA`, `AAA`, `Section 508`, `EN 301 549`, `ARIA`, `APG`, `axe`, `lighthouse`).
6. The full file listing of `.github/workflows/` (read each workflow that matches any capability's `evidenceHints[]`, including axe-core, Lighthouse a11y, pa11y, ESLint jsx-a11y, IBM Equal Access, Accessibility Insights, Playwright/Cypress axe integrations, and HTML validators).
7. Every status badge URL discovered in `README.md` or under `docs/` whose target is an accessibility score or conformance endpoint (for example axe-core CI dashboards, Lighthouse a11y badge, Accessibility Insights summary). Fetch the live endpoint and record the returned score in the inputs log; markdown alone does not encode the current score.

Record each pre-flight read in `skills-loaded.log` (append-only NDJSON to `state.skillsLoaded[]`) so the audit trail shows the inputs were consulted before scoring began. A capability may not be assigned a verdict other than `unknown` until the pre-flight reads relevant to that capability are complete.

## Evidence Exhaustion Rule (mandatory before any non-verified verdict)

Before assigning a `partial`, `absent`, or `n/a` verdict to any capability, the agent completes the following six checks. If any check surfaces evidence that has not yet been read, the agent reads that evidence before scoring. All evidence citations recorded in `state.capabilityInventory[].evidence[]` and rendered in surface-assessment output follow the canonical evidence row format defined in #file:../shared/evidence-citation.instructions.md.

1. **Trace cross-references.** If the accessibility statement, `README.md`, `CONTRIBUTING.md`, or any policy stub links to or names another document (for example anything under `accessibility/`, `contributing/`, `docs/a11y/`), open and read that target before scoring. Short policy files frequently delegate substance to longer companion docs.
2. **Search for canonical artifact names and tier names.** Run a workspace search for the artifact's standard names before declaring it absent. At minimum search for: `axe`, `lighthouse`, `pa11y`, `jsx-a11y`, `equal-access`, `accessibility-insights`, `fastpass`, `nvda`, `jaws`, `voiceover`, `talkback`, `apca`, `contrast`, `nu html checker`, `vnu`, `aria`, `landmark`, `focus-trap`, `skip-link`, `accessibility-audit`, `vpat`, `acr`, `conformance-report`. When scoring a tiered framework (WCAG level, EN 301 549 clause, Section 508 chapter), also search for the framework name and every tier name (for example `WCAG`, `2.2`, `level A`, `level AA`, `level AAA`, `Section 508`, `EN 301 549`).
3. **Check `CHANGELOG.md` for historical additions and tier-targeted PRs.** A capability may have been added in a prior release under a non-obvious filename, and conformance-advancement campaigns are typically announced in CHANGELOG entries. A grep for the capability's domain keywords in `CHANGELOG.md` is required before assigning `absent`. For tiered frameworks, additionally grep for the framework and tier names from check 2; PRs explicitly tagged "for AA", "for AAA", "Section 508 conformance", etc., are positive evidence of an active or completed conformance campaign.
4. **Consider equivalents.** If a capability names a specific tool (for example `axe-core-ci`), check for functional equivalents that use the same underlying primitives (for example `playwright-axe` and `cypress-axe` both invoke axe-core and are functionally equivalent for rule coverage; Lighthouse a11y category invokes axe-core under the hood). Score equivalents as `verified`, not `partial`. When the capability declares `equivalentImplementations` in its control YAML, treat presence of any listed equivalent as full credit.
5. **Fetch live endpoints for status badges and dynamic indicators.** Static markdown shows a generic badge URL; the current score or conformance state is encoded in the rendered SVG/JSON, not in the markdown. When a capability's `evidenceHints` reference an external badge or status endpoint, or when README/docs link to one (axe-core CI dashboards, Lighthouse a11y endpoint, Accessibility Insights summary, etc.), fetch the live endpoint and record the returned score in the inputs log before scoring. Do not infer score from the markdown image URL alone.
6. **Trust converging in-repo evidence.** When two or more independent in-repo artifacts (CHANGELOG entries, accessibility statement, VPAT, audit reports under `accessibility/` or `docs/a11y/`, dedicated conformance docs) explicitly name the same capability, framework, or deliverable, score the capability as `verified` and cite all converging artifacts. Conservative-by-default scoring (`partial` or `claim-ready`) is forbidden when in-repo evidence converges; either fetch the live endpoint to disconfirm (check 5) or accept the converging evidence as verified.

The six checks must be completed before assigning a non-`verified` verdict. Use the `unknown` verdict (see [Verdict Ladder](#verdict-ladder)) when the checks have not been completed; do not use `partial` as a placeholder for "not yet inspected".

## Verdict Ladder

The following verdicts are the only valid posture values the planner records for a capability row. The categorical `categories: [absent, partial, present, verified]` set in per-capability YAML defines authoring-time enums; `unknown` and `n/a` are planner-applied states surfaced in the assessment output and `state.capabilityInventory[].status` field.

* **verified** — Positive evidence of full coverage. Cite the specific file and line.
* **present** — Artifact exists but full conformance to the capability is not yet confirmed; cite the artifact.
* **partial** — Positive evidence of partial coverage. Required: cite both what is present and the specific gap.
* **unknown** — The Evidence Exhaustion Rule has not been completed for this capability. Either complete the rule or ask the user a follow-up question. `unknown` is not a final verdict; it must be resolved before Phase 3 begins.
* **absent** — Positive evidence the capability is not implemented after the Evidence Exhaustion Rule has been completed.
* **n/a** — Capability does not apply. Cite reason (alternative satisfied, surface-kind exclusion per risk classification, applicability discriminator, etc.).

`partial` requires positive evidence of incomplete coverage. Absence of inspection is `unknown`, not `partial`.

### Phase 3 Entry Gate

Phase 3 (standards mapping) cannot begin while any capability row carries a `status` of `unknown`. The planner must either complete the Evidence Exhaustion Rule for the capability or capture a user follow-up answer that resolves the status to one of `verified`, `present`, `partial`, `absent`, or `n/a`. The accessibility planner artifact validator enforces this gate on the surface-assessment output before allowing `phase` to advance past `surface-assessment`.

## Tier and Surface-Kind Gates

Capability mandatoriness depends on the depth tier and surface kinds resolved in [`#file:accessibility-risk-classification.instructions.md`](accessibility-risk-classification.instructions.md). Read that file's tier definitions and surface-kind exclusions before selecting which capabilities to evaluate.

* **Tier 1 (light)** — only the capabilities listed in each inventory's `phaseMap.surface-assessment` block whose `evidenceHints[]` cover automated CI checks are mandatory. Manual-audit and assistive-technology capabilities default to `n/a` unless the user opts in.
* **Tier 2 (standard)** — every capability in each inventory's `phaseMap.surface-assessment` block is mandatory. This is the default tier when risk classification does not narrow scope.
* **Tier 3 (deep)** — every capability in each inventory's full `capabilities[]` list is mandatory, including manual review and assistive-technology touchpoints.

Surface-kind exclusions remove capabilities that cannot apply to the target surface. Examples:

* **Voice-only or audio-only surfaces** exclude visual-contrast capabilities (`wcag-contrast-2x`, `apca-contrast`).
* **Static-content surfaces with no interactive controls** exclude focus-management and keyboard-only navigation capabilities.
* **Native-mobile-only surfaces** exclude HTML-validator and DOM-targeted scanner capabilities (`nu-html-checker`, `eslint-jsx-a11y`).
* **Server-rendered content with no client JS** exclude live-region and dynamic-update assistive-technology capabilities.

When excluding a capability for surface-kind reasons, record the exclusion as `status: n/a` with `notes` citing the exclusion rule from the risk classification file.

## Capability Inventory Discovery Protocol

Each capability inventory is a self-contained skill containing:

* `SKILL.md` — entrypoint metadata describing the inventory's source repository and scope.
* `index.yml` — `framework`, `version`, `domain`, `phaseMap` (per-phase capability subsets), and `capabilities[]` listing every capability id contributed by this skill (when present at root) or derived from the union of `phaseMap` blocks.
* `items/<capability-id>.yml` — one file per capability, validated against [`scripts/linting/schemas/planner-framework-control.schema.json`](../../../scripts/linting/schemas/planner-framework-control.schema.json).

The planner enumerates the Wave 1 inventories listed below and registers each capability as an entry in `state.capabilityInventory[]` (see [`scripts/linting/schemas/accessibility-state.schema.json`](../../../scripts/linting/schemas/accessibility-state.schema.json)).

### Wave 1 Capability Inventories

The following inventories are in scope for Wave 1. Both are enumerated explicitly by skill id; no globbing.

| Skill id                       | Capabilities | Scope                                                                                                                                         |
|--------------------------------|--------------|-----------------------------------------------------------------------------------------------------------------------------------------------|
| `capability-inventory-web`     | 17           | Web app/site tooling — automated scanners, static analyzers, component-test addons, assistive-technology touchpoints, contrast methodologies. |
| `capability-inventory-content` | 12           | Authoring/CMS tooling — prose linters, readability metrics, structural linters, plain-language and human-review touchpoints.                  |

Future waves register additional inventories under `.github/skills/accessibility/capability-inventory-*/` without edits to this file.

## Hard Loading Contract

1. Read `index.yml` for every Wave 1 capability-inventory skill listed above (filtered by Phase 1 `appliesTo` matching the project's surface kinds; for example, content-only projects skip `capability-inventory-web`).
2. Read **only** the `items/<capability-id>.yml` files for capabilities listed in the active phase block (`phaseMap.surface-assessment` for Tier 1/2; full `capabilities[]` for Tier 3).
3. Append one entry per `read_file` of any skill artifact to `state.skillsLoaded[]` as append-only NDJSON. See [`#file:accessibility-identity.instructions.md`](accessibility-identity.instructions.md) for the entry shape.

## Per-Capability Field Usage

For each capability YAML loaded:

* `id`, `title` — capability row identifier and human-readable label.
* `assessmentMethod: categorical` with `categories: [absent, partial, present, verified]` — the only valid posture values.
* `evidenceHints[]` — deterministic file globs (workflow paths, config files, lint rules, audit reports) the planner inspects to suggest current posture.
* `mapsTo[]` — cross-framework links (which WCAG success criteria, ARIA-APG patterns, or EN 301 549 clauses the capability satisfies) used to seed Phase 3 mapping.
* `gates[]` — assessment gates with `status: pending` until evidence is collected.
* `equivalentImplementations[]` (when present) — alternate tools that satisfy the same capability per the Evidence Exhaustion Rule check 4.

## Assessment Protocol

For every capability discovered, execute Detect → Classify → Document → Verify:

1. **Detect** — run `evidenceHints[]` globs against the target repository; collect file matches.
2. **Classify** — assign one verdict from the [Verdict Ladder](#verdict-ladder) (`verified`, `present`, `partial`, `unknown`, `absent`, or `n/a`) based on detected evidence and user confirmation. The Evidence Exhaustion Rule must be completed before any non-`verified` verdict; use `unknown` until it is.
3. **Document** — append the result to `state.capabilityInventory[]` with the record shape `{capabilityId, framework, status, evidence, notes}`. `framework` is the inventory id (`capability-inventory-web` or `capability-inventory-content`); `evidence` is an array of cited file paths (with line numbers when relevant) and live-endpoint snapshots; `notes` captures Evidence Exhaustion Rule observations and surface-kind exclusion rationale.
4. **Verify** — for `verified` status only, confirm the cited evidence is reproducible (CI run with passing axe report, manual audit report dated within review cadence, AT-pass log signed off by reviewer). When the capability requires a live endpoint, record the fetched score and timestamp.

## Question Cadence

Group capability questions per inventory skill rather than per capability. For each inventory in scope, ask one batched question that lists every in-scope capability with its current detected posture and asks the user to confirm verdicts and supply evidence for any that the planner could not resolve from `evidenceHints[]` alone. When the host supports a multi-select question tool, render every capability as a pre-checked option labeled with its detected verdict; otherwise, present a single batched question with safe defaults and ask the user to reply with capability ids to override plus brief reasons. Never serialize as N separate questions per inventory.

Persist every user-supplied override in `state.capabilityInventory[].notes` with the prompt timestamp so the audit trail shows when each verdict was confirmed.

## Entry Modes

Phase 1 entry modes (`capture`, `from-prd`, `from-brd`, `from-security-plan`) determine which capability inventories are in scope by populating `context.surfaces` and `context.complianceTargets`. Inventories with non-overlapping `appliesTo` are skipped (for example, a content-authoring-only project skips `capability-inventory-web`).

## Registering a New Capability Inventory

1. Create `.github/skills/accessibility/capability-inventory-<scope>/` with `SKILL.md`, `index.yml`, and per-capability YAML files.
2. Validate with `npm run validate:skills`.
3. Validate each capability against the planner-framework-control schema.
4. Add the new skill to `collections/accessibility.collection.yml` if it ships with the accessibility collection.
5. Add a new row to the Wave 1 Capability Inventories table above when the inventory is promoted out of draft and into the default-loaded set.

No edits to this instruction file's contract sections are required.

## Output

Write `surface-assessment.md` to `.copilot-tracking/accessibility-plans/{project-slug}/surface-assessment.md`. Group rows by source inventory. For each capability include: id, title, current posture, evidence list, source skill path, and surface-kind applicability note.

Update `state.json`:

* Append every loaded capability to `state.capabilityInventory[]` using the record shape `{capabilityId, framework, status, evidence, notes}`.
* Append every `read_file` of a skill artifact to `state.skillsLoaded[]` as append-only NDJSON entries.
* Set `phase` to `standards-mapping` once assessment is complete, the Phase 3 entry gate is clear (no `unknown` rows), and the user has confirmed the batched per-inventory verdicts.
