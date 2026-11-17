---
name: finops-value-valuation
description: 'Derives deterministic stated monetary value, net value, BCR, and ROI from 9-category FinOps benefit claims and HVE delivery evidence.'
argument-hint: '[-ClaimsPath <claims.json>] [-EvidencePath <evidence.json>] [-OutputPath <report.md>]'
user-invocable: true
license: MIT
compatibility: 'Requires PowerShell 7.4+ (with bash wrapper support on POSIX).'
metadata:
  authors: 'microsoft/hve-core'
  spec_version: '1.0'
  last_updated: '2026-11-15'
---

# HVE FinOps Monetary Value Valuation

## Overview

`finops-value-valuation` interprets FinOps benefit-claim evidence (`finops-value-evidence`) and HVE delivery snapshots to compute defensible **stated monetary representations** without LLM arithmetic. Every claim and rollup figure is assigned to one of four strict monetary basis buckets — `finance-approved`, `stated-indicative`, `modeled-counterfactual`, or `unmonetized-native-only` — with explicit double-count deductions (`overlap_group`), currency isolation, sensitivity bands, cost offsets, Benefit-Cost Ratios (BCR), and Return on Investment (ROI).

Read [references/value-valuation.md](references/value-valuation.md) for the nine-category conversion formulas, guardrail rules, and JSON contract.

## Prerequisites

| Requirement | Details                                                                                          |
|-------------|--------------------------------------------------------------------------------------------------|
| `pwsh`      | PowerShell 7.4+ for `scripts/Measure-HveBenefitValue.ps1` and `scripts/HveBenefitValuation.psm1` |
| `bash`      | Optional POSIX wrapper via `scripts/measure-hve-benefit-value.sh`                                |

## Quick Start

<!-- <example-measure-benefit-value> -->
```bash
# PowerShell (run relative to the resolved finops-value-valuation skill directory)
pwsh -NoProfile -File scripts/Measure-HveBenefitValue.ps1 \
  -ClaimsPath ./claims.json \
  -EvidencePath ../hve-value-evidence.json \
  -OutputPath .copilot-tracking/finops/2026-11-15-stated-value.md \
  -Format json

# POSIX / Bash
bash scripts/measure-hve-benefit-value.sh \
  --claims-path ./claims.json \
  --evidence-path ../hve-value-evidence.json \
  --output-path .copilot-tracking/finops/2026-11-15-stated-value.md
```
<!-- </example-measure-benefit-value> -->

## Parameters Reference

| Parameter       | Type   | Required | Default  | Description                                                                                             |
|-----------------|--------|----------|----------|---------------------------------------------------------------------------------------------------------|
| `-ClaimsPath`   | String | No       |          | Path to JSON file with `benefit_claims`, `cost_evidence`, `fx_rates`, and optional `delivery_valuation` |
| `-ClaimsJson`   | String | No       |          | Inline JSON string equivalent to `-ClaimsPath` (mutually exclusive)                                     |
| `-EvidencePath` | String | No       |          | Optional path to a JSON snapshot emitted by `Collect-HveValueEvidence.ps1`                              |
| `-OutputPath`   | String | No       |          | Optional local file path (`.md` or `.json`) to write the valuation deliverable                          |
| `-Format`       | String | No       | `json`   | Output format emitted on stdout (`json` or `markdown`)                                                  |
| `-AsOf`         | String | No       | UTC date | Optional `YYYY-MM-DD` date stamp for byte-reproducible reports                                          |

## Script Reference

### Measure-HveBenefitValue.ps1

Validates local paths (refusing remote URLs, UNC shares, and symbolic links), evaluates each claim against the nine FinOps category formulas and guardrails in `HveBenefitValuation.psm1`, reconciles HVE delivery evidence and AI accounting when `-EvidencePath` is provided, deducts overlapping pools within shared `overlap_group` identifiers, and outputs deterministic JSON or Markdown.

### measure-hve-benefit-value.sh

POSIX/bash twin forwarding `--claims-path`, `--claims-json`, `--evidence-path`, `--output-path`, `--format`, and `--as-of` to `Measure-HveBenefitValue.ps1`.

## Workflow

<!-- <workflow-monetary-valuation> -->
1. Gather evidenced claims (and optional `Collect-HveValueEvidence.ps1` output) plus explicit user- or Finance-supplied monetary conversion rates.
2. Assign a shared `overlap_group` to any claims monetizing the same underlying pool of hours, defects, or transactions.
3. Run `scripts/Measure-HveBenefitValue.ps1` and take every monetary figure directly from its deterministic output.
4. Present `financeApprovedValue`, `statedIndicativeValue`, `totalStatedEvidencedValue`, `sensitivityRange`, `totalEvidencedCost`, `netStatedValue`, `benefitCostRatio`, `statedRoiPct`, and separate `modeledCounterfactualValue`, keeping Finance/business sign-off with the human decision owner.
<!-- </workflow-monetary-valuation> -->
