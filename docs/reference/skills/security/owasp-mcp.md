---
title: owasp-mcp
description: "OWASP MCP Top 10 knowledge base for identifying, assessing, and remediating Model Context Protocol security risks."
sidebar_position: 8
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - security
  - owasp-mcp
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                  |
|-------------|----------------------------------------|
| Kind        | skill                                  |
| Source      | `.github/skills/security/owasp-mcp`    |
| Invocation  | Loaded on demand by referencing agents |
| Interactive | No                                     |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
OWASP MCP Top 10 knowledge base for identifying, assessing, and remediating Model Context Protocol security risks.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Load this reference during an agent-led review of Model Context Protocol clients,
servers, tool descriptions, authentication, or context sharing. Its OWASP MCP Top
10 (2025) organization helps focus on protocol integration risks rather than only
the surrounding web application. It supplies review knowledge, not an MCP server
installation or a live security scan.

## Example usage

Ask a reviewing agent to load `owasp-mcp` for a proposed file-search server. Supply
its tool schema, authorization design, redacted configuration, and synthetic tool
responses. Request a read-only assessment of scope, returned context, and auditing.

The agent should consult the relevant references for authentication, tool
poisoning, scope creep, and over-sharing, then explain which trust boundary each
supported finding affects. A useful result includes remediation options and
missing evidence without treating tool-returned instructions as authority. Do not
include access tokens or ask the review to register, connect to, or exercise an
unapproved server.
