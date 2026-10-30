---
title: privacy-pii-detector
description: "Automated PII/PI detection and privacy control verification for codebases. Scans for personal information processing patterns, classifies by sensitivity tier and industry, verifies protective controls exist, and raises findings when controls are missing. Use when you need to detect PII in code without privacy expertise."
sidebar_position: 13
author: Microsoft
ms.date: 2026-10-30
ms.topic: reference
keywords:
  - skill
  - project-planning
  - privacy-pii-detector
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                  |
|-------------|----------------------------------------------------------------------------------------|
| Kind        | skill                                                                                  |
| Source      | `.github/skills/project-planning/privacy-pii-detector`                                 |
| Invocation  | Invoked directly as `/privacy-pii-detector`, or loaded on demand by referencing agents |
| Interactive | No                                                                                     |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Automated PII/PI detection and privacy control verification for codebases. Scans for personal information processing patterns, classifies by sensitivity tier and industry, verifies protective controls exist, and raises findings when controls are missing. Use when you need to detect PII in code without privacy expertise.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill when you need to find where a codebase stores or processes
personal information and check whether each detected type has the expected
privacy controls, without bringing your own privacy expertise. It fits a
first-pass scan of an unfamiliar repository, a review of a pull request that
adds new data fields, or a control gap analysis that should end in backlog
items. Telco, healthcare, and financial services overlays add industry-specific
types when the industry is configured in `.pii-config.yml` or inferred from the
code.

Reach for `privacy-standards` instead when you need principle-level privacy
reasoning, standards mapping, or DPIA thresholds, and for the OWASP skills when
the question is security vulnerabilities rather than personal data. The skill is
a detection and planning aid, not legal advice.

## Example usage

Invoke `/privacy-pii-detector` on a fictional order service whose `Customer`
model has `email`, `phoneNumber`, `dateOfBirth`, and `cardNumber` fields, and
whose checkout handler logs `customer.email`. Use synthetic field names and
fixtures, not production data.

The skill records a detection for each field with its taxonomy ID, tier, file
location, and confidence. It then checks the required controls for each tier,
such as encryption at rest, log masking, and retention. The logged email becomes
a MEDIUM `PII-GAP` finding for missing log masking, with remediation and a
backlog item. Controls that live outside the repository, such as a breach
notification plan, are listed as NEEDS_REVIEW for confirmation instead of
failing. The assessment summary ends with an overall verdict of `PROTECTED`,
`GAPS_FOUND`, or `UNPROTECTED`.
