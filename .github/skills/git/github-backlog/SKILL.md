---
name: github-backlog
description: 'Plan and apply GitHub issue, sub-issue, milestone, label, and pull request field operations in one repository. Use for backlog discovery, triage, grooming, PRD hierarchies, and reviewed handoffs.'
argument-hint: '[inspect|discover|my-work|task-plan|triage|sprint|resume|groom|prd|add|run] [owner/repo] [query, issue, or handoff]'
license: MIT AND CC-BY-4.0
user-invocable: true
---

# GitHub Backlog

Use the [GitHub bindings](references/platform.md) to select supported operations and validate issue types, labels, milestones, sub-issue relationships, and pull request fields. When another workflow requests the bindings, supply the relevant section without starting a second workflow.

For a direct request, carry `owner/repo` and the supplied query, issue, PRD, or handoff into the matching workflow:

* To inspect one issue or answer a bounded query, run the preflight and reads in the GitHub bindings. Return matching issue numbers and requested fields from that repository.
* For discovery, assigned work, task planning, triage, sprint planning, or resumption, use `backlog-plan` with GitHub as the platform.
* For grooming, apply `github-backlog-grooming.instructions.md` and return its advisory report. Route approved grooming writeback through `GitHub Backlog Executor` for the field allowlist and freshness check, not an ordinary `run`.
* For a PRD, use `functional-planner` with the [GitHub hierarchy](references/hierarchy.md). Return a reviewable handoff, not created issues.
* For a single create (`add`) or a reviewed handoff (`run`), use `backlog-execute` with the GitHub bindings. Apply the destination, authorization, sanitization, and review controls in `backlog-management` before any write. Return the affected issue or PR numbers and any blocked operations.

Use the [community scenarios](references/community-interaction.md) for contributor-facing comments. Use `pull-request` for GitHub PR preparation, creation, or updates beyond backlog fields.

The hierarchy reference retains CC-BY-4.0; the other references and entry point are MIT.
