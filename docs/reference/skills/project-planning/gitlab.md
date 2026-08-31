---
title: gitlab
description: Manage GitLab merge requests and pipelines with a Python CLI
sidebar_position: 7
author: Microsoft
ms.date: 2026-08-14
ms.topic: reference
keywords:
  - skill
  - project-planning
  - gitlab
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                    |
|-------------|--------------------------------------------------------------------------|
| Kind        | skill                                                                    |
| Source      | `.github/skills/project-planning/gitlab`                                 |
| Invocation  | Invoked directly as `/gitlab`, or loaded on demand by referencing agents |
| Interactive | No                                                                       |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Manage GitLab merge requests and pipelines with a Python CLI
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill for GitLab merge-request, note, pipeline, and job-trace workflows.
OAuth is the default and supports public-client PKCE or human-assisted device
authorization. Use explicit legacy-token mode only when OAuth is unavailable.

Do not describe device authorization as unattended workload identity. A user
must approve the request on a browser-capable device.

## Example usage

Register a non-confidential OAuth application, set its application ID, then log
in and list merge requests:

```bash
export GITLAB_URL="https://gitlab.com"
export GITLAB_OAUTH_CLIENT_ID="your-application-id"
python scripts/gitlab.py auth login
python scripts/gitlab.py mr-list opened --fields iid,title,author.name
```
