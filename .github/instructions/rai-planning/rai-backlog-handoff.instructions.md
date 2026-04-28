---
description: 'RAI review and backlog handoff for Phase 6: review rubric, dual-format backlog generation, autonomy tiers, and Security Planner cross-references'
applyTo: '**/.copilot-tracking/rai-plans/**'
---

# RAI Review and Backlog Handoff

Phase 6 mechanics for the RAI Planner. Templates for the review summary, ADO work items, GitHub issues, transparency note, monitoring summary, and handoff summary are owned by the `rai-output-formats` framework skill (`phaseMap.phase-6-handoff`). This file defines only the planner mechanics: review rubric scoring, work item categorization, autonomy tier selection, priority derivation, cross-reference protocol, content sanitization, and audience adaptation.

Source-of-truth resolution:

* Review summary, ADO work item, GitHub issue, transparency note outline, monitoring summary, and handoff summary templates → `rai-output-formats` items keyed under `phaseMap.phase-6-handoff`.
* Trustworthiness characteristics referenced in tags and the per-characteristic summary → resolved through `frameworkSkillsActive` (default: `nist-ai-rmf`); never inlined here.
* Priority ladder, Concern Level model, and tie-break rules → `.github/instructions/shared/planner-priority-rules.instructions.md`.
* Disclaimer block appended to every external artifact → `.github/instructions/shared/disclaimer-language.instructions.md`.

When a required Phase 6 template is absent from the active framework skills, halt and ask the user to add it. Do not improvise.

## Review Rubric

A review checkpoint plus six quality dimensions evaluate completeness before backlog generation proceeds.

### Review Checkpoints

| Checkpoint      | Criteria                                                             | Status            |
|-----------------|----------------------------------------------------------------------|-------------------|
| Threat Coverage | Every RAI threat has at least one control surface and evidence entry | ☐ Met / ☐ Not Met |

A checkpoint marked "Not Met" indicates the relevant phase should be revisited before handoff.

### Review Quality Checklist

| Dimension             | Description                                                                  | Status      |
|-----------------------|------------------------------------------------------------------------------|-------------|
| Standards Alignment   | Coverage of activated framework skills' principles/controls                  | ☐ Addressed |
| Threat Completeness   | AI STRIDE coverage, dual threat ID consistency, ML STRIDE matrix completion  | ☐ Addressed |
| Control Effectiveness | Control surface coverage across Prevent/Detect/Respond per principle         | ☐ Addressed |
| Evidence Quality      | Evidence register completeness, confidence levels, gap identification        | ☐ Addressed |
| Tradeoff Resolution   | Tradeoff documentation quality, stakeholder impact, decision authority       | ☐ Addressed |
| Risk Classification   | Risk classification coverage, depth tier justification, downstream alignment | ☐ Addressed |

Review status derivation:

* **Ready for stakeholder review** — All dimensions addressed with supporting evidence.
* **Additional attention suggested** — Most dimensions addressed; one or more areas flagged.
* **Significant areas need further consideration** — Multiple dimensions have limited coverage or missing evidence.

Before presenting results, explain the dimensions in plain language and frame all assessments as suggested observations. When presenting, cite specific session observations for each dimension.

## Per-Principle Maturity Summary

The review summary template (`rai-output-formats` Phase 6) renders one row per active principle. Populate from `principleTracker`:

* Maturity level — from the Phase 5 assessment value (`Foundational | Developing | Established | Advanced`).
* Key observations — the most significant entries from `openObservations` and `resolvedObservations`.
* Open item count — `openObservations.length`.

When `principleTracker` data is incomplete for a principle, note the gap in the Key Observations column and suggest revisiting the relevant phase.

## Work Item Categories

Five categories classify RAI work items by purpose and urgency.

| Category               | Description                                                | Suggested Horizon  | Concern Level | Source                                                |
|------------------------|------------------------------------------------------------|--------------------|---------------|-------------------------------------------------------|
| Remediation            | Address identified RAI gaps or areas of concern            | Pre-Production     | High–Critical | Evidence gaps, principles with limited coverage       |
| Control Implementation | Implement new Prevent/Detect/Respond controls              | Pre-Production     | Moderate–High | Control surface gaps                                  |
| Monitoring Setup       | Deploy detection and monitoring capabilities               | Early Operations   | Moderate      | Detect controls without implementation                |
| Documentation          | Create or update transparency and accountability artifacts | Ongoing Governance | Low–Moderate  | Documentation gaps, tradeoff records                  |
| Enhancement            | Improve existing controls toward higher maturity           | Ongoing Governance | Low           | Principles at Developing/Established seeking Advanced |

Concern Level → priority mapping is defined in `planner-priority-rules.instructions.md`.

## RAI Tags

Tags applied to work items for tracking and filtering. Principle-scoped tags are derived dynamically from the active framework skills using the pattern `rai:<principle-id>` (slugified principle id from each `items/*.yml`). The cross-cutting tags below are emitted by every RAI session regardless of activated frameworks.

| Tag                       | Purpose                                | Applied When                                                |
|---------------------------|----------------------------------------|-------------------------------------------------------------|
| `rai:tradeoff`            | Tradeoff resolution item               | Originates from tradeoff documentation                      |
| `rai:cross-ref-security`  | Cross-references Security Planner item | Overlaps with or extends a Security Planner work item       |
| `rai:depth-{tier}`        | Records selected depth tier            | Always; `{tier}` is `basic`, `standard`, or `comprehensive` |
| `rai:framework-{skillId}` | Records activated framework skill      | One tag per entry in `frameworkSkillsActive`                |

For GitHub labels, strip the `rai:` prefix.

## Target System Selection

Select the template based on `userPreferences.targetSystem`:

* **ado** — Use the ADO work item template from `rai-output-formats` (`phaseMap.phase-6-handoff`).
* **github** — Use the GitHub issue template from `rai-output-formats`.
* **both** — Generate both formats for dual-system environments.

Default to the format specified in user preferences. If no preference was set, ask the user which system(s) to target.

## Work Item ID Conventions

Assign sequential IDs within the RAI plan distinct from Security Planner IDs to prevent collisions:

* ADO: `WI-RAI-{NNN}` (vs. Security Planner `WI-SEC-{NNN}`).
* GitHub temporary IDs: `{{RAI-TEMP-N}}` (vs. Security Planner `{{SEC-TEMP-N}}`), replaced with real issue numbers on creation.

Work item hierarchy maps from the RAI assessment structure:

* Epic — Active framework principle (one per principle with findings).
* Feature — Control category (Prevent, Detect, Respond per principle).
* User Story — Specific control or mitigation.
* Task — Implementation steps for a user story.
* Bug — Suggested RAI area requiring attention.

ADO execution follows `ado-update-wit-items.instructions.md`. GitHub execution follows `github-backlog-update.instructions.md`.

## Three-Tier Autonomy Model

Three tiers control how RAI work items reach the target backlog system.

| Tier    | Description                                              | Applies When                                                 |
|---------|----------------------------------------------------------|--------------------------------------------------------------|
| Full    | Agent creates work items without human approval          | Enhancement items (Backlog priority), documentation updates  |
| Partial | Agent drafts work items for human review before creation | Control implementation (Planned–Near-term), monitoring setup |
| Manual  | Agent provides recommendations; human creates items      | Remediation (Immediate–Near-term), tradeoff decisions        |

Ask the user in Phase 6 which tier they prefer. Default to Partial on first use. Persist the selection in `state.userPreferences.autonomyTier`.

## Suggested Priority Derivation

Derive Concern Level from assessment observations, then map to priority via `planner-priority-rules.instructions.md`. Autonomy tier and horizon follow from category and Concern Level.

| Assessment Observation                                | Concern Level | Autonomy Tier | Suggested Horizon  |
|-------------------------------------------------------|---------------|---------------|--------------------|
| Principle at Foundational maturity with critical gaps | Critical      | Manual        | Pre-Production     |
| Principle at Foundational maturity                    | High          | Manual        | Pre-Production     |
| Multiple open observations for a principle            | High          | Partial       | Pre-Production     |
| Tradeoff requiring implementation                     | Moderate      | Partial       | Early Operations   |
| Control surface gap (Prevent)                         | High          | Partial       | Pre-Production     |
| Control surface gap (Detect)                          | Moderate      | Partial       | Early Operations   |
| Control surface gap (Respond)                         | Moderate      | Partial       | Early Operations   |
| Documentation gap                                     | Low           | Full          | Ongoing Governance |
| Enhancement recommendation                            | Low           | Full          | Ongoing Governance |

Tie-break rules:

* Within a Concern Level, order Remediation before Control Implementation.
* When multiple observations apply to a single work item, use the highest Concern Level.
* When work item A depends on work item B, note the dependency in both bodies and place B earlier in the handoff sequence.

## Cross-Reference Protocol for Security Planner Interop

RAI work items relate to Security Planner work items when threats overlap.

Rules:

* When an RAI threat overlaps with a Security Planner threat (identified by dual `T-{BUCKET}-AI-{NNN}` IDs from Phase 4), the RAI work item includes a cross-reference field.
* Security Planner work items are not duplicated; RAI items extend or complement them instead.
* Cross-reference format: `Security-Ref: WI-SEC-{NNN}` in ADO, `Security: #{NNN}` in GitHub.
* The handoff summary includes a cross-reference table listing all overlapping items.
* Before creating new work items, search for existing Security Planner items with matching threat IDs or control surfaces. Link rather than duplicate.

Relationship types recorded in the cross-reference table:

* **Extends** — RAI item adds RAI-specific requirements to an existing security control.
* **Complements** — RAI item addresses a different aspect of the same threat.
* **Depends** — RAI item requires the security control to be implemented first.

The cross-reference table template lives in `rai-output-formats` (`phaseMap.phase-6-handoff`).

## Content Sanitization Protocol

Strip internal tracking paths and sensitive assessment details from work item output before handoff to external systems.

Sanitization rules:

1. Replace `.copilot-tracking/` paths with descriptive text (for example, "RAI plan artifacts").
2. Replace full file system paths with relative references.
3. Remove state JSON content or references.
4. Remove internal tracking IDs that are not work item IDs.
5. Preserve standards references resolved through active framework skills (principle ids, subcategory references) in all cases.

After generating each work item, scan the output for `.copilot-tracking/`. If found, strip the path and log the sanitization action.

Debug mode: Retain full paths in `.copilot-tracking/rai-plans/{slug}/debug/` output only. Paths never appear in external-facing work items.

## Optional Artifacts

During Phase 6, offer each optional artifact independently. Generate only those the user opts into. Each accepted artifact produces a corresponding "Documentation" category work item for completion.

| Artifact           | Prompt                                                                      | Template Source        | Generated Follow-Up Work Item                                              |
|--------------------|-----------------------------------------------------------------------------|------------------------|----------------------------------------------------------------------------|
| Transparency Note  | "Would you like a transparency note outline included in the handoff?"       | `rai-output-formats`   | `[RAI] Complete transparency note from Phase 6 outline` (Planned–Backlog)  |
| Monitoring Summary | "Would you like a consolidated monitoring summary included in the handoff?" | `rai-output-formats`   | `[RAI] Validate and operationalize monitoring summary` (Planned)           |
| Artifact Signing   | "Would you like cryptographic signing of all session artifacts?"            | n/a (script execution) | `[RAI] Verify artifact manifest integrity and configure signing` (Planned) |

When the monitoring summary is accepted, auto-populate from "Monitoring Setup" category work items generated during the assessment.

When artifact signing is accepted, invoke `npm run rai:sign -- -ProjectSlug {project-slug}` via terminal execution. The script generates a SHA-256 manifest (`artifact-manifest.json`) covering all files in the project directory and optionally signs it with cosign when available. After execution completes, update `state.json` fields `signingRequested` to `true` and `signingManifestPath` to the manifest output path. If the user also requests cosign signing, append `-IncludeCosign` to the command. Cosign uses keyless signing via Sigstore; it requires `cosign` in PATH and an OIDC identity provider.

## Handoff Summary

After generating all work items, produce a handoff summary using the template in `rai-output-formats` (`phaseMap.phase-6-handoff`). The template renders work item totals, horizon breakdown, Security Planner cross-references, outstanding tradeoffs, next steps, and the standard disclaimer.

Log all generation decisions (create, update, skip, link) in the handoff summary. Items that could not be generated include the reason for each failure.

## Evidence Citation Format

All evidence references emitted by handoff artifacts (review-rubric citations, work-item bodies, cross-reference protocol entries, optional artifacts) follow the canonical evidence row format defined in #file:../shared/evidence-citation.instructions.md. Use that format for every `path (Lines start-end)` reference; apply `kind:` qualifiers (`file-presence`, `live-endpoint`, `external-doc`) when a citation is not a line-spanned in-repo reference.

## Audience Adaptation

Adjust handoff output formatting based on `userPreferences.audienceProfile`:

* **technical** — Full implementation detail with control specifications, threat IDs, and suggested monitoring thresholds.
* **executive** — High-level summary with business impact, principle maturity overview, and key action items.
* **compliance** — Full detail with regulatory mapping, standards traceability, and audit trail references.
* **mixed** — Balanced format with executive summary followed by technical detail sections.

Default to **technical** when no preference is set. The audience profile affects the review summary, work item descriptions, and handoff summary formatting; it does not change which templates are loaded.
