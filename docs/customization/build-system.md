---
title: Build System and Validation
description: Understand the plugin generation pipeline, schema validation system, npm scripts, and CI checks for customizing and extending HVE Core
author: Microsoft
ms.date: 2026-02-24
ms.topic: how-to
keywords:
  - build system
  - plugin generation
  - schema validation
  - linting
  - npm scripts
estimated_reading_time: 8
---

## Plugin Generation Pipeline

The plugin generation pipeline transforms collection manifests into distributable plugin
output. It runs in three stages:

1. `Generate-Plugins.ps1` reads each `collections/*.collection.yml` manifest and produces
   output files under `plugins/`. Each collection gets its own subdirectory
   (e.g., `plugins/hve-core/`, `plugins/ado/`).

2. `lint:md:fix` applies markdownlint auto-fixes to generated markdown files.

3. `format:tables` aligns markdown table columns in generated output.

Run the full pipeline with a single command:

```bash
npm run plugin:generate
```

> [!IMPORTANT]
> Files under `plugins/` are generated output. Do not edit them directly.
> Changes made to plugin files are overwritten on the next generation run.

## Schema Validation System

YAML frontmatter in markdown files is validated against JSON schemas stored in
`scripts/linting/schemas/`. The validation system uses glob-based pattern matching to
determine which schema applies to each file.

### Schema Files

| Schema                                   | Applies To                        |
|------------------------------------------|-----------------------------------|
| `docs-frontmatter.schema.json`           | `docs/**/*.md`                    |
| `instruction-frontmatter.schema.json`    | `.github/**/*.instructions.md`    |
| `agent-frontmatter.schema.json`          | `.github/**/*.agent.md`           |
| `prompt-frontmatter.schema.json`         | `.github/**/*.prompt.md`          |
| `skill-frontmatter.schema.json`          | `.github/skills/**/SKILL.md`      |
| `chatmode-frontmatter.schema.json`       | `.github/**/*.chatmode.md`        |
| `collection-manifest.schema.json`        | Collection YAML manifests         |
| `root-community-frontmatter.schema.json` | Root files (README, CONTRIBUTING) |
| `base-frontmatter.schema.json`           | Default fallback                  |

### Pattern Mapping

The `scripts/linting/schemas/schema-mapping.json` file defines the glob-to-schema mapping.
Patterns are evaluated from most specific to least specific, and the first match determines
the schema. When no pattern matches, `base-frontmatter.schema.json` applies as the default.

### Adding Custom Schemas

To add validation for a new file type:

1. Create a JSON schema file in `scripts/linting/schemas/`
2. Add a mapping entry to `schema-mapping.json` with the glob pattern, scope name, and
   schema filename
3. Run `npm run lint:frontmatter` to verify the new schema validates correctly

## npm Scripts Reference

All validation, formatting, and testing operations run through npm scripts defined in
`package.json`. The table below groups scripts by purpose.

### Linting

| Script                      | Command                             | Description                              |
|-----------------------------|-------------------------------------|------------------------------------------|
| `lint:all`                  | `npm run lint:all`                  | Runs all linters in sequence             |
| `lint:md`                   | `npm run lint:md`                   | Markdown linting via markdownlint-cli2   |
| `lint:md:fix`               | `npm run lint:md:fix`               | Markdown linting with auto-fix           |
| `lint:ps`                   | `npm run lint:ps`                   | PowerShell analysis via PSScriptAnalyzer |
| `lint:yaml`                 | `npm run lint:yaml`                 | YAML syntax and structure validation     |
| `lint:links`                | `npm run lint:links`                | Link language checking                   |
| `lint:md-links`             | `npm run lint:md-links`             | Markdown link target validation          |
| `lint:frontmatter`          | `npm run lint:frontmatter`          | Frontmatter schema validation            |
| `lint:collections-metadata` | `npm run lint:collections-metadata` | Collection manifest validation           |
| `lint:marketplace`          | `npm run lint:marketplace`          | Marketplace manifest validation          |
| `lint:version-consistency`  | `npm run lint:version-consistency`  | GitHub Action version consistency        |
| `lint:permissions`          | `npm run lint:permissions`          | Workflow permissions validation          |

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

| Script                         | Command                                | Description                                        |
|--------------------------------|----------------------------------------|----------------------------------------------------|
| `plugin:generate`              | `npm run plugin:generate`              | Generate plugins, auto-fix markdown, format tables |
| `plugin:validate`              | `npm run plugin:validate`              | Validate collection metadata (alias)               |
| `extension:prepare`            | `npm run extension:prepare`            | Prepare VS Code extension for packaging            |
| `extension:prepare:prerelease` | `npm run extension:prepare:prerelease` | Prepare extension for pre-release                  |
| `extension:package`            | `npm run extension:package`            | Package VS Code extension                          |
| `extension:package:prerelease` | `npm run extension:package:prerelease` | Package extension as pre-release                   |

## Linting Pipeline

The `lint:all` script chains every linter in a fixed sequence:

1. `format:tables` aligns markdown table columns
2. `lint:md` checks markdown style rules (`.markdownlint.json`)
3. `lint:ps` analyzes PowerShell scripts (`PSScriptAnalyzer.psd1`)
4. `lint:yaml` validates YAML file syntax
5. `lint:links` checks link text language patterns
6. `lint:frontmatter` validates YAML frontmatter against schemas
7. `lint:collections-metadata` confirms collection manifest integrity
8. `lint:marketplace` validates marketplace manifest
9. `lint:version-consistency` checks GitHub Action version alignment
10. `lint:permissions` validates workflow permissions
11. `validate:skills` verifies skill directory structure

Each linter outputs results to `logs/` for inspection. Run individual linters for faster
feedback during development:

```bash
npm run lint:md -- docs/customization/collections.md
```

## CI Validation

Pull request validation runs linters in parallel CI jobs. Each job executes one or more
npm scripts from the list above. To reproduce CI checks locally, run the same npm scripts
against your changed files.

Full local validation:

```bash
npm run lint:all
```

Targeted validation for specific files:

```bash
npm run lint:md -- path/to/changed-file.md
npm run lint:frontmatter
```

> [!TIP]
> Run `lint:all` before pushing to catch issues that CI would flag. Individual linters
> provide faster feedback when you know which validation applies to your changes.

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

To include a new linter in the full pipeline, add it to the `lint:all` chain in
`package.json`.

## Role Scenarios

**Northwind Traders' SRE/Operations lead** runs `npm run lint:all` as a pre-push hook to
catch markdown formatting issues, broken links, and frontmatter schema violations before
they reach CI. When a new deployment instruction file needs custom frontmatter fields, the
lead adds a schema to `scripts/linting/schemas/` and registers the pattern in
`schema-mapping.json`.

**Adventure Works' security architect** extends the validation pipeline with a custom script
that checks instruction files for required security disclaimer sections. The script follows
the existing pattern of writing JSON results to `logs/` and integrates into the `lint:all`
chain through `package.json`.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
