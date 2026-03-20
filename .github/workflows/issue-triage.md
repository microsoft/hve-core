---
on:
  issues:
    types: [opened, labeled]
    names: [needs-triage]
  roles: [admin, maintainer, write, triage]
  skip-bots: ["dependabot[bot]", "github-actions[bot]"]
  reaction: eyes

engine: copilot
timeout-minutes: 10

imports:
  - ../agents/github/issue-triage.agent.md

permissions:
  contents: read
  issues: read
  pull-requests: read

safe-outputs:
  add-comment:
    max: 3
    target: "triggering"
  add-labels:
    allowed:
      - feature
      - bug
      - documentation
      - maintenance
      - infrastructure
      - enhancement
      - security
      - breaking-change
      - agents
      - prompts
      - instructions
      - skills
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

## Triage Procedure

Follow the triage workflow defined in your imported agent instructions:

1. Read the issue title, body, labels, and template metadata.
2. Classify the issue type using conventional commit patterns from the triage instructions.
3. Classify the component from bug report dropdowns or body content analysis.
4. Search for duplicate or related issues among open issues.
5. Assess issue quality: check for missing required fields, vague descriptions, semantic coherence, and scope relevance.
6. Remove `needs-triage` and apply determined type and component labels.
7. Evaluate whether the issue qualifies for `agent-ready` using conservative criteria.

For each step, follow the detailed guidance in the Issue Triage Agent instructions.

## Output Behavior

* **Well-formed issue:** Remove `needs-triage`, add type label(s) and component label(s). If all `agent-ready` criteria are met, also add `agent-ready`.
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
