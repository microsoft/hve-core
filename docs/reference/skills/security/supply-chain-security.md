---
title: supply-chain-security
description: "Software supply chain security reference for OpenSSF Scorecard, SLSA, Sigstore, SBOM, and posture/backlog taxonomies."
sidebar_position: 12
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - security
  - supply-chain-security
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                   |
|-------------|-----------------------------------------------------------------------------------------|
| Kind        | skill                                                                                   |
| Source      | `.github/skills/security/supply-chain-security`                                         |
| Invocation  | Invoked directly as `/supply-chain-security`, or loaded on demand by referencing agents |
| Interactive | No                                                                                      |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Software supply chain security reference for OpenSSF Scorecard, SLSA, Sigstore, SBOM, and posture/backlog taxonomies.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this reference to organize repository supply-chain posture across OpenSSF
Scorecard, SLSA v1.0, Sigstore, SBOMs, and the Best Practices Badge. It also supplies
adoption categories, effort sizing, and risk-based work ordering. Choose it when a
team needs to turn supplied evidence into a prioritized improvement plan, not when
it needs a vulnerability scanner or automatic workflow deployment.

## Example usage

Ask: `/supply-chain-security Map this sample repository's existing Scorecard
results, release workflow, and SBOM inventory to adoption gaps. Prioritize the
next steps without editing files or opening issues.` Use sanitized evidence and
identify when each result was collected.

The expected analysis selects the relevant catalogs, compares evidence against the
capabilities inventory, and classifies gaps by adoption category, effort, and
concern. Priority derivation should explain the ordering rather than assigning
unsupported scores. Success is a traceable list of next actions that separates
missing evidence from missing capability. A proposed signing or provenance change
does not mean an artifact was signed, a SLSA level achieved, or a tracker updated.
