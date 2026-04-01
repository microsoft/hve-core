---
name: jira
description: 'Jira issue workflows for search, issue updates, transitions, comments, and field discovery via the Jira REST API. Use when you need to search with JQL, inspect an issue, create or update work items, move an issue between statuses, post comments, or discover required fields for issue creation. - Brought to you by microsoft/hve-core'
compatibility: 'Requires Python 3.11+ and Jira credentials in environment variables'
---

# Jira Skill

## Overview

This skill provides a Python CLI for common Jira REST API workflows:

* Search with JQL
* Get issue details
* Create and update issues with JSON payloads
* Transition issues by name or ID
* Add comments and list existing comments
* Discover issue types and required fields for creation

The skill supports Jira Cloud with email plus API token authentication and Jira Server or Data Center with a personal access token.

Use `--fields` on read commands by default to keep output concise. The script supports dot-notation such as `fields.status.name` and prints tab-separated output for lists.

## Prerequisites

Set the required environment variables before running the script.

| Platform       | Runtime      |
|----------------|--------------|
| Cross-platform | Python 3.11+ |

### Authentication Variables

| Variable          | When required              | Purpose                                                    |
|-------------------|----------------------------|------------------------------------------------------------|
| `JIRA_BASE_URL`   | Always                     | Jira base URL, for example `https://company.atlassian.net` |
| `JIRA_USER_EMAIL` | Jira Cloud                 | Account email used for basic authentication                |
| `JIRA_API_TOKEN`  | Jira Cloud                 | API token paired with the Jira Cloud email                 |
| `JIRA_PAT`        | Jira Server or Data Center | Personal access token used for bearer authentication       |

Authentication is selected automatically:

* If `JIRA_PAT` is set, the script uses bearer authentication for Jira Server or Data Center.
* Otherwise, the script expects `JIRA_USER_EMAIL` and `JIRA_API_TOKEN` for Jira Cloud.

## Quick Start

Search for your current Jira issues and return a compact table:

```bash
python scripts/jira.py search 'assignee = currentUser() ORDER BY updated DESC' --fields key,fields.summary,fields.status.name
```

Inspect one issue with a compact field list:

```bash
python scripts/jira.py get PROJ-123 --fields key,fields.summary,fields.status.name,fields.assignee.displayName
```

Create an issue from JSON piped through stdin:

```bash
cat <<'EOF' | python scripts/jira.py create
{
  "fields": {
    "project": { "key": "PROJ" },
    "summary": "Fix login timeout on mobile",
    "issuetype": { "name": "Bug" }
  }
}
EOF
```

## Parameters Reference

| Command or option | Syntax                                                         | Default                | Description                                                         |
|-------------------|----------------------------------------------------------------|------------------------|---------------------------------------------------------------------|
| `search`          | `python scripts/jira.py search '<jql>' [max_results]`          | `max_results = 50`     | Search for issues with JQL                                          |
| `get`             | `python scripts/jira.py get <ISSUE-KEY>`                       | None                   | Get one issue                                                       |
| `create`          | `python scripts/jira.py create '<json>'`                       | Reads stdin if omitted | Create an issue from JSON                                           |
| `update`          | `python scripts/jira.py update <ISSUE-KEY> '<json>'`           | Reads stdin if omitted | Update an issue from JSON                                           |
| `transition`      | `python scripts/jira.py transition <ISSUE-KEY> '<name-or-id>'` | None                   | Move an issue to another workflow state                             |
| `comment`         | `python scripts/jira.py comment <ISSUE-KEY> '<body>'`          | Reads stdin if omitted | Add a comment to an issue                                           |
| `comments`        | `python scripts/jira.py comments <ISSUE-KEY> [ISSUE-KEY ...]`  | None                   | List comments across one or more issues                             |
| `fields`          | `python scripts/jira.py fields <PROJECT-KEY> [issue-type-id]`  | None                   | Discover issue types or required create fields                      |
| `--fields`        | `--fields key,fields.summary,...`                              | None                   | Extract selected fields from `search`, `get`, and `comments` output |

## Script Reference

### Search for Issues

Use bounded JQL for Jira Cloud queries. Include a project, assignee, sprint, or another filter instead of a bare `ORDER BY` query.
See [JQL Reference](./references/jql-reference.md) for the query patterns this
skill expects.

```bash
python scripts/jira.py search 'project = PROJ AND status = "In Progress"' --fields key,fields.summary,fields.status.name
python scripts/jira.py search 'assignee = currentUser() ORDER BY updated DESC' 10 --fields key,fields.summary
```

### Get One Issue

```bash
python scripts/jira.py get PROJ-123 --fields key,fields.summary,fields.priority.name,fields.status.name
```

### Create an Issue

Discover valid issue types first:

```bash
python scripts/jira.py fields PROJ
```

Inspect required fields for one issue type:

```bash
python scripts/jira.py fields PROJ 10045
```

Create the issue:

```bash
python scripts/jira.py create '{
  "fields": {
    "project": { "key": "PROJ" },
    "summary": "Document rollout checklist",
    "issuetype": { "name": "Task" },
    "labels": ["docs", "release"]
  }
}'
```

### Update an Issue

```bash
python scripts/jira.py update PROJ-123 '{
  "fields": {
    "summary": "Updated summary",
    "priority": { "name": "High" },
    "labels": ["backend", "urgent"]
  }
}'
```

### Transition an Issue

Use a transition display name or a numeric transition ID:

```bash
python scripts/jira.py transition PROJ-123 'In Progress'
python scripts/jira.py transition PROJ-123 31
```

If a transition name is not found, the script returns the available transition names in the error output.

### Comment on an Issue

```bash
python scripts/jira.py comment PROJ-123 'PR #42 addresses this issue.'
printf 'Deployed to staging.\n' | python scripts/jira.py comment PROJ-123
```

### List Comments

```bash
python scripts/jira.py comments PROJ-123 PROJ-456 --fields _issue,author.displayName,created,body
```

## Troubleshooting

| Symptom                    | Likely cause                                     | Resolution                                                                                                        |
|----------------------------|--------------------------------------------------|-------------------------------------------------------------------------------------------------------------------|
| `JIRA_BASE_URL is not set` | Base URL is missing                              | Export `JIRA_BASE_URL` in the current shell                                                                       |
| Authentication error       | Wrong token or missing auth variables            | Verify `JIRA_PAT` for Jira Server or Data Center, or verify `JIRA_USER_EMAIL` and `JIRA_API_TOKEN` for Jira Cloud |
| `Invalid issue key`        | Issue key format is malformed                    | Use keys in the form `PROJ-123`                                                                                   |
| Transition not found       | The requested workflow transition is unavailable | Re-run the command with the transition name returned in the error output                                          |
| JSON payload error         | Invalid JSON was passed to `create` or `update`  | Validate the payload and retry with well-formed JSON                                                              |
| Network connection error   | Jira instance URL is unreachable                 | Verify the base URL and local network access                                                                      |

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*