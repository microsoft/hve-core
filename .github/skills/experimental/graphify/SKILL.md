---
name: graphify
description: 'Build and query knowledge graphs over a codebase using the graphifyy CLI and MCP server - Brought to you by microsoft/hve-core'
license: MIT
compatibility: 'Requires Python 3.10+, the graphifyy PyPI package (pinned), and an ANTHROPIC_API_KEY environment variable for the semantic-extraction stage. GitHub Copilot Chat uses the graphify MCP server for queries.'
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-04-29"
---

# Graphify Skill

Use this skill to build a knowledge graph over a folder of source code, documentation, PDFs, and images, and to query that graph from GitHub Copilot Chat. The graph surfaces structural relationships, high-centrality nodes, and clusters that are not visible from grep alone.

This skill wraps the upstream [`graphifyy`](https://pypi.org/project/graphifyy/) PyPI package — it does not reimplement Graphify. Pin a single version of `graphifyy` so behaviour stays stable as the upstream project iterates.

## Third-Party Attribution

Graphify is an MIT-licensed project by Safi Shamsi. See <https://github.com/safishamsi/graphify>. This skill orchestrates the upstream CLI and MCP server; no upstream source is vendored.

## Prerequisites

| Requirement         | Notes                                                                                                    |
|---------------------|----------------------------------------------------------------------------------------------------------|
| Python 3.10+        | Match the upstream `graphifyy` minimum                                                                   |
| `graphifyy`         | Install with `pip install graphifyy==0.5.4`. The CLI binary is `graphify` (single `y`)                   |
| `ANTHROPIC_API_KEY` | Required for deep-mode semantic extraction. Each build issues parallel Claude calls — budget accordingly |
| MCP-capable client  | GitHub Copilot Chat in VS Code 1.97+ reads `.vscode/mcp.json` and surfaces tools as `mcp_graphify_*`     |

Optional extras:

| Extra              | Purpose                                                            |
|--------------------|--------------------------------------------------------------------|
| `graphifyy[video]` | Adds yt-dlp + Whisper for transcribing audio/video sources         |
| Neo4j driver       | Required only if pushing the graph to a Neo4j instance for queries |
| `obsidian` extras  | Required only when exporting an Obsidian vault                     |

## Quick Start

### 1. Build a graph

```bash
graphify ./path/to/repo --mode deep --update
```

This writes outputs into `./path/to/repo/graphify-out/`:

| File              | Purpose                                                                  |
|-------------------|--------------------------------------------------------------------------|
| `graph.json`      | Canonical graph data (nodes, edges, communities, audit tags)             |
| `graph.html`      | Interactive vis.js visualization                                         |
| `GRAPH_REPORT.md` | God nodes, surprising connections, suggested questions, token-cost table |
| `wiki/`           | One markdown article per community (agent-crawlable)                     |
| `cache/`          | SHA256 incremental cache for `--update` and `--watch`                    |

The `graphify-out/` directory **must be gitignored** in target repositories. See [graphify.instructions.md](../../../instructions/experimental/graphify.instructions.md) for the canonical pattern.

### 2. Register the MCP server with Copilot Chat

Add `graphify` to the workspace's `.vscode/mcp.json`:

```json
{
  "servers": {
    "graphify": {
      "command": "python3",
      "args": ["-m", "graphify.serve", "graphify-out/graph.json"],
      "type": "stdio"
    }
  }
}
```

Reload the VS Code window. Copilot Chat surfaces these tools (names follow GHCC's `mcp_<server>_<tool>` convention):

| Tool                         | Purpose                                                       |
|------------------------------|---------------------------------------------------------------|
| `mcp_graphify_query_graph`   | Free-form natural-language query against graph + communities  |
| `mcp_graphify_get_node`      | Fetch a node by ID with metadata                              |
| `mcp_graphify_get_neighbors` | Direct neighbours of a node, optionally filtered by edge type |
| `mcp_graphify_get_community` | All nodes in a community (cluster)                            |
| `mcp_graphify_god_nodes`     | High-centrality nodes (top connectors)                        |
| `mcp_graphify_graph_stats`   | Counts, density, clustering coefficient                       |
| `mcp_graphify_shortest_path` | Shortest path between two nodes                               |

### 3. Ask Copilot Chat structural questions

Once the MCP server is registered, the `@graph-researcher` agent (this collection) can answer questions like:

* "What other modules are implicitly affected if I change `auth_middleware.py`?"
* "Which agents in `.github/agents/` are most connected to security artifacts?"
* "Show me the shortest path between `feature_x` and `legacy_config_y`."
* "What communities exist in this repo, and which one is the auth code in?"

## Build Modes

| Mode               | Flag          | When to use                                                                                    |
|--------------------|---------------|------------------------------------------------------------------------------------------------|
| Fast               | `--mode fast` | AST/tree-sitter only. Deterministic, no LLM calls, no API key required. Use for CI smoke tests |
| Standard (default) | (no flag)     | AST + selective semantic extraction. Reasonable cost, good coverage                            |
| Deep               | `--mode deep` | Full parallel Claude semantic extraction. Highest fidelity, highest cost                       |
| Update             | `--update`    | Reuses the SHA256 cache; rebuilds only changed files. Safe to combine with any mode            |
| Watch              | `--watch`     | Daemon mode; rebuilds on file change                                                           |

For HVE Core's primary use case (analysing the artifact library itself), prefer `--mode standard --update`.

## Edge Audit Tags

Every edge in `graph.json` carries one of:

| Tag         | Meaning                                                                          |
|-------------|----------------------------------------------------------------------------------|
| `EXTRACTED` | Derived deterministically from AST/tree-sitter — high confidence                 |
| `INFERRED`  | Derived from LLM semantic extraction — medium confidence, has `confidence_score` |
| `AMBIGUOUS` | Multiple candidate interpretations — low confidence, surface to user             |

When the `@graph-researcher` agent answers a question, it must report the audit tag of the edges its conclusion rests on. Do not collapse `INFERRED` and `EXTRACTED` evidence in summaries.

## Cost and Safety Notes

* Deep-mode builds dispatch many parallel Claude calls. A first build over a 10k-file repo can run several USD; budget before enabling.
* Graphify uploads file *contents* to the Claude API during semantic extraction. Do not run deep mode against repositories containing secrets or content under upload restrictions. Use `--mode fast` (no LLM) for sensitive trees.
* The `cache/` directory under `graphify-out/` contains hashed file content snapshots. Treat it like build output — gitignore it.
* The MCP server reads `graph.json` from disk and exposes it over stdio. Do not commit `graph.json` to repos with private content.

## Troubleshooting

| Symptom                                          | Cause                                                     | Resolution                                                                  |
|--------------------------------------------------|-----------------------------------------------------------|-----------------------------------------------------------------------------|
| `graphify: command not found`                    | Wrong package name installed                              | The PyPI distribution name is `graphifyy` (double y); the CLI is `graphify` |
| `ANTHROPIC_API_KEY is not set`                   | Deep mode invoked without API credentials                 | Export the key, or downgrade to `--mode fast`                               |
| `graphify-out/graph.json not found`              | MCP server started before first build                     | Run `graphify <path>` once before reloading the VS Code window              |
| MCP tools not visible in Copilot Chat            | `.vscode/mcp.json` missing or VS Code not reloaded        | Confirm file path, then `Developer: Reload Window`                          |
| Graph contains no edges                          | Repository contains only file types Graphify cannot parse | Verify with `graphify <path> --dry-run` to see detected file types          |
| Stale results after edits                        | Cache hit on changed files                                | Run with `--update` (recommended) or delete `graphify-out/cache/`           |
| Edge `INFERRED` confidence is low for many edges | Deep extraction over an unfamiliar codebase               | Increase `--mode deep` budget or treat low-confidence edges as hypotheses   |

## Version Pinning Policy

The upstream `graphifyy` project is on default branch `v5` with frequent releases. This skill pins to a specific version. Bumps to the pinned version follow the standard `feat(skills)` / `fix(skills)` commit flow and require:

1. A re-run of the skill's regression tests in [tests/](tests/).
2. A diff review of the upstream `CHANGELOG` for breaking tool-name or output-shape changes that would invalidate `graph-researcher` agent assumptions.
3. A note in the version-bump commit body referencing the upstream tag.

> Brought to you by microsoft/hve-core

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
