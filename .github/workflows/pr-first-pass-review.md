---
on:
  pull_request:
    types: [opened, ready_for_review]
  skip-bots: ["dependabot[bot]", "github-actions[bot]"]
  reaction: eyes

engine: copilot
timeout-minutes: 15

imports:
  - ../agents/hve-core/pr-review.agent.md

permissions:
  contents: read
  issues: read
  pull-requests: read
  actions: read

safe-outputs:
  create-pull-request-review-comment:
    max: 20
  submit-pull-request-review:
    max: 1
  add-comment:
    max: 3
    target: "triggering"
  update-pull-request:
    max: 1
  add-labels:
    allowed: [needs-revision, review-passed]
    max: 2
  noop:
    max: 1
---

# PR First-Pass Review

Perform an automated first-pass quality review on pull requests from
non-maintainers before any maintainer needs to look at them.

## Activation Guard

Check the PR author's association from the event context.

**You MUST call `noop` and stop immediately if any of these conditions are true:**

* The author is a `MEMBER`, `OWNER`, or `COLLABORATOR`: call `noop` with message "Skipping: PR author is a maintainer."
* The PR is a draft: call `noop` with message "Skipping: PR is a draft."
* The PR modifies more than 50 files: call `noop` with message "Skipping: PR exceeds 50-file review limit."

Only proceed with review for PRs from `CONTRIBUTOR`, `FIRST_TIMER`,
`FIRST_TIME_CONTRIBUTOR`, or `NONE` associations that are not drafts
and contain 50 or fewer changed files.

**Failure to call `noop` when no review action is taken will cause workflow failure.**

## Review Steps

Perform each of the following checks in order. Collect all findings before
submitting a single consolidated review.

### 1. Issue Alignment

Read the PR description and identify linked issues (look for "Fixes #",
"Closes #", "Resolves #", or references in the "Related Issue(s)" section).
For each linked issue:

* Read the issue title and description.
* Verify the PR changes actually address what the issue asks for.
* Note any scope creep (changes beyond the issue scope).
* Note any missing parts (issue requirements not covered by the PR).
* Verify the issue description is still accurate given the PR changes. If
  the issue has become stale or its requirements shifted, flag this.

If no issue is linked, flag this as a required fix.

### 2. PR Template Compliance

Read the PR template at `.github/PULL_REQUEST_TEMPLATE.md`. Compare the
PR description against the template and check:

* The Description section is filled in (not placeholder text).
* The Related Issue(s) section contains valid issue references.
* The Type of Change section has at least one checkbox checked.
* The checked checkboxes match the actual content of the PR. For example:
  * If "Documentation update" is checked, verify docs were actually changed.
  * If "Bug fix" is checked, verify the change fixes a defect.
  * If "New feature" is checked, verify new functionality was added.
  * If "GitHub Actions workflow" is checked, verify workflow files changed.
  * If any AI Artifact checkbox is checked, verify the corresponding file
    types exist in the diff.
* The Testing section describes how changes were tested.
* The Checklist section has required items checked.
* If AI Artifact checkboxes are checked, verify the AI Artifact
  Contributions checklist items are also checked.

Flag unchecked required items and incorrectly checked items.

### 3. Coding Standards Review

Read the `.github/instructions/` files that apply to the changed file types
using their `applyTo` glob patterns. For each changed file:

* Match applicable instruction files.
* Verify the code follows the conventions specified in those instructions.
* Check for naming, formatting, architecture, and pattern compliance.
* Focus on objective violations rather than style preferences.

Also read `.github/copilot-instructions.md` for repo-wide conventions.

### 4. Code Quality and Security

Review the actual diff for:

* Obvious bugs or logic errors.
* Security vulnerabilities (injection, secrets exposure, unsafe input handling).
* Missing error handling at system boundaries.
* Performance concerns (unnecessary loops, missing pagination, resource leaks).
* Breaking changes that are not flagged as such.

### 5. Consolidate and Submit Review

Based on all findings, determine the review verdict:

**REQUEST_CHANGES** when any of these are true:

* No issue is linked.
* PR description is empty or uses only placeholder text.
* No Type of Change checkbox is checked.
* Checked checkboxes contradict the actual changes.
* Required checklist items are unchecked.
* Security vulnerabilities are found.
* Critical coding standard violations exist.
* The PR clearly does not address the linked issue.

**COMMENT** when:

* All required items are present but there are suggestions or minor issues.
* Some coding standard deviations exist but are non-critical.

For each finding, create an inline `create-pull-request-review-comment`
on the specific file and line where the issue occurs. For template and
process findings that are not tied to a specific line, include them in
the review body.

Then call `submit-pull-request-review` with:

* `event`: `REQUEST_CHANGES` or `COMMENT` as determined above.
* `body`: A structured summary including:
  * An overview of the review outcome.
  * A section for Issue Alignment findings.
  * A section for PR Template Compliance findings.
  * A section for Coding Standards findings.
  * A section for Code Quality findings.
  * Specific action items the author must address.

If the verdict is `REQUEST_CHANGES`, also add the label `needs-revision`
to the PR.

If all checks pass with no issues, submit a `COMMENT` review with a brief
confirmation that the PR meets initial quality standards, and add the label
`review-passed`.

If the PR has five or more critical findings (security vulnerabilities,
empty PR description, no linked issue, and fundamental misalignment with
the linked issue), convert the PR to draft by calling `update-pull-request`
with `draft: true` in addition to submitting REQUEST_CHANGES and adding
`needs-revision`. Add a comment explaining that the PR was converted to
draft due to insufficient quality for review.

## Constraints

* Do not approve PRs. Only use `COMMENT` or `REQUEST_CHANGES`.
* Do not modify any files or push code.
* Do not close the PR.
* Be constructive and specific in feedback. Reference the exact instruction
  file and rule when citing coding standard violations.
* Keep inline comments focused: one issue per comment.
* If the PR is too large to review thoroughly (more than 50 changed files),
  post a comment suggesting the author split it into smaller PRs, submit
  `REQUEST_CHANGES`, and stop.
* If no action is needed (maintainer PR or draft), you MUST call the `noop`
  tool with a message explaining why.
