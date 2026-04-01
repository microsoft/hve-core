---
description: "Detects stale documentation after code changes and creates issues for updates"
on:
  push:
    branches: [main]
    paths:
      - 'scripts/**'
      - '.github/agents/**'
      - '.github/instructions/**'
      - '.github/skills/**'
      - '.github/prompts/**'
      - 'extension/**'
      - 'collections/**'
      - '.devcontainer/**'
      - '.github/workflows/**'
      - '!.github/workflows/*.lock.yml'
  skip-bots: ["dependabot[bot]", "github-actions[bot]"]

engine: copilot
timeout-minutes: 15

imports:
  - ../agents/doc-update-checker.agent.md

checkout:
  sparse-checkout: |
    .github/copilot-instructions.md
    .github/ISSUE_TEMPLATE/
    .github/instructions/coding-standards/
    .github/instructions/hve-core/
    .github/instructions/shared/
    .github/workflows/
    docs/
    scripts/
    collections/
    extension/
    .devcontainer/

permissions:
  contents: read
  issues: read

safe-outputs:
  create-issue:
    max: 3
    labels: [documentation, needs-triage]
    title-prefix: "docs: "
  noop:
    max: 1
---

# Documentation Update Check

When code changes merge to main, check whether related documentation
still accurately describes the implementation. Open focused issues for
any documentation that has become stale.

## Activation Guard

**You MUST call `noop` and stop immediately if any of these conditions are true:**

* All changed files are documentation files (paths under `docs/`). Call `noop` with message "Skipping: only documentation files changed."
* Every code file changed in the push has its mapped documentation file also changed in the same push. Call `noop` with message "Skipping: documentation was updated alongside code."

**Failure to call `noop` when no documentation check is needed will cause workflow failure.**

## Procedure

1. Read the list of files changed in the push from the event context.
2. Filter out documentation-only changes.
3. For each code file changed, identify the documentation references using the mapping in the imported agent instructions.
4. Read each referenced documentation file.
5. Compare the documentation against the current implementation.
6. For documentation that no longer accurately describes the implementation, search for existing open issues about the same documentation file.
7. If no existing issue covers the gap, create a new issue following the guidelines below.

## Issue Creation Guidelines

When creating issues, use the **bug-report** template structure from `.github/ISSUE_TEMPLATE/bug-report.yml`:

* Use the `docs:` prefix in the title followed by a concise description (e.g., `docs: update scripts/README.md for new linting commands`).
* Structure the issue body to match the bug-report template fields.
* Apply `documentation`, `needs-triage`, and `agent-ready` labels so the issue-implement workflow can pick them up.

### Bug-Report Template Field Mapping

| Template Field     | Content                                                              |
|--------------------|----------------------------------------------------------------------|
| Component          | Always `Documentation`                                               |
| Bug Description    | Describe what documentation is stale and what changed in code        |
| Expected Behavior  | Describe what the documentation should say after the update          |
| Steps to Reproduce | Reference the specific commit or PR that introduced the change       |
| Additional Context | Link to the specific documentation file(s) and code file(s)         |

## Constraints

* Maximum 3 issues per push.
* Do not modify files.
* Skip changes that are purely cosmetic (formatting, whitespace, comments).
* Do not create issues when documentation was updated in the same push.

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
