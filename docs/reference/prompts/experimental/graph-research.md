---
title: Graph Research
description: "Research a codebase through rpi-research using an existing graphify knowledge graph, with audit-tagged evidence reporting"
sidebar_position: 2
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - experimental
  - graph-research
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                   |
|-------------|---------------------------------------------------------|
| Kind        | prompt                                                  |
| Source      | `.github/prompts/experimental/graph-research.prompt.md` |
| Invocation  | Slash command `/graph-research`                         |
| Interactive | Yes                                                     |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Research a codebase through rpi-research using an existing graphify knowledge graph, with audit-tagged evidence reporting
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt to investigate structural codebase questions when a graphify knowledge graph already exists. Use standard repository research when no graph is available or when the question does not depend on graph relationships.

## How to use it

Provide the research `topic` and optionally enable conversational output with `chat=true`. If graph prerequisites are unavailable, choose an explicit fallback rather than assuming this prompt builds or uploads a graph.

## Example usage

```text
/graph-research topic="what depends on auth_middleware.py" chat=true
```

The prompt returns graph-backed dependency evidence with audit tags for the named module.
