---
name: gitlab
description: 'Manage GitLab merge requests and pipelines with a Python CLI'
license: MIT
compatibility: 'Requires Python 3.11+. GitLab OAuth public-client credentials or explicit legacy-token mode.'
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-08-18"
---

# GitLab Skill

## Overview

Use this skill to inspect and update GitLab merge requests, notes, pipelines,
and job logs against GitLab.com or self-managed GitLab instances.

This skill is the repository-local Python workflow for GitLab tasks. It is not
the official GitLab MCP server integration surface.

This first hve-core implementation is Python-only. Run the CLI through
`python scripts/gitlab.py` and prefer `--fields` for read operations to keep
output concise.

## Prerequisites

The skill requires Python 3.11 or later.

Set these environment variables before running any command:

| Variable                 | Required    | Example              | Purpose                                                                         |
|--------------------------|-------------|----------------------|---------------------------------------------------------------------------------|
| `GITLAB_URL`             | Yes         | `https://gitlab.com` | GitLab instance URL                                                             |
| `GITLAB_AUTH_MODE`       | Optional    | `oauth`              | `oauth` or explicit `legacy-token` compatibility mode                           |
| `GITLAB_OAUTH_CLIENT_ID` | OAuth       | Application ID       | Non-confidential OAuth application ID; no client secret                         |
| `GITLAB_TOKEN`           | Legacy mode | `glpat-...`          | PAT accepted only with `GITLAB_AUTH_MODE=legacy-token`                          |
| `GITLAB_PROFILE`         | No          | `default`            | Named OAuth profile                                                             |
| `GITLAB_TOKEN_STORE`     | No          | path                 | OAuth store override; parent must be owner-only on POSIX                        |
| `GITLAB_ALLOW_INSECURE`  | No          | `1`                  | Permit explicit loopback HTTP development endpoints only                        |
| `XDG_DATA_HOME`          | No          | path                 | POSIX data root used for the default OAuth store                                |
| `LOCALAPPDATA`           | No          | path                 | Reserved Windows data root; OAuth persistence currently fails closed on Windows |
| `GITLAB_PROJECT`         | No          | `group/project`      | Project path or numeric project ID                                              |

If `GITLAB_PROJECT` is not set, the script attempts to detect the project from
`git remote get-url origin`. Set the variable explicitly when you are not in a
git repository or when you want to target a different project.

### Operational Variables

| Variable             | Required | Purpose                                                                                 |
|----------------------|----------|-----------------------------------------------------------------------------------------|
| `GITLAB_AUDIT_LOG`   | No       | Path to a JSON Lines audit log. When set, every request is audited (see Audit Logging). |
| `GITLAB_AUDIT_ACTOR` | No       | Overrides the recorded actor identity (for example, a CI service principal).            |
| `GITLAB_DEBUG`       | No       | Set to `1` to print a redacted traceback on failure. Never disables redaction.          |

### Audit Logging

When `GITLAB_AUDIT_LOG` is set, the script writes a structured JSON Lines audit trail for every REST API and OAuth form request. Auditing is fail-closed and write-ahead:

* An `attempt` record is written **before** the request is sent. If the audit log cannot be written, the operation is aborted and nothing is sent to GitLab.
* An `outcome` record (`success` or `error`, with HTTP status on failure) is written after the request completes.

REST records include a UTC timestamp, actor, auth mode, normalized origin,
operation, HTTP method, and event. OAuth records use bounded operation and
failure kinds without actor, origin, client, profile, code, body, or free-form
error fields. Resource paths, queries, profile names, and profile contents are
excluded. The optional audit sink is
operationally sensitive because origins can identify tenants or internal hosts.
Place it at an access-controlled path and retain it only as long as operations
require. Tokens and authorization headers are never written. Audit failures
after the request emit a warning without altering the result.

### Credential Rotation

OAuth is the default. Register a non-confidential user-, group-, or self-managed
instance-owned application with redirect URI
`http://127.0.0.1:8766/callback` and the `api` scope. Set only
`GITLAB_URL` and `GITLAB_OAUTH_CLIENT_ID`, then run `auth login` or the
human-assisted `auth device-login`. Browser login requires a rotating refresh
token; access tokens refresh before expiry and replacements are stored
atomically. Device login can return an access-token-only profile and then
requires another device login after expiry. A provider/local crash window can
still require re-login.

The default store is `$XDG_DATA_HOME/hve-core/gitlab/gitlab-token.json` on
POSIX, falling back to `~/.local/share/hve-core/gitlab/gitlab-token.json`.
POSIX store and lock files use mode `0600` inside a dedicated owner-only
directory. OAuth profile persistence fails closed on Windows because Python
3.11 mode bits cannot enforce an owner-only DACL. Use explicit
`legacy-token` mode on Windows until a protected OAuth backend is available.

PAT authentication remains available through `GITLAB_AUTH_MODE=legacy-token`.
Device authorization requires user approval on a browser-capable device and is
not unattended workload identity.

## Quick Start

Export your environment variables, then run a read command with `--fields`.

```bash
export GITLAB_URL="https://gitlab.com"
export GITLAB_OAUTH_CLIENT_ID="your-application-id"
export GITLAB_PROJECT="group/project"

python scripts/gitlab.py auth login
python scripts/gitlab.py mr-list opened --fields iid,title,author.name
```

Read pipeline jobs for a known pipeline:

```bash
python scripts/gitlab.py pipeline-jobs 12345 --fields id,name,status,stage
```

## Parameters Reference

### Common Option

| Parameter  | Applies To                                                       | Example                    | Description                                                                             |
|------------|------------------------------------------------------------------|----------------------------|-----------------------------------------------------------------------------------------|
| `--fields` | `mr-list`, `mr-get`, `mr-notes`, `pipeline-get`, `pipeline-jobs` | `--fields iid,title,state` | Extract specific fields with dot notation and print concise tabular or key-value output |

### Commands

| Command             | Arguments                  | Description                                                            |
|---------------------|----------------------------|------------------------------------------------------------------------|
| `auth login`        | None                       | Authenticate with Authorization Code and PKCE                          |
| `auth device-login` | None                       | Authenticate through human-assisted device authorization               |
| `auth status`       | None                       | Print secret-free local profile status                                 |
| `auth logout`       | None                       | Delete one local profile without revoking server authorization         |
| `mr-list`           | `[state] [max]`            | List merge requests, defaulting to all states and 20 results           |
| `mr-get`            | `<mr-iid>`                 | Get one merge request by project-scoped IID                            |
| `mr-create`         | `<json>` or stdin          | Create a merge request from a JSON payload                             |
| `mr-update`         | `<mr-iid> <json>` or stdin | Update merge request fields from a JSON payload                        |
| `mr-comment`        | `<mr-iid> <body>` or stdin | Add a comment to a merge request                                       |
| `mr-notes`          | `<mr-iid> [max]`           | List merge request notes, excluding system notes when using `--fields` |
| `pipeline-get`      | `<pipeline-id>`            | Get one pipeline by numeric ID                                         |
| `pipeline-run`      | `<branch-or-tag>`          | Trigger a pipeline for a branch or tag                                 |
| `pipeline-jobs`     | `<pipeline-id>`            | List jobs for a pipeline                                               |
| `job-log`           | `<job-id>`                 | Print raw log output for a job                                         |

## Script Reference

List recent open merge requests:

```bash
python scripts/gitlab.py mr-list opened --fields iid,title,author.name,user_notes_count
```

Get one merge request:

```bash
python scripts/gitlab.py mr-get 42 --fields iid,title,state,source_branch,target_branch
```

Create a merge request from inline JSON:

```bash
python scripts/gitlab.py mr-create '{
  "source_branch": "feature/add-auth",
  "target_branch": "main",
  "title": "feat(auth): add OAuth login"
}'
```

Add a merge request comment from standard input:

```bash
echo "CI passed. Ready for review." | python scripts/gitlab.py mr-comment 42
```

Inspect a failed pipeline:

```bash
python scripts/gitlab.py pipeline-get 12345 --fields id,status,web_url
python scripts/gitlab.py pipeline-jobs 12345 --fields id,name,status,stage
python scripts/gitlab.py job-log 67890
```

## Troubleshooting

| Symptom                                                   | Cause                                                                    | Resolution                                                                |
|-----------------------------------------------------------|--------------------------------------------------------------------------|---------------------------------------------------------------------------|
| `GITLAB_URL is not set`                                   | Required environment variable missing                                    | Export `GITLAB_URL` before running the script                             |
| `GITLAB_TOKEN is not set for legacy-token mode`           | Explicit legacy mode has no PAT                                          | Export a PAT only with `GITLAB_AUTH_MODE=legacy-token`                    |
| `GITLAB_TOKEN must not be set in oauth mode`              | Legacy PAT leaked into the OAuth configuration                           | Remove `GITLAB_TOKEN` or explicitly select legacy-token mode              |
| OAuth persistence is unavailable on Windows               | No protected Windows profile-store backend                               | Use explicit legacy-token mode or run OAuth from POSIX                    |
| `GITLAB_OAUTH_CLIENT_ID is not set`                       | OAuth application is not configured                                      | Set the public client ID, then run `auth login`                           |
| Callback listener cannot bind                             | Port 8766 is unavailable or not forwarded                                | Free the port or use `auth device-login`                                  |
| `timed out waiting for the GitLab OAuth token store lock` | Another process holds the profile-store lock                             | Wait for the other command to finish, then retry                          |
| `GitLab device response has invalid verification_uri`     | The verification URI is unsafe to display or does not match `GITLAB_URL` | Confirm `GITLAB_URL` matches the instance that serves device verification |
| `cannot parse git remote URL`                             | Project autodetection failed                                             | Set `GITLAB_PROJECT` explicitly                                           |
| `HTTP 401` or `HTTP 403`                                  | Credential is invalid or lacks access                                    | Re-login for OAuth; rotate the PAT in explicit legacy mode                |
| `HTTP 404`                                                | Wrong project, MR IID, pipeline ID, or job ID                            | Verify `GITLAB_PROJECT` and confirm the numeric identifiers               |
| `expected numeric ID`                                     | Non-numeric value passed to an ID argument                               | Use project MR IID values and numeric pipeline or job IDs                 |
| `python3 is required` or syntax errors on launch          | Unsupported interpreter                                                  | Run the script with Python 3.11 or later                                  |

GitLab uses MR IIDs such as `!42` inside a project. This skill expects the
numeric IID, not the global merge request ID.