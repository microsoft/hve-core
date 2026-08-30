---
title: proposal-response
description: "Build traceable internal-review proposal, RFI, RFP, tender, bid, and questionnaire responses from supplied questions and approved sources. Use to analyze questions, contribute business or product evidence, or draft qualified responses."
sidebar_position: 12
author: Microsoft
ms.date: 2026-08-21
ms.topic: reference
keywords:
  - skill
  - project-planning
  - proposal-response
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                               |
|-------------|-------------------------------------------------------------------------------------|
| Kind        | skill                                                                               |
| Source      | `.github/skills/project-planning/proposal-response`                                 |
| Invocation  | Invoked directly as `/proposal-response`, or loaded on demand by referencing agents |
| Interactive | No                                                                                  |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Build traceable internal-review proposal, RFI, RFP, tender, bid, and questionnaire responses from supplied questions and approved sources. Use to analyze questions, contribute business or product evidence, or draft qualified responses.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `proposal-response` when you have source questions and approved artifacts for an RFI, RFP, tender, bid, questionnaire, or reusable response-evidence task. It can classify questions, contribute business or product evidence, and render traceable internal-review drafts.

Use BRD Builder or PRD Builder for ordinary requirements authoring. Use human legal, commercial, security, and business owners for disclosure, commitment, approval, submission, and release decisions.

## How to use it

Invoke `/proposal-response` with `operation=analyze`, `operation=contribute`, or `operation=draft`. Supply the source questions, identify approved sources, and name `domain=business` or `domain=product` for contributions. Ask for an optional appendix only when you need one.

The complete `RESPONSE_EVIDENCE_V1` payload is stored under `.copilot-tracking/proposal-responses/<response-slug>/response-evidence.yml`. Chat returns `RESPONSE_EVIDENCE_POINTER_V1` with the artifact path, compact status, whether the artifact was written, changed IDs, unresolved IDs, ignored directive references, and any requested rendering paths. A status, coverage, or readiness question is answered from the stored payload without rewriting it.

The response always remains an internal-review draft. See the [proposal response workflow](../../../agents/project-planning/brd-prd-builders#proposal-response-workflow) for builder activation, complete examples, and human review boundaries.

## Example usage

```text
/proposal-response operation=analyze
Classify the supplied questionnaire questions, map required claims to the
approved BRD and PRD, keep unsupported claims as unresolved items, persist the
evidence artifact, and return its compact pointer.
```

The evidence artifact contains stable question and claim IDs, evidence-review states, coverage, and advisory structural readiness. It cannot represent external-use approval or release authorization.
