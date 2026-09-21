---
title: security-review
description: Run an OWASP vulnerability assessment against the current codebase
sidebar_position: 8
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - security
  - security-review
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                |
|-------------|------------------------------------------------------|
| Kind        | prompt                                               |
| Source      | `.github/prompts/security/security-review.prompt.md` |
| Invocation  | Slash command `/security-review`                     |
| Interactive | Yes                                                  |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Run an OWASP vulnerability assessment against the current codebase
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt for a profile-driven security assessment when the applicable OWASP or security skill is not already known. Use a fixed fast-path prompt for a web, LLM, or Secure by Design assessment with a confirmed scope.

## How to use it

Optionally provide `scope`, assessment `mode`, a target skill, or an existing plan. The prompt profiles the codebase, runs applicable assessments, and produces findings that require qualified security review before remediation or closure decisions.

## Example usage

```text
/security-review scope=src mode=audit targetSkill=owasp-top-10
```

The prompt assesses the sample source boundary and generates an evidence-backed draft report for security review.
