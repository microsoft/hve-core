---
description: 'Generates pull request descriptions from branch diffs - Brought to you by microsoft/hve-core'
agent: agent
argument-hint: "[branch=origin/main] [excludeMarkdown={true|false}]"
---

# Pull Request

## Inputs

* ${input:branch:origin/main}: (Optional, defaults to origin/main) Base branch reference for diff generation
* ${input:excludeMarkdown}: (Optional) When true, exclude markdown diffs from pr-reference generation

## Requirements

Read and follow all instructions from `pull-request.instructions.md` to generate a pull request body of changes using the pr-reference Skill with parallel subagents.

---

Generate a new pr.md file following the pull-request instructions.
