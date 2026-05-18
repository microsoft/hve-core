---
description: "Research a codebase using an existing graphify knowledge graph, with audit-tagged evidence reporting - Brought to you by microsoft/hve-core"
agent: Task Researcher
argument-hint: "topic=... [chat={true|false}]"
---

# Graph Research

Use the [Task Researcher](../../agents/hve-core/task-researcher.agent.md) workflow to investigate a structural question against a pre-built [graphify](https://github.com/safishamsi/graphify) knowledge graph. This prompt complements `task-research` for questions where typed graph queries are sharper than codebase search.

This prompt **never triggers a graph build**. Graph builds have cost, time, and upload implications and are user-initiated. The prompt assumes `graphify-out/graph.json` already exists in the workspace and the `graphify` MCP server is already registered (typically by running `graphify vscode install` from the upstream CLI). Read the [graphify output conventions](../../instructions/experimental/graphify.instructions.md) for the canonical rules; they auto-apply when Copilot reads any file under `graphify-out/`.

## Inputs

* ${input:topic}: (Required) Structural question or focus area (e.g., "what depends on `auth_middleware.py`", "shortest path between `feature_x` and `legacy_config_y`").
* ${input:chat:true}: (Optional, defaults to true) Include conversation context to refine scope.

## Prerequisites

Before starting research:

1. Confirm `graphify-out/graph.json` exists at the workspace root. If absent, stop and report: "No `graphify-out/graph.json` found. Run `graphify . --mode standard --update` from the upstream CLI before invoking `/graph-research`."
2. Attempt the first `mcp_graphify_*` call. The chat session has no API to enumerate available MCP tools, so server availability is confirmed reactively. If the call fails because the tool is unknown or the server is unreachable, stop and report: "Graphify MCP server not registered or unreachable. Run `graphify vscode install` from the upstream CLI and reload the window."

Do not proceed with speculative answers when the graph is unavailable.

## Tool Routing — Graph Beats Grep When…

Use graph evidence when the question is structural and the answer is not a literal string. Map the question to the smallest sufficient MCP tool:

| Question shape                           | Tool                         | Why                                                         |
|------------------------------------------|------------------------------|-------------------------------------------------------------|
| "What is X?" / "Tell me about X"         | `mcp_graphify_get_node`      | Direct node fetch with metadata                             |
| "What does X depend on / call / import?" | `mcp_graphify_get_neighbors` | Edge-typed neighbor lookup                                  |
| "What connects A and B?"                 | `mcp_graphify_shortest_path` | Returns path nodes + edge types                             |
| "What are the central pieces here?"      | `mcp_graphify_god_nodes`     | High-centrality top-N                                       |
| "What clusters / themes exist?"          | `mcp_graphify_graph_stats`   | Communities, density, clustering coefficient                |
| "What community contains X?"             | `mcp_graphify_get_community` | Returns the cluster X belongs to                            |
| Open-ended exploration                   | `mcp_graphify_query_graph`   | Use last; expensive and less deterministic than typed tools |

Reserve `query_graph` for genuine exploration; prefer typed tools when the question fits a typed shape.

## Tool Routing — Grep Beats Graph When…

Fall back to direct codebase search (the default `Researcher Subagent` toolset) when the question is lexical or specific:

* "Where is the string `TODO(perf)` used?"
* "Which files import `requests`?"
* "What changed in the last commit?"
* The graph is missing the file types in scope (e.g., docs not included in the build).
* An `INFERRED` edge contradicts a deterministic grep hit — trust grep.

If the question is lexical, decline the graph route gracefully and hand off to the standard `task-research` flow.

## Reporting Discipline

Every research finding that rests on graph evidence must:

1. Name the MCP tool(s) used and the node IDs touched.
2. Tag each load-bearing edge with its audit tag (`EXTRACTED`, `INFERRED`, `AMBIGUOUS`) and confidence score where present.
3. Distinguish "the graph says" from "I conclude". The graph is evidence, not an oracle.
4. Surface `AMBIGUOUS` edges as open questions, not facts.
5. When the graph contradicts the user's stated assumption, say so directly.
6. End with one suggested file or symbol to read next, picked from the graph result, to ground the conversation in source rather than the graph.

Example reporting shape:

```text
Tool: mcp_graphify_shortest_path(from="auth_middleware.py", to="legacy_session_store")
Path: auth_middleware.py -> session_manager.py -> legacy_session_store
Edge tags: EXTRACTED, INFERRED (confidence 0.71)
Conclusion: There is a 2-hop dependency, but the second hop is INFERRED — the
LLM saw a likely reference. Verify by reading session_manager.py:124-148.
```

The full audit-tag reporting table is in [graphify.instructions.md](../../instructions/experimental/graphify.instructions.md) and auto-applies when Copilot reads files under `graphify-out/`.

## Sensitive-Tree Fallback

If the workspace contains Microsoft-internal source, customer data, regulated material, or unencrypted secrets, and the user asks to build or refresh the graph, recommend `graphify . --mode fast` (AST-only, no LLM, no upload) instead of `--mode standard` or `--mode deep`. Note the reduced fidelity in the response. Do not surface `MOONSHOT_API_KEY` as a configuration option in regulated contexts without explicit clearance — the Moonshot backend is hosted in Beijing and carries separate data-residency implications from Anthropic.

This prompt itself never builds the graph; the fallback applies only when the user asks for a rebuild while research is in progress.

## Requirements

1. Verify the graph and MCP server are available before answering (Prerequisites above).
2. Route the question to the smallest sufficient MCP tool, or decline to the standard `task-research` flow when grep would answer faster.
3. Run research through the `Task Researcher` agent so findings consolidate into `.copilot-tracking/research/{{YYYY-MM-DD}}/{{topic}}-research.md` alongside any non-graph evidence.
4. Tag every load-bearing edge in the research document and chat response with its audit tag and confidence score.
5. Never trigger a graph rebuild from inside this prompt. Surface a rebuild recommendation to the user when staleness materially affects the answer, and let the user run it.
