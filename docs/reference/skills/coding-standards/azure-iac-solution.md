---
title: azure-iac-solution
description: "Design, generate, and review Azure infrastructure as code with Azure Verified Modules (AVM) as the default implementation path. Covers intent extraction, AVM catalogue discovery, module selection evidence, exception handling, and review of Bicep and Terraform solutions. Use when a request involves designing or implementing Azure infrastructure, converting architecture into Bicep or Terraform, reviewing Azure IaC, or modernizing raw resources into reusable modules."
sidebar_position: 1
author: Microsoft
ms.date: 2026-09-10
ms.topic: reference
keywords:
  - skill
  - coding-standards
  - azure-iac-solution
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                |
|-------------|--------------------------------------------------------------------------------------|
| Kind        | skill                                                                                |
| Source      | `.github/skills/coding-standards/azure-iac-solution`                                 |
| Invocation  | Invoked directly as `/azure-iac-solution`, or loaded on demand by referencing agents |
| Interactive | No                                                                                   |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Design, generate, and review Azure infrastructure as code with Azure Verified Modules (AVM) as the default implementation path. Covers intent extraction, AVM catalogue discovery, module selection evidence, exception handling, and review of Bicep and Terraform solutions. Use when a request involves designing or implementing Azure infrastructure, converting architecture into Bicep or Terraform, reviewing Azure IaC, or modernizing raw resources into reusable modules.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `azure-iac-solution` when the task is deciding *which* modules implement an Azure architecture, rather than how to write Bicep or Terraform syntax. It owns AVM catalogue discovery, the pattern-resource-native sourcing hierarchy, lifecycle-status and version-pinning rules, the module decision record, and the review checklist for module reuse.

Reach for a different asset when:

* The work is language mechanics only (file layout, expressions, validation commands). The `bicep` and `terraform` instructions files cover that and defer module sourcing to this skill.
* The infrastructure targets AWS, GCP, or on-premises. This skill's policy is Azure-specific.
* No Azure infrastructure is being created, reviewed, or modernized.

## Example usage

```text
/azure-iac-solution Design a private Container Apps environment with central diagnostics and produce the Terraform for it.
```

The skill extracts intent and non-functional requirements, resolves candidates from the AVM module index and registry, and emits a module decision record for confirmation before writing code:

```yaml
capabilities:
  - name: container-app-environment
    requirement: Private application hosting with central diagnostics
    implementation:
      kind: avm-resource-module
      source: Azure/avm-res-app-managedenvironment/azurerm
      version: "<resolved-from-registry>"
      status: Available
    rationale: Existing AVM module covers the required resource and extensions
```

Once the record is confirmed it generates Terraform or Bicep that composes the selected modules, followed by validation and a report of residual risks, preview dependencies, and recorded exceptions.
