---
title: owasp-infrastructure
description: "OWASP Infrastructure Top 10 knowledge base for identifying, assessing, and remediating internal IT infrastructure security risks."
sidebar_position: 6
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - security
  - owasp-infrastructure
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                          |
|-------------|------------------------------------------------|
| Kind        | skill                                          |
| Source      | `.github/skills/security/owasp-infrastructure` |
| Invocation  | Loaded on demand by referencing agents         |
| Interactive | No                                             |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
OWASP Infrastructure Top 10 knowledge base for identifying, assessing, and remediating internal IT infrastructure security risks.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this load-only reference for agent-assisted assessment of internal IT
infrastructure: asset inventories, management access, patching, authentication,
network controls, and detection coverage. It follows the OWASP Infrastructure
Security Top 10 (2024). Use `owasp-top-10` for application-layer behavior or `mcsb`
when the task specifically needs an Azure control-domain mapping.

## Example usage

Ask a reviewing agent to load `owasp-infrastructure` for a fictional build network.
Provide a sanitized asset list, network-access diagram, patch policy, and management
access rules. Ask which observations need remediation and which need more evidence.

The agent should consult the index and applicable references, then connect each
finding to the supplied inventory or configuration. For example, an undocumented
management component warrants an evidence question rather than an invented host
vulnerability. Success is a prioritized review with proposed controls and explicit
unknowns. The request does not authorize network scanning, log collection from
production, or changes to infrastructure.
