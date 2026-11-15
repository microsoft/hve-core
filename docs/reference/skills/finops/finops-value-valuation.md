---
title: finops-value-valuation
description: "Derives deterministic stated monetary value, net value, BCR, and ROI from 9-category FinOps benefit claims and HVE delivery evidence."
sidebar_position: 2
author: Microsoft
ms.date: 2026-11-15
ms.topic: reference
keywords:
  - skill
  - finops
  - finops-value-valuation
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                    |
|-------------|------------------------------------------------------------------------------------------|
| Kind        | skill                                                                                    |
| Source      | `.github/skills/finops/finops-value-valuation`                                           |
| Invocation  | Invoked directly as `/finops-value-valuation`, or loaded on demand by referencing agents |
| Interactive | No                                                                                       |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Derives deterministic stated monetary value, net value, BCR, and ROI from 9-category FinOps benefit claims and HVE delivery evidence.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `finops-value-valuation` (directly via `/finops-value-valuation` or through `FinOps Value Economist`) when you have structured nine-category FinOps benefit claims or an HVE evidence snapshot from `finops-value-evidence` and need deterministic monetary figures, sensitivity ranges, double-count deductions, Benefit-Cost Ratios (BCR), and ROI percentages:

* Separating `finance-approved` booked value from `stated-indicative` evidenced estimates, `modeled-counterfactual` routing/forecast figures, and `unmonetized-native-only` operational metrics.
* Enforcing FinOps monetization guardrails so raw hours saved without `redeployedShare`, quality-degraded outputs (`qualityFloorMet: false`), unverified demand, or leading-indicator engagement metrics are never inflated into false currency claims.

Use `finops-value-evidence` first when repository delivery artifacts and benefit-claim definitions have not yet been collected.

## Example usage

```bash
pwsh -NoProfile -File .github/skills/finops/finops-value-valuation/scripts/Measure-HveBenefitValue.ps1 \
  -ClaimsPath ./claims.json \
  -EvidencePath ../hve-value-evidence.json \
  -OutputPath .copilot-tracking/finops/2026-11-15-stated-value.md \
  -Format json
```

Expected output indicators:

* Exits `0`, writes `.copilot-tracking/finops/2026-11-15-stated-value.md`, and emits deterministic JSON containing `summary.financeApprovedValue`, `summary.statedIndicativeValue`, `summary.totalStatedEvidencedValue`, `summary.netStatedValue`, `summary.benefitCostRatio`, `summary.statedRoiPct`, `summary.modeledCounterfactualValue`, and `overlapAdjustments`.
