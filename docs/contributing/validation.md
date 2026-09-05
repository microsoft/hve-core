---
title: Validation Commands and CI-Owned Lanes
description: Choose local-safe validation defaults and reproduce CI-owned documentation and evaluation lanes when their prerequisites are available
sidebar_position: 12
author: Microsoft
ms.date: 2026-08-21
ms.topic: how-to
keywords:
  - validation
  - ci
  - npm
  - docusaurus
  - playwright
  - vally
  - evaluations
  - package feeds
estimated_reading_time: 10
---

Validation command names distinguish the checks that are safe defaults for a
local development loop from lanes owned by CI. The distinction helps people and
automation choose an appropriate default without implying that a CI-owned
command cannot run on a workstation.

`ci:*` is a naming and default-agent-routing convention. It does not prevent
local execution, add a runtime guard, or require a special npm flag. Run a
named lane directly with its ordinary npm command when its prerequisites are
available.

## Start with local-safe validation

Use the smallest local-safe command that covers the change. Generic validation
does not select a `ci:*` lane, and a command mentioned in documentation, a
plan, a log, or an error message is not an agent execution request.

| Need                                      | Command                      | Notes                                                 |
|-------------------------------------------|------------------------------|-------------------------------------------------------|
| Repository-wide local-safe validation     | `npm run validate:local`     | Non-mutating default validation aggregate             |
| Documentation static and component checks | `npm run validate:docs`      | Does not run the browser E2E lane                     |
| Markdown tables check                     | `npm run lint:tables`        | Non-mutating table alignment check                    |
| Markdown link check                       | `npm run lint:md-links`      | Non-mutating link check included in `validate:local`  |
| Markdown tables fix                       | `npm run format:tables`      | Explicitly mutates table formatting                   |
| Markdown lint fix                         | `npm run lint:md:fix`        | Explicitly mutates Markdown where possible            |
| Targeted check                            | `npm run <local-check>`      | Choose the check that owns the changed file           |
| Design Intent contract lint               | `npm run lint:design-intent` | Validates authored records and verification artifacts |

For example, use `npm run lint:md -- docs/contributing/validation.md` for a
targeted Markdown check, or invoke `npm run lint:frontmatter` after changing
frontmatter. Use explicit fixers only when you intend to modify files, then
review the resulting diff.

## Install dependencies at the package root

This repository has independent lockfiles and package roots. Run `npm ci` in
the root whose command you intend to use. Do not substitute `npm install` for
the reproducible bootstrap path.

| Package root      | Use it for                                                      |
|-------------------|-----------------------------------------------------------------|
| Repository root   | Root validation, scripts, and `ci:eval:*` commands              |
| `docs/docusaurus` | Docusaurus lint, component test, build, and Playwright commands |

Installing dependencies for one root does not provision the other roots. The
root commands that delegate to Docusaurus still need the Docusaurus package
dependencies available.

## Install behind a restricted network

Some organizations block direct access to public package registries, release
downloads, or gallery endpoints and require installs to route through approved
proxies. Restore commands can then fail to reach npm or Python package indexes,
commonly with `ENOTCONN` or a connection timeout. DevContainer setup can also
fail while downloading tools or PowerShell modules.

This repository commits a project-level `.npmrc` that pins the canonical public
registry, and npm resolves configuration in the order `cli > env > project
.npmrc > user .npmrc > global`. A user-level `~/.npmrc` is therefore outranked
and silently ignored. Set an environment variable or pass a CLI flag instead.

Keep the proxy address out of the repository. It belongs in your own
environment, never in a tracked file.

Each tool reads its own environment variable:

| Tool | Environment variable  | Public default                |
|------|-----------------------|-------------------------------|
| npm  | `npm_config_registry` | `https://registry.npmjs.org/` |
| pip  | `PIP_INDEX_URL`       | `https://pypi.org/simple/`    |
| uv   | `UV_DEFAULT_INDEX`    | `https://pypi.org/simple/`    |

| Environment                | Where the override belongs                                                                  |
|----------------------------|---------------------------------------------------------------------------------------------|
| macOS or Linux             | A file in your home directory sourced from `~/.zshrc` or `~/.bashrc`                        |
| Windows                    | A PowerShell profile (`$PROFILE`) or a user environment variable                            |
| Dev container or Codespace | Host environment before container creation; `containerEnv` for runtime package indexes only |

macOS and Linux:

```bash
export npm_config_registry="https://proxy.example.com/npm/"
export PIP_INDEX_URL="https://proxy.example.com/pypi/simple/"
export UV_DEFAULT_INDEX="https://proxy.example.com/pypi/simple/"
npm ci
```

Windows PowerShell:

```powershell
$env:npm_config_registry = 'https://proxy.example.com/npm/'
$env:PIP_INDEX_URL = 'https://proxy.example.com/pypi/simple/'
$env:UV_DEFAULT_INDEX = 'https://proxy.example.com/pypi/simple/'
npm ci
```

Dev container runtime package indexes, in VS Code user settings so no
repository file changes:

```json
{
  "dev.containers.containerEnv": {
    "NPM_CONFIG_REGISTRY": "https://proxy.example.com/npm/",
    "PIP_INDEX_URL": "https://proxy.example.com/pypi/simple/",
    "UV_DEFAULT_INDEX": "https://proxy.example.com/pypi/simple/"
  }
}
```

### DevContainer build and setup overrides

The repository DevContainer supports additional host-side overrides for
container creation and setup. `.devcontainer/devcontainer.json` reads these
values through `${localEnv:...}`, so define them before opening VS Code or
rebuilding the container.

| Variable                   | Purpose                                                    |
|----------------------------|------------------------------------------------------------|
| `HVE_DEVCONTAINER_IMAGE`   | Selects the base image used by the Dockerfile              |
| `NPM_CONFIG_REGISTRY`      | Sets the npm registry in the built container               |
| `PIP_INDEX_URL`            | Sets the pip-compatible Python package index               |
| `UV_DEFAULT_INDEX`         | Sets the Python package index used by `uv`                 |
| `HVE_GITHUB_RELEASES_URL`  | Redirects release binary downloads used by setup scripts   |
| `HVE_GITHUB_API_URL`       | Redirects GitHub API requests made by security scripts     |
| `HVE_PSGALLERY_REPOSITORY` | Selects the PowerShell repository used for module installs |
| `HVE_PSGALLERY_SOURCE_URL` | Registers a custom PowerShell repository source URL        |

macOS and Linux:

```bash
export HVE_DEVCONTAINER_IMAGE="registry.corp.example.com/devcontainers/base:2-jammy"
export NPM_CONFIG_REGISTRY="https://proxy.example.com/npm/"
export PIP_INDEX_URL="https://proxy.example.com/pypi/simple/"
export UV_DEFAULT_INDEX="https://proxy.example.com/pypi/simple/"
export HVE_GITHUB_RELEASES_URL="https://artifacts.corp.example.com/github-releases"
export HVE_GITHUB_API_URL="https://github.corp.example.com/api/v3"
export HVE_PSGALLERY_REPOSITORY="InternalGallery"
export HVE_PSGALLERY_SOURCE_URL="https://packages.corp.example.com/powershell/"
```

Windows PowerShell:

```powershell
$env:HVE_DEVCONTAINER_IMAGE = 'registry.corp.example.com/devcontainers/base:2-jammy'
$env:NPM_CONFIG_REGISTRY = 'https://proxy.example.com/npm/'
$env:PIP_INDEX_URL = 'https://proxy.example.com/pypi/simple/'
$env:UV_DEFAULT_INDEX = 'https://proxy.example.com/pypi/simple/'
$env:HVE_GITHUB_RELEASES_URL = 'https://artifacts.corp.example.com/github-releases'
$env:HVE_GITHUB_API_URL = 'https://github.corp.example.com/api/v3'
$env:HVE_PSGALLERY_REPOSITORY = 'InternalGallery'
$env:HVE_PSGALLERY_SOURCE_URL = 'https://packages.corp.example.com/powershell/'
```

Restart VS Code from the configured shell and run **Dev Containers: Rebuild
Container**. Runtime `containerEnv` settings cannot change the base image
because Docker resolves it before the container starts. See
[Enterprise artifact hub](../customization/enterprise-artifact-hub.md) for the
complete defaults, affected files, and security considerations.

### Codespaces

For GitHub Codespaces, create account-specific
[development environment secrets](https://docs.github.com/en/codespaces/managing-your-codespaces/managing-your-account-specific-secrets-for-github-codespaces)
named `NPM_CONFIG_REGISTRY`, `PIP_INDEX_URL`, and `UV_DEFAULT_INDEX`. These
values become environment variables when the codespace is created or restarted;
they do not configure the Docker image build.

`onCreateCommand` and `updateContentCommand` can run while a Codespaces
prebuild is created, before account-specific secrets are available. Run setup
that requires those secrets from `postCreateCommand` or later.

The committed `.npmrc` sets `replace-registry-host=always`, so npm rewrites each
lockfile tarball host to the configured registry at fetch time only. `npm ci`
never writes `package-lock.json`, and it still verifies every download against
the committed `sha512` integrity value.

Use restore commands for proxied installs. `npm ci` verifies downloads
against the committed integrity values, and `uv sync --frozen` installs without
updating the lockfile. A plain `pip install -r` verifies committed hashes only
when the requirements file contains hashes and hash-checking mode is enabled,
for example with `--require-hashes`. Dependency-resolution commands may update
lockfiles with proxy-specific metadata. Review lockfile changes before
committing, and run
`npm run lint:public-dependency-feeds` if you suspect a lockfile picked up a
non-public source.

### Add or update a dependency from a restricted network

Generate the lockfile where the public registry is reachable, then commit the
result. Dependabot covers version bumps of dependencies that already exist, but
it does not add new ones.

| Situation                       | How to produce the lockfile                                                        |
|---------------------------------|------------------------------------------------------------------------------------|
| Bump an existing dependency     | Let Dependabot open the pull request                                               |
| Add a new dependency            | Edit `package.json`, push the branch, and let an agent or CI job run `npm install` |
| Need an interactive environment | Use a codespace or any workstation with direct public registry access              |

If a proxy-generated lockfile changes source or integrity metadata, regenerate
it where the public registry is reachable instead of editing it by hand.

## Documentation checks and browser lane

The documentation commands separate static and component validation from the
browser-backed lane.

| Lane                            | Command                                                | Prerequisites and cost                                                        | Output and interpretation                                                   |
|---------------------------------|--------------------------------------------------------|-------------------------------------------------------------------------------|-----------------------------------------------------------------------------|
| Local docs validation           | `npm run validate:docs`                                | Docusaurus package dependencies. Fast local static and component work.        | Console output; use as the normal docs default                              |
| Docs browser setup              | `npm run ci:docs:setup:e2e`                            | Docusaurus dependencies, browser installation, and supported host privileges. | Provisions Chrome for the E2E lane                                          |
| Docs browser E2E                | `npm run ci:docs:test:e2e`                             | Docusaurus dependencies and Chrome. Browser-backed and potentially slower.    | `docs/docusaurus/test-results/` and Playwright output show browser failures |
| Nested browser E2E              | `npm run ci:test:e2e`                                  | Run from `docs/docusaurus`; same browser prerequisites.                       | Standard browser-suite output                                               |
| Nested fast or interactive mode | `npm run ci:test:e2e:fast` or `npm run ci:test:e2e:ui` | Run from `docs/docusaurus`; `:ui` is interactive.                             | Use only when the relevant browser workflow is intended                     |

The setup command and the E2E command remain separate. A generic validation
request does not install a browser, start a service, or run Playwright. In
hosted CI, a failed browser lane means the configured browser environment did
not complete the suite. Locally, first determine whether the browser and its
dependencies were provisioned before treating a launch failure as a product
failure.

## Evaluation lanes

Evaluation lanes are CI-owned because their prerequisites and costs vary. They
remain directly runnable on a prepared local environment.

### Static checks

These lanes do not invoke a model. They are suitable for deliberate local
reproduction after installing root dependencies, but they are not included in
`validate:local`.

| Lane                          | Command                       | Typical prerequisites and output                                              |
|-------------------------------|-------------------------------|-------------------------------------------------------------------------------|
| Eval spec and generator drift | `npm run ci:eval:lint:vally`  | Root dependencies and Vally; may write a drift diff under `logs/`             |
| Eval schema                   | `npm run ci:eval:lint:schema` | Root dependencies and PowerShell modules; writes schema results under `logs/` |
| Eval text                     | `npm run ci:eval:lint:text`   | Root dependencies and Node; writes text-lint results under `logs/`            |
| Eval safety                   | `npm run ci:eval:lint:safety` | Root dependencies; writes `logs/vally-test-safety.json`                       |
| Skill hygiene                 | `npm run ci:eval:lint:skills` | Root dependencies and Vally; validates `.github/skills/`                      |

### Manifest, presence, and runtime sequence

Presence and execution lanes consume changed-artifact manifests. Generate the
manifest with the existing script before invoking them locally, then retain the
output in `logs/` while diagnosing a failure.

| Lane                 | Command                                                                                      | Prerequisites, cost, and output                                                                                                                                                  |
|----------------------|----------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Stimulus presence    | `npm run ci:eval:presence`                                                                   | Changed-artifact manifest at `logs/changed-ai-artifacts.json`; fast structural check writing `logs/stimulus-presence.json`                                                       |
| Eval execution       | `npm run ci:eval:execute`                                                                    | Manifest, Vally, Copilot credential, and a noninteractive service-capable environment; model-backed and potentially costly; writes `logs/eval-summary.json` and per-spec results |
| General eval suites  | `npm run ci:eval:run`                                                                        | Vally and model access; model-backed and potentially costly                                                                                                                      |
| One suite            | `npm run ci:eval:run:skills`, `npm run ci:eval:run:agents`, or `npm run ci:eval:run:scripts` | Same model and service prerequisites as the selected suite                                                                                                                       |
| Agent conformance    | `npm run ci:eval:run:conformance`                                                            | Vally and model access; runs the six planner-agent conformance suites in sequence and stops at the first failing suite                                                           |
| Result comparison    | `npm run ci:eval:equivalence -- -Agent <slug> -Tier devloop`                                 | Vally and model access; runs the baseline-vs-customized comparison for one agent                                                                                                 |
| Prompt behavior      | `npm run ci:eval:behavior-prompts`                                                           | Vally and model access; runs the prompt conformance spec                                                                                                                         |
| Instruction behavior | `npm run ci:eval:behavior-instructions`                                                      | Vally and model access; runs the instruction conformance spec                                                                                                                    |
| Skill behavior       | `npm run ci:eval:behavior-skills`                                                            | Vally and model access; runs the skill behavior conformance spec                                                                                                                 |
| Agent matrix entry   | `npm run ci:eval:agent`                                                                      | Agent-matrix arguments supplied after `--`; model-backed when execution is selected                                                                                              |

Set `COPILOT_GITHUB_TOKEN` only in the environment that needs model-backed
execution. Never commit credentials, paste them into documentation, or assume
they are available to fork pull requests. Hosted CI clean-skips model execution
when secrets are unavailable to an untrusted fork. A local credential or
service failure is an environment result, not evidence that an eval contract
failed.

### Moderation

| Lane                     | Command                              | Prerequisites and output                                                                             |
|--------------------------|--------------------------------------|------------------------------------------------------------------------------------------------------|
| Input moderation         | `npm run ci:eval:moderate`           | Root dependencies plus the moderation Python environment                                             |
| Corpus moderation        | `npm run ci:eval:moderate:corpus`    | Changed-artifact manifest and moderation Python environment                                          |
| Artifact moderation      | `npm run ci:eval:moderate:artifacts` | Changed-artifact manifest and moderation Python environment; writes `logs/moderation-artifacts.json` |
| Moderation wrapper tests | `npm run ci:eval:moderate:test`      | Root test dependencies; no model invocation                                                          |

Provision the moderation environment with its locked `uv` environment in
`scripts/evals/moderation` before running a real Detoxify lane. The model-backed
moderation path can download or use model weights and is not a generic local
validation default. A setup exit indicates missing dependencies rather than a
clean moderation result.

### Baseline equivalence and agent matrix

| Lane                 | Command                                                         | Behavior and output                                                                                                     |
|----------------------|-----------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------|
| Baseline equivalence | `npm run ci:eval:equivalence -- -Agent rpi-agent -Tier devloop` | Model-backed comparison; writes `logs/baseline-equivalence-summary.json` and result trajectories under `evals/results/` |
| Equivalence dry run  | `npm run ci:eval:equivalence -- -Agent rpi-agent -WhatIf`       | Prints planned work and writes a dry-run summary without SDK calls                                                      |
| Agent matrix         | `npm run ci:eval:agent:matrix`                                  | Model-backed nightly matrix; writes date-scoped output under `evals/results/agent-matrix/`                              |
| Agent matrix dry run | `npm run ci:eval:agent:matrix:dryrun`                           | No model invocation; writes a dry-run matrix summary                                                                    |
| Changed-agent matrix | `npm run ci:eval:agent:changed`                                 | Requires a suitable git comparison base and model access                                                                |

Devloop-tier equivalence results are advisory while CI-tier results are
authoritative. These tiers name the baseline-equivalence exit policy and are
distinct from the unchanged `pr` and `nightly` vocabulary of the separate
agent-matrix commands above. Read the lane's generated JSON verdict and the
hosted workflow status together. Do not infer a hosted CI policy from a direct
local invocation.

### Dashboards and reports

Dashboard generation is noninteractive. These commands generate artifacts but
do not open a browser:

```bash
npm run ci:eval:agent:dashboard
npm run ci:eval:agent:report
npm run ci:eval:agent:report:dryrun
npm run ci:eval:dashboard
```

Only `npm run ci:eval:agent:dashboard:open` is interactive and opens the
generated dashboard. Keep it separate from unattended validation or report
generation.

## Agent conformance workflow

Agent conformance is a CI-owned workflow that runs the six planner-agent
suites under `evals/agent-conformance/`. It is invoked from
`weekly-validation.yml` through `workflow_call`, has a 30-minute timeout, and
requires the `copilot-github-token` secret exported as `COPILOT_GITHUB_TOKEN`.
The workflow runs one matrix leg per suite with `fail-fast: false`, so a single
failing agent does not mask the others:

```bash
npx vally eval --suite agent-conformance-dt-coach
```

Results are written under `evals/results/` and uploaded as a per-suite
artifact. Each stimulus launches the agent artifact in turn 0 and delivers the
case query in turn 1, then grades the response with a model judge plus advisory
wall-time and content budgets. Establish the credential through an
operator-managed environment before a deliberate local reproduction. Do not ask
for or transmit the credential through chat, do not treat this lane as part of
`validate:local`, and do not infer its prerequisites from generic validation.

## Review and cleanup

Review generated results before removing them. Common local outputs include
`logs/`, `evals/results/`, `docs/docusaurus/build/`, and browser test-report
directories. These artifacts help distinguish a contract failure from missing
dependencies, unavailable credentials, or an unsupported local host.

Treat a passing local reproduction as useful evidence, not as a replacement
for the hosted CI status. Hosted CI controls its own operating system,
credentials, browser provisioning, and branch-protection policy.

## Related guidance

* [Evals in CI](evals-ci) covers the hosted workflow authentication, fork, and
  evaluation-spec contracts.
* [Build System and Validation](../customization/build-system) explains the
  local validation commands and customization points.
* [HVE Core Documentation Site](https://github.com/microsoft/hve-core/blob/main/docs/docusaurus/README.md)
  covers the Docusaurus project and accessibility layers.

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
