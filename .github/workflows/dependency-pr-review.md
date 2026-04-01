---
description: "Reviews and auto-approves Dependabot version bump PRs after safety validation"
on:
  pull_request:
    types: [opened, synchronize]
    paths:
      - 'package.json'
      - 'package-lock.json'
      - '**/requirements.txt'
      - '**/pyproject.toml'
      - '.github/workflows/*.yml'
      - '.devcontainer/**'
  reaction: eyes

engine: copilot
timeout-minutes: 15

imports:
  - ../agents/dependency-reviewer.agent.md

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
    max: 5
  submit-pull-request-review:
    max: 1
  add-comment:
    max: 2
    target: "triggering"
  noop:
    max: 1
---

# Dependabot PR Review

Review pull requests authored by Dependabot that bump dependency versions.
Approve the PR when the version bump is safe, or leave a comment explaining
concerns that require human review.

## Activation Guard

**You MUST call `noop` and stop immediately if any of these conditions are true:**

* The PR author is NOT `dependabot[bot]`. Call `noop` with message "Skipping: PR author is not Dependabot."
* The PR is a draft. Call `noop` with message "Skipping: PR is a draft."
* No dependency files were actually modified in the PR diff. Call `noop` with message "Skipping: no dependency changes found in diff."

**Failure to call `noop` when no review action is taken will cause workflow failure.**

## Review Procedure

1. Read the PR title, description, and diff to identify which dependencies changed.
2. Classify each change as a patch, minor, or major version bump.
3. Review the Dependabot PR body for changelog links, release notes, and compatibility information.
4. Evaluate each change using the review dimensions below.

### Safety Checks

For each dependency change, verify:

* The license remains compatible with the project's MIT license.
* GitHub Actions references use SHA pinning with a version comment.
* No new dependencies were introduced (Dependabot bumps existing dependencies only).
* The bump does not introduce a known vulnerability (check Dependabot's own assessment).
* Devcontainer and `copilot-setup-steps.yml` remain synchronized when both are affected.

### Approval Criteria

**Approve** the PR when ALL of these conditions are met:

* The change is a patch or minor version bump.
* License compatibility is maintained.
* SHA pinning compliance is satisfied for GitHub Actions references.
* No environment synchronization violations exist.
* Dependabot reports no known vulnerabilities.

**Comment without approving** when ANY of these conditions are true:

* The change is a major version bump (potential breaking changes require human review).
* A license change is detected but appears permissive (needs human confirmation).
* The changelog mentions breaking changes or deprecations.
* Environment synchronization between `.devcontainer/` and `copilot-setup-steps.yml` needs verification.

**Request changes** only when:

* The dependency introduces a license incompatible with MIT.
* SHA pinning is missing for a GitHub Actions reference.
* A clear environment synchronization violation exists.

## Review Output

Submit a single review with the appropriate verdict. Include:

* A summary of dependencies updated with version ranges.
* The bump classification (patch, minor, or major) for each dependency.
* Any findings from the safety checks.
* For approvals, a brief confirmation that all safety checks passed.

Use inline `create-pull-request-review-comment` for findings tied to specific lines.

## Constraints

* Only process PRs authored by `dependabot[bot]`.
* Do not duplicate vulnerability scanning already done by Dependabot or CodeQL.
* Do not merge the PR; approval alone is sufficient.
* Maximum 5 inline review comments.
* Keep review comments actionable and specific.

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
