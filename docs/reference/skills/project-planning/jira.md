---
title: jira
description: "Jira issue workflows for search, issue updates, transitions, comments, field discovery, and interactive credential setup via the Jira REST API. Use when you need to configure Jira access, search with JQL, inspect an issue, create or update work items, move an issue between statuses, post comments, or discover required fields for issue creation."
sidebar_position: 8
author: Microsoft
ms.date: 2026-08-14
ms.topic: reference
keywords:
  - skill
  - project-planning
  - jira
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                  |
|-------------|------------------------------------------------------------------------|
| Kind        | skill                                                                  |
| Source      | `.github/skills/project-planning/jira`                                 |
| Invocation  | Invoked directly as `/jira`, or loaded on demand by referencing agents |
| Interactive | No                                                                     |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Jira issue workflows for search, issue updates, transitions, comments, field discovery, and interactive credential setup via the Jira REST API. Use when you need to configure Jira access, search with JQL, inspect an issue, create or update work items, move an issue between statuses, post comments, or discover required fields for issue creation.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill for Jira issue search, creation, update, transition, comments, and
field discovery. Jira Cloud supports unscoped or scoped expiring API tokens;
scoped mode binds requests to Atlassian's resource API. Jira Data Center uses a
bounded PAT supplied out of band.

Do not use the CLI to issue or print a new Data Center PAT. It has no
transactional, non-model-visible secret sink for safe handover.

## Example usage

Configure a scoped Jira Cloud token without placing its value on the command
line, then run a compact issue search:

```bash
export JIRA_BASE_URL="https://company.atlassian.net"
export JIRA_USER_EMAIL="you@example.com"
export JIRA_API_TOKEN="$(cat ~/.secrets/jira-token)"
export JIRA_CLOUD_TOKEN_MODE="scoped"
export JIRA_CLOUD_ID="your-cloud-id"
python scripts/jira.py --fields key,fields.summary search "assignee = currentUser()"
```
