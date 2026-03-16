---
on:
  issues:
    types: [labeled]
  # Also support manual trigger via slash command in issue comments
  # command:
  #   name: implement

skip-bots: ["dependabot[bot]", "github-actions[bot]"]

engine: copilot

imports:
  - ../agents/hve-core/task-implementor.agent.md

permissions:
  contents: read
  issues: read
  pull-requests: read
  actions: read

safe-outputs:
  create-pull-request:
    max: 1
  add-comment:
    max: 5
    target: "triggering"
---

# Issue Implementation Agent

When an issue is labeled `agent-ready`, analyze the issue, research the
codebase, plan the implementation, and open a pull request with the changes.

## Activation Guard

Only proceed if the triggering label is `agent-ready`.

**If the triggering label is not `agent-ready`, you MUST call `noop` with the message "Skipping: triggering label is not agent-ready" and stop immediately. Do not add a comment.**

**Failure to call `noop` when no implementation action is taken will cause workflow failure.**

## Workflow

1. Read the issue title and description from
   `${{ needs.activation.outputs.text }}`. Identify what needs to change,
   which files are involved, and any acceptance criteria.

2. Search for relevant files, existing patterns,
   and conventions. Read the instructions in `.github/instructions/` that
   apply to the file types you will modify. Follow all coding standards.

3. Outline the changes needed. Keep the scope
   minimal; implement only what the issue asks for.

4. Make the changes. Mirror existing architecture, naming,
   and data-flow patterns. Avoid partial implementations.

5. Verify the changes compile, follow repo conventions,
   and satisfy the issue's acceptance criteria.

6. Create a PR that references the issue. Include
   a clear description of what changed and why. The PR title should start
   with the issue number.

## Constraints

* Do not modify files unrelated to the issue.
* Do not add tests, documentation, or refactoring beyond what the issue
  explicitly requests.
* If the issue is ambiguous or too large, post a comment asking for
  clarification instead of guessing.
* Keep the PR small and focused.
