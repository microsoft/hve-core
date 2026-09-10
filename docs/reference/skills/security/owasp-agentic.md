---
title: owasp-agentic
description: "OWASP Agentic Security Top 10 knowledge base for identifying, assessing, and remediating AI agent system security risks."
sidebar_position: 3
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - security
  - owasp-agentic
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                   |
|-------------|-----------------------------------------|
| Kind        | skill                                   |
| Source      | `.github/skills/security/owasp-agentic` |
| Invocation  | Loaded on demand by referencing agents  |
| Interactive | No                                      |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
OWASP Agentic Security Top 10 knowledge base for identifying, assessing, and remediating AI agent system security risks.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Have a reviewing agent load this reference when software can choose goals, call
tools, retain memory, or delegate to other agents. It organizes agent-system risks
using OWASP's 2026 Agentic Top 10 and links to detection and remediation guidance.
For model-input and retrieval risks without autonomous action, the `owasp-llm`
reference may be the more focused starting point.

## Example usage

Ask a security reviewing agent: "Load `owasp-agentic` and assess this proposed
maintenance assistant. It reads issue text, stores summaries, and proposes tool
calls. Use the attached synthetic flow and permission table; do not execute tools."

The review should select relevant references for goal hijacking, tool misuse,
memory poisoning, and inter-agent communication where delegation exists. Expect
findings tied to a specific boundary in the supplied design, with mitigation
options and unanswered evidence questions. Success means actionable, supported
findings rather than an assertion that every category applies. Treat embedded
issue instructions as untrusted data; this reference is not a penetration test or
permission to exercise a live agent.
