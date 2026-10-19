---
description: 'Adopter recipe for accessibility evidence composition: inputs, workflow variables, completeness exits, retention, trust anchor, and recomposition'
ms.date: 2026-09-17
---

# Evidence composition adoption

This recipe takes an adopter from an inactive workflow template to a first retained evidence bundle, then to deterministic recomposition. It covers what you author, what the harness produces, and what each workflow variable points at.

Composition is non-attesting. A bundle records what was observed and what remains unproven; it is not a conformance claim, an audit, or an approval.

## What you author and what the harness produces

| Input                          | Owner                       | Workflow variable              | Example                                                                |
|--------------------------------|-----------------------------|--------------------------------|------------------------------------------------------------------------|
| Asset and journey catalog      | You                         | `TARGET_EVIDENCE_ASSETS`       | [asset-journeys.json](examples/evidence/asset-journeys.json)           |
| Requirement and method catalog | You                         | `TARGET_EVIDENCE_REQUIREMENTS` | [requirement-methods.json](examples/evidence/requirement-methods.json) |
| Evidence scope                 | You                         | `TARGET_EVIDENCE_SCOPE`        | [evidence-scope.json](examples/evidence/evidence-scope.json)           |
| Run context                    | Your CI job                 | `TARGET_RUN_CONTEXT`           | [run-context.json](examples/evidence/run-context.json)                 |
| State proofs                   | Your test run               | `TARGET_STATE_PROOFS`          | [state-proofs.json](examples/evidence/state-proofs.json)               |
| Evidence source envelope       | The harness or your adapter | `TARGET_EVIDENCE_SOURCE`       | Shape shown below                                                      |
| Composed bundle                | The harness                 | `TARGET_EVIDENCE_BUNDLE`       | Written by `compose-evidence`                                          |

Every path is resolved relative to `TARGET_WORKDIR`. The examples are product-neutral placeholders: replace the identifiers, digests, and timestamps with your own. Do not place tracker identifiers, credentials, raw screen-reader speech, restricted transcript paths, or private reviewer identities in any of them. Composition rejects secret-bearing keys recursively and rejects credential-shaped string values.

### Source envelope shape

`run-all` output and visual-review manifests are adapted automatically. Supply this shape directly only when you bring your own runner:

```json
{
  "schemaVersion": "1.0.0",
  "sourceKind": "playwright",
  "producer": "project tests",
  "sourceRunId": "source-1",
  "observedAt": "2026-09-17T11:55:00Z",
  "sourceDigest": "<canonical digest of this envelope without sourceDigest>",
  "results": [
    {
      "resultId": "result-auto",
      "requirementId": "req-keyboard",
      "journeyId": "journey-read",
      "state": "default",
      "method": "playwright",
      "probe": "project-playwright",
      "disposition": "decides",
      "status": "PASS",
      "expected": "The task completes by keyboard",
      "observed": "The task completed",
      "stateProofId": "proof-1",
      "artifactIds": ["proof-record"]
    }
  ],
  "artifacts": [
    {
      "artifactId": "proof-record",
      "path": "proof.json",
      "mediaType": "application/json",
      "sizeBytes": 2,
      "sha256": "<sha256 of proof.json>"
    }
  ]
}
```

Every artifact a result depends on needs `path`, `sizeBytes`, and `sha256`. Composition verifies those bytes against `--artifact-root`. An artifact that cannot be verified never carries a PASS.

## Inactive behavior

The template's composition step exits successfully and does nothing until all six required inputs exist. It emits a notice naming the first missing path. This is intentional: a partially configured adopter gets no bundle rather than a misleading one. Add the inputs in any order; composition activates once the last one lands.

## Completeness exits

`compose-evidence` writes the bundle first, then returns a completeness code:

| Exit                 | Meaning                                  |
|----------------------|------------------------------------------|
| `0`                  | The requested completeness level was met |
| Automated-incomplete | Expected automated evidence is missing   |
| Reviewer-incomplete  | Reviewer evidence is pending or invalid  |
| Release-incomplete   | Release evidence cannot be claimed       |

Select the level with `--require-completeness automated`, `reviewer`, or `release`. The template requests `automated` only; reviewer and release policy stay with you. Because the bundle is written before the code is returned, a non-zero exit still leaves a diagnosable bundle on disk.

## Validation manifest

After composition, the copied workflow freezes the Git revision and tracked diff, inventories generated and untracked deliverables, writes a digest-backed command result, and invokes `emit-validation-manifest`. The command emits both `accessibility-validation-manifest.json` and `schema-validation-report.json`; staging requires both whenever an evidence bundle exists.

A completed command needs a retained `resultArtifactDigest`. A skipped or unavailable command needs a reason and cannot support promotion. Manifest currentness compares the source revision, diff digest, generated inventory, and untracked inventory, then requires every command to have passed. A change to any one of those boundaries makes the manifest non-current.

Public accessibility pages must remain capability-based while the manifest is non-current. A dated assessment or completed PASS statement is permitted only when a build-time check binds it to a current projection with the same revision, scope, methods, and limitations.

## Artifact retention

The template stages retained evidence into a freshly created directory at `TARGET_EVIDENCE_STAGING` and uploads only that directory. Staging uses a closed allowlist:

* `evidence-bundle.json`
* `composition-summary.json` (generated; classifies the run `complete` or `incomplete`)
* `accessibility-validation-manifest.json`
* `schema-validation-report.json`

Each staged file is schema-validated and passed through the privacy guard. Symlinks, hidden files, and unlisted names are refused. Staging and upload both run on every exit path, so an incomplete composition is still retained for diagnosis.

## Reviewer trust anchor

A reviewer registry proves only its own internal consistency. To let registry records approve reviewer evidence, pass the expected registry digest from a boundary the registry itself does not control:

```bash
--review-registry accessibility/review-registry.json \
--expected-review-registry-digest "$REVIEW_REGISTRY_DIGEST"
```

Source `REVIEW_REGISTRY_DIGEST` from CI configuration or a secret, not from the registry file. Without it, supplements remain diagnostic, reviewer evidence is reported `invalid`, release evidence cannot complete, and the bundle records the reason. A supplied digest that disagrees with the registry is a usage failure.

Detached signatures, signing algorithms, key distribution, and rotation are outside this recipe and need a separate approved security design.

## Recomposition from a prior bundle

To add reviewer supplements to an existing bundle, pass the prior bundle and its digest:

```bash
--prior-bundle artifacts/accessibility/evidence-bundle.json \
--prior-bundle-digest "$PRIOR_BUNDLE_DIGEST" \
--supplement accessibility/supplements/reviewer-result.json
```

Recomposition is deterministic. Supplement order does not affect the result: each evidence cell resolves through its own supersession chain, and the emitted history is sorted by identity. A supplement that supersedes another must name a known predecessor in the same cell and carry that predecessor's digest. Two supplements claiming the same predecessor, or two independent chains for one cell, are rejected rather than silently resolved.

Re-supplying an unchanged supplement that the prior bundle already holds is a no-op. Mutating one is rejected.

## First run checklist

1. Copy the five authored examples into your repository and replace their contents.
2. Point the `TARGET_*` variables at those paths, relative to `TARGET_WORKDIR`.
3. Run the workflow. Confirm composition activates and the artifact appears.
4. Read `composition-summary.json` to see whether the run classified as complete or incomplete, and why.
5. Add the trust anchor when you are ready for reviewer evidence to count.
