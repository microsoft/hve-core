---
title: Validation Commands and CI-Owned Lanes
description: Choose local-safe validation defaults and reproduce CI-owned documentation and evaluation lanes when their prerequisites are available
sidebar_position: 12
author: Microsoft
ms.date: 2026-08-10
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

| Need                                      | Command                  | Notes                                                |
|-------------------------------------------|--------------------------|------------------------------------------------------|
| Repository-wide local-safe validation     | `npm run validate:local` | Non-mutating default validation aggregate            |
| Documentation static and component checks | `npm run validate:docs`  | Does not run the browser E2E lane                    |
| Markdown tables check                     | `npm run lint:tables`    | Non-mutating table alignment check                   |
| Markdown link check                       | `npm run lint:md-links`  | Non-mutating link check included in `validate:local` |
| Markdown tables fix                       | `npm run format:tables`  | Explicitly mutates table formatting                  |
| Markdown lint fix                         | `npm run lint:md:fix`    | Explicitly mutates Markdown where possible           |
| Targeted check                            | `npm run <local-check>`  | Choose the check that owns the changed file          |

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

Some organizations block direct access to public package registries and require
installs to route through an approved feed proxy. `npm ci`, `pip install`, and
`uv sync` then fail to reach `registry.npmjs.org` or `pypi.org`, commonly with
`ENOTCONN` or a connection timeout.

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

| Environment    | Where the override belongs                                                |
|----------------|---------------------------------------------------------------------------|
| macOS or Linux | A file in your home directory sourced from `~/.zshrc` or `~/.bashrc`      |
| Windows        | A PowerShell profile (`$PROFILE`) or a user environment variable          |
| Dev container  | The host environment available to VS Code when it builds the image        |
| Codespaces     | Development environment secrets for post-build setup and runtime commands |

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

### Dev container build and runtime variables

`.devcontainer/devcontainer.json` reads `NPM_CONFIG_REGISTRY`,
`PIP_INDEX_URL`, and `UV_DEFAULT_INDEX` from the host with
`${localEnv:VAR}` and passes them as `build.args` to
`.devcontainer/Dockerfile`. The Dockerfile declares matching `ARG` and `ENV`
entries, persists the selected values for commands inside the container, and
falls back to each public registry when the build argument is empty.

The current Dockerfile does not install project packages. Dependency
installation occurs after the container is created: `onCreateCommand` runs
`.devcontainer/scripts/on-create.sh`, and `updateContentCommand` runs `npm ci`.
The persisted registry values configure those lifecycle commands as well as
later interactive commands.

Set the variables in the host environment before launching VS Code and
rebuilding the container. The npm build argument uses uppercase
`NPM_CONFIG_REGISTRY`, while npm commands outside the container use lowercase
`npm_config_registry` as shown above.

```bash
export NPM_CONFIG_REGISTRY="https://proxy.example.com/npm/"
export PIP_INDEX_URL="https://proxy.example.com/pypi/simple/"
export UV_DEFAULT_INDEX="https://proxy.example.com/pypi/simple/"
code .
```

On Windows, set the same variables in a PowerShell session before launching
VS Code:

```powershell
$env:NPM_CONFIG_REGISTRY = 'https://proxy.example.com/npm/'
$env:PIP_INDEX_URL = 'https://proxy.example.com/pypi/simple/'
$env:UV_DEFAULT_INDEX = 'https://proxy.example.com/pypi/simple/'
code .
```

VS Code substitutes the host values at build time. If VS Code is already open,
restart it from the configured environment before rebuilding the container.
There is no repository file to edit.

### Codespaces

For a codespace created directly for your account, create
[development environment secrets](https://docs.github.com/en/codespaces/managing-your-codespaces/managing-your-account-specific-secrets-for-github-codespaces)
named `NPM_CONFIG_REGISTRY`, `PIP_INDEX_URL`, and `UV_DEFAULT_INDEX`. These
values become environment variables when the codespace is created or restarted.

Do not rely on account-specific secrets in `onCreateCommand` or
`updateContentCommand` when the repository uses Codespaces prebuilds. Those
commands can run while the shared prebuild is created, before an individual
user's secrets are available. Repository or organization administrators must
configure any secrets required by the prebuild, or secret-dependent setup must
run after the user creates the codespace. Account-specific secrets are
available to `postCreateCommand` and later commands in the user's codespace.

Account-specific Codespaces secrets are not available while the image is
built. They cannot redirect a package download performed by a Dockerfile `RUN`
instruction or another image-build step. Use an organization-approved prebuilt
image or other build infrastructure when the image build itself requires
authenticated package access.

The committed `.npmrc` sets `replace-registry-host=always`, so npm rewrites each
lockfile tarball host to the configured registry at fetch time only. `npm ci`
never writes `package-lock.json`, and it still verifies every download against
the committed `sha512` integrity value.

Restrict proxied installs to restore commands. `npm ci` verifies downloads
against the committed integrity values, and `uv sync --frozen` installs without
updating the lockfile. A plain `pip install -r` verifies committed hashes only
when the requirements file contains hashes and hash-checking mode is enabled,
for example with `--require-hashes`. Commands that resolve dependencies, such
as `npm install`, `npm update`, `npm audit fix`, `uv lock`, and `uv add`, write
the proxy's own URLs into the lockfile and can downgrade npm integrity from
`sha512` to `sha1`.

The dev container's skill setup currently runs plain `uv sync`, which may
update a lockfile; the moderation environment uses `uv sync --locked`. Inspect
lockfile changes after container setup and run
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

Do not repair a proxy-generated lockfile by hand. Rewriting `resolved` back to
the public registry leaves the weakened `integrity` value in place, and
recomputing the hash from the proxy-served bytes only attests to what the proxy
returned rather than to what the registry published.

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
| Result comparison    | `npm run ci:eval:compare`                                                                    | Existing Vally result sets; compares prior outputs without selecting another suite                                                                                               |
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

| Lane                  | Command                                                    | Behavior and output                                                                                                     |
|-----------------------|------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------|
| Baseline equivalence  | `npm run ci:eval:equivalence -- -Agent rpi-agent -Tier pr` | Model-backed comparison; writes `logs/baseline-equivalence-summary.json` and result trajectories under `evals/results/` |
| Equivalence dry run   | `npm run ci:eval:equivalence -- -Agent rpi-agent -WhatIf`  | Prints planned work and writes a dry-run summary without SDK calls                                                      |
| Raw equivalence specs | `npm run ci:eval:run:equivalence`                          | Runs paired specs directly; requires the selected model environment                                                     |
| Agent matrix          | `npm run ci:eval:agent:matrix`                             | Model-backed nightly matrix; writes date-scoped output under `evals/results/agent-matrix/`                              |
| Agent matrix dry run  | `npm run ci:eval:agent:matrix:dryrun`                      | No model invocation; writes a dry-run matrix summary                                                                    |
| Changed-agent matrix  | `npm run ci:eval:agent:changed`                            | Requires a suitable git comparison base and model access                                                                |

PR-tier equivalence results can be advisory while nightly results can be
authoritative. Read the lane's generated JSON verdict and the hosted workflow
status together. Do not infer a hosted CI policy from a direct local invocation.

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
