---
title: Copilot Studio pac Deployment Flows
description: Full command walkthrough for the two verified Copilot Studio pac deployment flows, workspace layout, and the pack knowledge gotcha.
author: microsoft/hve-core
ms.date: 2026-07-01
ms.topic: reference
keywords:
  - copilot-studio
  - power-platform
  - pac
  - deployment
  - mcs-yml
---

# Copilot Studio pac Deployment Flows

Two flows are verified. The flow determines which components can be authored,
so pick the flow first, then author only the components that flow supports.

## Flow 1: new agent (init, pack, solution import)

Scaffold and ship a brand-new agent. This flow supports the agent core,
suggested prompts, and topics. It does not support knowledge or actions.

### Step 1: scaffold the workspace

```bash
pac copilot init --name "<Agent Name>" --publisher-prefix <publisherPrefix> --template default
```

`pac copilot init` creates a workspace directory containing:

| Artifact           | Purpose                                                     |
|--------------------|-------------------------------------------------------------|
| `agent.mcs.yml`    | Agent core metadata, instructions, model, suggested prompts |
| `settings.mcs.yml` | Workspace and environment settings                          |
| `icon.png`         | Agent icon                                                  |
| `topics/`          | Directory for conversational and system topics              |

The `--template` value is `default` or `minimal`. Do not hand-fabricate a
template; obtain authentic templates with `pac copilot extract-template`
(see `pac-verb-reference.md`).

### Step 2: pack the workspace into a solution

```bash
pac copilot pack --publisher-prefix <publisherPrefix> --project-dir <ws> --solution-name <solutionName> --output-path <dir>
```

Here `<ws>` is the workspace directory that contains `agent.mcs.yml`, and
`<dir>` is where the packed solution `.zip` is written.

### Step 3: import the solution

```bash
pac solution import --path <dir>/<solutionName>.zip --publish-changes --force-overwrite
```

`--publish-changes` publishes on import; `--force-overwrite` replaces an
existing solution of the same name.

### Flow 1 gotcha: pack rejects knowledge

`pac copilot pack` fails when the workspace contains a `knowledge/` directory:

```text
Unsupported directory: knowledge/
```

Knowledge sources and actions are not part of Flow 1. Author them through
Flow 2 (clone, edit, push) instead.

## Flow 2: existing agent (clone, edit, push, publish)

Edit an existing deployed agent. This flow supports the full component surface,
including `knowledge/`, `actions/`, and `connectionreferences.mcs.yml`.

### Step 1: clone a synced workspace

```bash
pac copilot clone --bot <copilotId or schemaName> --output-dir <dir>
```

`pac copilot clone` creates a synced workspace as a subfolder of `<dir>` named
after the agent. All editing happens inside that subfolder. The `--bot` value
accepts either the agent id (`<copilotId>`) or its `<schemaName>`.

### Step 2: edit the component files

Edit the `*.mcs.yml` files in the synced workspace. See
`component-recipes.md` for the file-to-recipe map. A fully authored Flow 2
workspace can contain:

```text
<Agent Name>/
  agent.mcs.yml
  settings.mcs.yml
  connectionreferences.mcs.yml
  icon.png
  knowledge/
    <knowledge source name>.mcs.yml
  actions/
    <action name>.mcs.yml
  topics/
    <custom topic name>.mcs.yml
    Search.mcs.yml
```

### Step 3: push the edits

```bash
pac copilot push --project-dir <ws>
```

`pac copilot push` requires a synced or cloned workspace. Against a plain
directory it errors:

```text
No synced workspace found
```

Here `<ws>` is the folder that contains `agent.mcs.yml` (the cloned subfolder).

### Step 4: publish

```bash
pac copilot publish --bot <copilotId>
```

`pac copilot publish` makes pushed changes live. It can fail transiently; retry
on failure.

## Flow selection summary

| Component                    | Flow 1 (init, pack, import)     | Flow 2 (clone, push, publish) |
|------------------------------|---------------------------------|-------------------------------|
| Agent core (`agent.mcs.yml`) | Supported                       | Supported                     |
| Suggested prompts            | Supported                       | Supported                     |
| Topics (`topics/`)           | Supported                       | Supported                     |
| Knowledge (`knowledge/`)     | Not supported (pack rejects it) | Supported                     |
| Actions (`actions/`)         | Not supported                   | Supported                     |
| Connection references        | Not supported                   | Supported                     |
