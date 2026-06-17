---
description: Accessibility backlog handoff protocol consuming impact-assessment state and writing handoff artifacts
---

# Accessibility Backlog Handoff


This phase consumes state produced by `references/impact-assessment.md` and writes handoff artifacts under `.copilot-tracking/`. The phase exits when the user confirms the rendered backlog and the planner sets `gates.backlog-handoff.confirmed = true`.

## Handoff Protocol

Phase 6 executes a fixed six-step sequence. Steps run in order; each step gates the next.

1. **Read state** — Load `state.json` for the project slug. Validate that `gates.impact-evidence.confirmed = true` and that `workItemSeeds`, `evidenceRegister`, and (when populated) `tradeoffLog` are present.
2. **Resolve target system** — Read `userPreferences.targetSystem` if set. When unset, ask the user whether to render `ado`, `github`, or `both`. Persist the response under `userPreferences.targetSystem`.
3. **Run the review rubric** — Walk the checkpoints and quality checklist below. Record findings into the Accessibility Review Summary template. Block the rest of the phase if any checkpoint is Not Met.
4. **Render work items** — Apply the dual-format templates to every seed in `workItemSeeds`. Derive suggested priority and autonomy tier per the mapping table. Attach evidence cross-links, tradeoff cross-links, and cross-planner refs.
5. **Sanitize and emit** — Apply the content sanitization protocol, write ADO output to `.copilot-tracking/workitems/backlog/{project-slug}-a11y/work-items.md` and GitHub output to `.copilot-tracking/github-issues/discovery/{project-slug}-a11y/issues-plan.md`, include the disclaimer block in the generated artifacts, then emit the professional-review reminder and handoff summary.
6. **Finalize state** — Update `state.json` per the Final State Update section. Set `gates.backlog-handoff.confirmed = true` only after the user explicitly confirms the rendered backlog.

The phase is non-destructive. Re-running Phase 6 regenerates output files in place but preserves any user-supplied content under a `## User Notes` heading at the bottom of each output file.

## Review Rubric

The rubric has two parts: binary checkpoints that gate the phase, and a six-dimension quality checklist that informs the suggested review status.

### Review Checkpoints

Every checkpoint must read Met before work items render. A Not Met checkpoint blocks the phase and returns the user to the named upstream phase.

| Checkpoint            | Pass Criterion                                                                                                                                 | Block Returns To              |
|-----------------------|------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------|
| Phase Gates           | `gates.discovery`, `gates.framework-selection`, `gates.standards-mapping`, `gates.plan-risk-assessment`, `gates.impact-evidence` all `true`    | Identity Phase Recovery       |
| Seed Coverage         | Every `controlMappings` entry with `status` in (`gap`, `partial`) maps to at least one `workItemSeeds` entry OR a `deferredMitigations` record | Phase 5: Impact and Evidence  |
| Evidence Linkage      | Every seed lists at least one `evidenceRefs` entry that resolves to an `evidenceRegister` id                                                   | Phase 5: Impact and Evidence  |
| Tradeoff Acceptance   | Every `tradeoffLog` entry has `acceptedBy` populated when seeds reference it                                                                   | Phase 4: Plan Risk Assessment |
| Framework Disablement | Every framework with `enabled: false` carries an atomic `disabled` + `disabledReason` + `disabledAtPhase` bundle                               | Phase 2: Framework Selection  |
| Cross-Planner Refs    | When `raiPlanRef`, `securityPlanRef`, or `ssscPlanRef` is set, `crossPlannerRefs` contains at least one entry pointing at the linked plan      | Phase 5: Impact and Evidence  |

### Review Quality Checklist

Six dimensions inform the suggested review status (Ready for stakeholder review, Additional attention suggested, Significant areas need further consideration). Each dimension scores Strong / Adequate / Limited based on the criteria below.

| Dimension               | Strong                                                                      | Adequate                                               | Limited                                              |
|-------------------------|-----------------------------------------------------------------------------|--------------------------------------------------------|------------------------------------------------------|
| Framework Coverage      | All enabled frameworks have control mappings for every in-scope surface     | One enabled framework has partial surface coverage     | Multiple enabled frameworks missing surface coverage |
| Surface Coverage        | Every `project.surfaces` value has at least one seed                        | One surface missing seeds despite gaps in mappings     | Multiple surfaces missing seeds                      |
| Persona Impact          | Every critical/major seed names affected `personaImpact`                    | Some seeds omit `personaImpact` but rationale recorded | `personaImpact` absent across most seeds             |
| Evidence Quality        | Evidence is `verified` for >75% of seeds                                    | Evidence is `verified` or `pending` for >75% of seeds  | Evidence is mostly `pending` or missing              |
| Tradeoff Resolution     | All tradeoffs accepted with mitigations and owners                          | Tradeoffs accepted but mitigations underspecified      | Tradeoffs open or missing owner                      |
| Risk Tier Justification | `riskClassification.tier` matches screening signals with explicit rationale | Tier recorded but rationale brief                      | Tier set without rationale or contradicts signals    |

Score mapping for the summary: Strong across all six = Ready for stakeholder review; one or two Limited = Additional attention suggested; three or more Limited = Significant areas need further consideration.

## Accessibility Review Summary

Populate this template before rendering work items. Insert it as the first section of the ADO and GitHub output files.

```markdown
# Accessibility Review Summary

## Project: {project.name} ({project.slug})
## Date: {YYYY-MM-DD}
## Risk Tier: {basic|standard|comprehensive}
## Suggested Review Status: {Ready for stakeholder review | Additional attention suggested | Significant areas need further consideration}

### Frameworks In Scope

| Framework | Version | Conformance Level | Notes |
|-----------|---------|-------------------|-------|
| {id} | {version} | {A|AA|AAA|N/A} | {notes} |

### Surfaces In Scope

| Surface   | Personas Affected | Open Seeds |
|-----------|-------------------|------------|
| {surface} | {personas}        | {count}    |

### Quality Checklist

| Dimension | Score | Key Observation |
|-----------|-------|-----------------|
| Framework Coverage | {Strong|Adequate|Limited} | {observation} |
| Surface Coverage | {Strong|Adequate|Limited} | {observation} |
| Persona Impact | {Strong|Adequate|Limited} | {observation} |
| Evidence Quality | {Strong|Adequate|Limited} | {observation} |
| Tradeoff Resolution | {Strong|Adequate|Limited} | {observation} |
| Risk Tier Justification | {Strong|Adequate|Limited} | {observation} |

### Cross-Planner References

| Linked Planner | Plan Reference | Seeds Sharing Controls |
|----------------|----------------|------------------------|
| {rai-planner|security-planner|sssc-planner} | {planRef} | {count} |

### AI-Generated Content Note

This summary was drafted with AI assistance. Review and validate every seed, evidence link, and tradeoff before treating the backlog as authoritative.
```

## Work Item Categories

Five categories classify accessibility work items by purpose and urgency.

| Category                   | Description                                                              | Suggested Horizon  | Priority Range      | Source                                                              |
|----------------------------|--------------------------------------------------------------------------|--------------------|---------------------|---------------------------------------------------------------------|
| Remediation                | Close a `gap` on a WCAG Level A or Section 508 functional criterion      | Pre-Production     | Immediate–Near-term | `controlMappings.status = gap` and `severity = critical`            |
| Control Implementation     | Add or harden an accessibility control covering a partial mapping        | Pre-Production     | Near-term–Planned   | `controlMappings.status = partial` and `severity in (major, minor)` |
| Documentation              | Author or update VPAT, ACR, accessibility statement, or training docs    | Ongoing Governance | Planned–Backlog     | Evidence type `document` or `attestation` missing                   |
| Monitoring and Audit Setup | Schedule recurring audits, automated scans, or assistive-tech regression | Early Operations   | Planned             | Evidence type `audit-result` or `test-result` missing               |
| Enhancement                | Pursue AAA, COGA, or persona-driven uplift beyond baseline               | Ongoing Governance | Backlog             | `severity = enhancement`                                            |

## Accessibility Tags

Tags apply to work items in both ADO and GitHub for filtering, dashboards, and cross-planner queries. GitHub strips the `a11y:` prefix when rendering labels for repos that disallow colons.

| Tag                       | Purpose                                           | Applied When                                  |
|---------------------------|---------------------------------------------------|-----------------------------------------------|
| `a11y:wcag-22`            | WCAG 2.2 conformance work                         | Seed `framework = wcag-22`                    |
| `a11y:aria-apg`           | ARIA Authoring Practices Guide work               | Seed `framework = aria-apg`                   |
| `a11y:coga`               | Cognitive Accessibility work                      | Seed `framework = coga`                       |
| `a11y:section-508`        | US Section 508 conformance work                   | Seed `framework = section-508`                |
| `a11y:en-301-549`         | EN 301 549 conformance work                       | Seed `framework = en-301-549`                 |
| `a11y:web`                | Web surface affected                              | Seed `surface = web`                          |
| `a11y:mobile`             | Mobile surface affected                           | Seed `surface = mobile`                       |
| `a11y:desktop`            | Desktop surface affected                          | Seed `surface = desktop`                      |
| `a11y:documents`          | Document surface affected                         | Seed `surface = documents`                    |
| `a11y:kiosk`              | Kiosk surface affected                            | Seed `surface = kiosk`                        |
| `a11y:voice`              | Voice surface affected                            | Seed `surface = voice`                        |
| `a11y:tradeoff`           | Originates from an accepted tradeoff              | Seed references `tradeoffLog` entry           |
| `a11y:cross-ref-security` | Cross-references a Security Planner item          | `crossPlannerRefs.planner = security-planner` |
| `a11y:cross-ref-rai`      | Cross-references an RAI Planner item              | `crossPlannerRefs.planner = rai-planner`      |
| `a11y:cross-ref-sssc`     | Cross-references an SSSC Planner item (VPAT, EAA) | `crossPlannerRefs.planner = sssc-planner`     |

## Target System Selection

Target system selection (ADO, GitHub, both) follows the canonical convention in `.github/skills/shared/backlog-templates/SKILL.md` under the Overview's Output Targets table. Accessibility emits the neutral intermediate to `.copilot-tracking/accessibility/{slug}/backlog-handoff.md`; platform-specific files derive per the skill's Per-Platform Field Mappings.

## Dual-Format Backlog Templates

Both ADO and GitHub formats follow the canonical templates, field blocks, augmentation keys, title prefix, and temporary-ID conventions defined in `.github/skills/shared/backlog-templates/SKILL.md`. Read the accessibility entries under "ADO Work Item Template", "GitHub Issue Template", and "Work Item ID Naming Convention" at emission time. Accessibility tag and label vocabulary lives in `## Accessibility Tags` above.

## Severity-to-Field Mapping

Severity drives ADO Priority numerics and GitHub label sets. The planner emits these field values without renegotiating with the user.

| Severity    | ADO Priority | GitHub Labels                              | Notes                                                                 |
|-------------|--------------|--------------------------------------------|-----------------------------------------------------------------------|
| critical    | 1            | `priority:immediate`, `severity:critical`  | WCAG Level A gap or Section 508 functional performance criterion gap  |
| major       | 2            | `priority:near-term`, `severity:major`     | WCAG AA gap or Level A partial                                        |
| minor       | 3            | `priority:planned`, `severity:minor`       | WCAG AA partial or AAA gap when AAA is in scope                       |
| enhancement | 4            | `priority:backlog`, `severity:enhancement` | Opportunistic uplift; covered mapping with persona-driven improvement |

When the seed framework is `coga` and `riskClassification.tier = comprehensive`, escalate the severity one level (critical stays critical; enhancement becomes minor). Record the escalation in the seed's `notes` field for audit traceability.

## Autonomy-Tier Routing

The three-tier autonomy model is defined canonically in `.github/skills/shared/backlog-templates/SKILL.md` under `Autonomy-Tier Enumeration`. Accessibility uses the canonical vocabulary directly: `manual`, `supervised`, and `autonomous` (matching the seed-schema `autonomyTier` enum). Accessibility-specific severity-to-tier routing: seed `severity = critical` or seed references an open tradeoff routes to `manual`; seed `severity in (major, minor)` routes to `supervised`; seed `severity = enhancement` with `evidence.status = verified` routes to `autonomous`. The default tier on first use is `supervised`. Persist the user's response under `userPreferences.autonomyTier`.

## Suggested Priority Derivation

Derive suggested priority, autonomy tier, and remediation horizon from the seed metadata. The table below is the canonical mapping; the planner does not negotiate these defaults with the user during rendering.

| Seed Condition                                                          | Suggested Priority | Autonomy Tier | Suggested Horizon  |
|-------------------------------------------------------------------------|--------------------|---------------|--------------------|
| Severity `critical` and framework in (`wcag-22`, `section-508`)         | Immediate          | manual        | Pre-Production     |
| Severity `critical` and framework in (`aria-apg`, `coga`, `en-301-549`) | Immediate          | manual        | Pre-Production     |
| Severity `major` and `assistiveTechValidated` required                  | Near-term          | supervised    | Pre-Production     |
| Severity `major` and `assistiveTechValidated` not required              | Near-term          | supervised    | Early Operations   |
| Severity `minor` and `wcagLevel = AA`                                   | Planned            | supervised    | Early Operations   |
| Severity `minor` and `wcagLevel = AAA`                                  | Backlog            | supervised    | Ongoing Governance |
| Severity `enhancement`                                                  | Backlog            | autonomous    | Ongoing Governance |
| References open tradeoff (`tradeoffLog.acceptedBy` absent)              | Hold               | manual        | Pre-Production     |

Within the same priority level, order remediation items before control implementation items, and order WCAG Level A items before AA items. Consider persona-impact severity: seeds affecting screen-reader and cognitive-load personas receive earlier attention within their priority band.

When multiple conditions apply to a single seed, use the most restrictive (highest priority, lowest autonomy) row.

When work item A depends on work item B, note the dependency in both work item bodies and place B earlier in the handoff sequence.

## Cross-Planner Evidence Cross-Links

Accessibility seeds frequently share evidence and controls with the Security, RAI, and SSSC planners. The Phase 5 `crossPlannerRefs` array enumerates these relationships; Phase 6 renders them as cross-reference fields on the work items.

Rules:

* Search Security, RAI, and SSSC backlog output files (`work-items.md`, `issues-plan.md`) before creating new work items. Link to existing items rather than duplicate.
* Cross-reference format in ADO: `Accessibility-Ref: WI-A11Y-{NNN}`, `Security-Ref: WI-SEC-{NNN}`, `RAI-Ref: WI-RAI-{NNN}`, `SSSC-Ref: WI-SSSC-{NNN}`.
* Cross-reference format in GitHub: `Accessibility: #{NNN}`, `Security: #{NNN}`, `RAI: #{NNN}`, `SSSC: #{NNN}`.
* The handoff summary includes a cross-reference table listing every overlapping item.
* When a Security or RAI item already exists for a shared control, the accessibility item extends rather than duplicates, and uses tag `a11y:cross-ref-security` or `a11y:cross-ref-rai`.

Cross-reference table template:

| Accessibility Item | Linked Item  | Planner   | Relationship                          | Notes         |
|--------------------|--------------|-----------|---------------------------------------|---------------|
| WI-A11Y-{NNN}      | WI-{X}-{NNN} | {planner} | shared-control / informs / depends-on | {description} |

Relationship semantics inherit from the Phase 5 `crossPlannerRefs.relationship` enum:

* shared-control: Same underlying control implementation satisfies both planners.
* informs: Linked planner item provides context or evidence the accessibility item consumes.
* depends-on: The accessibility item cannot be closed until the linked planner item is closed.

## VPAT and EAA Evidence Emission Rules

VPAT (Voluntary Product Accessibility Template) and EAA (European Accessibility Act) attestations are the canonical artifacts the SSSC Planner consumes for supply chain disclosure. Phase 6 emits dedicated work items for these artifacts when downstream attestation is required.

Emission rules:

* When `ssscPlanRef` is set, emit one Documentation-category work item per requested attestation type (VPAT 2.5, EU EAA conformance assessment, ACR refresh) referencing the relevant `evidenceRegister` entries.
* The VPAT work item lists every WCAG 2.2 criterion mapping with surface coverage and conformance status (Supports, Partially Supports, Does Not Support, Not Applicable). Source the conformance status from `controlMappings.status` (`covered = Supports`, `partial = Partially Supports`, `gap = Does Not Support`, `not-applicable = Not Applicable`).
* The EAA work item lists every EN 301 549 criterion mapping with the same status translation and adds a regulatory-scope field referencing `project.regulatoryScope`.
* Both items tag `a11y:cross-ref-sssc` and include the SSSC plan slug in the description.
* Evidence references on VPAT and EAA items must include at least one `attestation` or `audit-result` evidence type. When none exist, emit a Monitoring and Audit Setup work item first and mark the VPAT/EAA item as depends-on the audit item.
* When the project ships AI-generated UI (`project.aiGeneratedSurfaces = true`) and `raiPlanRef` is set, the VPAT work item adds an RAI cross-reference and notes any AI-content disclosure obligations from the RAI plan.

The SSSC Planner pulls these work items into its supply chain evidence inventory by querying for tag `a11y:cross-ref-sssc`. Keep work item titles stable across re-runs so SSSC cross-references remain valid.

## Content Sanitization Protocol

Content sanitization follows the five-rule protocol in `.github/skills/shared/backlog-templates/SKILL.md` under `Content Sanitization Protocol`. Accessibility-specific standards identifiers that must be preserved verbatim per rule 4: WCAG criterion IDs (for example, `1.1.1`, `1.3.5`, `2.4.7`), WCAG levels (`A`, `AA`, `AAA`), Section 508 chapter and clause IDs, EN 301 549 clause numbers, and EAA article references. Debug-mode output remains under `.copilot-tracking/accessibility/{slug}/debug/`.

## Handoff Summary Format

After generating all work items, produce a handoff summary covering totals, cross-references, and outstanding decisions. Append the summary to both output files and to `.copilot-tracking/accessibility/{project-slug}/handoff-summary.md`.

```markdown
# Accessibility Backlog Handoff Summary

## System: {ado|github|both}
## Date: {YYYY-MM-DD}
## Risk Tier: {basic|standard|comprehensive}
## Suggested Review Status: {Ready for stakeholder review | Additional attention suggested | Significant areas need further consideration}

### Work Item Summary

| Category                   | Count   | Immediate | Near-term | Planned | Backlog |
|----------------------------|---------|-----------|-----------|---------|---------|
| Remediation                | {n}     | {n}       | {n}       | {n}     | {n}     |
| Control Implementation     | {n}     | {n}       | {n}       | {n}     | {n}     |
| Documentation              | {n}     | {n}       | {n}       | {n}     | {n}     |
| Monitoring and Audit Setup | {n}     | {n}       | {n}       | {n}     | {n}     |
| Enhancement                | {n}     | {n}       | {n}       | {n}     | {n}     |
| **Total**                  | **{n}** | **{n}**   | **{n}**   | **{n}** | **{n}** |

### Severity Breakdown

| Severity    | Count |
|-------------|-------|
| critical    | {n}   |
| major       | {n}   |
| minor       | {n}   |
| enhancement | {n}   |

### Surface Breakdown

| Surface   | Count |
|-----------|-------|
| web       | {n}   |
| mobile    | {n}   |
| desktop   | {n}   |
| documents | {n}   |
| kiosk     | {n}   |
| voice     | {n}   |

### Autonomy Tier Distribution

| Tier       | Count |
|------------|-------|
| manual     | {n}   |
| supervised | {n}   |
| autonomous | {n}   |

### Cross-Planner References

| Accessibility Item | Linked Item  | Planner   | Relationship   | Notes         |
|--------------------|--------------|-----------|----------------|---------------|
| WI-A11Y-{NNN}      | WI-{X}-{NNN} | {planner} | {relationship} | {description} |

### Outstanding Decisions

* {decision_1}
* {decision_2}

### VPAT / EAA Attestation Items

| Item ID       | Attestation Type | Linked Evidence       | Status   |
|---------------|------------------|-----------------------|----------|
| WI-A11Y-{NNN} | {VPAT|EAA|ACR}   | EV-A11Y-{NNN}         | {status} |
```


## Phase Exit Criteria

Phase 6 closes when every criterion below is true. The planner does not set `gates.backlog-handoff.confirmed = true` until the user explicitly confirms the rendered backlog.

* Every review checkpoint reads Met.
* The Accessibility Review Summary template is populated and embedded in the output files.
* Every `workItemSeeds` entry has rendered into at least one work item in the selected target system(s).
* Every work item carries derived priority, autonomy tier, horizon, and tags.
* Cross-references for every `crossPlannerRefs` entry resolve to a linked planner item or carry a TBD note when the linked planner has not run yet.
* VPAT and EAA attestation work items exist when `ssscPlanRef` is set.
* Content sanitization has run and the debug log records any actions taken.
* The user has reviewed the rendered backlog and confirmed.

## Final State Update


```json
{
  "phase": "backlog-handoff",
  "gates": {
    "backlog-handoff": {
      "confirmed": true,
      "confirmedAt": "{ISO 8601 timestamp}"
    }
  },
  "noticeLog": [
    {
      "noticeType": "handoff-disclaimer",
      "shownAt": "{ISO 8601 timestamp}",
      "source": ".github/instructions/accessibility/accessibility-identity.instructions.md",
      "details": {
        "phase": "backlog-handoff",
        "artifact": ".copilot-tracking/accessibility/{project-slug}/handoff-summary.md"
      }
    }
  ],
  "userPreferences": {
    "targetSystem": "{ado|github|both}",
    "autonomyTier": "{manual|supervised|autonomous}"
  },
  "handoffArtifacts": {
    "adoBacklog": ".copilot-tracking/workitems/backlog/{project-slug}-a11y/work-items.md",
    "githubBacklog": ".copilot-tracking/github-issues/discovery/{project-slug}-a11y/issues-plan.md",
    "summary": ".copilot-tracking/accessibility/{project-slug}/handoff-summary.md"
  }
}
```

`handoffArtifacts` is a planner-local convenience field not enforced by the schema; the schema validates `userPreferences` and `gates` strictly. The planner writes the artifact paths to the summary file regardless of schema validation outcome.

## Anti-Patterns

Avoid these patterns. They produce non-actionable backlogs, break audit trails, or leak internal state to external systems.

* Emitting work items without running the review rubric first. The rubric is a gate, not advisory.
* Renaming severity values to match a target system's vocabulary. Keep `critical`, `major`, `minor`, `enhancement` and let the labels translate them.
* Duplicating a Security, RAI, or SSSC work item instead of cross-referencing it. Cross-link and tag with the appropriate `a11y:cross-ref-*` tag.
* Promoting a seed to `autonomous` tier without `evidence.status = verified`. Verified evidence is the precondition for autonomous push.
* Skipping the VPAT or EAA item emission when `ssscPlanRef` is set. SSSC depends on these items for supply chain attestation.
* Pushing work items via MCP before sanitization. Sanitization runs first, every time.
* Setting `gates.backlog-handoff.confirmed = true` without explicit user confirmation. The gate is user-driven, not planner-driven.
* Listing seed IDs (`SEED-A11Y-{NNN}`) in the ADO description. Seed IDs surface only in the GitHub YAML metadata block.
* Rendering work items with empty `AreaPath` for ADO. Empty AreaPath blocks ADO push; ask the user before rendering.
