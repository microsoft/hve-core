---
title: Forking and Extending HVE Core
description: Fork HVE Core to create a fully customized prompt engineering framework with upstream sync and Copilot-assisted adaptation
author: Microsoft
ms.date: 2026-02-24
ms.topic: tutorial
keywords:
  - forking
  - extending
  - upstream sync
  - customization
estimated_reading_time: 10
---

## When to Fork

Forking creates an independent copy of HVE Core that you fully control. Consider forking
when in-place customization (adding instructions, creating collections, extending
validation) is insufficient for your needs.

**Fork when you need to:**

* Replace core workflow agents with organization-specific versions
* Modify the plugin generation pipeline or build system
* Enforce custom governance policies that require structural changes
* Maintain a private distribution channel with proprietary artifacts
* Integrate with internal systems that require changes to core scripts

**Stay with in-place customization when you:**

* Add new agents, prompts, or instructions without modifying existing ones
* Create organization-specific collections alongside existing collections
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
npm install
```

### Step 4: Make initial configuration changes

Update these files to reflect your organization:

* `package.json`: Change the `name`, `description`, and `repository` fields
* `README.md`: Update branding, installation instructions, and support links
* `CONTRIBUTING.md`: Adjust contribution guidelines for your team
* `SECURITY.md`: Point to your organization's security reporting process

### Step 5: Verify the build

```bash
npm run lint:all
npm run plugin:generate
```

## Seven Customization Areas

After forking, these areas provide the highest-value customization opportunities.

### 1. VS Code Extensions

The `extension/` directory contains packaging configuration for distributing collections
as a VS Code extension. Modify `extension/templates/` to customize the extension manifest,
README, and marketplace presentation. See the
[VS Code Extension API](https://code.visualstudio.com/api) for extension packaging details.

### 2. Copilot Paths

Agent and prompt files live under `.github/agents/` and `.github/prompts/`. Restructure
these directories to match your organization's team topology or domain boundaries. Update
collection manifests to reflect new paths.

### 3. MCP Servers

If your workflows depend on MCP (Model Context Protocol) servers, configure server
definitions in `.vscode/mcp.json` or workspace settings. Fork-level changes let you
add organization-specific MCP servers that all collections can reference.

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
* Collection YAML files (added or removed artifacts)
* Workflow files (permission or job changes)

For each conflict, evaluate whether to keep your change, accept the upstream change, or
combine both. Validate after resolution:

```bash
npm run lint:all
npm run plugin:generate
```

### Files to sync vs. skip

| Sync (accept upstream)                     | Skip (keep your version)              |
|--------------------------------------------|---------------------------------------|
| Core scripts in `scripts/`                 | `package.json` (your custom fields)   |
| Schema files in `scripts/linting/schemas/` | `README.md` (your branding)           |
| Agent and prompt templates                 | `.github/workflows/` (your CI config) |
| Shared instructions                        | `CONTRIBUTING.md` (your guidelines)   |
| Documentation in `docs/`                   | Custom collection manifests           |

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
* Keep it with a `maturity: deprecated` tag for a transition period
* Replace it with an organization-specific alternative

### Health checks

Run the full validation suite after every sync:

```bash
npm run lint:all
npm run plugin:generate
npm run plugin:validate
```

## Role Scenarios

**Fabrikam's platform team** forks HVE Core to establish org-wide Copilot governance.
They replace the default RPI workflow agents with versions that enforce Fabrikam's code
review policies, add custom MCP server configurations for internal APIs, and distribute
the fork as a private VS Code extension to all engineering teams. A biweekly upstream sync
ensures they receive new skills and security patches without disrupting their customizations.

**Woodgrove Bank's compliance team** forks HVE Core to add financial regulation
instructions and audit trail requirements. They customize the build system to include
compliance validation scripts that check every agent and prompt for required disclaimer
sections. The compliance team maintains a strict monthly sync cadence, reviewing each
upstream change against regulatory requirements before merging.

## Further Reading

* [VS Code Extension API](https://code.visualstudio.com/api) for extension packaging and
  distribution
* [docs/contributing/](../contributing/) for artifact syntax and contribution guidelines

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
