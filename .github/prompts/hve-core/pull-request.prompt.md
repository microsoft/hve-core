---
description: 'Generates pull request descriptions from branch diffs - Brought to you by microsoft/hve-core'
agent: agent
argument-hint: "[branch=origin/main] [createPullRequest=false] [excludeMarkdown={true|false}]"
---

# Pull Request

## Inputs

* ${input:branch:origin/main}: (Optional, defaults to origin/main) Base branch reference for diff generation
* ${input:createPullRequest:false}: (Optional, determined through conversation provided by user) When true, then explicitly include following instructions for creating pull request with MCP tools.
* ${input:excludeMarkdown:false}: (Optional) When true, exclude markdown diffs from pr-reference generation

## Requirements

Read and follow all instructions from `hve-core/pull-request.instructions.md` to generate a pull request body of changes using the pr-reference Skill with parallel subagent review.

---

Generate a new pr.md file following the pull-request instructions.

* Analyzes branch diffs against the base branch and reviews changes using parallel subagents.
* Produces `.copilot-tracking/pr/pr.md` with the final PR description, along with temporary analysis artifacts in `.copilot-tracking/pr/subagents/`.
* Creates a pull request via MCP tools when explicitly requested.
