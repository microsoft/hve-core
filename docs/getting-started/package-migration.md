---
title: Migrate to the HVE Core Identity
description: Move retired package installations to the single HVE Core plugin or extension
sidebar_position: 4
author: Microsoft
ms.date: 2026-08-19
ms.topic: how-to
keywords:
  - migration
  - hve-core
  - copilot plugin
  - vscode extension
  - selective clone
  - retired packages
estimated_reading_time: 8
---

HVE Core now publishes one `hve-core` plugin and one `ise-hve-essentials.hve-core` extension. Root `plugin.json` owns the complete distributable membership, and `.github/plugin/marketplace.json` contains one relative locator to the repository root.

Choose the migration path for your host. Neither GitHub Copilot nor VS Code provides a universal automatic migration between different published identities.

## Replace Retired Identities

Remove any retired domain, utility, or `hve-core-all` plugin registration before installing `hve-core`. Remove any package-suffixed HVE Core extension before installing the single HVE Core extension.

## GitHub Copilot Plugin Selection

Changing a Copilot marketplace registration is a configuration operation. It does not delete files from your repository or modify a cloned HVE Core installation.

Use the ref-less development tip:

```bash
copilot plugin marketplace add microsoft/hve-core
```

Use a moving reviewed channel:

```bash
copilot plugin marketplace add microsoft/hve-core#release/prerelease
copilot plugin marketplace add microsoft/hve-core#release/stable
```

Use an immutable channel tag:

```bash
copilot plugin marketplace add microsoft/hve-core#prerelease-v<version>
copilot plugin marketplace add microsoft/hve-core#v<version>
```

The ref-less registration resolves current `main`. A release-branch registration resolves the current reviewed branch. An exact-tag registration fixes the catalog, manifest, and source tree together.

Refresh the marketplace before requesting an installed-plugin update:

```bash
copilot plugin marketplace update hve-core
copilot plugin update hve-core@hve-core
```

Switching registrations can require removing and re-adding the marketplace.
Do not depend on a specific outcome for duplicate same-name registrations.

## VS Code Extension Selection

The sole extension identity is `ise-hve-essentials.hve-core`. Stable and PreRelease have the same complete component set but differ in source ownership, cadence, and version.

PreRelease packages from the reviewed `release/prerelease` path and its
`prerelease-v<version>` tag. Stable packages from the reviewed
`release/stable` path and its `v<version>` tag. Stable can lag PreRelease
because each promotion and release is independently reviewed.

Select the channel offered by the HVE Core extension page in VS Code. A
published channel release carries the associated release assurance; client
channel-switch behavior must be confirmed in the installed host.

## Selective Clone Adaptation

Use clone-based selective adoption when the complete plugin is broader than your repository needs.

1. Pin or clone the HVE Core source version you intend to adopt.
2. Invoke `hve-core-installer` and choose all manifest components or a subset.
3. Review the selected components and collisions before allowing writes.
4. Review the resulting `.hve-tracking.json` manifest before committing adopted files.

The installer preserves repository-relative paths for every copied component. A selected skill includes its complete distributable directory, excluding local tests, environments, and caches. Hooks are plugin runtime configuration and are not copied into the target repository.

Schema version 2 stores `selection.profile` and `selection.components`. File records identify component ownership without package identity, and hooks are not copied. Existing schema version 1 tracking files are not upgraded in place: remove `.hve-tracking.json` and run a clean installation. Because the one-plugin manifest no longer declares per-component maturity, new schema version 2 file records use the schema-default `stable` value.

## Retired Package Identities

Thirteen package identities are retired. Their capabilities now ship through the complete `hve-core` plugin and extension. The Marketplace offers no deprecation or tombstone signal, so an already-installed retired extension keeps surfacing commands that no longer resolve. Install `ise-hve-essentials.hve-core`, verify the replacement, then uninstall each retired extension listed below.

The source tree still groups capabilities by areas such as `project-planning` and `security`, but those areas are no longer separate extension identities.

### Retired extension identities

| If you installed                          | Install instead               |
|-------------------------------------------|-------------------------------|
| `ise-hve-essentials.hve-ado`              | `ise-hve-essentials.hve-core` |
| `ise-hve-essentials.hve-coding-standards` | `ise-hve-essentials.hve-core` |
| `ise-hve-essentials.hve-data-science`     | `ise-hve-essentials.hve-core` |
| `ise-hve-essentials.hve-design-thinking`  | `ise-hve-essentials.hve-core` |
| `ise-hve-essentials.hve-experimental`     | `ise-hve-essentials.hve-core` |
| `ise-hve-essentials.hve-github`           | `ise-hve-essentials.hve-core` |
| `ise-hve-essentials.hve-installer`        | `ise-hve-essentials.hve-core` |
| `ise-hve-essentials.hve-jira`             | `ise-hve-essentials.hve-core` |
| `ise-hve-essentials.hve-gitlab`           | `ise-hve-essentials.hve-core` |
| `ise-hve-essentials.hve-core-all`         | `ise-hve-essentials.hve-core` |
| `ise-hve-essentials.hve-project-planning` | `ise-hve-essentials.hve-core` |
| `ise-hve-essentials.hve-rpi`              | `ise-hve-essentials.hve-core` |
| `ise-hve-essentials.hve-security`         | `ise-hve-essentials.hve-core` |

### Retired read-only commands

Each replacement resolves your tracker from the workspace, so you no longer choose a platform variant.

| Retired command                                | Replacement               |
|------------------------------------------------|---------------------------|
| `/ado-discover-work-items`                     | `/backlog-plan discover`  |
| `/github-discover-issues`                      | `/backlog-plan discover`  |
| `/jira-discover-issues`                        | `/backlog-plan discover`  |
| `/ado-triage-work-items`                       | `/backlog-plan triage`    |
| `/github-triage-issues`                        | `/backlog-plan triage`    |
| `/jira-triage-issues`                          | `/backlog-plan triage`    |
| `/ado-sprint-plan`                             | `/backlog-plan sprint`    |
| `/github-sprint-plan`                          | `/backlog-plan sprint`    |
| `/ado-get-my-work-items`                       | `/backlog-plan my-work`   |
| `/ado-process-my-work-items-for-task-planning` | `/backlog-plan task-plan` |
| `/github-suggest`                              | `/backlog-plan resume`    |

### Retired mutation commands

| Retired command           | Replacement            |
|---------------------------|------------------------|
| `/ado-add-work-item`      | `/backlog-execute add` |
| `/github-add-issue`       | `/backlog-execute add` |
| `/ado-update-wit-items`   | `/backlog-execute run` |
| `/github-execute-backlog` | `/backlog-execute run` |
| `/jira-execute-backlog`   | `/backlog-execute run` |

### Commands absorbed elsewhere

| Retired command    | Replacement                                      |
|--------------------|--------------------------------------------------|
| `/jira-prd-to-wit` | The `Functional Planner` agent                   |
| `/jira-setup`      | The Credential Setup section of the `jira` skill |

### Relocated, not retired

| Command                    | Now ships in |
|----------------------------|--------------|
| `/ado-create-pull-request` | `hve-core`   |
| `/ado-get-build-info`      | `hve-core`   |

### Relocated skills within HVE Core

| Skill              | Source capability area |
|--------------------|------------------------|
| `jira`             | `project-planning`     |
| `gitlab`           | `project-planning`     |
| `gh-code-scanning` | `security`             |

### Retired agents

| Retired agent             | Where its capability went                                                                                                                                     |
|---------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `ADO Backlog Manager`     | The `Backlog Manager` agent, using `/backlog-plan` for read-only work and `/backlog-execute` for tracker changes                                              |
| `GitHub Backlog Manager`  | The `Backlog Manager` agent, using `/backlog-plan` for read-only work and `/backlog-execute` for tracker changes                                              |
| `Jira Backlog Manager`    | The `Backlog Manager` agent, using `/backlog-plan` for read-only work and `/backlog-execute` for tracker changes                                              |
| `ADO PRD to WIT`          | The `Functional Planner` agent, which plans read-only and emits a handoff for `/backlog-execute run`                                                          |
| `Jira PRD to WIT`         | The `Functional Planner` agent, which plans read-only and emits a handoff for `/backlog-execute run`                                                          |
| `Agile Coach`             | The work-item quality reference inside the backlog skill, applied during requirements-to-backlog work                                                         |
| `Product Manager Advisor` | Evidence-quality questioning and prioritization lenses in the `requirements-author` skill; hypothesis validation was already covered by `Experiment Designer` |

### Behavior that got wider

Runtime tracker resolution removed restrictions the platform-specific commands carried:

* `/github-suggest` resumed GitHub sessions only. `/backlog-plan resume` resumes on any supported tracker.
* `/ado-get-my-work-items` and the task-planning pair were Azure DevOps only. Both now work on any supported tracker.
* Single-item creation used a fixed list of five Azure DevOps work item types. It now discovers the types your tracker actually offers.

Autonomy tiers, content sanitization, dry-run preview, planning file locations and formats, and MCP server configuration are unchanged.

## Historical Catalog Support

Previously issued `plugins-v` and `hve-core-v` catalogs and tags are immutable
historical records. They are not future publication targets or active
migration commands.

## Verify the Result

Confirm the plugin's agents, prompts, instructions, and skills are available in the host. For selective clones, verify `.hve-tracking.json` records the intended profile and components. Review the [HVE Core identity and channels](packages) and [installation guide](install) for the current distribution contract.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
