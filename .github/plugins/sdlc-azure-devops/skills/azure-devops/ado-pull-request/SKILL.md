---
name: ado-pull-request
description: 'Prepare an Azure Repos pull request from local Git changes, or create it in a confirmed Azure DevOps repository with related work items and optional reviewers.'
argument-hint: '[prepare|create] [adoProject=...] [repository=...] [base=...] [draft=true|false]'
license: MIT
user-invocable: true
---

# Azure DevOps Pull Request

Use the [Azure Repos workflow](references/creation.md) for the branch comparison, PR description, work-item discovery, reviewer selection, and creation record. It lists the optional branch, draft, search, reviewer-selection, and presentation settings.

* `prepare` uses only local Git evidence. Follow phases 1 and 2, apply the [content sanitization and trust controls](../ado-backlog/references/operations.md#content-sanitization), and return the title, description, and local artifact path. Make no Azure DevOps call. Use this mode when write intent is unclear.
* `create` requires a project and repository. Run the workflow's Mandatory Preflight, then follow its discovery, approval, creation, and reporting phases. `noGates` changes presentation, not authorization. Leave the PR as a local proposal if the destination, guards, or required approvals are not established.

Return the Azure DevOps PR URL only after a successful create. Distinguish work items actually linked and reviewers actually added from proposals or failed operations. Updating or completing an existing PR is outside this workflow.
