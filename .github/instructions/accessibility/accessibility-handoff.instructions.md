---
description: "Phase 6 review-handoff protocol with active-rules.json export, persona overlays, and dual-format output for Accessibility Planner."
applyTo: '**/.copilot-tracking/accessibility-plans/**'
---

# Accessibility Planner Phase 6 — Review and Handoff

Validate the complete accessibility plan, generate conformance projections, and produce platform-specific handoff files plus the Wave 1 downstream consumer artifacts (`active-rules.json` and per-persona journey overlays).

Attach the Accessibility Planning disclaimer block from [`#file:../shared/disclaimer-language.instructions.md`](../shared/disclaimer-language.instructions.md) at the top of every handoff artifact written by this phase.

Cross-references:

* [`#file:accessibility-identity.instructions.md`](accessibility-identity.instructions.md) — six-phase contract, state schema, framework gate.
* [`#file:accessibility-backlog.instructions.md`](accessibility-backlog.instructions.md) — Phase 5 work item templates consumed by this phase.

Before writing handoff files, run `Validate-PlannerArtifacts.ps1 -Scope accessibility -PlanRoot .copilot-tracking/accessibility-plans/{project-slug}` to confirm the plan satisfies the schema and skill-loading contract. After writing, run `Sign-PlannerArtifacts.ps1 -Scope accessibility -PlanRoot .copilot-tracking/accessibility-plans/{project-slug}` to produce the artifact manifest.

## Handoff Protocol

1. Read `accessibility-backlog.md` (the neutral work item list from Phase 5).
2. Validate completeness: every gap from Phase 4 has a corresponding work item.
3. Generate conformance projections (see below).
4. Render the [Excluded Frameworks and Criteria](#excluded-frameworks-and-criteria) audit appendix.
5. Emit the [Active Rules Manifest](#active-rules-manifest) (`active-rules.json`).
6. Emit the [Journey Overlays](#journey-overlays) (`journey-overlays/<persona-id>.md`, one per persona).
7. Present the complete plan to the user for final review.
8. On confirmation, generate platform-specific handoff files.
9. Update `state.json` handoff fields.

## Excluded Frameworks and Criteria

Render an audit appendix in `accessibility-handoff.md` (and at the bottom of every platform-specific handoff file) summarizing every framework and criterion the user opted out of during the session. The data source is `state.json`:

* **Frameworks** — every entry in `state.frameworks[]` where `disabled === true`. Render `id`, `version`, `disabledReason`, and `disabledAtPhase`.
* **Criteria** — every entry in `state.frameworks[<id>].suppressedControls[]` (across all frameworks, including frameworks that are otherwise enabled). Render the parent framework `id`, the criterion `id`, `reason`, and `suppressedAtPhase`.

Use this layout:

```markdown
## Excluded Frameworks and Criteria

The following frameworks and success criteria were intentionally excluded from this assessment. Each exclusion is recorded with the user-supplied reason and the workflow phase at which it was applied.

### Disabled Frameworks

| Framework | Version | Reason | Excluded at Phase |
|-----------|---------|--------|-------------------|
| {id}      | {ver}   | {why}  | {phase}           |

### Suppressed Criteria

| Framework | Criterion | Reason | Suppressed at Phase |
|-----------|-----------|--------|---------------------|
| {fw-id}   | {ctrl}    | {why}  | {phase}             |
```

Omit either subsection when its source array is empty. When both arrays are empty, render the heading and a single line: `_No frameworks or success criteria were excluded from this assessment._`

## Active Rules Manifest

Write the consolidated in-scope rule set to `active-rules.json` at the plan root. This file is the contract consumed by downstream automated linters, CI accessibility scanners, the UX/UI Designer agent, the PR Review agent, and the PPTX consumer.

Include only enabled frameworks and criteria. Skip every framework with `disabled === true` and every criterion appearing in `suppressedControls[]`.

JSON shape (schema sketch):

```json
{
  "frameworks": ["wcag-2-2", "aria-apg"],
  "rules": [
    {
      "frameworkId": "wcag-2-2",
      "controlId": "1.1.1",
      "level": "A",
      "surfaceScope": ["web", "content"],
      "status": "active"
    }
  ]
}
```

Field contract:

| Key                    | Type     | Notes                                                                                      |
|------------------------|----------|--------------------------------------------------------------------------------------------|
| `frameworks`           | string[] | Framework ids enabled at handoff time. Order: as discovered in `state.frameworks[]`.       |
| `rules[]`              | object[] | Flat list of every active criterion across all enabled frameworks.                         |
| `rules[].frameworkId`  | string   | Parent framework id (matches an entry in `frameworks`).                                    |
| `rules[].controlId`    | string   | Criterion id as published by the framework (for example `1.4.3` for WCAG 2.2).             |
| `rules[].level`        | string   | Conformance level or tier (for example `A`, `AA`, `AAA`, or framework-native equivalent).  |
| `rules[].surfaceScope` | string[] | Surfaces this rule applies to (for example `web`, `content`, `mobile`, `desktop`).         |
| `rules[].status`       | string   | Always `active` in this manifest. Suppressed and disabled entries are omitted, not listed. |

Write the file to `.copilot-tracking/accessibility-plans/{project-slug}/active-rules.json` and record the path in `state.handoff.activeRulesPath`.

## Journey Overlays

For every entry in `state.userPersonas[]`, write one paste-ready narrative file to `.copilot-tracking/accessibility-plans/{project-slug}/journey-overlays/<persona-id>.md`. Slugify the persona id (lowercase, hyphenate non-alphanumerics, collapse repeats).

Each overlay summarizes the gaps from Phase 4 that affect that persona's journey through the surface. Output is consumed by the UX/UI Designer agent, so favor concise narrative blocks the designer can paste into journey maps.

Recommended structure per file:

```markdown
# Journey Overlay — {persona name}

## Persona Snapshot

* **Id**: {persona-id}
* **Assistive technology**: {AT-list}
* **Primary needs**: {needs}

## Affected Surfaces

| Surface   | Stage           | Affected Gaps      |
|-----------|-----------------|--------------------|
| {surface} | {journey stage} | WI-A11Y-{NNN}, ... |

## Narrative

{2-5 sentences describing what breaks for this persona and which work items resolve it.}

## Recommended Designer Actions

* {actionable bullet}
```

Append every overlay file path to `state.handoff.journeyOverlayPaths[]`.

When `state.userPersonas[]` is empty, skip overlay generation, write a single `journey-overlays/README.md` noting "No personas declared in scoping; overlays not generated", and record only that path.

## Coverage Disclosure

Render `state.criterionTracker[]` as a table so reviewers can distinguish what was assessed from what was skipped. This section is always rendered (never collapsed):

```markdown
## Coverage Disclosure

The following table records every criterion referenced during this assessment. Criteria with `mappedInPhase3 = false` were not read in Phase 3 standards-mapping and therefore have no gap-analysis evidence; their `suggestedStatus` reflects only structural defaults, not assessment.

| Framework | Criterion     | Mapped in Phase 3 | Suggested Status                                                  | Notes |
|-----------|---------------|-------------------|-------------------------------------------------------------------|-------|
| {fw-id}   | {criterionId} | {true|false}      | {addressed|partial|not-addressed|deferred|not-applicable}         | {why} |
```

When `state.criterionTracker[]` is empty, render a single line: `_No criteria were tracked during this assessment._` and proceed.

## Evidence Citation Format

All evidence references emitted by handoff artifacts (Coverage Disclosure notes, journey overlays, persona snapshots, ADO/GitHub handoff payloads) follow the canonical evidence row format defined in #file:../shared/evidence-citation.instructions.md. Use that format for every `path (Lines start-end)` reference; apply `kind:` qualifiers (`file-presence`, `live-endpoint`, `external-doc`) when a citation is not a line-spanned in-repo reference.

## WCAG Conformance Projection

For each enabled framework, project the conformance level the surface would achieve after completing all related work items:

| Framework | Target Level   | Current Conformance | Projected Conformance | Work Items           |
|-----------|----------------|---------------------|-----------------------|----------------------|
| {id}      | {A / AA / AAA} | {level / partial}   | {level}               | {WI-A11Y-{NNN}, ...} |

Include a summary row per framework with the count of remaining open criteria after the projected work is complete.

## ADO Handoff

Write ADO-formatted work items to `.copilot-tracking/workitems/backlog/{project-slug}-accessibility/work-items.md`.

Apply the ADO work item template from `accessibility-backlog.instructions.md` with:

* HTML-formatted description fields
* `WI-A11Y-{NNN}` sequential IDs
* Type hierarchy: Epic → Feature → User Story → Task
* Tags: `accessibility`, `a11y`, plus per-framework and per-criterion tags
* Priority derived from gap severity and risk tier

Set `state.json` field `handoffGenerated.ado` to `true` after writing.

## GitHub Handoff

Write GitHub-formatted issues to `.copilot-tracking/github-issues/discovery/{project-slug}-accessibility/issues-plan.md`.

Apply the GitHub issue template from `accessibility-backlog.instructions.md` with:

* YAML metadata blocks
* `{{A11Y-TEMP-N}}` temporary IDs
* Markdown-formatted body
* Labels: `accessibility`, `a11y`, plus per-framework and per-criterion labels
* Milestone assignment if one exists

Set `state.json` field `handoffGenerated.github` to `true` after writing.

## Handoff Summary

After generating handoff files, produce a summary covering:

* Total items by type and platform
* Items by framework and conformance level
* Items by surface
* Items by gap severity
* Estimated total effort (sum of T-shirt sizes)
* Cross-references to Security Planner and RAI Planner artifacts (if `securityPlannerLink` or `raiPlannerLink` is populated)
* Wave 1 consumer next-step recommendations: invoke the UX/UI Designer with `journey-overlays/`, the PR Review agent with `active-rules.json`, and the PPTX agent for executive summary slides.

## Final State Update

Update `state.json`:

* Append every `read_file` of a skill artifact to `skillsLoaded[]`.
* Populate `state.handoff.packagePath` with the absolute path to `accessibility-handoff.md`.
* Populate `state.handoff.activeRulesPath` with the path written in [Active Rules Manifest](#active-rules-manifest).
* Populate `state.handoff.journeyOverlayPaths[]` with every file written in [Journey Overlays](#journey-overlays).
* Update `handoffGenerated.ado` and `handoffGenerated.github` for each platform written.
* Set `phase` to `complete` and clear `nextActions` (or populate with post-handoff recommendations).

Present the user with next steps:

* For ADO: invoke the ADO Backlog Manager to create work items from the handoff file.
* For GitHub: invoke the GitHub Backlog Manager to create issues from the handoff file.
* For UX/UI Designer: pass `journey-overlays/` for journey-map integration.
* For PR Review and CI scanners: pass `active-rules.json` as the lint contract.
* If cross-agent artifacts exist: note the links for continuity across security and responsible-AI domains.
