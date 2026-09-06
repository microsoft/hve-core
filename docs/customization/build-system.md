---
title: Build System and Validation
description: Understand plugin manifest synchronization, schema validation, npm scripts, and CI checks for customizing HVE Core
author: Microsoft
ms.date: 2026-08-19
ms.topic: how-to
keywords:
  - build system
  - plugin manifest
  - schema validation
  - linting
  - npm scripts
estimated_reading_time: 8
---

## Plugin Manifest Synchronization

Root `plugin.json` is the deterministic distribution manifest for the one `hve-core` plugin and VSIX. Its component paths are repository-relative, while discovery remains scoped to eligible package directories under `.github`.

`npm run plugin:sync` runs `Sync-PluginManifest.ps1`, which derives agents, prompts, instructions, and distributable skills from git-tracked package-scoped paths. It preserves plugin metadata, synchronizes the repository version, and retains the fixed telemetry hook.

`npm run plugin:validate` runs manifest check mode followed by hook validation. Check mode writes nothing and verifies deterministic membership, the one-entry `.github` locator, metadata parity, source containment, and declared component coverage.

Synchronize after a distributable artifact changes:

```bash
npm run plugin:sync
npm run plugin:validate
```

> [!IMPORTANT]
> The Copilot plugin root is the repository root. Do not create a copied plugin tree or plugin ZIP; keep distributable artifacts in their canonical `.github` package directories.

## Schema Validation System

YAML frontmatter in markdown files is validated against JSON schemas stored in
`scripts/linting/schemas/`. The validation system uses glob-based pattern matching to
determine which schema applies to each file.

### Schema Files

:::table{caption="Frontmatter schemas and the files they validate"}

| Schema                                   | Applies To                        |
|------------------------------------------|-----------------------------------|
| `docs-frontmatter.schema.json`           | `docs/**/*.md`                    |
| `instruction-frontmatter.schema.json`    | `.github/**/*.instructions.md`    |
| `agent-frontmatter.schema.json`          | `.github/**/*.agent.md`           |
| `prompt-frontmatter.schema.json`         | `.github/**/*.prompt.md`          |
| `skill-frontmatter.schema.json`          | `.github/skills/**/SKILL.md`      |
| `chatmode-frontmatter.schema.json`       | `.github/**/*.chatmode.md`        |
| `root-community-frontmatter.schema.json` | Root files (README, CONTRIBUTING) |
| `base-frontmatter.schema.json`           | Default fallback                  |

:::

### Pattern Mapping

The `scripts/linting/schemas/schema-mapping.json` file defines the glob-to-schema mapping.
Patterns are evaluated from most specific to least specific, and the first match determines
the schema. When no pattern matches, `base-frontmatter.schema.json` applies as the default.

### Planner State Schemas

The same `scripts/linting/schemas/` directory also holds JSON Schemas for planner session
state. These validate the `state.json` files that phase-based planning agents persist under
`.copilot-tracking/`. They are not frontmatter schemas, so they are not listed in
`schema-mapping.json` and are not exercised by `npm run lint:frontmatter`.

| Schema                            | Validates                                                    |
|-----------------------------------|--------------------------------------------------------------|
| `accessibility-state.schema.json` | `.copilot-tracking/accessibility/{project-slug}/state.json`  |
| `rai-state.schema.json`           | `.copilot-tracking/rai-plans/{project-slug}/state.json`      |
| `security-state.schema.json`      | `.copilot-tracking/security-plans/{project-slug}/state.json` |
| `sssc-state.schema.json`          | `.copilot-tracking/sssc-plans/{project-slug}/state.json`     |

Each schema is the source of truth for its planner's required keys, field types, enum
values, and defaults. Agent and instruction files show illustrative state snippets with
JSON-literal defaults; when a snippet and its schema disagree, the schema wins.

Two enforcement paths cover these schemas:

* Editor validation through the `json.schemas` entries in `.vscode/settings.json`, which
  bind the RAI and accessibility state paths to their schemas as you edit.
* Pester coverage in `scripts/tests/linting/Test-PlannerStateSchemas.Tests.ps1` and
  `scripts/tests/linting/Test-AccessibilityStateSchema.Tests.ps1`, which validate schema
  fixtures and guard the inline state examples in agent and instruction files against
  drift. Run them with `npm run test:ps -- -TestPath "scripts/tests/linting/"`.

### Adding Custom Schemas

To add validation for a new file type:

1. Create a JSON schema file in `scripts/linting/schemas/`
2. Add a mapping entry to `schema-mapping.json` with the glob pattern, scope name, and
   schema filename
3. Run `npm run lint:frontmatter` to verify the new schema validates correctly

## npm Scripts Reference

All validation, formatting, and testing operations run through npm scripts defined in
`package.json`. The table below groups scripts by purpose. These tables are representative
of the most commonly used scripts rather than an exhaustive list; consult `package.json`
for the complete set.

### Linting

| Script                     | Command                            | Description                                |
|----------------------------|------------------------------------|--------------------------------------------|
| `validate:local`           | `npm run validate:local`           | Runs the local-safe validation aggregate   |
| `lint:md`                  | `npm run lint:md`                  | Markdown linting via markdownlint-cli2     |
| `lint:md:fix`              | `npm run lint:md:fix`              | Markdown linting with auto-fix             |
| `lint:ps`                  | `npm run lint:ps`                  | PowerShell analysis via PSScriptAnalyzer   |
| `lint:yaml`                | `npm run lint:yaml`                | YAML syntax and structure validation       |
| `lint:links`               | `npm run lint:links`               | Link language checking                     |
| `lint:md-links`            | `npm run lint:md-links`            | Markdown link target validation            |
| `lint:frontmatter`         | `npm run lint:frontmatter`         | Frontmatter schema validation              |
| `lint:json`                | `npm run lint:json`                | JSON syntax validation                     |
| `lint:adr-consistency`     | `npm run lint:adr-consistency`     | ADR structure and consistency checks       |
| `lint:plugin-manifest`     | `npm run lint:plugin-manifest`     | Plugin manifest and locator drift check    |
| `lint:hooks`               | `npm run lint:hooks`               | Hook manifest validation                   |
| `lint:version-consistency` | `npm run lint:version-consistency` | GitHub Action version consistency          |
| `lint:permissions`         | `npm run lint:permissions`         | Workflow permissions validation            |
| `lint:models`              | `npm run lint:models`              | Model reference validation against catalog |

### Validation

| Script               | Command                      | Description                          |
|----------------------|------------------------------|--------------------------------------|
| `validate:copyright` | `npm run validate:copyright` | Copyright header presence check      |
| `validate:skills`    | `npm run validate:skills`    | Skill directory structure validation |

### Formatting

| Script          | Command                 | Description                     |
|-----------------|-------------------------|---------------------------------|
| `format:tables` | `npm run format:tables` | Markdown table column alignment |

### Testing

| Script    | Command           | Description                  |
|-----------|-------------------|------------------------------|
| `test:ps` | `npm run test:ps` | PowerShell Pester test suite |

### Plugin and Extension

| Script                         | Command                                | Description                                  |
|--------------------------------|----------------------------------------|----------------------------------------------|
| `plugin:sync`                  | `npm run plugin:sync`                  | Synchronize deterministic plugin membership  |
| `plugin:validate`              | `npm run plugin:validate`              | Check manifest, locator, coverage, and hooks |
| `extension:prepare`            | `npm run extension:prepare`            | Prepare the Stable extension output          |
| `extension:prepare:prerelease` | `npm run extension:prepare:prerelease` | Prepare the same content for PreRelease      |
| `extension:package`            | `npm run extension:package`            | Package the Stable VSIX                      |
| `extension:package:prerelease` | `npm run extension:package:prerelease` | Package the VSIX with the pre-release flag   |

For local-safe defaults, CI-owned lanes, and package-root-specific setup, see
[Validation Commands and CI-Owned Lanes](../contributing/validation).

## Local Validation Pipeline

The `validate:local` script chains local-safe checks in a fixed sequence:

1. `lint:plugin-manifest` checks deterministic membership and locator validity
2. `lint:tables` checks markdown table columns without modifying them
3. `lint:md` checks markdown style rules (`.markdownlint.json`)
4. `lint:ps` analyzes PowerShell scripts (`PSScriptAnalyzer.psd1`)
5. `lint:yaml` validates YAML file syntax
6. `lint:json` validates JSON syntax
7. `lint:links` checks link text language patterns
8. `lint:md-links` resolves markdown link targets
9. `lint:frontmatter` validates YAML frontmatter against schemas
10. `lint:adr-consistency` checks ADR structure and consistency rules
11. `lint:hooks` validates hook manifests
12. `lint:design-intent` validates design intent declarations
13. `lint:version-consistency` checks GitHub Action version alignment
14. `lint:permissions` validates workflow permissions
15. `lint:dangerous-workflow` checks workflows for dangerous patterns
16. `lint:dependency-pinning` checks dependencies are pinned to fixed versions
17. `lint:public-dependency-feeds` confirms dependency sources use canonical public feeds
18. `lint:pr-gate` validates the pull request validation gate
19. `lint:ps-module-pins` checks PowerShell module versions are pinned
20. `lint:extension-artifact-naming` validates the one extension artifact identity
21. `lint:py` lints Python scripts via `Invoke-PythonLint.ps1`
22. `validate:skills` verifies skill directory structure
23. `lint:ai-artifacts` validates planner AI artifacts
24. `lint:asset-docs` confirms assets have documentation pages
25. `lint:models` validates model references against the catalog
26. `validate:devcontainer-lockfile` checks devcontainer lockfile integrity

Each linter outputs results to `logs/` for inspection. Run individual linters for faster
feedback during development:

```bash
npm run lint:md -- docs/customization/packages.md
```

## CI Validation

Pull request validation runs linters in parallel CI jobs. Each job executes one or more
npm scripts from the list above. To reproduce CI checks locally, run the same npm scripts
against your changed files.

Full local-safe validation:

```bash
npm run validate:local
```

Targeted validation for specific files:

```bash
npm run lint:md -- path/to/changed-file.md
npm run lint:frontmatter
```

> [!TIP]
> Run `validate:local` before pushing for the repository default. Individual
> checks provide faster feedback when you know which validation applies to your
> changes. Reproduce browser, model, moderation, or credential-dependent CI
> lanes separately when they are relevant.

## Customizing Validation

### Markdown Rules

Configure markdownlint rules in `.markdownlint.json` at the repository root. Each rule
maps to a markdownlint rule ID (e.g., `MD013` for line length). Disable rules by setting
them to `false`, or customize parameters such as line length limits.

### PowerShell Analysis

PSScriptAnalyzer rules are configured in `scripts/linting/PSScriptAnalyzer.psd1`. Add or
exclude rules to match your team's PowerShell coding standards. Run analysis with:

```bash
npm run lint:ps
```

Results appear in `logs/psscriptanalyzer-results.json` and
`logs/psscriptanalyzer-summary.json`.

### Custom Validation Scripts

Add new validation scripts to `scripts/linting/` and register them as npm scripts in
`package.json`. Follow the existing pattern: scripts accept file paths or glob patterns
as input and write structured results to `logs/`.

To include a new local-safe linter in the default pipeline, add it to the `validate:local` chain in
`package.json`.

## Role Scenarios

**Northwind Traders' SRE/Operations lead** runs `npm run validate:local` as a pre-push hook to
catch markdown formatting issues, broken links, and frontmatter schema violations before
they reach CI. When a new deployment instruction file needs custom frontmatter fields, the
lead adds a schema to `scripts/linting/schemas/` and registers the pattern in
`schema-mapping.json`.

**Adventure Works' security architect** extends the validation pipeline with a custom script
that checks instruction files for required security disclaimer sections. The script follows
the existing pattern of writing JSON results to `logs/` and integrates into the `validate:local`
chain through `package.json`.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
