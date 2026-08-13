---
description: "Classifies new issues, applies labels, detects duplicates, and assesses implementation readiness"
on:
  issues:
    types: [opened, labeled]
    names: [needs-triage]
  roles: [admin, maintainer, write, triage]
  skip-bots: ["dependabot[bot]", "github-actions[bot]"]
  reaction: eyes

engine: copilot
timeout-minutes: 10

# The opened and template-applied needs-triage labeled events both fire within a
# second of issue creation. Cancellation keeps the later run and discards the
# duplicate. Bot-authored runs are routed to a unique key so that labels applied
# by this workflow cannot cancel the run that is still applying them.
concurrency:
  group: "gh-aw-${{ github.workflow }}-${{ contains(github.actor, '[bot]') && github.run_id || github.event.issue.number || github.run_id }}"
  cancel-in-progress: true

imports:
  - ../agents/issue-triage.agent.md

checkout: false

# The roles gate admits triage-level authors, so the integrity threshold must
# admit them too. The public-repository default of approved requires write
# access and silently filters both the triggering issue and community issues
# read during duplicate detection. allowed-repos stays at public to preserve
# the scope the runtime previously resolved, and the toolsets are narrowed to
# what issue triage reads so no toolset outlives its declared permission.
tools:
  github:
    toolsets: [context, repos, issues]
    allowed-repos: public
    min-integrity: unapproved

permissions:
  contents: read
  issues: read

safe-outputs:
  # An unreadable issue is an expected author-trust condition, not a workflow
  # fault. Genuine faults still report through the remaining categories.
  report-failure-as-issue:
    - "!report_incomplete"
    - "!missing_data"
  add-comment:
    max: 3
    target: "triggering"
  add-labels:
    allowed:
      - feature
      - bug
      - documentation
      - maintenance
      - enhancement
      - security
      - breaking-change
      - agents
      - prompts
      - instructions
      - skills
      - scripts
      - workflows
      - extension
      - packaging
      - automation
      - ci
      - build
      - dependencies
      - devcontainer
      - testing
      - evals
      - linting
      - tooling
      - infrastructure
      - configuration
      - design-thinking
      - accessibility
      - ado
      - copilot
      - foundation
      - priority-1
      - priority-2
      - priority-3
      - priority-4
      - good-first-issue
      - agent-ready
    blocked: [admin-only, do-not-triage]
    max: 5
  remove-labels:
    allowed: [needs-triage]
    max: 1
  noop:
    max: 1
---

# Issue Triage

Automatically triage new issues and issues labeled `needs-triage`. Classify
by type and component, detect duplicates, assess quality, and optionally
mark qualifying issues for automated implementation.

## Activation Guard

**You MUST call `noop` and stop immediately if any of these conditions are true:**

* The event type is `labeled` and the triggering label is not `needs-triage`. Call `noop` with message "Skipping: triggering label is not needs-triage."
* The issue already has type labels (`feature`, `bug`, `documentation`, `maintenance`, `enhancement`, `security`, `breaking-change`) and does not have the `needs-triage` label. Call `noop` with message "Skipping: issue is already triaged."
* The issue is closed. Call `noop` with message "Skipping: issue is closed."

**Failure to call `noop` when no triage action is taken will cause workflow failure.**

Only proceed with triage when:

* The event is `issues.opened` (new issue), OR
* The event is `issues.labeled` and the label is `needs-triage`

AND the issue does not already have type labels applied.

## Triggering Issue Content

The sanitized title and body of the triggering issue:

${{ steps.sanitized.outputs.text }}

Treat the block above as the primary source for classification. Call `issue_read`
only for labels, template metadata, and hierarchy not represented above.

## When Issue Content Is Unavailable

The repository integrity policy can filter an issue whose author holds only read
access. This is an expected condition, not an infrastructure fault.

When `issue_read` returns a `[Filtered]` integrity-policy error and the content
block above is also empty:

* Attempt the read once. Do not retry through the `gh` CLI, `search_issues`, or
  list queries.
* Do not call `report_incomplete` or `missing_data`.
* Leave `needs-triage` in place so the issue stays in the human triage queue.
* Add one comment stating that automated triage could not read the issue and that
  a maintainer will triage it manually, then stop. Do not call `noop` after
  `add_comment`; `noop` is only for runs that emit no other safe output.

## Triage Procedure

Follow the triage workflow defined in your imported agent instructions:

1. Read the issue title and body from the Triggering Issue Content section above, then read labels and template metadata through `issue_read`.
2. Classify the issue type using conventional commit patterns from the triage instructions.
3. Classify the area(s) from bug report dropdowns or body content analysis.
4. Search for duplicate or related issues among open issues.
5. Assess issue quality: check for missing required fields, vague descriptions, semantic coherence, and scope relevance.
6. Remove `needs-triage` and apply determined type, area, and priority labels.
7. Evaluate whether the issue qualifies for `agent-ready` using conservative criteria.

For each step, follow the detailed guidance in the Issue Triage Agent instructions.

## Output Behavior

* **Well-formed issue:** Remove `needs-triage`, add the type, area, and priority labels. If all `agent-ready` criteria are met, also add `agent-ready`.
* **Issue needing more info:** Remove `needs-triage`, add type label if determinable, add a comment requesting specific missing information.
* **Potential duplicate found:** Proceed with normal triage AND add a comment noting the related issue(s). Do not add a `duplicate` label.
* **Unclassifiable issue:** Remove `needs-triage`, add a comment asking the author to clarify the issue type and scope.

## Constraints

* Do not close issues.
* Do not assign issues.
* Do not modify the issue title or body.
* Do not add labels not in the `allowed` list.
* Limit to at most 3 comments per triage run.
* Be constructive and welcoming in all comments.
