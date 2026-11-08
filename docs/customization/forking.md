---
title: Forking and Extending HVE Core
description: Fork HVE Core to create a fully customized prompt engineering framework with upstream sync and Copilot-assisted adaptation
author: Microsoft
ms.date: 2026-10-31
ms.topic: tutorial
keywords:
  - forking
  - extending
  - upstream sync
  - customization
  - plugin marketplace
estimated_reading_time: 11
---

## When to Fork

Forking creates an independent copy of HVE Core that you fully control. Consider forking
when in-place customization (adding instructions, adding package-scoped artifacts, extending
validation) is insufficient for your needs.

### Fork when you need to

* Replace core workflow agents with organization-specific versions
* Modify plugin membership, extension packaging, or the build system
* Enforce custom governance policies that require structural changes
* Maintain a private distribution channel with proprietary artifacts
* Integrate with internal systems that require changes to core scripts

### Stay with in-place customization when you

* Add new agents, skills, or instructions without modifying existing ones
* Add organization-specific artifacts under your own package-scoped namespaces
* Extend validation with custom linting scripts
* Configure existing tools through their settings files

> [!IMPORTANT]
> Forking introduces ongoing maintenance cost. Every upstream release requires evaluation,
> merge, and potential conflict resolution. Choose forking only when in-place customization
> cannot achieve your goals.

## Fork Setup

### Step 1: Create the fork

Fork the repository through GitHub's fork mechanism. Choose whether to fork into a personal
account or an organization.

```bash
gh repo fork microsoft/hve-core --org your-org --clone
cd hve-core
```

### Step 2: Configure the upstream remote

```bash
git remote add upstream https://github.com/microsoft/hve-core.git
git fetch upstream
```

### Step 3: Install dependencies

```bash
npm ci
```

If your network blocks public package registries, see
[Install behind a restricted network](../contributing/validation#install-behind-a-restricted-network).
Set the registry override in your environment rather than in a fork file, so the
fork stays restorable for everyone who clones it.

### Step 4: Make initial configuration changes

Update these files to reflect your organization:

* `package.json`: Change the `name`, `description`, and `repository` fields
* `plugin.json` and `.github/plugin/marketplace.json`: Point `homepage` and
  `repository` at your fork in both files, since `npm run plugin:validate`
  checks that the marketplace entry matches `plugin.json`
* `README.md`: Update branding, installation instructions, and support links
* `CONTRIBUTING.md`: Adjust contribution guidelines for your team
* `SECURITY.md`: Point to your organization's security reporting process

### Step 5: Verify the build

```bash
npm run validate:local
npm run plugin:sync
npm run plugin:validate
```

## Seven Customization Areas

After forking, these areas provide the highest-value customization opportunities.

### 1. VS Code Extensions

The `extension/` directory contains packaging configuration for distributing the HVE Core component set as one VS Code extension. Modify `extension/templates/` to customize the extension manifest,
README, and marketplace presentation. See the
[VS Code Extension API](https://code.visualstudio.com/api) for extension packaging details.
VS Code forwards the extension's agents and skills to Copilot sessions, but its
instructions may not reach them and the VSIX carries no canvases. When your teams
need the full set, distribute the fork as a plugin, as described in
[Distribute Your Fork](#distribute-your-fork).

### 2. Copilot Paths

Agents, skills, and instructions live in package folders under `.github/agents/`,
`.github/skills/`, and `.github/instructions/`. Copilot discovers them at any
folder depth, so you can reorganize the package folders to match your
organization's team topology or domain boundaries without changing any settings.
Keep each artifact inside a package folder, because files placed directly in
`.github/agents/`, `.github/instructions/`, or `.github/skills/` stay out of the
plugin. Run `npm run plugin:sync` to reflect the new paths in root `plugin.json`.

### 3. MCP Servers

If your workflows depend on MCP (Model Context Protocol) servers, add them to
`.mcp.json.sample` at the repository root. Copilot reads servers from `.mcp.json`
at the workspace root, under a top-level `mcpServers` object, so teams copy the
sample into their workspace as `.mcp.json`. Agents name a server's tools in their
`tools` lists as `server/tool` or `server/*`, so keep the keys in the sample the
same as the names your agents use. Leave out a `github` server, because Copilot
includes one, and reference secrets as `${NAME}` environment variables instead of
writing them into the file.

### 4. npm Scripts

Add, modify, or remove npm scripts in `package.json` to match your build and validation
needs. Common additions include organization-specific linting rules, custom deployment
scripts, and integration test runners.

### 5. Markdownlint Rules

Customize `.markdownlint.json` to enforce your organization's documentation standards.
Add custom rules or adjust limits (such as line length) to match existing style guides.

### 6. Release Configuration

Modify `release-please-config.json` to align with your release cadence and changelog
format. Adjust version bumping strategy and changelog sections for your workflow.

### 7. Workflow Permissions

GitHub Actions workflows in `.github/workflows/` define CI/CD behavior. Adjust workflow
permissions, add organization-specific validation jobs, or integrate with internal CI
systems.

## Distribute Your Fork

Your fork keeps root `plugin.json` and `.github/plugin/marketplace.json`, so
Copilot installs it the same way it installs HVE Core. Give each person or
repository one route, because Copilot lists each agent more than once when the
same content arrives by two routes.

| Route              | How teams use it                                                                                                                                                                         |
|--------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Plugin marketplace | Run `/plugin marketplace add <org>/hve-core` in a Copilot chat session, or `copilot plugin marketplace add <org>/hve-core` in Copilot CLI, then install the plugin from that marketplace |
| Plugin from source | In the Agent Customizations editor, select **Plugins**, select the add (`+`) button next to **User** or **Workspace**, and enter the fork's Git URL or the root folder of a clone        |
| Repository default | Commit `.github/copilot/settings.json` with your fork's `owner/repo` as the marketplace source, so the Copilot harness offers the plugin to everyone who opens that repository           |

A repository default for a fork at `contoso/hve-core` looks like this:

```json
{
  "extraKnownMarketplaces": {
    "hve-core": {
      "source": {
        "source": "github",
        "repo": "contoso/hve-core"
      }
    }
  },
  "enabledPlugins": {
    "hve-core@hve-core": true
  }
}
```

The example assumes your fork keeps the marketplace name `hve-core`, the top-level
`name` in `.github/plugin/marketplace.json`. The key under `extraKnownMarketplaces`
must match the marketplace name, so if you rename the marketplace, use the new
name as the key. Plugin references take the form `plugin@marketplace`, so a
renamed marketplace also changes the `enabledPlugins` entry and install commands
such as `/plugin install hve-core@hve-core`.

[Installing HVE Core](../getting-started/install) covers each route in more
detail, including updates and how to check that the plugin loaded.

## Upstream Sync Workflow

Periodically pull upstream changes to receive new features, bug fixes, and security
patches.

### Fetch and review upstream changes

```bash
git fetch upstream
git log --oneline upstream/main..HEAD
git log --oneline HEAD..upstream/main
```

### Merge upstream changes

```bash
git checkout main
git merge upstream/main
```

### Resolve conflicts

Conflicts typically occur in files you have customized. Common conflict points:

* `package.json` (script modifications)
* `.markdownlint.json` (rule adjustments)
* Root `plugin.json` membership after artifacts are added or removed
* `.github/plugin/marketplace.json` metadata, if you pointed it at your fork
* Workflow files (permission or job changes)

For each conflict, evaluate whether to keep your change, accept the upstream change, or
combine both. Validate after resolution:

```bash
npm run validate:local
npm run plugin:sync
npm run plugin:validate
```

### Files to sync vs. skip

| Sync (accept upstream)                     | Skip (keep your version)              |
|--------------------------------------------|---------------------------------------|
| Core scripts in `scripts/`                 | `package.json` (your custom fields)   |
| Schema files in `scripts/linting/schemas/` | `README.md` (your branding)           |
| Agent, instruction, and skill templates    | `.github/workflows/` (your CI config) |
| Shared instructions                        | `CONTRIBUTING.md` (your guidelines)   |
| Documentation in `docs/`                   | Custom plugin membership and branding |

## Copilot-Assisted Adaptation

Use Copilot to accelerate upstream integration and fork maintenance. These prompts help
you analyze and adapt changes efficiently.

### Analyze upstream diff

```text
Analyze the upstream changes between our fork and upstream/main.
Summarize what changed, identify which files conflict with our
customizations, and recommend a merge strategy for each conflict.
```

### Adapt new instructions to organization context

```text
Review the new instruction files added in the upstream merge.
Adapt them to use our organization's terminology, coding standards,
and tool chain. Preserve the original intent while aligning with
our conventions in .github/instructions/.
```

### Validate fork health

```text
Compare our fork against upstream/main. Identify files that have
diverged significantly, check for deprecated patterns we still use,
and list any new upstream features we have not adopted. Produce a
prioritized maintenance backlog.
```

## Maintaining Your Fork

Establish a regular maintenance cadence to keep your fork healthy.

### Sync frequency

Sync with upstream at least once per release cycle. More frequent syncs (weekly or
biweekly) reduce the size of each merge and lower conflict risk.

### Versioning strategy

Maintain your own version scheme in `package.json` that reflects your release cadence.
Track the upstream version you last synced from in a comment or separate tracking file
so you can identify the delta on each sync.

### Deprecation handling

When upstream deprecates an artifact, evaluate whether to:

* Remove it from your fork immediately
* Move it under `.github/deprecated/` for a documented transition period
* Replace it with an organization-specific alternative

### Health checks

Run the full validation suite after every sync:

```bash
npm run validate:local
npm run plugin:sync
npm run plugin:validate
```

## Role Scenarios

**Fabrikam's platform team** forks HVE Core to establish org-wide Copilot governance.
They replace the default RPI workflow agents with versions that enforce Fabrikam's code
review policies, add their internal API servers to the fork's `.mcp.json.sample`, and
register the fork as a plugin marketplace that every engineering repository offers
through `.github/copilot/settings.json`. A biweekly upstream sync brings in new skills
and security patches without disrupting their customizations.

**Woodgrove Bank's compliance team** forks HVE Core to add financial regulation
instructions and audit trail requirements. They customize the build system to include
compliance validation scripts that check every agent and skill for required disclaimer
sections. The compliance team maintains a strict monthly sync cadence, reviewing each
upstream change against regulatory requirements before merging.

## Further Reading

* [Installing HVE Core](../getting-started/install) for the plugin, repository
  default, and clone routes your fork can use
* [VS Code Extension API](https://code.visualstudio.com/api) for extension packaging and
  distribution
* [docs/contributing/](../contributing/) for artifact syntax and contribution guidelines
* [Validation Commands and CI-Owned Lanes](../contributing/validation) for local-safe defaults and separate CI lanes

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
