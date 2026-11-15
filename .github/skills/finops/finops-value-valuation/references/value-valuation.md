---
title: FinOps Stated Monetary Valuation Reference
description: Nine-category monetization formulas, basis separation, overlap deduplication, and JSON schema for Measure-HveBenefitValue.ps1
author: Microsoft
ms.date: 2026-11-15
ms.topic: reference
---

# FinOps Stated Monetary Valuation

Use this reference when `FinOps Value Economist` or `finops-value-valuation` derives stated monetary value, net value, Benefit-Cost Ratio (BCR), and Return on Investment (ROI) from FinOps benefit claims and HVE delivery evidence.

## Four Strict Monetary Basis Buckets

| Basis                     | Definition                                                                                                                                                                                                                                                                         | Included in `totalStatedEvidencedValue`? |
|---------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------|
| `finance-approved`        | `status: supported` with `evidence_links`, valid category conversion formula, `valuation.financeApproved: true`, and `business_decision.status: approved` with a non-empty `reference`                                                                                             | Yes (`financeApprovedValue`)             |
| `stated-indicative`       | `status: supported` with `evidence_links` and explicit conversion drivers (`unitValue`, `hourlyRate` + `redeployedShare`, `costPerDefect`, etc.), awaiting Finance sign-off                                                                                                        | Yes (`statedIndicativeValue`)            |
| `modeled-counterfactual`  | Counterfactual AI routing savings (`counterfactualBaselineUsd - costUsd`) or target-based forecasts for `pending` claims                                                                                                                                                           | No (`modeledCounterfactualValue`)        |
| `unmonetized-native-only` | Claims with `status: gap`, missing conversion drivers, violated guardrails (`qualityFloorMet: false`, `demandVerified: false`, missing `redeployedShare`, `pipelineOnly: true` without conversion, or `engagement` without downstream conversion), or unconverted foreign currency | No (retained in native unit)             |

## Input JSON Schema

<!-- <schema-valuation-input> -->
```json
{
  "report_id": "hve-q4-valuation",
  "as_of": "2026-11-15",
  "currency": "USD",
  "fx_rates": { "EUR": 1.08 },
  "includeAiSpendInCost": true,
  "delivery_valuation": {
    "baselineHoursPerDeliverable": 6.0,
    "observedHoursPerDeliverable": 1.5,
    "hourlyRate": 110.0,
    "redeployedShare": 0.75,
    "attributionShare": 1.0,
    "financeApproved": false
  },
  "benefit_claims": [
    {
      "claim_id": "claim-cap-01",
      "category": "capacity gained",
      "hypothesis": "Reduce engineering cycle effort per accepted deliverable with HVE RPI workflows",
      "beneficiary": "Platform Engineering",
      "measurement_owner": "Engineering Director",
      "status": "supported",
      "overlap_group": "platform-eng-hours",
      "baseline": { "metric": "hours_per_feature", "value": 12.0, "unit": "hours", "period": "2026-09", "source": "Jira cycle export" },
      "target": { "metric": "hours_per_feature", "value": 5.0, "unit": "hours", "by": "2026-12" },
      "observation": { "value": 5.5, "unit": "hours", "period": "2026-10", "source": "Jira cycle export" },
      "evidence_links": ["docs/evidence/cycle-october.csv"],
      "business_decision": { "status": "approved", "owner": "VP Engineering", "reference": "FIN-2026-210" },
      "valuation": {
        "direction": "decrease",
        "volume": 40,
        "hourlyRate": 115.0,
        "redeployedShare": 0.80,
        "attributionShare": 0.90,
        "periodFactor": 1.0,
        "uncertaintyPct": 15,
        "financeApproved": true,
        "primaryInGroup": true
      }
    }
  ],
  "cost_evidence": [
    {
      "scope": "copilot-and-foundry-enablement",
      "amount": 2400.00,
      "currency": "USD",
      "period": "2026-10",
      "source": "Billing export",
      "evidence_link": "docs/evidence/billing-october.csv"
    }
  ]
}
```
<!-- </schema-valuation-input> -->

## Nine-Category Monetization Formulas

For each claim, `nativeDelta = baseline.value - observation.value` when lower is better (`direction: "decrease"` or `target.value < baseline.value`) and `observation.value - baseline.value` otherwise. Baseline and observation units must match, and `attributionShare` must be in `(0, 1]`.

1. **Revenue enablement**: `nativeDelta * volume * (conversionToRecognizedRate ?? 1.0) * unitValue * attributionShare * periodFactor` (`pipelineOnly: true` without `conversionToRecognizedRate` remains `unmonetized-native-only`).
2. **Cost avoidance**: `(counterfactualCost - observedCost) * attributionShare * periodFactor` or `nativeDelta * volume * unitCost * attributionShare * periodFactor`.
3. **Capacity gained**: `nativeDelta * volume * redeployedShare * hourlyRate * attributionShare * periodFactor` (or `avoidedExpenseAmount * attributionShare * periodFactor`; raw hours saved are never monetized without `redeployedShare` in `(0, 1]`).
4. **Labour augmentation**: `nativeDelta * volume * redeployedShare * hourlyRate * attributionShare * periodFactor` (refused when `qualityFloorMet: false`).
5. **Quality**: `nativeDelta * volume * costPerDefect * attributionShare * periodFactor`.
6. **Speed**: `nativeDelta * volume * valuePerTimeUnit * attributionShare * periodFactor`.
7. **Risk reduction**: `(baselineLikelihood - observedLikelihood) * impactAmount * attributionShare * periodFactor` or `nativeDelta * volume * costPerIncident * attributionShare * periodFactor`.
8. **New capacity**: `nativeDelta * volume * unitValue * attributionShare * periodFactor` (refused when `demandVerified: false`).
9. **Engagement**: `nativeDelta * volume * downstreamConversionRate * downstreamUnitValue * attributionShare * periodFactor` (requires both downstream parameters).

## Double-Count Deduplication and Net Return

* **Overlap deduplication (`overlap_group`)**: Within each shared `overlap_group` among evidenced claims, the primary claim (`primaryInGroup: true`, then `finance-approved`, then largest pre-deduction value) keeps its full value and secondary claims have `preDeductionValue * overlapShare` (default `1.0`) deducted in `overlapAdjustments[]`.
* **Net Stated Value, BCR, and ROI**:
  * `netStatedValue = totalStatedEvidencedValue - totalEvidencedCost`
  * `benefitCostRatio = totalStatedEvidencedValue / totalEvidencedCost`
  * `statedRoiPct = (netStatedValue / totalEvidencedCost) * 100`
