# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

HVE (Hyper Velocity Engineering) Core is an enterprise-ready prompt engineering framework for GitHub Copilot. It is **not** a traditional source code repository -- it contains markdown-based AI artifacts (agents, prompts, instructions, skills), PowerShell validation scripts, and a VS Code extension that distributes these artifacts.

## Commands

```bash
# Linting
npm run lint:md              # Markdown linting (markdownlint-cli2)
npm run lint:md:fix           # Markdown linting with auto-fix
npm run lint:ps              # PowerShell ScriptAnalyzer
npm run lint:yaml            # YAML linting
npm run lint:frontmatter     # Frontmatter schema validation
npm run lint:links           # Link language checking
npm run lint:md-links        # Markdown link checking
npm run lint:version-consistency  # Action version consistency
npm run lint:all             # Run all linters sequentially

# Spell check
npm run spell-check          # cspell across md/ts/js/json/yaml files

# Table formatting
npm run format:tables        # Format markdown tables (run before lint:md)

# Testing (Pester 5.x / PowerShell)
npm run test:ps              # Run all Pester tests (excludes Integration/Slow tags)

# Extension
npm run extension:prepare    # Prepare VS Code extension
npm run extension:package    # Package VS Code extension (.vsix)

# Copyright
npm run validate:copyright   # Check copyright headers on source files
```

### Running a Single Pester Test

```bash
pwsh -NoProfile -Command "Invoke-Pester -Path './scripts/tests/path/to/Specific.Tests.ps1'"
```

## Architecture

### Artifact Types

All AI artifacts are markdown files with YAML frontmatter validated against JSON schemas in `scripts/linting/schemas/`.

| Type         | Location                | Naming              | Schema                                | Purpose                                                                |
|--------------|-------------------------|---------------------|---------------------------------------|------------------------------------------------------------------------|
| Agents       | `.github/agents/`       | `*.agent.md`        | `agent-frontmatter.schema.json`       | Interactive AI personas with tools and handoffs                        |
| Instructions | `.github/instructions/` | `*.instructions.md` | `instruction-frontmatter.schema.json` | Passive coding guidelines auto-attached by VS Code via `applyTo` globs |
| Prompts      | `.github/prompts/`      | `*.prompt.md`       | `prompt-frontmatter.schema.json`      | Task-specific templates with `${input:variableName}` support           |
| Skills       | `.github/skills/`       | directory-based     | `skill-frontmatter.schema.json`       | Self-contained executable packages                                     |

### RPI Methodology

The core workflow is Research -> Plan -> Implement -> Review. Key agents:

- `task-researcher` -> `task-planner` -> `task-implementor` -> `task-reviewer`
- `rpi-agent` orchestrates all phases autonomously for simpler tasks

### Key Directories

- `scripts/linting/` -- Markdown, YAML, frontmatter, link, and PowerShell validators
- `scripts/security/` -- Dependency pinning, SHA staleness, copyright header checks
- `scripts/tests/` -- Pester test suites mirroring the `scripts/` source structure
- `scripts/lib/` -- Shared PowerShell modules
- `extension/` -- VS Code extension manifest and packaging (synced to root `package.json` version)
- `docs/` -- User documentation: getting started, RPI workflow, contributing guides, templates
- `.claude/agents/` -- Claude Code local development agents (not published)
- `.copilot-tracking/` -- Gitignored AI workflow artifacts (plans, research, PR tracking)

### VS Code Extension

The extension (`extension/package.json`) registers all agents, prompts, and instructions as VS Code contributes. Version is kept in sync with root `package.json` (currently 2.2.0). Packaging uses `scripts/extension/Prepare-Extension.ps1` and `scripts/extension/Package-Extension.ps1`.

## Conventions

### Commit Messages

Conventional Commits format is required. Types: `feat`, `fix`, `refactor`, `perf`, `style`, `test`, `docs`, `build`, `ops`, `chore`. Scopes: `agents`, `prompts`, `instructions`, `skills`, `templates`, `workflows`, `extension`, `scripts`, `docs`, `adrs`, `settings`, `build`. Description must be < 100 bytes. See `.github/instructions/commit-message.instructions.md` for full format including footer requirements.

### Frontmatter

Every markdown artifact requires YAML frontmatter. The `npm run lint:frontmatter` command validates against schemas in `scripts/linting/schemas/`. Maturity levels: `experimental` -> `preview` -> `stable` -> `deprecated`.

### PowerShell

Scripts follow PSScriptAnalyzer rules from `scripts/linting/PSScriptAnalyzer.psd1`. All scripts must include copyright headers (MIT license). New scripts require corresponding `*.Tests.ps1` files in `scripts/tests/`.

### Priority Rules (from copilot-instructions.md)

- Codebase conventions and styling take precedence for all changes.
- Breaking changes are acceptable; backward-compatibility layers only when explicitly requested.
- Tests, scripts, and one-off docs are created/modified only when explicitly requested.
- Comments must be brief and factual -- no narrative reasoning or temporal markers.
- Proactively fix problems encountered while working, even if unrelated to the original request.

## CI/CD

GitHub Actions workflows in `.github/workflows/`. The main pipeline (`main.yml`) runs: spell check, markdown lint, table format check, dependency pinning scan, Pester tests, then release-please for automated versioning. Releases use [release-please](https://github.com/googleapis/release-please) driven by conventional commits.
