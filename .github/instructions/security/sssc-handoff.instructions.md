---
description: "Phase 6 backlog handoff protocol with Scorecard projections and dual-format output for SSSC Planner."
applyTo: '**/.copilot-tracking/sssc-plans/**'
---

# SSSC Phase 6 — Review and Handoff

Validate the complete SSSC plan, generate improvement projections, and produce platform-specific handoff files for backlog managers.

## Handoff Protocol

1. Read `sssc-backlog.md` (the neutral work item list from Phase 5).
2. Validate completeness: every gap from Phase 4 has a corresponding work item.
3. Generate improvement projections (see below).
4. Present the complete plan to the user for final review.
5. On confirmation, generate platform-specific handoff files.
6. Sign planner artifacts (see [Signed Artifact Manifest](#signed-artifact-manifest)).
7. Update `state.json` handoff flags and signing fields.

## Threat ID Convention

When handoff outputs cross-reference threats produced by the Security Planner (or any upstream threat-modeling artifact captured via `securityPlannerLink`), use the canonical token `T-SEC-{NNN}` with sequential, zero-padded numbering scoped to the Security Planner session being referenced. This token is the only form accepted in SSSC handoff descriptions, work item bodies, and improvement-projection rows; it preserves traceability back to the originating Security Planner outputs without re-deriving threat content inside SSSC artifacts.

## Scorecard Improvement Projection

For each of the 20 Scorecard checks, project the score improvement if all related work items are completed:

| #   | Check        | Risk   | Current Score | Projected Score | Work Items           |
|-----|--------------|--------|---------------|-----------------|----------------------|
| {n} | {check_name} | {risk} | {current}/10  | {projected}/10  | {WI-SSSC-{NNN}, ...} |

Include a summary row with the estimated overall Scorecard score improvement.

## SLSA Level Assessment

Project the SLSA Build level that the repository would achieve after completing all relevant work items:

* **Current level**: Build L{N}
* **Projected level**: Build L{N}
* **Remaining steps**: {list of what would still be needed}

## Best Practices Badge Readiness

Assess which Badge tier the repository would qualify for after completing all work items:

* **Current readiness**: {Passing|Silver|Gold|Not enrolled}
* **Projected readiness**: {Passing|Silver|Gold}
* **Missing criteria** (if any): {list}

## ADO Handoff

Write ADO-formatted work items to `.copilot-tracking/workitems/backlog/{project-slug}-sssc/work-items.md`.

Apply the ADO work item template from `sssc-backlog.instructions.md` with:

* HTML-formatted description fields
* `WI-SSSC-{NNN}` sequential IDs
* Type hierarchy: Epic → Feature → User Story → Task
* Tags: `supply-chain`, `ossf`, plus per-check and per-category tags
* Priority derived from Scorecard risk level

Set `state.json` field `handoffGenerated.ado` to `true` after writing.

## GitHub Handoff

Write GitHub-formatted issues to `.copilot-tracking/github-issues/discovery/{project-slug}-sssc/issues-plan.md`.

Apply the GitHub issue template from `sssc-backlog.instructions.md` with:

* YAML metadata blocks
* `{{SSSC-TEMP-N}}` temporary IDs
* Markdown-formatted body
* Labels: `supply-chain`, `ossf`, plus per-check and per-category labels
* Milestone assignment if one exists

Set `state.json` field `handoffGenerated.github` to `true` after writing.

## Handoff Summary

After generating handoff files, produce a summary covering:

* Total items by type and platform
* Items by Scorecard check
* Items by adoption category
* Items by risk level
* Estimated total effort (sum of T-shirt sizes)
* Cross-references to Security Planner and RAI Planner artifacts (if `securityPlannerLink` or `raiPlannerLink` is populated)

## Final State Update

Update `state.json`:
* Set `phases.6-handoff.status` to `✅`
* Update `handoffGenerated` flags for each platform written
* Set `signingManifestPath` to the manifest path returned by `Sign-PlannerArtifacts.ps1` when signing completed
* Clear `nextActions` (or populate with post-handoff recommendations)

## Signed Artifact Manifest

After both platform-specific handoff files are written, sign the SSSC planner artifacts by invoking the shared planner signing script. Use the session-path parameter set so the manifest is emitted as `sssc-manifest.json` inside the active SSSC session directory:

```pwsh
pwsh scripts/security/Sign-PlannerArtifacts.ps1 -SessionPath '.copilot-tracking/sssc-plans/<session>' -ManifestName 'sssc-manifest.json'
```

Append `-IncludeCosign` when the user has opted in to cosign keyless signing via the top-level `signingRequested` field in `state.json`. Cosign keyless signing requires `cosign` in PATH and a Sigstore-compatible OIDC identity provider; the script gracefully skips signing with a warning when cosign is unavailable.

The parameter contract for `Sign-PlannerArtifacts.ps1` exposes two mutually exclusive parameter sets:

* `-ProjectSlug <slug>` (RAI sessions; resolves to `.copilot-tracking/rai-plans/<slug>/`).
* `-SessionPath <path>` (any planner session, including SSSC; absolute or repo-relative directory).
* `-ManifestName <file>` (optional; defaults to `artifact-manifest.json`; SSSC sessions must pass `sssc-manifest.json`).
* `-OutputPath <path>` (optional; full path override that takes precedence over `-ManifestName`).

On success, capture the manifest path returned by the script and update `state.json` field `signingManifestPath`. The `sssc-manifest.json` file (and, when cosign is used, the accompanying `.sig` and `.bundle` siblings) becomes the verifiable record covering every artifact under the SSSC session directory at handoff time.

Present the user with next steps:
* For ADO: invoke the ADO Backlog Manager to create work items from the handoff file
* For GitHub: invoke the GitHub Backlog Manager to create issues from the handoff file
* If cross-agent artifacts exist: note the links for continuity across security domains
