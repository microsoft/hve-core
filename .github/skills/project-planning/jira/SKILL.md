---
name: jira
description: 'Jira issue workflows for search, issue updates, transitions, comments, field discovery, and interactive credential setup via the Jira REST API. Use when you need to configure Jira access, search with JQL, inspect an issue, create or update work items, move an issue between statuses, post comments, or discover required fields for issue creation.'
license: MIT
user-invocable: true
argument-hint: "[setup|search|get|create|update|transition|comment|fields] [arguments]"
compatibility: 'Requires Python 3.11+ and Jira credentials in environment variables'
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-08-01"
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

### Operational Variables

| Variable           | When required | Purpose                                                                                 |
|--------------------|---------------|-----------------------------------------------------------------------------------------|
| `JIRA_AUDIT_LOG`   | Optional      | Path to a JSON Lines audit log. When set, every request is audited (see Audit Logging). |
| `JIRA_AUDIT_ACTOR` | Optional      | Overrides the recorded actor identity (for example, a CI service principal).            |

### Audit Logging

When `JIRA_AUDIT_LOG` is set, the script writes a structured JSON Lines audit trail for every API request. Auditing is fail-closed and write-ahead:

* An `attempt` record is written **before** the request is sent. If the audit log cannot be written, the operation is aborted and nothing is sent to Jira.
* An `outcome` record (`success` or `error`, with HTTP status on failure) is written after the request completes.

Each record includes a UTC timestamp, the `actor` (from `JIRA_AUDIT_ACTOR`, otherwise `JIRA_USER_EMAIL` or `jira-pat`), the operation, HTTP method, and the request path. Credentials, authorization headers, and query strings are never written. Audit failures after the request emit a warning without altering the result.

### Credential Rotation

The script reads credentials from the environment on every invocation, so an external rotator can swap `JIRA_API_TOKEN` or `JIRA_PAT` between calls without code changes. A `401` or `403` response indicates the token may be expired or revoked; rotate the credential through your Atlassian account or instance token settings. Full OAuth-style refresh flows are out of scope for this CLI.

## Credential Setup

Run this workflow when credentials are missing, incomplete, or failing. It is verification-first and non-destructive: it audits the current state, guides acquisition, writes only non-secret values, and validates connectivity after the user supplies the credential themselves.

### Safety boundary

These rules are not adjustable by autonomy mode or user request.

* Never ask for, accept, or echo a token or PAT in chat. Display this warning whenever instructing the user to add one:

  ```text
  ⚠️ NEVER paste your API token or PAT into this chat.
     Tokens entered here are sent through the AI model and are not secure.
     Edit the credentials file directly in the editor instead.
  ```

* Never write a credential value. Non-secret values (base URL, email) may be written; the token line is a placeholder the user replaces in their editor.
* Never write credentials to a tracked file. `~/.jira.env` lives in the user's home directory, outside any repository, so it cannot be accidentally committed. Do not write to `.vscode/mcp.json` or any repository file.
* Never modify a shell profile without explicit user confirmation.
* Mask every displayed token: first four characters followed by `****`.
* After sourcing the environment file, never run a command that dumps the full environment. Only a filtered, masked `printenv | grep -i JIRA` is permitted. Never include raw credential values, full request headers, or verbose or trace HTTP output in a response, even while troubleshooting.
* Send nothing over the network until the user explicitly confirms connectivity testing.

### Terminal session isolation

The agent's terminal and the user's terminal are separate sessions, so an `export` in one is invisible to the other. The environment file is the mechanism that bridges them:

1. Create `~/.jira.env` with non-secret values filled in and placeholder lines for credentials.
2. Resolve and display the **absolute** path so the user knows exactly which file to edit.
3. Open it with `code ~/.jira.env`.
4. The user replaces the placeholders and saves.
5. Source it (`set -a && source ~/.jira.env && set +a`) before running any command.

### Protocol

1. **Audit.** Run `printenv | grep -i JIRA` and classify each variable as set or missing. Use no modifying command during the audit. Check for an existing `~/.jira.env`.
2. **Detect the platform.** `JIRA_PAT` set indicates Server or Data Center. `JIRA_USER_EMAIL` with `JIRA_API_TOKEN` indicates Cloud. When mixed or ambiguous, ask which platform the user has rather than guessing, because the wrong choice produces an authentication failure that looks like a bad credential.
3. **Validate what exists.** Confirm `JIRA_BASE_URL` starts with `https://` and flag a malformed value. Identify which required variables are missing for the detected platform.
4. **Guide acquisition.** Direct the user to their Atlassian account token page for Cloud, or their instance personal-access-token settings for Server or Data Center. Give the steps; never request the result.
5. **Write the file.** Create or update `~/.jira.env` with non-secret values and credential placeholders, including a do-not-commit warning comment.
6. **Validate connectivity.** After the user confirms the credential is saved, source the file and run one read-only call. A `401` or `403` means the credential is wrong, expired, or revoked; a connection error means the base URL is wrong.
7. **Summarize.** Report what changed, what remains, and the masked state of each variable.

### Completion

Setup is complete when every required variable for the detected platform is set, the base URL is well-formed, and one read-only call succeeds. Anything short of that is reported as incomplete with the specific remaining step, never as a qualified success.

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
