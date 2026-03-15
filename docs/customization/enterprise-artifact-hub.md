---
title: Enterprise Artifact Hub
description: Configure HVE Core to download tools and modules from internal mirrors or artifact proxies
author: Microsoft
ms.date: 2026-03-13
ms.topic: how-to
keywords:
  - enterprise
  - artifact hub
  - mirror
  - proxy
  - environment variables
estimated_reading_time: 5
---

## Overview

Organizations behind firewalls or air-gapped networks often cannot reach public
registries such as `github.com` or `PSGallery`. HVE Core uses `HVE_*`
environment variables to redirect tool downloads, PowerShell module installs, and
GitHub API calls to internal mirrors or artifact proxies. When these variables
are unset, every download falls back to its public default, so no configuration
is needed for public GitHub environments.

## Environment Variables

The table below lists every `HVE_*` variable, its default value, and which files
read it.

| Variable                   | Default                                        | Description                                              |
|----------------------------|------------------------------------------------|----------------------------------------------------------|
| `HVE_GITHUB_RELEASES_URL`  | `https://github.com`                           | Base URL for tool downloads (actionlint, gitleaks, uv)   |
| `HVE_GITHUB_API_URL`       | `https://api.github.com`                       | GitHub API base URL for security scripts                 |
| `HVE_PSGALLERY_REPOSITORY` | `PSGallery`                                    | PowerShell repository name for module installs           |
| `HVE_PSGALLERY_SOURCE_URL` | _(empty)_                                      | Source URL for custom PowerShell repository registration |
| `HVE_DEVCONTAINER_IMAGE`   | `mcr.microsoft.com/devcontainers/base:2-jammy` | Base container image for DevContainer builds             |

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
  `.devcontainer/devcontainer.json`

## DevContainer Configuration

Set the variables on your host machine before opening the DevContainer. The
`.devcontainer/devcontainer.json` file uses `HVE_DEVCONTAINER_IMAGE` in the
`image` field to select the base container image, and forwards the remaining
four variables into the container through its `remoteEnv` block. No changes to
the DevContainer configuration are required.

Export the variables in your shell profile:

```bash
export HVE_GITHUB_RELEASES_URL="https://artifactory.corp.example.com/github-releases"
export HVE_GITHUB_API_URL="https://github.corp.example.com/api/v3"
export HVE_PSGALLERY_REPOSITORY="InternalGallery"
export HVE_PSGALLERY_SOURCE_URL="https://nuget.corp.example.com/v2"
export HVE_DEVCONTAINER_IMAGE="registry.corp.example.com/devcontainers/base:2-jammy"
```

Add these lines to `~/.bashrc`, `~/.zshrc`, or a `.env` file sourced by your
shell so they persist across sessions.

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

## Security Scripts

`HVE_GITHUB_API_URL` is used by the security analysis scripts under
`scripts/security/`:

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

HVE Core respects the standard `.npmrc` registry configuration. Set the
registry in a project-level or user-level `.npmrc` file:

```text
registry=https://npm.corp.example.com/
```

### pip and uv

HVE Core respects the standard `UV_INDEX_URL` environment variable. Set it
in your shell profile or add an `[[tool.uv.index]]` entry in `pyproject.toml`:

```bash
export UV_INDEX_URL="https://pypi.corp.example.com/simple"
```

### Container Images

Set `HVE_DEVCONTAINER_IMAGE` to point at a mirrored base image in your internal
container registry. The `.devcontainer/devcontainer.json` `image` field reads
this variable at build time and falls back to the default MCR image when unset.

```bash
export HVE_DEVCONTAINER_IMAGE="registry.corp.example.com/devcontainers/base:2-jammy"
```

## Verification

After configuring the variables, confirm the setup works:

1. Rebuild the DevContainer and verify that tool downloads (actionlint, gitleaks,
   uv) complete from the configured URLs.
2. Run `npm run lint:ps` and confirm the security scripts complete without API
   errors.
3. When `HVE_PSGALLERY_SOURCE_URL` is set, check that `Register-PSRepository`
   succeeds and PowerShell modules install from the custom repository.

🤖 _Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers._
