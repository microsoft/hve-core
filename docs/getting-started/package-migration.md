---
title: Migrate to the HVE Core Identity
description: Move retired package installations to the single HVE Core plugin or extension and find replacements for retired slash commands
sidebar_position: 4
author: Microsoft
ms.date: 2026-10-07
ms.topic: how-to
keywords:
  - migration
  - hve-core
  - copilot plugin
  - vscode extension
  - selective clone
  - retired packages
  - retired commands
  - prompt files
estimated_reading_time: 10
---

HVE Core now publishes one `hve-core` plugin and one `ise-hve-essentials.hve-core` extension. Root `plugin.json` owns the complete distributable membership, and `.github/plugin/marketplace.json` contains one relative locator to the repository root.

Choose the migration path for your host. Neither GitHub Copilot nor VS Code provides a universal automatic migration between different published identities.

HVE Core also retired its prompt files. If a slash command you relied on no longer resolves, [Retired Prompt Commands](#retired-prompt-commands) names its replacement.

## Replace Retired Identities

Remove any retired domain, utility, or `hve-core-all` plugin registration before installing `hve-core`. Remove any package-suffixed HVE Core extension before installing the single HVE Core extension.

## GitHub Copilot Plugin Selection

Changing a Copilot marketplace registration is a configuration operation. It does not delete files from your repository or modify a cloned HVE Core installation.

Register the repository as a marketplace. The registration tracks `main`:

```bash
copilot plugin marketplace add microsoft/hve-core
```

There are no PreRelease or Stable plugin channels. The repository does not publish `release/prerelease` or `release/stable` branches, so a registration such as `microsoft/hve-core#release/stable` no longer resolves, and a tag ref such as `microsoft/hve-core#hve-core-v<version>` stays fixed at that tag. To follow `main`, remove the earlier registration and register again:

```bash
copilot plugin marketplace remove hve-core --force
copilot plugin marketplace add microsoft/hve-core
copilot plugin install hve-core@hve-core
```

The `--force` option also uninstalls plugins installed from that marketplace.

Refresh the marketplace before requesting an installed-plugin update:

```bash
copilot plugin marketplace update hve-core
copilot plugin update hve-core@hve-core
```

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

## Retired Prompt Commands

HVE Core no longer ships prompt files. Each workflow a prompt started now lives in the agent, skill, or instruction that owns it, so the behavior has one source instead of a prompt copy that can drift. When a replacement is an agent, select it from the agent picker in VS Code or with `/agent` in Copilot CLI, then make the request shown.

### Commands that kept their names

These commands became skills with the same name, so the slash command still works:

* `/accessibility-coverage-matrix`
* `/cspell-config`
* `/dt-figma-export`
* `/engagement-report-council-critique`
* `/git-commit`
* `/git-merge`, which now asks for the branch instead of defaulting to `origin/dev`
* `/git-setup`
* `/incident-response`
* `/risk-register`
* `/synth-data-generate`

> [!NOTE]
> Every skill in this list except `/dt-figma-export` sets `disable-model-invocation: true`, so agents do not start it for you and Copilot CLI does not run it yet. Use these skills from VS Code until the CLI supports them. [Skills vs Agent Mode](methods/cli-plugins#skills-vs-agent-mode) tracks the limitation.

### Security and supply chain

| Retired command            | Replacement                                                                                                                                                   |
|----------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `/security-review`         | The `Security Reviewer` agent, which defaults to `audit` mode and accepts the same `mode`, `scope`, `targetSkill`, and `plan` inputs                          |
| `/security-review-llm`     | The `Security Reviewer` agent; ask for an LLM and agentic review, which sets `skills=owasp-llm,owasp-agentic`                                                 |
| `/security-review-web`     | The `Security Reviewer` agent; ask for a web application review, which sets `targetSkill=owasp-top-10`                                                        |
| `/security-review-sbd`     | The `Security Reviewer` agent; ask for a Secure by Design review, which sets `targetSkill=secure-by-design`                                                   |
| `/security-capture`        | The `Security Planner` agent; start without a PRD or BRD to use `capture` mode                                                                                |
| `/security-plan-from-prd`  | The `Security Planner` agent; ask to start from your PRD or BRD to use `from-prd` mode                                                                        |
| `/sssc-capture`            | The `SSSC Planner` agent; start without a PRD, BRD, or security plan to use `capture` mode                                                                    |
| `/sssc-from-prd`           | The `SSSC Planner` agent; ask to start from your PRD to use `from-prd` mode                                                                                   |
| `/sssc-from-brd`           | The `SSSC Planner` agent; ask to start from your BRD to use `from-brd` mode                                                                                   |
| `/sssc-from-security-plan` | The `SSSC Planner` agent; ask to extend a completed security plan to use `from-security-plan` mode, or use the SSSC Planner handoff in the `Security Planner` |
| `/vex-implement`           | The `SSSC Planner` agent; ask to plan VEX for your project. It plans the stand-up as backlog work rather than changing the project                            |
| `/vex-scan`                | The `SSSC Reviewer` agent; ask for a VEX scan, optionally with `scope` and `product`                                                                          |
| `/vex-triage`              | The `SSSC Reviewer` agent; ask to triage an existing Trivy, OSV-Scanner, or SPDX report, and attach it or pass `report=<path>`                                |

### Responsible AI

| Retired command                | Replacement                                                                                                                                                     |
|--------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `/rai-capture`                 | The `RAI Planner` agent; start without a PRD or security plan to use `capture` mode                                                                             |
| `/rai-plan-from-prd`           | The `RAI Planner` agent; ask to start from your PRD or BRD to use `from-prd` mode                                                                               |
| `/rai-plan-from-security-plan` | The `RAI Planner` agent; ask to start from a completed security plan to use `from-security-plan` mode, or use the RAI Planner handoff in the `Security Planner` |

### Design Thinking

| Retired command                    | Replacement                                                                                                                                                                |
|------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `/dt-start-project`                | The `DT Coach` agent; describe the project you want coaching on                                                                                                            |
| `/dt-resume-coaching`              | The `DT Coach` agent; ask to resume, and it lists your existing projects                                                                                                   |
| `/dt-method-next`                  | The `DT Coach` agent; ask which method comes next, or use its Method Next handoff                                                                                          |
| `/dt-method-04-ideation`           | The `DT Coach` agent; ask for Method 4 (Brainstorming) ideation                                                                                                            |
| `/dt-method-04-convergence`        | The `DT Coach` agent; ask to cluster Method 4 ideas into themes                                                                                                            |
| `/dt-method-05-concepts`           | The `DT Coach` agent; ask to turn brainstorming themes into Method 5 (User Concepts) concepts                                                                              |
| `/dt-method-05-evaluation`         | The `DT Coach` agent; ask to evaluate Method 5 concepts with stakeholders                                                                                                  |
| `/dt-method-06-planning`           | The `DT Coach` agent; ask to plan a Method 6 (Low-Fidelity Prototypes) prototype                                                                                           |
| `/dt-method-06-building`           | The `DT Coach` agent; ask to build the Method 6 prototype                                                                                                                  |
| `/dt-method-06-testing`            | The `DT Coach` agent; ask to test the Method 6 prototype                                                                                                                   |
| `/dt-canonical-deck`               | The `DT Coach` agent; ask to create or refresh the canonical deck or to build the customer-card PowerPoint, or use its Canonical Deck or Build Customer Cards PPTX handoff |
| `/dt-handoff-problem-space`        | The `DT Coach` agent; ask to hand off the Problem Space to RPI                                                                                                             |
| `/dt-handoff-solution-space`       | The `DT Coach` agent; ask to hand off the Solution Space to RPI                                                                                                            |
| `/dt-handoff-implementation-space` | The `DT Coach` agent; ask to hand off the Implementation Space to RPI                                                                                                      |

### Development workflow

| Retired command            | Replacement                                                                                                                                         |
|----------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------|
| `/rpi`                     | The `RPI Agent`; describe the task                                                                                                                  |
| `/pr-review`               | The `Code Review` agent, which reviews the pull request you name or the open one for your branch, and otherwise a branch diff or your local changes |
| `/git-commit-message`      | `/git-commit mode=message-only`, which writes a message for your staged changes without committing                                                  |
| `/vally-test-write`        | `/vally-tests mode=from-artifact`, with `files=<path>`                                                                                              |
| `/evals-import`            | `/vally-tests mode=corpus-import`, with `path=<corpus>`                                                                                             |
| `/ado-create-pull-request` | `/pull-request action=create`, which routes Azure DevOps repositories to the `backlog-management` pull request protocol                             |
| `/ado-get-build-info`      | The Azure DevOps build reference in the `backlog-management` skill, loaded when you ask for build status                                            |

## Historical Catalog Support

Previously issued `plugins-v` and `hve-core-v` catalogs and tags are immutable
historical records. They are not future publication targets or active
migration commands.

## Verify the Result

Confirm the plugin's agents, instructions, and skills are available in the host. For selective clones, verify `.hve-tracking.json` records the intended profile and components. Review the [HVE Core identity and channels](packages) and [installation guide](install) for the current distribution contract.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
