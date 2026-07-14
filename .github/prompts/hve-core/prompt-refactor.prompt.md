---
description: 'Refactor prompt-engineering artifacts while preserving behavior through HVE Builder refactor mode'
agent: Prompt Builder
argument-hint: "[promptFiles=...] [requirements=...]"
---

# Prompt Refactor

## Inputs

* `${input:promptFiles}`: existing prompt-engineering artifacts inside the approved write boundary; defaults to current open or attached files
* `${input:requirements}`: cleanup objectives, constraints, and behavior that must remain unchanged

## Requirements

1. Route the targets to `hve-builder` refactor mode.
2. Derive evidence-backed cleanup objectives from baseline review when requirements are omitted.
3. Preserve documented behavior unless the user explicitly approves a behavior change.
4. Complete static review, behavior testing, and host validation before reporting Pass.
5. Return changed files, rationale, gate results, overall outcome, and evidence links.
