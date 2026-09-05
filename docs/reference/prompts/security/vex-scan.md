---
title: vex-scan
description: "Run a full VEX pipeline that scans dependencies, enriches CVEs, analyzes exploitability, and drafts an OpenVEX document for review - Brought to you by microsoft/hve-core"
sidebar_position: 14
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - security
  - vex-scan
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                         |
|-------------|-----------------------------------------------|
| Kind        | prompt                                        |
| Source      | `.github/prompts/security/vex-scan.prompt.md` |
| Invocation  | Slash command `/vex-scan`                     |
| Interactive | Yes                                           |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Run a full VEX pipeline that scans dependencies, enriches CVEs, analyzes exploitability, and drafts an OpenVEX document for review - Brought to you by microsoft/hve-core
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt when a project needs dependency scanning, CVE enrichment, exploitability analysis, and a draft OpenVEX document. Use vex-triage when a supported scan report or SBOM already exists and scanning should be skipped.

## How to use it

Optionally provide the project `scope` and product package URL. Review the evidence behind every status determination; a qualified product security reviewer and author of record must approve the draft before publication.

## Example usage

```text
/vex-scan scope=packages/api product=pkg:npm/@example/sample-api
```

The prompt scans the fictional package and produces an evidence-linked OpenVEX draft for qualified review.
