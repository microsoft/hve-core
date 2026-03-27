---
description: "Reviews dependency changes in PRs for licensing, maintenance status, necessity, and SHA pinning"
on:
  pull_request:
    types: [opened, synchronize]
    paths:
      - 'package.json'
      - 'package-lock.json'
      - '**/requirements.txt'
      - '**/pyproject.toml'
      - '.devcontainer/**'
      - '.github/workflows/copilot-setup-steps.yml'
  skip-bots: ["dependabot[bot]"]
  reaction: eyes

engine: copilot
timeout-minutes: 15

imports:
  - ../agents/hve-core/dependency-reviewer.agent.md

checkout:
  sparse-checkout: |
    .github/copilot-instructions.md
    .github/instructions/coding-standards/
    .github/instructions/hve-core/
    .github/instructions/shared/
    .devcontainer/
    .github/workflows/copilot-setup-steps.yml
    package.json
    package-lock.json
    **/requirements.txt
    **/pyproject.toml

permissions:
  contents: read
  pull-requests: read

safe-outputs:
  create-pull-request-review-comment:
    max: 10
  submit-pull-request-review:
    max: 1
  add-comment:
    max: 2
    target: "triggering"
  noop:
    max: 1
---

# Dependency Review

Perform a semantic review of dependency changes in pull requests. Evaluate
new dependencies for licensing, maintenance, necessity, and check SHA
pinning compliance for GitHub Actions references.

## Activation Guard

**You MUST call `noop` and stop immediately if any of these conditions are true:**

* The PR is a draft. Call `noop` with message "Skipping: PR is a draft."
* No dependency files were actually modified in the PR diff (path filter may match on renamed files). Call `noop` with message "Skipping: no dependency changes found in diff."

**Failure to call `noop` when no review action is taken will cause workflow failure.**

## Review Procedure

1. Read the PR diff and identify which dependency files changed.
2. For each changed dependency file, identify added, removed, and updated dependencies.
3. Evaluate each change using the review dimensions in the imported agent instructions.
4. Create inline review comments for specific findings.
5. Submit a consolidated review with COMMENT or REQUEST_CHANGES verdict.

## Constraints

* Do not block PRs for informational findings; use COMMENT.
* Only use REQUEST_CHANGES for license incompatibility, missing SHA pinning, or env sync violations.
* Do not duplicate vulnerability scanning already done by Dependabot or CodeQL.
* Maximum 10 inline review comments.

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
