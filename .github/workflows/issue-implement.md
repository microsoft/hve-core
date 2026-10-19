---
description: "Analyzes agent-ready issues and opens pull requests with the implementation"
on:
  issues:
    types: [labeled]
    names: [agent-ready]
  # Also support manual trigger via slash command in issue comments
  # command:
  #   name: implement
  roles: [admin, maintainer, write]
  skip-bots: ["dependabot[bot]", "github-actions[bot]"]
  reaction: eyes

engine: copilot
timeout-minutes: 30

checkout:
  sparse-checkout: |
    .github/workflows/
    .github/copilot-instructions.md
    .github/instructions/coding-standards/
    .github/instructions/hve-core/
    .github/instructions/shared/
    scripts/
    package.json
    justfile

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
  noop:
    max: 1
---

# Issue Implementation Agent

When an issue is labeled `agent-ready`, analyze the issue, research the
codebase, plan the implementation, and open a pull request with the changes.

## Activation Guard

Only proceed if the triggering label is `agent-ready`.

**If the triggering label is not `agent-ready`, you MUST call `noop` with the message "Skipping: triggering label is not agent-ready" and stop immediately. Do not add a comment.**

**Failure to call `noop` when no implementation action is taken will cause workflow failure.**

## Instruction Priority

Follow the Workflow section below as the sole implementation procedure. This
workflow is self-contained and does not import another agent protocol.

## Workflow

1. Read the issue title and description from
   `${{ steps.sanitized.outputs.text }}`. Identify what needs to change,
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

## Security Scanning Policy

Follow the repository code-scanning alert lifecycle:
<https://github.com/microsoft/hve-core/blob/main/docs/security/code-scanning-alert-lifecycle.md>.

* Never dismiss Code Scanning, CodeQL, Scorecard, or dependency alerts.
* Never add CodeQL configuration exclusions, query filters, inline suppressions,
  or `__all__` exports to satisfy a query.
* Never add allowlist entries, including `audit-ci.json` advisories or
  allowed-advisory entries in `dependency-review.yml`.
* Never add or extend an entry in `security/code-scanning-exceptions.yml`.
* If no code or configuration fix exists, comment with the evidence, explain
  that a human must decide whether a tracked exception is appropriate, and
  stop without opening a pull request.

## Constraints

* Do not modify files unrelated to the issue.
* Do not add tests, documentation, or refactoring beyond what the issue
  explicitly requests.
* If the issue is ambiguous or too large, post a comment asking for
  clarification instead of guessing.
* Keep the PR small and focused.
