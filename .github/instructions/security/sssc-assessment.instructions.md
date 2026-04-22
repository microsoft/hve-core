---
description: "Phase 2 supply chain assessment contract — discovers capability inventory skills under .github/skills/security/capability-inventory-* and populates state.capabilityInventory."
applyTo: '**/.copilot-tracking/sssc-plans/**'
---

# SSSC Phase 2 — Supply Chain Assessment (Capability-Skill Consumer Contract)

This file is a **consumer contract**. The 27 combined hve-core / physical-ai-toolchain capabilities are no longer encoded inline. The planner discovers capability inventories by reading skills under `.github/skills/security/capability-inventory-*/`. Adding or replacing an inventory requires no edits to this file.

## Phase 2 Pre-Flight Checklist

Before scoring any control in this phase, the planner reads the following inputs. This is the procedural enforcement of the Evidence Exhaustion Rule, applied at phase entry rather than per control.

1. `SECURITY.md` and every file it links to (follow every relative or absolute repo link, including indirect chains).
2. The security section of `README.md` and every file it links to.
3. Every file under `security/` (or any directory whose name starts with `security`), recursively.
4. Every file under `contributing/` (or `CONTRIBUTING.md` and `.github/CONTRIBUTING.md`) whose name contains `branch`, `review`, `code-of-conduct`, or `security`.
5. `CHANGELOG.md`, grepped for the canonical artifact keyword set in the [Evidence Exhaustion Rule](#evidence-exhaustion-rule-mandatory-before-any-non-verified-verdict) item 2, and additionally for every framework name and tier name in scope (for example `OSSF`, `OpenSSF`, `bestpractices`, `silver`, `gold`, `scorecard`, `SLSA`, `level 2`).
6. The full file listing of `.github/workflows/` (read each workflow that matches any control's `evidenceHints[]`).
7. Every status badge URL discovered in `README.md` or under `docs/` whose target is a tier-encoding or score-encoding endpoint (for example `bestpractices.dev/projects/<id>`, `api.securityscorecards.dev`, `slsa.dev/level/<n>`). Fetch the live endpoint and record the returned tier or score in the inputs log; markdown alone does not encode the current tier.

Record each pre-flight read in `skills-loaded.log` (or the equivalent inputs log) so the audit trail shows the inputs were consulted before scoring began. A control may not be assigned a verdict other than `unknown` until the pre-flight reads relevant to that control are complete.

## Evidence Exhaustion Rule (mandatory before any non-verified verdict)

Before assigning a `partial`, `absent`, or `n/a` verdict to any control, the agent completes the following six checks. If any check surfaces evidence that has not yet been read, the agent reads that evidence before scoring.

1. **Trace cross-references.** If `SECURITY.md`, `README.md`, `CONTRIBUTING.md`, or any policy stub links to or names another document (for example anything under `security/`, `contributing/`, `architecture/`), open and read that target before scoring. Short policy files frequently delegate substance to longer companion docs.
2. **Search for canonical artifact names and tier names.** Run a workspace search for the artifact's standard names before declaring it absent. At minimum search for: `threat-model`, `security-model`, `assurance-case`, `STRIDE`, `trust-boundary`, `branch-protection`, `remediation`, `SLA`, `severity`, `deprecat`, `sunset`, `EOL`, `license-check`, `allow-licenses`, `fail-on-severity`, `attest-build-provenance`, `attest-sbom`, `gh attestation`, `cosign`, `gitsign`. When scoring a tiered framework (badge, scorecard, maturity model), also search for the framework name and every tier name (for example `OSSF`, `OpenSSF`, `bestpractices`, `passing`, `silver`, `gold`, `scorecard`, `SLSA`, `level 1`/`level 2`/`level 3`).
3. **Check `CHANGELOG.md` for historical additions and tier-targeted PRs.** A control may have been added in a prior release under a non-obvious filename, and tier-advancement campaigns are typically announced in CHANGELOG entries. A grep for the control's domain keywords in `CHANGELOG.md` is required before assigning `absent`. For tiered frameworks, additionally grep for the framework and tier names from check 2; PRs explicitly tagged "for Silver", "for Gold", "Scorecard", etc., are positive evidence of an active or completed tier-advancement campaign.
4. **Consider equivalents.** If a control names a specific tool (for example `cosign sign`), check for functional equivalents that use the same underlying primitives (for example `actions/attest-build-provenance` and `gh attestation verify` both use Sigstore Fulcio plus Rekor and are functionally equivalent to `cosign sign-blob` and `cosign verify-blob`). Score equivalents as `verified`, not `partial`. When the framework skill declares `equivalentImplementations` for a control, treat presence of any listed equivalent as full credit.
5. **Fetch live endpoints for status badges and dynamic indicators.** Static markdown shows a generic badge URL (for example `https://www.bestpractices.dev/projects/11795/badge` or `https://api.securityscorecards.dev/...`); the current tier or score is encoded in the rendered SVG/JSON, not in the markdown. When a control's `evidenceHints` reference an external badge or status endpoint, or when README/docs link to one (`bestpractices.dev/projects/<id>`, `api.securityscorecards.dev`, `slsa.dev/level/<n>`, etc.), fetch the live endpoint and record the returned tier/score in the inputs log before scoring. Do not infer tier from the markdown image URL alone.
6. **Trust converging in-repo evidence.** When two or more independent in-repo artifacts (CHANGELOG entries, GOVERNANCE.md, ROADMAP.md, SECURITY.md, threat models, dedicated docs under `security/` or `architecture/`) explicitly name the same control, tier, or framework deliverable, score the control as `verified` and cite all converging artifacts. Conservative-by-default scoring (`partial` or `claim-ready`) is forbidden when in-repo evidence converges; either fetch the live endpoint to disconfirm (check 5) or accept the converging evidence as verified.

The six checks must be completed before assigning a non-`verified` verdict. Use the `unknown` verdict (see [Verdict Ladder](#verdict-ladder)) when the checks have not been completed; do not use `partial` as a placeholder for "not yet inspected".

## Verdict Ladder

The following verdicts are the only valid posture values the planner records for a control row. The categorical `categories: [absent, partial, present, verified]` set in per-control YAML defines authoring-time enums; `unknown` and `n/a` are planner-applied states surfaced in the assessment output and `state.capabilityInventory[].verdict` field.

* **verified** — Positive evidence of full coverage. Cite the specific file and line.
* **present** — Artifact exists but full conformance to the control is not yet confirmed; cite the artifact.
* **partial** — Positive evidence of partial coverage. Required: cite both what is present and the specific gap.
* **unknown** — The Evidence Exhaustion Rule has not been completed for this control. Either complete the rule or ask the user a follow-up question. `unknown` is not a final verdict; it must be resolved before Phase 3 closes.
* **absent** — Positive evidence the control is not implemented after the Evidence Exhaustion Rule has been completed.
* **n/a** — Control does not apply. Cite reason (alternative satisfied, applicability discriminator, repo-settings-only, etc.).

`partial` requires positive evidence of incomplete coverage. Absence of inspection is `unknown`, not `partial`.

### Phase 3 Exit Gate

Phase 3 (standards mapping) cannot close while any control row carries a `verdict` of `unknown`. The planner must either complete the Evidence Exhaustion Rule for the control or capture a user follow-up answer that resolves the verdict to one of `verified`, `present`, `partial`, `absent`, or `n/a`. `Validate-PlannerArtifacts.ps1` enforces this gate on the assessment output before allowing `phase` to advance past `standards-mapping`.

## Capability Inventory Discovery Protocol

Each capability inventory is a self-contained skill containing:

* `SKILL.md` — entrypoint metadata describing the inventory's source repository and scope.
* `index.yml` — `inventory`, `version`, `appliesTo` (target ecosystems), and `capabilities[]` listing every capability id contributed by this skill.
* `controls/<capability-id>.yml` — one file per capability, validated against [`scripts/linting/schemas/planner-framework-control.schema.json`](../../../scripts/linting/schemas/planner-framework-control.schema.json).

The planner enumerates `.github/skills/security/capability-inventory-*/index.yml` and registers each capability as a `capabilityEntry` in `state.json` (see [`scripts/linting/schemas/sssc-state.schema.json`](../../../scripts/linting/schemas/sssc-state.schema.json) `$defs.capabilityEntry`).

## Hard Loading Contract

1. Read `index.yml` for every capability-inventory skill in scope (filtered by Phase 1 `appliesTo` matching the project's `techStack`).
2. Read **only** the `controls/<capability-id>.yml` files for capabilities listed in those `index.yml` files.
3. Append one entry per `read_file` of any skill artifact to `skills-loaded.log` (see Identity instructions).

## Per-Capability Field Usage

For each `controls/<capability-id>.yml` loaded:

* `id`, `title` — capability row identifier and human-readable label.
* `assessmentMethod: categorical` with `categories: [absent, partial, present, verified]` — the only valid posture values.
* `evidenceHints[]` — deterministic file globs (workflow paths, script paths, config files) the planner inspects to suggest current posture.
* `mapsTo[]` — cross-framework links (which Scorecard checks, SLSA levels, or SSDF tasks the capability satisfies) used to seed Phase 3 mapping.
* `gates[]` — assessment gates with `status: pending` until evidence is collected.

## Assessment Protocol

For every capability discovered, execute Detect → Classify → Document → Verify:

1. **Detect** — run `evidenceHints[]` globs against the target repository; collect file matches.
2. **Classify** — assign one verdict from the [Verdict Ladder](#verdict-ladder) (`verified`, `present`, `partial`, `unknown`, `absent`, or `n/a`) based on detected evidence and user confirmation. The Evidence Exhaustion Rule must be completed before any non-`verified` verdict; use `unknown` until it is.
3. **Document** — write the result to `state.capabilityInventory[]` with the evidence list.
4. **Verify** — for `verified` status only, confirm signed/attested artifacts exist (cosign signature, SLSA provenance, signed SBOM).

## Entry Modes (Unchanged)

Phase 1 entry modes (`capture`, `from-prd`, `from-brd`, `from-security-plan`) determine which capability inventories are in scope by populating `context.techStack` and `context.complianceTargets`. Inventories with non-overlapping `appliesTo` are skipped.

## Registering a New Capability Inventory

1. Create `.github/skills/security/capability-inventory-<scope>/` with `SKILL.md`, `index.yml`, and `controls/<capability-id>.yml` files.
2. Validate with `npm run validate:skills`.
3. Validate each control against the planner-framework-control schema.
4. Add the new skill to `collections/security.collection.yml` if it is to ship with the security collection.

No edits to this instruction file are required.

## Output

Write `supply-chain-assessment.md` to `.copilot-tracking/sssc-plans/{project-slug}/supply-chain-assessment.md`. Group rows by source inventory. For each capability include: id, title, current posture, evidence list, source skill path.

Update `state.json`:

* Append every loaded capability to `capabilityInventory[]`.
* Append every `read_file` of a skill artifact to `skillsLoaded[]`.
* Set `phase` to `standards-mapping` once assessment is complete and user-confirmed.
