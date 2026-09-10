---
title: owasp-llm
description: "OWASP Top 10 for LLM Applications (2025) knowledge base for identifying, assessing, and remediating large language model security risks."
sidebar_position: 7
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - security
  - owasp-llm
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                  |
|-------------|----------------------------------------|
| Kind        | skill                                  |
| Source      | `.github/skills/security/owasp-llm`    |
| Invocation  | Loaded on demand by referencing agents |
| Interactive | No                                     |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
OWASP Top 10 for LLM Applications (2025) knowledge base for identifying, assessing, and remediating large language model security risks.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Have an agent load this reference when reviewing an LLM application that accepts
untrusted inputs, retrieves documents, handles model output, or exposes sensitive
context. Its OWASP 2025 reference set includes retrieval, output handling, excessive
agency, and consumption risks. Use `owasp-agentic` alongside it when autonomous
goals, tools, memory, or delegation introduce additional system-level boundaries.

## Example usage

Ask a security reviewing agent: "Load `owasp-llm` and review this retrieval-based
help assistant using synthetic documents, the retrieval access policy, and the
HTML-rendering code. Do not call a model or retrieve real user records."

The review should identify relevant references for prompt injection, sensitive
information disclosure, vector and embedding weaknesses, and output handling.
Expect findings that name the supplied evidence, affected boundary, and proposed
mitigation or test. Success means distinguishing demonstrated code or design gaps
from hypotheses requiring later evaluation. A read-only review does not establish
resistance to attacks or replace privacy assessment.
