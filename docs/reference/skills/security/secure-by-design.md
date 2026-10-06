---
title: secure-by-design
description: "Secure by Design principles knowledge base for assessing security-first design, development, and deployment across the software lifecycle."
sidebar_position: 10
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - security
  - secure-by-design
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                      |
|-------------|--------------------------------------------|
| Kind        | skill                                      |
| Source      | `.github/skills/security/secure-by-design` |
| Invocation  | Loaded on demand by referencing agents     |
| Interactive | No                                         |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Secure by Design principles knowledge base for assessing security-first design, development, and deployment across the software lifecycle.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Load this reference when an agent-led review needs to examine security decisions
across product design, development, operation, and retirement, rather than only
individual vulnerabilities. The package synthesizes UK Government principles and
Australian Signals Directorate / Australian Cyber Security Centre foundations
into review areas. It complements technical OWASP reviews with governance, usable
controls, assurance, and deprecation questions.

## Example usage

Ask a security reviewing agent to load `secure-by-design` for a fictional service
launch. Supply its architecture, ownership model, incident-response outline, and
retirement policy. Request a review of decisions still needed before release.

The agent should use the principle index to select applicable guidance and return
evidence-backed gaps, proposed ownership, and follow-up questions. For example, an
absent retirement plan belongs in a lifecycle finding, not a fabricated code
defect. Success is a review that separates documented practices from assumptions
and gives the team decisions it can act on. Human owners still approve policy and
risk acceptance; the reference confers no certification or government endorsement.
