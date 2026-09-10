---
title: Agentic Workflow Runtime Scripts
description: Trusted runtime support for compiled Agentic Workflows
author: HVE Core Team
ms.date: 2026-09-10
ms.topic: reference
keywords:
  - agentic workflows
  - powershell
  - runtime
estimated_reading_time: 2
---

Trusted scripts in this directory perform deterministic processing for
compiled Agentic Workflows. They do not make semantic decisions assigned to
the model.

## Backlog Grooming

The `backlog-grooming/` runtime owns candidate result collection and wave
validation.

| Script                                                    | Purpose                                                                                  |
|-----------------------------------------------------------|------------------------------------------------------------------------------------------|
| `backlog-grooming/Invoke-BacklogGroomResultCollector.ps1` | Convert normalized candidate calls and trusted shard context into an immutable v2 result |
| `backlog-grooming/Invoke-BacklogGroomWaveValidator.ps1`   | Validate a complete immutable wave and construct its aggregate                           |
| `backlog-grooming/Modules/BacklogGrooming.psm1`           | Validate candidate semantics and construct canonical shard rows, provenance, and digests |

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.