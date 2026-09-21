---
title: Enterprise Artifact Hub
description: Configure HVE Core to download tools, modules, and packages from internal mirrors or artifact proxies
author: Microsoft
ms.date: 2026-08-13
ms.topic: how-to
keywords:
  - enterprise
  - artifact hub
  - mirror
  - proxy
  - package registry
  - npm
  - uv
  - environment variables
estimated_reading_time: 5
---

## Overview

Organizations behind firewalls or air-gapped networks often cannot reach public
services such as GitHub, PowerShell Gallery, npm, or PyPI. HVE Core uses `HVE_*`
environment variables to redirect release downloads, PowerShell module installs,
GitHub API calls, and the DevContainer base image. Standard package manager
variables redirect npm, pip-compatible, and uv package installs.

Each setting has a public default except the optional custom PowerShell Gallery
source URL. Public GitHub environments therefore require no configuration.

## Environment Variables

The table lists the supported enterprise variables and their defaults.

| Variable                   | Default                                        | Purpose                                                  |
|----------------------------|------------------------------------------------|----------------------------------------------------------|
| `HVE_GITHUB_RELEASES_URL`  | `https://github.com`                           | Base URL for release binary downloads                    |
| `HVE_GITHUB_API_URL`       | `https://api.github.com`                       | GitHub API base URL for security scripts                 |
| `HVE_PSGALLERY_REPOSITORY` | `PSGallery`                                    | PowerShell repository name for module installs           |
| `HVE_PSGALLERY_SOURCE_URL` | _(empty)_                                      | Source URL for custom PowerShell repository registration |
| `HVE_DEVCONTAINER_IMAGE`   | `mcr.microsoft.com/devcontainers/base:2-jammy` | Base image used to build the DevContainer                |
| `NPM_CONFIG_REGISTRY`      | `https://registry.npmjs.org/`                  | Registry used by npm commands                            |
| `PIP_INDEX_URL`            | `https://pypi.org/simple/`                     | Index used by pip-compatible commands                    |
| `UV_DEFAULT_INDEX`         | `https://pypi.org/simple`                      | Index used by uv project commands such as `uv sync`      |

The three package index variables are standard tool settings rather than
HVE-specific settings. The DevContainer reads them from the host, passes them as
Docker build arguments, and persists them under the same names inside the
container.

Affected files per variable:

* `HVE_GITHUB_RELEASES_URL` :
  `.devcontainer/scripts/on-create.sh`,
  `.github/workflows/copilot-setup-steps.yml`
* `HVE_GITHUB_API_URL` :
  PowerShell scripts under `scripts/security/`
* `HVE_PSGALLERY_REPOSITORY` and `HVE_PSGALLERY_SOURCE_URL` :
  `.devcontainer/scripts/on-create.sh`,
  `.github/workflows/copilot-setup-steps.yml`
* `HVE_DEVCONTAINER_IMAGE` :
  `.devcontainer/devcontainer.json`,
  `.devcontainer/Dockerfile`
* `NPM_CONFIG_REGISTRY`, `PIP_INDEX_URL`, and `UV_DEFAULT_INDEX` :
  `.devcontainer/devcontainer.json`,
  `.devcontainer/Dockerfile`

## DevContainer Configuration

Set the variables on your host machine before building the DevContainer. The
`.devcontainer/devcontainer.json` file maps `HVE_DEVCONTAINER_IMAGE` to
`build.args.BASE_IMAGE`. The `.devcontainer/Dockerfile` consumes that argument
in its `FROM` instruction.

The npm, pip, and uv settings map to same-named Docker build arguments and
environment variables. The remaining four `HVE_*` settings enter the container
through `remoteEnv`. No repository changes are required.

Export the variables in your shell profile:

```bash
export HVE_GITHUB_RELEASES_URL="https://artifactory.corp.example.com/github-releases"
export HVE_GITHUB_API_URL="https://github.corp.example.com/api/v3"
export HVE_PSGALLERY_REPOSITORY="InternalGallery"
export HVE_PSGALLERY_SOURCE_URL="https://nuget.corp.example.com/v2"
export HVE_DEVCONTAINER_IMAGE="registry.corp.example.com/devcontainers/base:2-jammy"
export NPM_CONFIG_REGISTRY="https://npm.corp.example.com/"
export PIP_INDEX_URL="https://pypi.corp.example.com/simple/"
export UV_DEFAULT_INDEX="https://pypi.corp.example.com/simple/"
```

Add these lines to `~/.bashrc`, `~/.zshrc`, or a `.env` file sourced by your
shell so they persist across sessions.

> [!CAUTION]
> Use repository and index URLs that do not contain credentials. Docker build
> arguments and environment variables can persist in image metadata and the
> resulting container. Configure authentication separately through your
> organization's approved credential mechanism.

## GitHub Copilot Coding Agent

The `copilot-setup-steps.yml` workflow reads variables from GitHub repository or
organization settings. Navigate to **Settings > Secrets and variables > Actions >
Variables** and create entries for:

* `HVE_GITHUB_RELEASES_URL`
* `HVE_PSGALLERY_REPOSITORY`
* `HVE_PSGALLERY_SOURCE_URL`

The workflow references these values as `vars.HVE_GITHUB_RELEASES_URL`,
`vars.HVE_PSGALLERY_REPOSITORY`, and `vars.HVE_PSGALLERY_SOURCE_URL`. When a
variable is absent, the workflow falls back to the public default.

The package index and base image build variables apply to the DevContainer.
The Copilot setup workflow does not read them.

## Security Scripts

`HVE_GITHUB_API_URL` is consumed by the shared security helper module
`scripts/security/Modules/SecurityHelpers.psm1` and the security automation that depends
on it:

* `Test-SHAStaleness.ps1`
* `Update-ActionSHAPinning.ps1`
* `Test-DependencyPinning.ps1`
* `SecurityHelpers.psm1`

These scripts call the GitHub API for SHA resolution, staleness checks, and
token validation. In GitHub Enterprise Server environments, set
`HVE_GITHUB_API_URL` to your instance's API endpoint (for example,
`https://github.corp.example.com/api/v3`).

## Other Enterprise Configuration

Some tools have their own configuration mechanisms that do not require HVE Core
code changes but are relevant for a complete enterprise artifact hub setup.

### npm

The DevContainer reads `NPM_CONFIG_REGISTRY` from the host at build time. The
resulting environment setting overrides the canonical public registry in the
tracked `.npmrc` for npm commands inside the container.

Keep internal registry URLs out of the repository. For npm commands outside the
DevContainer and for Codespaces, follow
[Install behind a restricted network](../contributing/validation#install-behind-a-restricted-network).

### pip and uv

HVE Core installs Python project dependencies with `uv sync`. Set
`UV_DEFAULT_INDEX` to redirect those installs. `PIP_INDEX_URL` controls pip and uv's
pip-compatible interface; it does not redirect `uv sync`. Set both variables
when your workflows use both command families.

Write `UV_DEFAULT_INDEX` with the exact index URL recorded in the tracked
`uv.lock` files. uv treats `https://pypi.org/simple` and
`https://pypi.org/simple/` as different lock inputs, so a trailing-slash
mismatch makes `uv sync --locked` fail even when the resolved dependencies are
identical.

Keep internal indexes out of tracked `pyproject.toml` and `uv.lock` files so
committed dependency metadata remains reproducible for public contributors.

### Container Images

Set `HVE_DEVCONTAINER_IMAGE` to point at a mirrored base image in your internal
container registry. The `.devcontainer/devcontainer.json`
`build.args.BASE_IMAGE` setting reads this variable and passes it to the
Dockerfile. It falls back to the default MCR image when unset.

```bash
export HVE_DEVCONTAINER_IMAGE="registry.corp.example.com/devcontainers/base:2-jammy"
```

## Verification

After configuring the variables, confirm the setup works:

1. Rebuild the DevContainer and verify that release downloads, npm setup, and
  uv environment synchronization complete through the configured services.
2. Run `npm config get registry` inside the container and confirm it returns the
  internal npm registry.
3. Run `uv sync --frozen` from a skill directory and confirm package downloads
  use the internal Python index.
4. Run the required security scripts and confirm GitHub API calls complete
  without connection errors.
5. When `HVE_PSGALLERY_SOURCE_URL` is set, check that `Register-PSRepository`
  succeeds and PowerShell modules install from the custom repository.

🤖 _Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers._
