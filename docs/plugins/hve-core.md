---
title: HVE Core
description: Complete HVE Core plugin identity, distribution channels, membership policy, and capability inventory
sidebar_position: 1
author: Microsoft
ms.date: 2026-10-28
ms.topic: reference
keywords:
  - package
  - hve core
  - foundation
---

HVE Core is the single plugin and extension identity for all distributable HVE Core content.

> [!CAUTION]
> HVE Core evolves quickly. Evaluate these assets as adaptable engineering patterns, review changes before adoption, and use the VS Code extension or a pinned selective clone when reproducible, release-gated source is required. The Copilot CLI plugin tracks `main`, which has no release gate or release attestation.

Root `plugin.json` owns complete membership. `.github/plugin/marketplace.json` contains one `hve-core` entry whose relative source is the repository root; it does not repeat component membership. The plugin details view resolves root `README.md` and `LICENSE`, while the VSIX retains its own generated README and license.

The VS Code extension's Stable and PreRelease channels contain the same complete agents, instructions,
and skills. Channel selection changes source ownership, cadence, version,
release assurance, and VS Code Marketplace behavior, not membership. Canvases
ship only in the Copilot plugin; the VSIX has no canvas contribution point.

The Copilot CLI plugin has one registration, `microsoft/hve-core`, which tracks `main`; there are no PreRelease or Stable plugin channels. The extension's PreRelease follows a reviewed promotion from `main` to `release/prerelease`, and Stable follows a reviewed promotion from `release/prerelease` to `release/stable`.

Release workflows package one VSIX from an exact release tag and bind it to its source SHA with SPDX and provenance attestations. Stable also publishes OpenVEX.

## Install and Select

Register the marketplace and install the plugin:

```bash
copilot plugin marketplace add microsoft/hve-core
copilot plugin install hve-core@hve-core
```

Install the extension as `ise-hve-essentials.hve-core`. For a repository-owned subset, use `hve-core-installer` to choose all manifest components or a custom selection. The installer records `selection.profile` and `selection.components` in `.hve-tracking.json` and does not copy hooks.

The full repository-relative path inventory remains machine-readable in root `plugin.json`. Agent, instruction, and skill reference pages are available under `docs/reference/`.

## Component Inventory

| Component kind    | Manifest field | Source convention                                        |
|-------------------|----------------|----------------------------------------------------------|
| Agents            | `agents`       | `.github/agents/<package>/**/*.agent.md`                 |
| Prompts           | `commands`     | `.github/prompts/<package>/**/*.prompt.md`               |
| Instructions      | `rules`        | `.github/instructions/<package>/**/*.instructions.md`    |
| Skills            | `skills`       | `.github/skills/<package>/<skill>/SKILL.md`              |
| Canvas extensions | `extensions`   | `.github/extensions/<package>/<extension>/extension.mjs` |

The `extensions` field lists package folders, such as `.github/extensions/hve-core`, and the host loads each extension folder inside them.

### Canvases

The plugin ships the Session Log canvas (`hve-core-session-log`). It lists the Copilot sessions recorded on your machine and shows the selected session as a live, navigable log: system prompt, prompts, responses and reasoning, tool calls with their arguments and results, model and context usage, skills, instructions, and each subagent as its own log. It opens on the current session and refreshes while visible.

The plugin also ships the RPI Workflow canvas (`hve-core-rpi-workflow`).
It shows an RPI session from your workspace's `.copilot-tracking/` folder phase by phase, or a sample session with made-up data. You read research and plans and suggest edits to them, answer the agent's decisions and see how it understood your answers, ask for more research, watch implementation and its discoveries, and work through review findings and follow-ups.
For a real session, it follows the RPI files while it is open and shows every loop in the session folder (`.copilot-tracking/rpi-sessions/<date>/<session>/`). It moves to the running loop in the same panel, and you can switch to any loop or to another session.
The canvas never changes the files. What you add waits until you open Review and send, which lists every item to check, edit, or discard and shows the exact message before it reaches your chat; the agent then updates the files.
The RPI Agent opens the canvas on its session when the host offers it and treats what you send from it as your direction.
The [RPI Workflow Canvas](../rpi/rpi-workflow-canvas) guide shows how to use it, with screenshots from a real session.

Canvases are an experimental Copilot feature. They render in the GitHub Copilot app, in the Copilot CLI with experimental extensions turned on, and in VS Code when `chat.canvases.enabled` is on for a Copilot harness session.
Ask the agent to open a canvas by name, or open it from the host's canvas list.
See the [Session Log README](https://github.com/microsoft/hve-core/blob/main/.github/extensions/hve-core/session-log/README.md) and the [RPI Workflow README](https://github.com/microsoft/hve-core/blob/main/.github/extensions/hve-core/rpi-workflow/README.md) for actions, data, and privacy details.

### Capability Areas

The complete plugin includes:

* RPI lifecycle coordination, research, planning, implementation, review, and walkthroughs
* HVE Builder authoring, review, validation, and Vally conformance support
* Coding standards and code review for multiple languages and infrastructure formats, including contract-focused TypeScript documentation comments
* Security, TM7 threat-model generation, supply-chain security, privacy, accessibility, and Responsible AI planning and review
* Outcome hypotheses, business requirements, product requirements, architecture decisions, performance, proposal and RFP responses, and backlog workflows
* Azure DevOps, GitHub, GitLab, and Jira integrations
* Source-grounded engagement reporting, review, Council critique, and optional
  Outlook draft creation
* Design Thinking, UX, data science, experimentation, diagrams, PowerPoint, voice-over, and demo media tooling
* Documentation authoring, release workflows, Git operations, and local
  telemetry foundations
* Session Log canvas for reading Copilot sessions, tool calls, and subagents
  as a live log
* RPI Workflow canvas for following and steering the workspace's RPI sessions
  phase by phase

### Membership Policy

`npm run plugin:sync` includes tracked package-scoped agents, prompts, and instructions that match their canonical suffixes. It includes a skill when `.github/skills/<package>/<skill>/SKILL.md` is tracked and its top-level license has no noncommercial qualifier. It includes the package folder `.github/extensions/<package>` when a tracked `.github/extensions/<package>/<extension>/extension.mjs` exists.

Extension folders placed directly under `.github/extensions/` are repository-only project extensions and stay out of the plugin.

Repository-root artifacts without a package segment are repository-specific
and excluded. The manifest is unique and ordinal-sorted and declares no hooks.
`npm run plugin:validate` checks this membership without writing.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
