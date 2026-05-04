---
title: Jira JQL Reference for the Jira Skill
description: Practical JQL patterns for the hve-core Jira skill, including bounded searches, common filters, and safe query shaping
author: Microsoft
ms.date: 2026-03-22
ms.topic: reference
keywords:
  - jira
  - jql
  - search
  - skill
estimated_reading_time: 4
---

## When to Use JQL in This Skill

Use JQL with the `search` command when you need a focused issue list before you
inspect, update, transition, or comment on results.

Keep queries bounded. Start with a project, assignee, sprint, status, label, or
issue type filter, then add sorting.

```bash
python scripts/jira.py search 'project = PROJ AND assignee = currentUser() ORDER BY updated DESC' --fields key,fields.summary,fields.status.name
```

## Practical Query Shape

Use this pattern for most searches:

```text
<scope filter> AND <work filter> ORDER BY <recent field> DESC
```

Examples:

* `project = PROJ AND status = "In Progress" ORDER BY updated DESC`
* `project = PROJ AND assignee = currentUser() ORDER BY priority DESC, updated DESC`
* `project = PROJ AND labels = docs ORDER BY created DESC`
* `project = PROJ AND sprint in openSprints() ORDER BY rank ASC`

Avoid unbounded queries such as `ORDER BY updated DESC` with no filter. They are
slower, noisier, and harder to review in agent workflows.

## Common Filters

| Goal                  | JQL pattern                                                |
|-----------------------|------------------------------------------------------------|
| My active work        | `assignee = currentUser() AND resolution = Unresolved`     |
| Project backlog       | `project = PROJ AND statusCategory != Done`                |
| Recently updated bugs | `project = PROJ AND issuetype = Bug ORDER BY updated DESC` |
| Sprint work           | `project = PROJ AND sprint in openSprints()`               |
| Label slice           | `project = PROJ AND labels = backend`                      |
| Team ownership        | `project = PROJ AND component = API`                       |

## Common Search Commands

Use `--fields` to keep output compact and machine-readable.

```bash
python scripts/jira.py search 'project = PROJ AND statusCategory != Done' 20 --fields key,fields.summary,fields.status.name
python scripts/jira.py search 'assignee = currentUser() AND resolution = Unresolved ORDER BY updated DESC' 10 --fields key,fields.summary
python scripts/jira.py search 'project = PROJ AND sprint in openSprints()' --fields key,fields.summary,fields.assignee.displayName
```

## Safe Query Shaping

Use these habits when calling the skill:

* Filter before sorting
* Limit the result count when you only need a short working set
* Prefer project-scoped queries in shared Jira instances
* Quote values with spaces, such as `status = "In Progress"`
* Use `currentUser()` when you want portable assignee queries

## Patterns to Avoid

Avoid these query shapes unless you have a specific reason:

* Bare sort clauses with no filter
* Very broad text searches across all projects
* Large result sets when you only need a triage shortlist
* Filters that depend on custom fields unless you have already verified the field name in your Jira instance

## Next Step After Search

After a search returns the right issues, use the other Jira skill commands for
the next action:

* `get` to inspect one issue in detail
* `comment` to add a note
* `transition` to move workflow state
* `update` to modify fields with JSON

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
 