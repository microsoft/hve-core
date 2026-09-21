---
title: security-review-sbd
description: Run a Secure by Design principles assessment per UK and Australian government guidance
sidebar_position: 6
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - security
  - security-review-sbd
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                    |
|-------------|----------------------------------------------------------|
| Kind        | prompt                                                   |
| Source      | `.github/prompts/security/security-review-sbd.prompt.md` |
| Invocation  | Slash command `/security-review-sbd`                     |
| Interactive | Yes                                                      |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Run a Secure by Design principles assessment per UK and Australian government guidance
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt for a focused Secure by Design principles assessment when codebase profiling is unnecessary. Use the general security review when the applicable framework or system boundary still needs discovery.

## How to use it

Optionally provide the assessment `scope`. The prompt runs the fixed Secure by Design path and records evidence-backed observations for qualified security review rather than issuing a compliance certification.

## Example usage

```text
/security-review-sbd scope=src/service
```

The prompt evaluates the sample service boundary and drafts Secure by Design findings for review.
