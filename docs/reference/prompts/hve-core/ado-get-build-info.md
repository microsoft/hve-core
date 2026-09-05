---
title: Ado Get Build Info
description: Retrieve Azure DevOps build status and logs for a pull request or build number
sidebar_position: 2
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - hve-core
  - ado-get-build-info
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                   |
|-------------|---------------------------------------------------------|
| Kind        | prompt                                                  |
| Source      | `.github/prompts/hve-core/ado-get-build-info.prompt.md` |
| Invocation  | Slash command `/ado-get-build-info`                     |
| Interactive | Yes                                                     |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Retrieve Azure DevOps build status and logs for a pull request or build number
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt to inspect Azure DevOps build status or logs for a pull request or known build number. Use the pull-request creation prompt when the required pull request does not exist yet.

## How to use it

Provide the project and either `pr` or `build`, then choose the requested `info` such as status or logs. Review log output for credentials, tokens, customer data, or internal identifiers before sharing it.

## Example usage

```text
/ado-get-build-info project=hve-core pr=123 info=status
```

The prompt returns the current build state associated with the sample pull request number.
