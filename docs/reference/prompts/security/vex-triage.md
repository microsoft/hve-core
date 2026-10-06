---
title: vex-triage
description: "Triage CVEs from an existing scan report or SBOM and draft an OpenVEX document, skipping the scan phase - Brought to you by microsoft/hve-core"
sidebar_position: 15
author: Microsoft
ms.date: 2026-09-04
ms.topic: reference
keywords:
  - prompt
  - security
  - vex-triage
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                           |
|-------------|-------------------------------------------------|
| Kind        | prompt                                          |
| Source      | `.github/prompts/security/vex-triage.prompt.md` |
| Invocation  | Slash command `/vex-triage`                     |
| Interactive | Yes                                             |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Triage CVEs from an existing scan report or SBOM and draft an OpenVEX document, skipping the scan phase - Brought to you by microsoft/hve-core
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt to triage CVEs from an existing supported scan report or SBOM and draft an OpenVEX document without running the scan again. Use vex-scan when current dependency discovery and enrichment are still required.

## How to use it

Provide the required `report` path and optionally the product package URL. The prompt preserves source precedence and drafts status determinations, which require qualified product security review and author-of-record approval before publication.

## Example usage

```text
/vex-triage report=reports/sample-sbom.spdx.json product=pkg:npm/@example/sample-api
```

The prompt triages the fictional SBOM and creates an evidence-linked OpenVEX draft without running a new scan.
