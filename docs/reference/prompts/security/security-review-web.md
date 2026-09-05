---
title: security-review-web
description: Run an OWASP Top 10 web vulnerability assessment without codebase profiling
sidebar_position: 7
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - security
  - security-review-web
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                    |
|-------------|----------------------------------------------------------|
| Kind        | prompt                                                   |
| Source      | `.github/prompts/security/security-review-web.prompt.md` |
| Invocation  | Slash command `/security-review-web`                     |
| Interactive | Yes                                                      |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Run an OWASP Top 10 web vulnerability assessment without codebase profiling
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt for a focused OWASP Top 10 web application assessment when codebase profiling is unnecessary. Use the general security review when the technology or applicable security framework is uncertain.

## How to use it

Optionally provide the web application `scope`. The prompt runs the fixed web-assessment path and records evidence and findings for qualified security review; it does not certify the application as secure.

## Example usage

```text
/security-review-web scope=src/web
```

The prompt assesses the sample web source boundary against the OWASP Top 10 and drafts reviewable findings.
