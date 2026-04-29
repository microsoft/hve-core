---
title: CLAUDE.md
description: Guidance for Claude Code (claude.ai/code) sessions working in the hve-core repository
author: Microsoft
ms.date: 2026-04-29
ms.topic: guide
keywords:
  - claude code
  - agent guidance
  - hve-core
  - development
estimated_reading_time: 5
---

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

HVE Core (Hypervelocity Engineering Core) is **not a runtime application**. It is a Microsoft-published library of GitHub Copilot customization artifacts (agents, coding instructions, reusable prompts, and skills) distributed as VS Code extensions. The repo's "build" is validation, packaging, and plugin/collection generation; there is no application server, no compiled output, no end-user feature code in the traditional sense.

Authoritative authoring rules live in [.github/copilot-instructions.md](.github/copilot-instructions.md). Read it before edits: its "Priority Rules" section overrides general guidance.

## Architecture: artifacts to collections to plugins to extensions

There are exactly four artifact types, each with its own filename suffix and frontmatter shape:

| Artifact     | Path                                                                                  | Suffix              | Key frontmatter                                            |
|--------------|---------------------------------------------------------------------------------------|---------------------|------------------------------------------------------------|
| Agents       | `.github/agents/<collection>/` (subagents under `subagents/`)                         | `*.agent.md`        | `name`, `description`, optional `agents:` (subagent globs) |
| Instructions | `.github/instructions/<collection>/`                                                  | `*.instructions.md` | `description`, `applyTo` (glob)                            |
| Prompts      | `.github/prompts/<collection>/`                                                       | `*.prompt.md`       | `description`, `agent`, `argument-hint`                    |
| Skills       | `.github/skills/<collection>/<name>/SKILL.md` (+ `references/`, `scripts/`, `tests/`) | `SKILL.md`          | `name`, `description`, `license`, `user-invocable`         |

The pipeline you must understand:

1. Authors edit artifacts under `.github/{agents,instructions,prompts,skills}/<collection>/`.
2. `collections/<id>.collection.yml` lists the artifacts in each bundle (with `path` + `kind`); `<id>.collection.md` describes it.
3. `npm run plugin:generate` reads the collection manifests and writes generated outputs under `plugins/`. **Files in `plugins/` are generated. Never edit them directly.** The generate step also runs `lint:md:fix` and `format:tables` as post-processing.
4. `extension/` packages selected plugins into VSIX files for the VS Code Marketplace.

### Critical rules tied to this pipeline

* When you add, move, or remove any agent, instruction, prompt, skill, or subagent, update every affected `collections/*.collection.yml` and `*.collection.md`, then run `npm run plugin:generate` and `npm run plugin:validate`.
* Subagents declared in a parent agent's `agents:` frontmatter (matched via globs like `.github/agents/**/researcher-subagent.agent.md`) must also be listed in any collection that ships the parent.
* Artifacts placed at the root of `.github/agents/`, `.github/instructions/`, `.github/prompts/`, or `.github/skills/` (no `<collection>/` subdir) are intentionally repo-only: excluded from collections, plugin generation, and extension packaging. Validation enforces this.
* AI-workflow scratch state lives under `.copilot-tracking/` (gitignored). Never commit anything from there.

## Common commands

Run everything via npm scripts. Never invoke Pester, PSScriptAnalyzer, ruff, or pytest directly.

```bash
# Full validation gate (matches CI). Run this before pushing.
npm run lint:all

# Targeted linters
npm run lint:md                   # markdownlint-cli2
npm run lint:ps                   # PSScriptAnalyzer
npm run lint:yaml                 # YAML
npm run lint:frontmatter          # schema-validate frontmatter (schemas in scripts/linting/schemas/)
npm run lint:md-links             # markdown link check
npm run lint:collections-metadata # collections/*.collection.yml
npm run lint:marketplace          # VSIX marketplace metadata
npm run lint:dependency-pinning   # SHA pinning of GitHub Actions
npm run lint:permissions          # workflow permission scopes
npm run lint:py                   # ruff
npm run validate:skills           # skill directory structure
npm run validate:copyright        # copyright headers (incl. bash files)
npm run spell-check               # cspell
npm run format:tables             # markdown-table-formatter

# PowerShell tests
npm run test:ps                                                    # all
npm run test:ps -- -TestPath "scripts/tests/linting/"              # one directory
npm run test:ps -- -TestPath "scripts/tests/security/Test-DependencyPinning.Tests.ps1"  # one file

# Python tests
npm run test:py

# Plugin/extension regeneration (run after collection or artifact changes)
npm run plugin:generate
npm run plugin:validate
npm run extension:prepare
npm run extension:package

# Docs (Docusaurus site)
npm run docs:build && npm run docs:serve
```

### Test output protocol

Pester writes structured results to `logs/` regardless of how it was invoked:

* `logs/pester-summary.json` (pass/fail counts, duration, status)
* `logs/pester-failures.json` (failure name, file, message, stack)

After running `npm run test:ps`, read `pester-summary.json` to confirm status, then `pester-failures.json` if anything failed. The `logs/` directory is gitignored, so use search tools that include ignored files when grepping there. Most lint scripts also emit JSON results into `logs/` (e.g. `logs/python-lint-results.json`, `logs/action-version-consistency-results.json`).

## Conventions that matter for edits

| Topic                  | Rule                                                                                                                                                                                                                                                                                                                                                                                                            |
|------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Test location          | PowerShell tests mirror source: `scripts/linting/Foo.ps1` to `scripts/tests/linting/Test-Foo.Tests.ps1`. Skill tests are the exception: they live inside the skill at `.github/skills/<collection>/<skill>/tests/`.                                                                                                                                                                                             |
| Python skills          | Every Python-bearing skill needs a `pyproject.toml` with `[tool.ruff]` (required) and, when `tests/` exists, `[tool.pytest.ini_options]` with `python_files = ["test_*.py", "fuzz_harness.py"]`, plus a polyglot Atheris fuzz harness at `tests/fuzz_harness.py` and a `fuzz` dependency group with `atheris>=3.0` (kept separate from `dev` because there are no macOS wheels). Enforced by `validate:skills`. |
| Conventional Commits   | Drive releases via release-please. Scopes map to directories: `(agents)` to `.github/agents/`, `(instructions)`, `(prompts)`, `(skills)`, `(scripts)`, `(extension)`, `(collections)`, `(workflows)`, `(docs)`, `(ci)`, `(build)`, `(settings)`. `feat:` is a minor bump, `fix:` is a patch, `docs:` / `chore:` / `refactor:` skip the bump, `feat!:` or `BREAKING CHANGE:` is a major bump.                    |
| Markdown style         | Lists use `*`, not `-`. Em dashes are banned (use colons, commas, or parentheses). Bolded-prefix list items (`* **Label**: text`) are banned (use tables or headings). Enforced by markdownlint-cli2 + a custom search-replace rule.                                                                                                                                                                            |
| Comments               | Brief, factual, behavioral. No narrative reasoning, no "phase 2" / dated / task-id markers (strip them on touch per Priority Rules).                                                                                                                                                                                                                                                                            |
| Backward compatibility | Opt-in. Breaking changes are acceptable; do not add compat shims unless explicitly requested.                                                                                                                                                                                                                                                                                                                   |
| Tests, scripts, docs   | Opt-in. Do not create them unless the task asks. (Genuine new functionality still requires tests per CONTRIBUTING.md, which is a different axis.)                                                                                                                                                                                                                                                               |
| Error handling         | Root-cause over symptom. Fix unrelated breakage you encounter while in the area; do not paper over it.                                                                                                                                                                                                                                                                                                          |

## Environments

* DevContainer ([.devcontainer/README.md](.devcontainer/README.md)) is the recommended local setup: Node 24, Python 3.11, PowerShell 7, gitleaks, all linters preinstalled.
* Copilot Coding Agent uses `.github/workflows/copilot-setup-steps.yml` as a parallel cloud environment. It mirrors the devcontainer but excludes gitleaks. When adding or removing tooling, evaluate whether both environments need the change.

## Where to look first

* Authoring rules and full directory map: [.github/copilot-instructions.md](.github/copilot-instructions.md)
* Contribution and release process: [CONTRIBUTING.md](CONTRIBUTING.md)
* Artifact contribution guides: [docs/contributing/](docs/contributing/)
* Common standards across all artifact types: [docs/contributing/ai-artifacts-common.md](docs/contributing/ai-artifacts-common.md)
* Frontmatter schemas: [scripts/linting/schemas/](scripts/linting/schemas/) (mapping in `schema-mapping.json`)
* Shared CI helpers: [scripts/lib/Modules/CIHelpers.psm1](scripts/lib/Modules/CIHelpers.psm1)

---

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
