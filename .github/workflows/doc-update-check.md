---
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
  skip-bots: ["dependabot[bot]", "github-actions[bot]"]

engine: copilot
timeout-minutes: 15

imports:
  - ../agents/hve-core/doc-update-checker.agent.md

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
* All changed files already have documentation updates in the same push. Call `noop` with message "Skipping: documentation was updated alongside code."

**Failure to call `noop` when no documentation check is needed will cause workflow failure.**

## Procedure

1. Read the list of files changed in the push from the event context.
2. Filter out documentation-only changes.
3. For each code file changed, identify the documentation references using the mapping in the imported agent instructions.
4. Read each referenced documentation file.
5. Compare the documentation against the current implementation.
6. For documentation that no longer accurately describes the implementation, search for existing open issues about the same documentation file.
7. If no existing issue covers the gap, create a new issue with the `docs:` title prefix.

## Constraints

* Maximum 3 issues per push.
* Do not modify files.
* Skip changes that are purely cosmetic (formatting, whitespace, comments).
* Do not create issues when documentation was updated in the same push.
