---
description: "Conventions for working with graphify-out/ directories and graph-derived evidence"
applyTo: '**/graphify-out/**'
---

# Graphify Instructions

Conventions that apply whenever Copilot reads, writes, or references files under any `graphify-out/` directory. These instructions govern the [graphify skill](../../skills/experimental/graphify/) and the [Graph Researcher agent](../../agents/experimental/graph-researcher.agent.md).

## Working Directory

A `graphify-out/` directory is generated build output. It contains:

```text
graphify-out/
├── graph.json          # Canonical graph data — read-only for agents
├── graph.html          # Interactive visualization
├── GRAPH_REPORT.md     # God nodes, surprising connections, suggested questions
├── wiki/               # Per-community markdown articles
└── cache/              # SHA256 incremental cache (do not edit)
```

Rules:

* Treat every file under `graphify-out/` as build output. Do not edit by hand.
* Add `graphify-out/` to the target repository's `.gitignore` before the first build.
* When reading `graph.json`, prefer MCP queries over direct JSON parsing. The MCP server applies confidence filtering and edge typing that raw JSON does not.

## Audit-Tag Reporting

Every edge in a graphify graph carries an audit tag: `EXTRACTED`, `INFERRED`, or `AMBIGUOUS`. When summarizing graph findings:

| Tag         | How to report                                                               |
|-------------|-----------------------------------------------------------------------------|
| `EXTRACTED` | State as fact: "X depends on Y."                                            |
| `INFERRED`  | Hedge with the confidence score: "X likely depends on Y (confidence 0.74)." |
| `AMBIGUOUS` | Surface as a question, not a claim: "It is unclear whether X depends on Y." |

Never collapse multiple audit tags into a single sentence without distinguishing them. A path through the graph that contains both `EXTRACTED` and `INFERRED` edges is an `INFERRED` path overall — the chain is only as strong as its weakest edge.

## Reading GRAPH_REPORT.md

`GRAPH_REPORT.md` is a generated summary. When the user asks an open-ended exploration question ("what's interesting in this codebase?"), prefer reading `GRAPH_REPORT.md` over running multiple MCP queries — the report already contains god-node, surprising-connection, and suggested-question sections that are cheaper to read than to recompute.

If `GRAPH_REPORT.md` is older than the most recent commit on the default branch, recommend a `graphify . --update` rebuild before relying on it.

## Cost Discipline

The deep-mode rebuild path issues many parallel Claude API calls. Agents must not trigger rebuilds autonomously. When a user's question would benefit from a fresher graph, surface the recommendation and the approximate cost-shape ("roughly N files changed since last build, expect a partial rebuild") and let the user decide.

## Privacy and Upload Discipline

Graphify's deep-extraction stage uploads file *contents* to the Claude API. Before recommending a deep rebuild, check:

* Does the target tree contain secrets, credentials, or `.env` files that are not gitignored?
* Does the tree contain content under upload restrictions (customer data, regulated material)?

If either is true, recommend `--mode fast` (no LLM, AST-only) instead, and note the reduced fidelity in the conversation.

## Out of Scope

These instructions do not cover:

* How to install or configure `graphifyy` — see the [skill](../../skills/experimental/graphify/SKILL.md).
* How to register the MCP server with Copilot Chat — see the skill Quick Start.
* General code-review or refactor practices — graph centrality is not a code-quality signal.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
