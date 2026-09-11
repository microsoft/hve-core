---
title: owasp-top-10
description: "OWASP Top 10 for Web Applications (2025) knowledge base for identifying, assessing, and remediating web application security risks."
sidebar_position: 9
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - security
  - owasp-top-10
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                  |
|-------------|----------------------------------------|
| Kind        | skill                                  |
| Source      | `.github/skills/security/owasp-top-10` |
| Invocation  | Loaded on demand by referencing agents |
| Interactive | No                                     |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
OWASP Top 10 for Web Applications (2025) knowledge base for identifying, assessing, and remediating web application security risks.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this load-only reference to guide a web-application security review against
the OWASP Top 10 (2025). It helps organize evidence about access control,
authentication, input handling, configuration, integrity, and exceptional
conditions. For build-pipeline or host-management concerns, choose `owasp-cicd` or
`owasp-infrastructure` instead of forcing them into an application-only review.

## Example usage

Ask a reviewing agent to load `owasp-top-10` and inspect a sample order API's route
handlers, authorization middleware, error handling, and tests. Specify that the
review is limited to these files and uses synthetic order identifiers.

The expected result maps supported observations to applicable references, such as
access control or exceptional-condition handling, and proposes concrete regression
tests. Success means each finding identifies evidence and a corrective action;
deployment controls that were not inspected remain unknown. No live requests,
exploit execution, or claim of OWASP certification follows from loading the reference.
