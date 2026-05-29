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
      - '.devcontainer/**'
  bots: ["dependabot[bot]"]
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
    .github/skills/

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
Post a `COMMENT` review summarizing safety check results, or `REQUEST_CHANGES`
when findings require human action. This workflow never approves PRs: humans
remain the merge gate.

## Activation Guard

**You MUST call `noop` and stop immediately if any of these conditions are true:**

* The PR originates from a fork (`github.event.pull_request.head.repo.id` is null or does not equal `github.repository_id`). Call `noop` with message "Skipping: fork PR, secrets unavailable."
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

### Verdict Selection

This workflow does not approve PRs. GitHub Actions identities are not permitted
to approve pull requests, and human merge approval should remain explicit.
Choose between two verdicts, reserving `REQUEST_CHANGES` for true blockers so the
bot never blocks a PR that only needs human eyes.

**`COMMENT`** (clean confirmation) when ALL of these are true:

* The change is a patch or minor version bump.
* License compatibility is maintained.
* SHA pinning compliance is satisfied for GitHub Actions references.
* No environment synchronization violations exist.
* Dependabot reports no known vulnerabilities.

The review body should briefly confirm that safety checks passed so the human
reviewer can merge with confidence.

**`COMMENT`** (flag for human attention, do not block) when ANY of these are
true:

* The change is a major version bump (breaking changes require human review).
* The changelog mentions breaking changes or deprecations.
* A license change is detected and appears permissive.
* Environment synchronization between `.devcontainer/` and
  `copilot-setup-steps.yml` needs verification.

Call out the specific signal(s) in the review body so the human reviewer knows
where to focus.

**`REQUEST_CHANGES`** when ANY of these are true:

* The dependency introduces a license incompatible with MIT.
* SHA pinning is missing for a GitHub Actions reference.
* A clear environment synchronization violation between `.devcontainer/` and
  `copilot-setup-steps.yml` exists.
* Dependabot reports a known vulnerability the bump fails to resolve.

State the specific finding(s) and the action required to resolve them in the
review body or inline comments.

## Review Output

Submit a single review with the appropriate verdict (`COMMENT` or
`REQUEST_CHANGES`, never `APPROVE`). Include:

* A summary of dependencies updated with version ranges.
* The bump classification (patch, minor, or major) for each dependency.
* Any findings from the safety checks.
* For clean `COMMENT` reviews, a brief confirmation that all safety checks passed.

Use inline `create-pull-request-review-comment` for findings tied to specific lines.

## Constraints

* Only process PRs authored by `dependabot[bot]`.
* Do not duplicate vulnerability scanning already done by Dependabot or CodeQL.
* Never approve or merge the PR; humans remain the merge gate.
* Maximum 5 inline review comments.
* Keep review comments actionable and specific.

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
