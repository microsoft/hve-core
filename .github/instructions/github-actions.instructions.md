---
description: "Instructions for GitHub Actions workflow files"
applyTo: "**/.github/workflows/*.yml"
maturity: stable
---

# GitHub Actions Instructions

These instructions define required conventions and security requirements for GitHub Actions workflows in this repository.

## Dependency Pinning

All third-party GitHub Actions MUST be pinned to a full commit SHA.

Version tags MUST NOT be used as the reference. A semantic version MAY be included as a trailing comment for readability.

Local reusable workflows referenced via relative paths are excluded.

## Permissions

Workflows MUST declare explicit permissions.

The default permission set is `contents: read`.  
Additional permissions MUST be granted at the job level and only when required for a specific capability.

Global permission elevation (for example, `write-all`) MUST NOT be used.

## Credentials

Workflows MUST NOT persist GitHub credentials by default.

Credential persistence MUST be enabled only when explicitly required for a specific capability.  
Secrets and tokens MUST be granted explicitly and scoped to the minimum required permissions.

## Runners

Workflows run on the `ubuntu-latest` runner.

## Workflow Structure

Reusable workflows are enabled via `workflow_call` and SHOULD be preferred over duplicated logic.

Each workflow MUST have a single, well-defined responsibility.

## Security and Validation

All workflows MUST pass repository validation checks, including:

- `actionlint`
- Dependency pinning validation
- SHA staleness checks

Secrets MUST NOT be exposed in logs.  
Authentication SHOULD use the built-in `GITHUB_TOKEN` or OIDC where applicable.
