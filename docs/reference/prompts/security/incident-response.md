---
title: incident-response
description: Run an incident response workflow for Azure operations scenarios
sidebar_position: 1
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - security
  - incident-response
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                  |
|-------------|--------------------------------------------------------|
| Kind        | prompt                                                 |
| Source      | `.github/prompts/security/incident-response.prompt.md` |
| Invocation  | Slash command `/incident-response`                     |
| Interactive | Yes                                                    |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Run an incident response workflow for Azure operations scenarios
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt to assist with triage, diagnosis, mitigation planning, or root-cause analysis for an Azure operations incident. Follow the organization's emergency runbook directly when immediate human-led containment takes priority.

## How to use it

Provide a sanitized `incident-description`, then optionally set severity and phase. Keep resource identifiers and telemetry non-sensitive, and require qualified operations and security review before applying material mitigation actions.

## Example usage

```text
/incident-response incident-description="sample API latency alert" severity=3 phase=triage
```

The prompt produces an assistive triage record for the fictional alert without changing Azure resources.
