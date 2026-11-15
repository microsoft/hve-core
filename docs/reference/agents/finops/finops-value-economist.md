---
title: FinOps Value Economist
description: "Collects HVE delivery and benefit evidence and derives stated monetary value, net value, BCR, and ROI using deterministic FinOps valuation math."
sidebar_position: 1
author: Microsoft
ms.date: 2026-11-15
ms.topic: reference
keywords:
  - agent
  - finops
  - finops-value-economist
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                           |
|-------------|-----------------------------------------------------------------|
| Kind        | agent                                                           |
| Source      | `.github/agents/finops/finops-value-economist.agent.md`         |
| Invocation  | Selected from the chat agent picker as `FinOps Value Economist` |
| Interactive | Yes                                                             |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Collects HVE delivery and benefit evidence and derives stated monetary value, net value, BCR, and ROI using deterministic FinOps valuation math.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `FinOps Value Economist` when you want to quantify and communicate the measurable business or engineering value of Hypervelocity Engineering (HVE) workflows, AI-assisted delivery, or cloud optimization initiatives in defensible monetary terms:

* Turning operational improvements across the nine FinOps value categories (`revenue enablement`, `cost avoidance`, `capacity gained`, `labour augmentation`, `quality`, `speed`, `risk reduction`, `new capacity`, and `engagement`) into stated monetary representations.
* Proving the return on HVE adoption by joining SHA-256-verified repository and `.copilot-tracking/` RPI delivery evidence (`finops-value-evidence`) with explicit engineering labor or business conversion rates (`finops-value-valuation`).
* Auditing whether overlapping claims double-count the same pool of hours, defects, or transactions, and separating Finance-approved booked value from indicative estimates and counterfactual routing savings.

Reach for `System Architecture Reviewer` when comparing architectural trade-offs before implementation, or `Experiment Designer` when designing a Minimum Viable Experiment before outcome evidence exists.

## How to use it

1. Select **FinOps Value Economist** from the Copilot agent picker in VS Code or invoke it in Copilot CLI.
2. Provide your repository context, benefit-claim evidence (or ask the agent to collect an HVE repository baseline first), cost records, and any known monetary conversion drivers such as hourly labor rate, redeployment share, unit margin, or defect remediation cost.
3. Answer any `ask_user` prompts when required conversion drivers or Finance approval references are missing.
4. Review the generated Stated Monetary Value Report under `.copilot-tracking/finops/` alongside the separated basis summary (`finance-approved`, `stated-indicative`, `modeled-counterfactual`, and `unmonetized-native-only`).

## Example usage

User request:

```text
Collect our repository's HVE delivery evidence and value the 40 accepted RPI features we delivered this quarter. Baseline effort was 8 hours per feature and observed effort with HVE was 3 hours, with 75% productive redeployment at $110/hr against $1,800 in AI tooling spend.
```

Execution flow:

1. Runs `Collect-HveValueEvidence.ps1` from `finops-value-evidence` to write a read-only SHA-256 evidence snapshot outside the repository.
2. Structures the `capacity gained` claim and cost evidence JSON and executes `Measure-HveBenefitValue.ps1` from `finops-value-valuation`.
3. Writes `.copilot-tracking/finops/2026-11-15-q4-hve-stated-value.md` and reports `$16,500.00` in `stated-indicative` value, `$14,700.00` net stated value, a `9.17x` Benefit-Cost Ratio, and `816.7%` stated ROI while keeping Finance sign-off with the human decision owner.
