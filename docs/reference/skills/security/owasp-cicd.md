---
title: owasp-cicd
description: "OWASP CI/CD Top 10 knowledge base for identifying, assessing, and remediating CI/CD pipeline security risks."
sidebar_position: 4
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - security
  - owasp-cicd
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                  |
|-------------|----------------------------------------|
| Kind        | skill                                  |
| Source      | `.github/skills/security/owasp-cicd`   |
| Invocation  | Loaded on demand by referencing agents |
| Interactive | No                                     |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
OWASP CI/CD Top 10 knowledge base for identifying, assessing, and remediating CI/CD pipeline security risks.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Load this reference in an agent-led security review of build, test, and deployment
pipelines. It is useful when untrusted contributions, workflow identities,
third-party dependencies, or release artifacts cross trust boundaries. Choose
`supply-chain-security` for the broader Scorecard, provenance, SBOM, and supply-chain
planning vocabulary rather than only pipeline risk categories.

## Example usage

Ask a reviewing agent to load `owasp-cicd` and inspect a sanitized workflow that
builds pull requests and publishes releases. Supply the workflow YAML, permission
settings, and artifact-promotion description; request read-only findings.

The agent should use the vulnerability index to investigate applicable concerns
such as pipeline execution, credential hygiene, and artifact integrity. A useful
result names the affected workflow step, supporting evidence, risk category, and
proposed correction, while separating unavailable repository settings from proven
defects. No pipeline run, credential disclosure, permission change, or release
publication is needed to illustrate this review.
