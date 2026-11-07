---
description: "Manual quality review on pull requests, triggered by /review"
on:
  slash_command:
    name: review
    events: [pull_request_comment, pull_request_review_comment]
  roles: [admin, maintainer, write]
  reaction: eyes
  # The pre-activation job needs no token scopes; declaring that explicitly
  # keeps scanners from reading the empty workflow default as unset.
  permissions:
    contents: none

engine:
  id: copilot
  # Pinned Copilot CLI; scripts/security/tool-checksums.json records it.
  version: "1.0.87"
runs-on: ubuntu-24.04
runs-on-slim: ubuntu-24.04
runtimes:
  node:
    version: "24.21.0"
# runtimes.node opts the agent into Node registry and CDN domains; the agent
# installs no packages, so the Node ecosystem stays blocked.
network:
  allowed:
    - defaults
  blocked:
    - node
timeout-minutes: 15

checkout:
  # Skills and instructions the code-review skill reads at runtime. The
  # accessibility perspective needs only the accessibility skill entry and
  # its framework references.
  sparse-checkout: |
    .github/copilot-instructions.md
    .github/PULL_REQUEST_TEMPLATE.md
    .github/instructions/
    .github/skills/coding-standards/code-review/
    .github/skills/coding-standards/code-review-core/
    .github/skills/coding-standards/code-review-functional/
    .github/skills/coding-standards/code-review-standards/
    .github/skills/coding-standards/code-review-accessibility/
    .github/skills/coding-standards/code-review-security/
    .github/skills/coding-standards/code-review-readiness/
    .github/skills/coding-standards/hve-artifact-authoring/
    .github/skills/coding-standards/python-foundational/
    .github/skills/shared/telemetry-foundations/
    .github/skills/accessibility/accessibility/SKILL.md
    .github/skills/accessibility/accessibility/references/frameworks/
    scripts/
    docs/
    package.json

permissions:
  contents: read
  issues: read
  pull-requests: read
  actions: read

safe-outputs:
  threat-detection:
    runs-on: ubuntu-24.04
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
    max: 1
  noop:
    max: 1
---

# PR Review

Perform a quality review on a pull request when a maintainer or contributor
invokes `/review` in a PR conversation comment or inline review comment. This
workflow is manual-only; it does not run automatically on PR open or update,
and it does not respond to `/review` placed in the PR description body.
Because it is triggered via comment events on the base repository, it runs in
the base-repo context with full secrets and write access, so it works on PRs
from forks as well as same-repo PRs.

## Maintainer Advisory Mode

Determine the PR author's association from the event context. For PR
conversation comments, read `github.event.issue.user.author_association`; for
PR review comments, read `github.event.pull_request.user.author_association`.
If the PR author is a `MEMBER`, `OWNER`, or `COLLABORATOR`, set the review
mode to **advisory**.
In advisory mode:

* Never use `REQUEST_CHANGES`. Use `COMMENT` for all findings.
* Do not add the `needs-revision` label.
* Do not convert PRs to draft.
* Prefix the review summary with "Advisory review, this PR is from a
  maintainer. Findings are informational only."

For all other associations (`CONTRIBUTOR`, `FIRST_TIMER`,
`FIRST_TIME_CONTRIBUTOR`, `NONE`), use the standard review mode with full
enforcement.

## Code Review Skill Activation

This workflow is the host-managed automation contract for the `code-review`
skill. Read these before reviewing and follow them as the review policy for
this run:

1. `.github/skills/coding-standards/code-review/SKILL.md`, including its
   Host-managed automation section
2. `.github/skills/coding-standards/code-review-core/SKILL.md` and its
   `references/review-contract.md`
3. The `SKILL.md` of each perspective skill under
   `.github/skills/coding-standards/`: `code-review-functional`,
   `code-review-standards`, `code-review-accessibility`,
   `code-review-security`, and `code-review-readiness`
4. For accessibility, `.github/skills/accessibility/accessibility/SKILL.md`
   and only the files under its `references/frameworks/` that the changed
   surface needs
5. For standards, the applicable `.github/instructions/` files and the
   matching domain skills: `python-foundational` and `hve-artifact-authoring`
   under `.github/skills/coding-standards/`, and
   `.github/skills/shared/telemetry-foundations/`

Run the skill with these fixed settings:

* Profile `full`: the functional, standards, accessibility, security, and
  readiness perspectives.
* Depth `basic`.
* No human pauses. Accept the change scope derived from the PR diff and treat
  derived choices as agent-owned.
* Apply each perspective inline. Do not dispatch subagents.
* Keep review state in memory. Do not run the `code-review-core` helper, write
  tracking files or a local report, or open a canvas.
* This run supplies no business-alignment sources or Security Plan Drift
  baseline, so those comparisons do not run.

The review target is the pull request that received the `/review` comment.
Before step 1, read its open or closed state, base and head SHAs, description,
linked issues, changed files, and diff through the GitHub tools. Record the
state and both SHAs for the freshness check in step 5. If the pull request
cannot be read, call `noop` with the reason.

## Instruction Priority

Follow the Review Steps below as the authoritative procedure and output
contract. This workflow owns target acquisition, output, freshness checks,
and publication. The skills supply the review criteria and the finding
verification, severity, and coverage rules. The Review Steps, not the skill's
outcome, set the review event, labels, and draft conversion. Report findings
in the matching review body section: readiness metadata under Issue Alignment
or PR Template Compliance, standards under Coding Standards, and functional,
security, accessibility, and changed-documentation findings under Code
Quality. When required review work is blocked or unavailable, state what was
not reviewed in the overview and do not add `review-passed`.

Search for and apply `content-policy-citation.instructions.md` before submitting
PR review comments, review summaries, PR updates, or other GitHub-visible text
that references or alludes to a suspected content-policy or terms-of-service
concern. When the output is community-facing, also search for and apply the
relevant community writing instructions for the context.

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

Based on all findings, determine the review verdict. If the review mode is
**advisory** (maintainer PR), always use `COMMENT` regardless of findings.

**REQUEST_CHANGES** (non-maintainer PRs only) when any of these are true:

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

Immediately before the first safe output that writes to the PR, re-read the
pull request and compare its open or closed state and its base and head SHAs
with the values recorded before step 1. If any of them changed, do not submit
the review, inline comments, labels, or draft conversion. Post one
`add-comment` stating that the review was not submitted because the pull
request changed while it ran, then stop. Otherwise, confirm that each inline
comment's path and line still fall on a changed line on the RIGHT side of the
current diff, and move any finding that does not map into the review body.

For each finding, create an inline `create-pull-request-review-comment`
on the specific file and line where the issue occurs. For template and
process findings that are not tied to a specific line, include them in
the review body.

When a finding references a suspected content-policy or terms-of-service
concern, follow the imported content-policy guard. The public inline
comment or review body must cite only the file path and line range, use
neutral wording, and omit category labels, rationale, quoted snippets,
paraphrases, payload examples, and deep links.

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
to the PR. Skip this in advisory mode.

If all checks pass with no issues, submit a `COMMENT` review with a brief
confirmation that the PR meets initial quality standards, and add the label
`review-passed`.

If the PR has five or more critical findings (security vulnerabilities,
empty PR description, no linked issue, and fundamental misalignment with
the linked issue) and the review mode is **not** advisory, convert the PR
to draft by calling `update-pull-request` with `draft: true` in addition
to submitting REQUEST_CHANGES and adding `needs-revision`. Add a comment
explaining that the PR was converted to draft due to insufficient quality
for review.

## Constraints

* Do not approve PRs. Only use `COMMENT` or `REQUEST_CHANGES`.
* Do not modify any files or push code.
* Do not close the PR.
* Be constructive and specific in feedback. Reference the exact instruction
  file and rule when citing coding standard violations.
* For content-policy concerns, use only the neutral shared template from the
  imported content-policy guard.
* Keep inline comments focused: one issue per comment.
* If the PR is too large to review thoroughly (more than 50 changed files),
  post a comment suggesting the author split it into smaller PRs, submit
  `REQUEST_CHANGES`, and stop.
* If you decide no review action is appropriate, call the `noop` tool with
  a message explaining why.
