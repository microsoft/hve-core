---
title: Copilot Studio pac Verb Reference
description: The relevant pac copilot and pac solution verbs for Copilot Studio agent authoring, plus the local MCP server and template extraction notes.
author: microsoft/hve-core
ms.date: 2026-07-01
ms.topic: reference
keywords:
  - copilot-studio
  - power-platform
  - pac
  - cli
  - mcp
---

# Copilot Studio pac Verb Reference

The verbs below are the ones this skill relies on. Names in code spans are
literal CLI tokens.

## Verb map

| Verb | Purpose | Flow |
| --- | --- | --- |
| `pac copilot init` | Scaffold a new local agent workspace | Flow 1 |
| `pac copilot pack` | Package a workspace into a solution `.zip` | Flow 1 |
| `pac copilot clone` | Create a synced workspace from a deployed agent | Flow 2 |
| `pac copilot push` | Push local edits to the synced agent | Flow 2 |
| `pac copilot publish` | Make pushed changes live | Flow 2 |
| `pac copilot create` | Create an agent in the environment | Provisioning |
| `pac copilot list` | List agents in the environment | Discovery |
| `pac copilot delete` | Delete an agent | Lifecycle |
| `pac copilot extract-template` | Obtain an authentic agent template | Authoring |
| `pac copilot mcp` | Run the built-in local MCP server | Local dev and test |
| `pac solution import` | Import a packed solution into the environment | Flow 1 |

## Common flags

| Flag | Verbs | Meaning |
| --- | --- | --- |
| `--name` | `init` | Display name of the new agent |
| `--publisher-prefix` | `init`, `pack` | Publisher prefix for schema names |
| `--template` | `init` | Template to scaffold from (`default` or `minimal`) |
| `--project-dir` | `pack`, `push` | Workspace directory containing `agent.mcs.yml` |
| `--solution-name` | `pack` | Name of the packed solution |
| `--output-path` | `pack` | Directory where the solution `.zip` is written |
| `--bot` | `clone`, `publish` | Agent id (`<copilotId>`) or `<schemaName>` |
| `--output-dir` | `clone` | Parent directory for the synced workspace |
| `--path` | `solution import` | Path to the solution `.zip` |
| `--publish-changes` | `solution import` | Publish on import |
| `--force-overwrite` | `solution import` | Replace an existing solution of the same name |

## Template extraction

`pac copilot extract-template` is how authentic templates are obtained. Do not
hand-fabricate templates; extract them so the scaffold matches the current
Copilot Studio schema.

## Local MCP server

`pac copilot mcp --run` (invoked through `dnx`) runs a built-in local MCP
server for development and test invocation only.

| Property | Value |
| --- | --- |
| Runtime | .NET 10 or later |
| Transport | stdio |
| Scope | Local development and test invocation only |

This server is not the runtime tools and actions channel of a deployed agent.
It adds no capability and no gate to a deployed agent; it exists to invoke and
test locally.
