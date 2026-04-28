---
description: "Canonical evidence-citation row format for FSI-consuming planner agents — uniform `path (Lines start-end)` references across RAI, Security, SSSC, Accessibility, Sustainability, and Requirements planning"
applyTo: '**/.copilot-tracking/rai-plans/**, **/.copilot-tracking/security-plans/**, **/.copilot-tracking/sssc-plans/**, **/.copilot-tracking/accessibility-plans/**, **/.copilot-tracking/sustainability-plans/**, **/.copilot-tracking/requirements-sessions/**'
---

# Evidence Citation

This file is the single source of truth for how FSI-compatible planner and reviewer agents (RAI, Security, SSSC, Accessibility, Sustainability, Requirements) cite evidence in verdict-bearing findings tables, gap analyses, backlog source references, and handoff audit trails. Per-domain instructions reference this contract instead of restating the row format.

## Scope

This contract applies to every verdict-bearing evidence row emitted by an FSI-consuming planner agent into `.copilot-tracking/**-plans/**` (and the equivalent `.copilot-tracking/requirements-sessions/**` tree for the Requirements Builder). It does not apply to:

* Review logs under `.copilot-tracking/reviews/**`. Review-time findings cite evidence informally; tightening them is tracked as a separate follow-up.
* Research notes under `.copilot-tracking/research/**`. Research is exploratory and is not gated by this rule.
* Authoring-time `evidenceHints[]` arrays inside `.github/skills/**/items/*.yml`. Those are discovery aids for planners and are explicitly not citations themselves.

The lint hook (`npm run lint:evidence-citation`) walks the same root set and fails (exit 1) for every row in scope that violates the canonical format. Out-of-scope artifacts may carry looser evidence prose without triggering the hook.

## Canonical Row Format

Every Evidence cell that supports a `verified` or `partial` verdict uses one of the rows below. The `Evidence:` prefix is required; the path uses backticks; the line span uses an en-hyphen pair.

| Kind                        | Row Format                                                                                  |
|-----------------------------|---------------------------------------------------------------------------------------------|
| Default (file + line range) | `Evidence: ` + `` `path/to/file.ext` `` + ` (Lines N-M) — short rationale`                  |
| `kind: file-presence`       | `Evidence: ` + `` `path/to/file.ext` `` + ` (kind: file-presence) — short rationale`        |
| `kind: live-endpoint`       | `Evidence: ` + `<https://endpoint>` + ` (kind: live-endpoint) — observed value + rationale` |
| `kind: external-doc`        | `Evidence: ` + `<https://doc-url>` + ` (kind: external-doc) — short rationale`              |

The `kind:` qualifier is only allowed when the citation cannot resolve to a single file with a line span. `file-presence` is reserved for controls that score on existence alone (for example, a license file). `live-endpoint` is reserved for controls whose current state lives in a rendered badge or API response. `external-doc` is reserved for citations that fall outside the workspace.

## Evidence Exhaustion Rule

When no source line is available for a finding that would otherwise be `verified` or `partial`, the agent downgrades the verdict by one tier rather than emitting a bare path. The downgrade ladder follows the per-domain Verdict Ladder (typically `verified → present`, `present → partial`, `partial → unknown`). The downgrade is recorded in the Evidence cell with a brief reason (for example, `— downgraded: no line anchor available`).

This rule generalizes the SSSC Phase 2 Evidence Exhaustion Rule to every FSI-consuming planner. Per-domain instructions may add domain-specific exhaustion checks but may not weaken this downgrade requirement.

## Forbidden Patterns

* Bare paths in `verified` or `partial` rows. A path without `(Lines N-M)` and without an explicit `kind:` qualifier is a violation.
* Verbatim copies of `evidenceHints[]` glob entries in evidence rows. `evidenceHints[]` is an authoring-time discovery aid for the FSI item; resolved file references with line spans must replace globs in planner output.
* Badge-image inference. A README badge image alone never satisfies a `verified` row; pair it with either a `kind: live-endpoint` row citing the fetched endpoint or with a documentation citation that records the observed tier.

## Worked Examples

A `verified` row citing a workflow file:

```text
| openssf-scorecard.token-permissions | verified | Evidence: `.github/workflows/release.yml` (Lines 12-18) — top-level `permissions: read-all` plus per-job least-privilege grants. |
```

A `partial` row downgraded for a missing line span:

```text
| sssc.branch-protection | partial | Evidence: `docs/contributing/branch-protection.md` — downgraded: policy described but no enforcement evidence located in repository settings export. |
```

A `kind: live-endpoint` row:

```text
| openssf-best-practices-badge.tier | verified | Evidence: <https://www.bestpractices.dev/projects/11795> (kind: live-endpoint) — endpoint returned `silver` on 2026-04-24. |
```
