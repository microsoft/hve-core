---
title: finops-value-evidence
description: "Collects verifiable HVE repository, RPI deliverable, test, and AI accounting value evidence alongside 9-category FinOps benefit definitions."
sidebar_position: 1
author: Microsoft
ms.date: 2026-11-15
ms.topic: reference
keywords:
  - skill
  - finops
  - finops-value-evidence
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                   |
|-------------|-----------------------------------------------------------------------------------------|
| Kind        | skill                                                                                   |
| Source      | `.github/skills/finops/finops-value-evidence`                                           |
| Invocation  | Invoked directly as `/finops-value-evidence`, or loaded on demand by referencing agents |
| Interactive | No                                                                                      |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Collects verifiable HVE repository, RPI deliverable, test, and AI accounting value evidence alongside 9-category FinOps benefit definitions.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `finops-value-evidence` (directly via `/finops-value-evidence` or through `FinOps Value Economist`) whenever you need a tamper-evident, read-only baseline of HVE engineering outputs or need to structure benefit hypotheses across the nine FinOps value categories before monetization:

* Capturing Git file manifests with SHA-256 digests, `.copilot-tracking/` RPI deliverables (`research`, `plans`, `changes`, `reviews`), independent review acceptance counts, test XML summaries, and AI session accounting without dirtying the target repository.
* Structuring or auditing benefit claims (`supported`, `gap`, or `pending`) with explicit baselines, targets, measurement owners, and `overlap_group` links.

Use `finops-value-valuation` next when you are ready to convert the collected evidence into stated monetary amounts, BCR, and ROI.

## Example usage

```bash
pwsh -NoProfile -File .github/skills/finops/finops-value-evidence/scripts/Collect-HveValueEvidence.ps1 \
  -RepoRoot . \
  -OutputPath ../hve-value-evidence.json \
  -AccountingPath ./accounting-summary.json
```

Expected output indicators:

* Writes `../hve-value-evidence.json` outside `-RepoRoot` and prints a compact JSON summary on stdout with `statusStableDuringCollection: true`, `fileManifestSha256`, `categories`, and `rpiDelivery.acceptedReviews`.
