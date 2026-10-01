---
description: 'PRD consumer rules for the feasibility-to-PRD handoff: Assess ingestion, Create persistence, Build disposition, BRD coexistence, and source traceability'
---

# Feasibility-to-PRD Handoff — PRD Consumer Contract

## Purpose

The feasibility-to-PRD handoff carries a confirmed feasibility verdict and evidence-backed candidates into PRD authoring. It supplements business context and never bypasses PRD Build. Candidates are not final requirements, and concern hints do not select a final NFR category or downstream planner.

The producer contract is owned by `feasibility`. This reference defines only PRD consumer behavior.

## Assess

1. Recognize the artifact by `kind: feasibility-to-prd-handoff`.
2. Verify required metadata is present and the workspace-relative `study_path` and `study_revision_id` are readable.
3. Record `study_revision_id` so a reader can compare it against the study's current revision. Do not recompute a content hash; the producer regenerates the handoff after a material study revision, and no repository tooling verifies a hash.
4. Preserve BRD coverage and waiver processing unchanged. Treat feasibility as supplementary evidence. Never silently override signed-off BRD scope.
5. Validate the verdict matrix:
   * `proceed` and `proceed-with-scope-reduction` require both candidate fields.
   * `do-not-proceed` and `insufficient-evidence` forbid both candidate fields and retain recommendation, evidence, constraints, and gaps.
6. Require top-level `evidence_sections`. Its values name study sections. Candidate-level `evidence_refs` values are `FS-###` display references to study items and are carried through unchanged; this consumer does not resolve either reference against the study.
7. Carry exactly this normalized metadata in Assess output for a new session:

```yaml
kind: feasibility-to-prd-handoff
path: <WORKSPACE_RELATIVE_HANDOFF_PATH>
ingested_at: <ISO_8601_TIMESTAMP>
verdict: <VERDICT>
study_revision_id: <STUDY_REVISION_UUID_URN>
```

When state already exists, update its `feasibilityHandoff` object directly. Do not store raw candidate content in state.

Malformed required fields, an unreadable path, or a verdict outside the matrix blocks Assess. A negative verdict does not itself block Assess; it records evidence and creates no candidate dispositions.

## Create

For a new PRD session, write the normalized metadata atomically with the state skeleton:

```json
"feasibilityHandoff": {
  "kind": "feasibility-to-prd-handoff",
  "path": "docs/data/example-feasibility-to-prd-handoff.yml",
  "ingestedAt": "2026-08-03T12:00:00Z",
  "verdict": "proceed",
  "studyRevisionId": "urn:uuid:1d9b7f42-05c8-4a6e-9b31-7c2e8a5f0d64"
}
```

State written before this contract may carry a `schemaVersion` field instead of `kind`. Read it without error, and rewrite the object to the current five-field shape on the next feasibility metadata update.

Keep BRD handling separate so simultaneous BRD and feasibility inputs cannot overwrite each other.

## Build

Build reads candidate content from `feasibilityHandoff.path`. Stop when feasibility ingestion was reported but the metadata object is missing or the path cannot be read.

For forward verdicts, give every source candidate exactly one disposition:

* `accepted-fr`
* `accepted-nfr`
* `accepted-constraint`
* `retained-gap`
* `rejected`
* `deferred`

Allocate `FR-###`, `NFR-###`, or `CON-###` only after the final PRD statement is authored and accepted. Require source-authored criteria or record an explicit gap instead of inventing criteria.

Use the PRD Feasibility Candidate Disposition register:

| Source handoff ID | Source candidate ID | Evidence references | Disposition | Resulting PRD ID | Rationale |
|-------------------|---------------------|---------------------|-------------|------------------|-----------|
| Replace           | Replace             | Replace             | Replace     | Replace or `n/a` | Replace   |

Every source candidate has one row. Negative verdicts have no candidate rows. Concern hints are advisory evidence only.

## BRD coexistence and conflicts

A signed-off BRD remains the approved business-context source. When feasibility evidence conflicts with BRD scope or goals:

1. Preserve both source references.
2. Do not silently select one source.
3. Record the conflict in the disposition register or as a Build gap.
4. Resolve it with explicit rationale when current authority and evidence support a decision.
