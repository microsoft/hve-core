---
title: incident-response
description: "Run a structured Azure incident response workflow for triage, diagnosis, mitigation, and root cause analysis. Use when operations or security teams need guided incident handling for Azure service symptoms."
sidebar_position: 2
author: Microsoft
ms.date: 2026-10-02
ms.topic: reference
keywords:
  - skill
  - security
  - incident-response
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                            |
|-------------|--------------------------------------------------------------------------------------------------|
| Kind        | skill                                                                                            |
| Source      | `.github/skills/security/incident-response`                                                      |
| Invocation  | Invoked directly as `/incident-response`; model invocation is disabled, so agents do not load it |
| Interactive | No                                                                                               |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Run a structured Azure incident response workflow for triage, diagnosis, mitigation, and root cause analysis. Use when operations or security teams need guided incident handling for Azure service symptoms.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill to assist with triage, diagnosis, mitigation planning, or root-cause analysis for an Azure operations incident. Follow the organization's emergency runbook directly when immediate human-led containment takes priority.

## How to use it

Provide a sanitized `incident-description`, then optionally set severity and phase. Keep resource identifiers and telemetry non-sensitive, and require qualified operations and security review before applying material mitigation actions.

## Example usage

```text
/incident-response incident-description="sample API latency alert" severity=3 phase=triage
```

The skill produces an assistive triage record for the fictional alert without changing Azure resources.
