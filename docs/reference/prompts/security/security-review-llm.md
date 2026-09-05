---
title: security-review-llm
description: Run OWASP LLM and Agentic vulnerability assessments with codebase profiling
sidebar_position: 5
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - security
  - security-review-llm
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                    |
|-------------|----------------------------------------------------------|
| Kind        | prompt                                                   |
| Source      | `.github/prompts/security/security-review-llm.prompt.md` |
| Invocation  | Slash command `/security-review-llm`                     |
| Interactive | Yes                                                      |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Run OWASP LLM and Agentic vulnerability assessments with codebase profiling
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt when an LLM or agentic application needs paired OWASP LLM and agentic security assessments. Use the general security review when AI-specific applicability has not been established.

## How to use it

Optionally provide the AI application `scope`. The prompt profiles the codebase, runs both assessment lenses, and produces evidence for qualified security review without exposing proprietary prompts, endpoints, or secrets.

## Example usage

```text
/security-review-llm scope=src/assistant
```

The prompt evaluates the sample assistant boundary and drafts combined LLM and agentic security findings.
