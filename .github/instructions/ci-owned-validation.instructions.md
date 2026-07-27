---
description: "Command taxonomy and CI-owned validation conventions for package scripts, eval wrappers, and owning workflows"
applyTo: 'package.json, docs/docusaurus/package.json, scripts/evals/**, .github/workflows/docusaurus-tests.yml, .github/workflows/eval-validation.yml, .github/workflows/beval.yml, .github/workflows/pr-validation.yml'
---

# CI-Owned Validation Instructions

Keep ordinary local validation predictable while preserving direct, named reproduction of CI-owned lanes.

## Command taxonomy

* Use `lint:*` for non-mutating static checks.
* Use `format:*` or an explicit fixer suffix for mutating cleanup.
* Use `validate:*` for non-mutating aggregates composed only of locally safe checks.
* Use `test:*` for locally safe deterministic or component tests.
* Use `ci:*` for CI-owned or otherwise non-default validation lanes, including eval-framework execution and documentation Playwright E2E.

The `ci:*` prefix communicates ownership and default agent behavior. It does not block direct local execution and requires no marker, wrapper, or opt-in flag.

## Selection and composition

* Generic validation uses applicable local-safe commands such as `validate:local`, `validate:docs`, or targeted checks. It does not select `ci:*` commands.
* A task that specifically asks to run or reproduce a named CI lane may invoke its ordinary `ci:*` command after its prerequisites and side effects are understood.
* Keep `validate:*` aggregates free of `ci:*` commands, fixers, generators, installers, browser actions, and interactive children.
* Keep report generation noninteractive. Use a separately named `:open` or `:ui` command for browser or interactive behavior.
* Do not restore removed `eval:*`, `lint:all`, `lint:docs-site`, `docs:test:e2e*`, or nested `test:e2e*` compatibility aliases.

## Package and workflow changes

* Coordinate a breaking package-script rename with every owning workflow consumer in the same change set.
* Preserve workflow change detection, gates, arguments, outputs, artifacts, summaries, permissions, and failure behavior when changing only an entry-point name.
* Keep Beval service orchestration and direct workflow invocation unchanged unless a separate requirement justifies a package entry point.
* Use existing repository syntax, workflow, and source checks plus hosted CI evidence. Do not add a command-policy test subsystem or dedicated policy job solely for this taxonomy.

## Prerequisites and evidence

* Establish dependencies for each relevant package root with `npm ci` when no successful installation for its current lockfile is known. Do not substitute `npm install` or reinstall a known-current package root.
* Treat browser installation, model or moderation environments, service startup, credentials, execution outside the sandbox, and interactive UI as lane-specific prerequisites. Generic validation does not imply those actions.
* Record CI-owned checks that did not run as `Pending CI`, `Skipped`, `Deferred`, or `Unavailable`, as applicable. Do not report them as passed.
* Use the canonical validation guide at `docs/contributing/validation.md` for operator commands, prerequisites, outputs, and local reproduction guidance.

This root-level instruction is repository-specific. Do not add it to collection manifests or generated plugin and extension outputs.
