---
name: finops-value-evidence
description: 'Collects verifiable HVE repository, RPI deliverable, test, and AI accounting value evidence alongside 9-category FinOps benefit definitions.'
argument-hint: '[-RepoRoot <path>] -OutputPath <evidence.json> [-AccountingPath <accounting.json>]'
user-invocable: true
license: MIT
compatibility: 'Requires PowerShell 7.4+ (or bash + git + jq on POSIX) and a local git repository.'
metadata:
  authors: 'microsoft/hve-core'
  spec_version: '1.0'
  last_updated: '2026-11-15'
---

# HVE FinOps Value Evidence Collector

## Overview

`finops-value-evidence` captures tamper-evident, reproducible evidence of Hypervelocity Engineering (HVE) delivery and structures business-outcome hypotheses across nine FinOps value categories. It bridges technical delivery telemetry (git manifests, `.copilot-tracking/` research/plan/change/review deliverables, test reports, and AI session accounting) with FinOps benefit-claim rigor so `finops-value-valuation` and `FinOps Value Economist` can derive defensible monetary representations.

Read [references/business-value-measurement.md](references/business-value-measurement.md) when defining or auditing benefit claims, baselines, attribution, and evidence status (`supported`, `gap`, or `pending`).

## Prerequisites

| Requirement   | Details                                                                    |
|---------------|----------------------------------------------------------------------------|
| `pwsh`        | PowerShell 7.4+ for `scripts/Collect-HveValueEvidence.ps1`                 |
| `git`         | Local Git CLI for tracked/untracked manifest and commit metadata           |
| `bash` + `jq` | Optional POSIX wrapper support via `scripts/collect-hve-value-evidence.sh` |

## Quick Start

<!-- <example-collect-evidence> -->
```bash
# PowerShell (cross-platform)
pwsh -NoProfile -File .github/skills/finops/finops-value-evidence/scripts/Collect-HveValueEvidence.ps1 \
  -RepoRoot . \
  -OutputPath ../hve-value-evidence.json

# POSIX / Bash
bash .github/skills/finops/finops-value-evidence/scripts/collect-hve-value-evidence.sh \
  --repo-root . \
  --output-path ../hve-value-evidence.json
```
<!-- </example-collect-evidence> -->

## Parameters Reference

| Parameter         | Type   | Required | Default           | Description                                                                                                           |
|-------------------|--------|----------|-------------------|-----------------------------------------------------------------------------------------------------------------------|
| `-RepoRoot`       | String | No       | `.`               | Local Git repository root to inventory read-only                                                                      |
| `-OutputPath`     | String | Yes      |                   | Destination JSON file outside `-RepoRoot` for the collected evidence snapshot                                         |
| `-AccountingPath` | String | No       |                   | Optional AI session/provider accounting JSON (`sessions`, `calls`, `knownProviderUnits`, `costUsd`, or `sessionRows`) |
| `-TestReportPath` | String | No       | `testResults.xml` | Optional NUnit/JUnit XML test report path (relative to `-RepoRoot` or absolute)                                       |

## Script Reference

### Collect-HveValueEvidence.ps1

Reads the target Git repository strictly read-only (`GIT_OPTIONAL_LOCKS=0`), refuses symbolic links and reparse points, requires `-OutputPath` to live outside `-RepoRoot` so collection never dirties the repository under measurement, verifies working-tree stability before and after collection, and emits a SHA-256-sealed JSON evidence bundle summarizing:

* Git HEAD, branch, file counts, and full SHA-256 file manifest
* HVE customization categories (`.github/agents/`, `.github/instructions/`, `.github/skills/`, `docs/`, `tests/`)
* RPI delivery inventory under `.copilot-tracking/` (`research`, `plans`, `changes`, `reviews`, and review-accepted deliverable counts)
* Optional XML test report attributes (DTD-prohibited safe XML reader) and AI accounting summary

### collect-hve-value-evidence.sh

POSIX/bash entrypoint accepting `--repo-root`, `--output-path`, `--accounting-path`, and `--test-report-path`, forwarding validated arguments to `Collect-HveValueEvidence.ps1` under `pwsh -NoProfile`.

## Workflow

<!-- <workflow-evidence-collection> -->
1. Confirm the target repository root and choose an `-OutputPath` outside the repository tree.
2. Run `scripts/Collect-HveValueEvidence.ps1` (or `scripts/collect-hve-value-evidence.sh`) and verify `statusStableDuringCollection: true` in the emitted summary.
3. When business or operational benefit hypotheses are in scope, structure each claim per [references/business-value-measurement.md](references/business-value-measurement.md) with a stable `claim_id`, single primary FinOps category, baseline, target, measurement owner, evidence links, and status (`supported`, `gap`, or `pending`).
4. Pass the resulting evidence snapshot to `finops-value-valuation` (`Measure-HveBenefitValue.ps1 -EvidencePath <path>`) when the user requests a stated monetary valuation or ROI report.
<!-- </workflow-evidence-collection> -->
