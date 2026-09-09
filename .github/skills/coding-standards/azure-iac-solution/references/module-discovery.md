---
title: Module Discovery
description: Procedure for resolving AVM module names, lifecycle status, and versions from the module index and registries at execution time
author: microsoft/hve-core
ms.date: 2026-09-10
ms.topic: reference
keywords:
  - azure
  - avm
  - bicep
  - terraform
  - coding-standards
estimated_reading_time: 4
---

# Module Discovery

Every module reference in generated code traces back to a lookup performed during the
session. The steps below are the only sanctioned sources.

## 1. Find candidates in the module index

AVM publishes one CSV per language and class. Fetch the relevant index and filter on the
resource type or capability:

```text
https://raw.githubusercontent.com/Azure/Azure-Verified-Modules/main/docs/static/module-indexes/<Index>.csv
```

| Index                      | Class    | Language  |
|----------------------------|----------|-----------|
| `TerraformPatternModules`  | Pattern  | Terraform |
| `TerraformResourceModules` | Resource | Terraform |
| `TerraformUtilityModules`  | Utility  | Terraform |
| `BicepPatternModules`      | Pattern  | Bicep     |
| `BicepResourceModules`     | Resource | Bicep     |
| `BicepUtilityModules`      | Utility  | Bicep     |

Match on `ProviderNamespace` and `ResourceType` (for example `Microsoft.Storage` and
`storageAccounts`), then read `ModuleName`, `ModuleStatus`, and `PublicRegistryReference`.

## 2. Filter on lifecycle status

| `ModuleStatus` | Action                                                                                 |
|----------------|----------------------------------------------------------------------------------------|
| `Available`    | Eligible for adoption                                                                  |
| `Proposed`     | Not published; treat the capability as tier 3 and note the pending module as follow-up |
| `Orphaned`     | No maintainer; report to the user before adopting                                      |
| `Deprecated`   | Do not adopt; if already in use, flag for migration                                    |

Roughly half of the Terraform pattern modules in the index are `Proposed`, so a name appearing
in the index is not evidence that the module exists in the registry.

## 3. Resolve the current version

Terraform:

```bash
curl -s https://registry.terraform.io/v1/modules/Azure/avm-res-storage-storageaccount/azurerm | jq -r .version
```

Bicep:

```bash
curl -s https://mcr.microsoft.com/v2/bicep/avm/res/storage/storage-account/tags/list \
  | jq -r '.tags | map(select(test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))) | sort_by(split(".") | map(tonumber)) | last'
```

Where Azure MCP tools are available, `azureterraform` (AVM module documentation and versions)
and `bicepschema` provide the same information without shelling out.

## 4. Record the evidence

Write the resolved `source`, `version`, and `status` into the module decision record with
the date the index was checked. A later reviewer re-runs steps 1 and 2 for every recorded
tier 3 exception: if `Available` coverage now exists, the follow-up is a migration work item,
not a permanent exception.
