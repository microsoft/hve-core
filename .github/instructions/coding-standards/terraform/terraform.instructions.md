---
applyTo: '**/*.tf, **/*.tfvars, **/terraform/**'
description: 'Terraform infrastructure-as-code authoring conventions'
---
# Terraform Instructions

These instructions define conventions for Terraform Infrastructure as Code (IaC) development in this codebase. Terraform files deploy cloud resources declaratively through the HashiCorp Configuration Language (HCL).

> [!NOTE]
> These instructions target Terraform 1.6+ and include features through January 2026. For Azure deployments, use AzureRM provider 4.0+ or AzAPI for latest resource support.

## Project Structure

The root module composes registry modules directly. Local modules exist only for solution-specific reuse (see Azure Module Sourcing):

```text
terraform/
├── main.tf                       # Registry module calls and remaining direct resources
├── variables.tf
├── outputs.tf
├── versions.tf
├── backend.tf
├── modules/                      # Local modules, only where reuse justifies them
│   └── workload/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── versions.tf
└── README.md
```

## File Organization

Every Terraform configuration follows a consistent file structure:

| File                   | Purpose                                              |
|------------------------|------------------------------------------------------|
| `main.tf`              | Primary resource definitions and module calls        |
| `variables.tf`         | Input variable declarations                          |
| `outputs.tf`           | Output value declarations                            |
| `versions.tf`          | Required providers and Terraform version constraints |
| `backend.tf`           | State backend configuration (root modules only)      |
| `locals.tf`, `data.tf` | Local values and data sources (when numerous)        |

Within each file, order content as: terraform/provider blocks, variables, locals, data sources, resources, module calls, outputs.

## Naming Conventions

File and folder names use `kebab-case` (e.g., `storage-account.tf`, `modules/web-app/`).

Resource names, variable names, local values, and output names use `snake_case` (e.g., `azurerm_storage_account.data_storage`, `resource_group_name`, `local.computed_name`).

### Resource and Data Source Logical Names

Logical names (the label after the resource or data source type) follow these patterns:

* Singleton of a type: use `"this"` (e.g., `azurerm_resource_group.this`, `data.azurerm_client_config.this`). The Terraform community has coalesced around `"this"` as the dominant symbolic name for the sole resource or data source of a given type within a module.
* Multiple instances with distinct purposes: use descriptive names (e.g., `azurerm_storage_account.data`, `azurerm_storage_account.logs`)
* Dynamic instances: use `for_each` with descriptive keys from `each.key`

```hcl
resource "azurerm_storage_account" "this" {
  // resource parameters here
}

data "azurerm_client_config" "this" {}
```

## Variables and Outputs

### Variable Declarations

Variable conventions:

* Every variable includes a `description` without trailing periods
* Boolean variables start with `should_` or `is_` (e.g., `should_enable_https`, `is_production`)
* Sensitive variables include `sensitive = true`
* Required variables omit the `default` attribute; optional variables include sensible defaults
* Use `null` for optional defaults instead of empty strings
* Add `validation` blocks for variables with known domain constraints, such as enumerations, name length limits, or allowed SKU values

```hcl
variable "storage_account_tier" {
  description = "Performance tier for the storage account"
  type        = string
  default     = "Standard"
  sensitive   = false  // Set true for secrets
}
```

### Output Declarations

Every output includes a meaningful `description` without trailing periods. Sensitive outputs include `sensitive = true`. Conditional resources require conditional output expressions.

```hcl
output "storage_account_id" {
  description = "Resource ID of the deployed storage account"
  value       = var.should_deploy ? azurerm_storage_account.this[0].id : null
  sensitive   = true  // Set true for secrets
}
```

## Comment Style

Use `//` for single-line and `/* */` for multi-line comments. Do not use `#` for comments in this codebase.

Section headers use visual separators for organization:

```hcl
// =====================================================
// Networking Resources
// =====================================================
```

## Module Conventions

Child modules in `modules/{name}/` inherit providers and state from the calling root module.

### Azure Module Sourcing

Azure infrastructure composes [Azure Verified Modules](https://aka.ms/avm) before authoring `azurerm` or `azapi` resources directly. The `azure-iac-solution` skill owns the sourcing hierarchy, discovery procedure, and exception record; load it for any Azure implementation or review. In Terraform:

* AVM modules live in the `Azure` registry namespace as `Azure/avm-{ptn,res,utl}-*/azurerm`.
* Resolve names and versions from the registry during the session, never from memory.
* AVM Terraform modules are pre-1.0, so pin to the patch series (`version = "~> 0.10.0"`) or an exact version. A `~> 0.10` constraint admits breaking minor releases.

```hcl
module "storage_account" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "~> 0.10.0"

  name                = var.storage_account_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
}
```

### Module Calls

Follow AVM [TFNFR7](https://azure.github.io/Azure-Verified-Modules/spec/TFNFR7/): use `count = var.condition ? 1 : 0` for conditional creation of a single instance, and `for_each` with a map keyed by stable identifiers for multiple instances. Never use `count` over a list, because removing an element re-addresses the remaining instances.

```hcl
module "workload" {
  source   = "../../modules/workload"
  for_each = var.workload_configurations

  name                = each.key
  resource_group_name = azurerm_resource_group.this.name
  configuration       = each.value
}
```

## Expression Functions

### coalesce()

Returns the first non-null and non-empty value. Prefer over ternary operators for default value selection:

```hcl
location = coalesce(var.override_location, var.primary_location, "eastus")
```

Note: `coalesce()` treats empty strings as falsy. Use ternary when empty string is a valid value.

### try()

Returns the value of an expression or a fallback when the expression fails. Prefer over ternary operators for optional attribute access:

```hcl
endpoint = try(var.network.private_endpoint.ip, null)
database_id = try(module.database[0].id, null)
subnet_id = try(each.value.subnet_id, var.default_subnet_id)
```

### Combining coalesce() and try()

Combine these functions for complex optional configuration patterns:

```hcl
// try() inside coalesce(): safe attribute access with simple fallback
nsg_name = coalesce(try(var.network_security_group.name, null), "${var.subnet_name}-nsg")

// coalesce() inside try(): computed default that might fail (Azure Verified Modules pattern)
nsg_name = try(coalesce(var.new_nsg.name, "${var.subnet_name}-nsg"), "${var.subnet_name}-nsg")
```

### When to Use Ternary Operators

Ternary operators remain appropriate for boolean conditions (`var.is_production ? "Premium" : "Standard"`), conditional counts (`count = var.enable_feature ? 1 : 0`), and complex multi-factor logic.

## Data Sources and Deferred Lookups

Use standard Terraform data source syntax for existing resource lookups (e.g., `data "azurerm_resource_group"`, `data "azurerm_client_config"`). Apply the same logical-name convention as resources: a singleton data source uses `"this"`, while multiple data sources of the same type use descriptive names or `for_each` keys.

### Avoid Imperative Lookups

Do not use `terraform_data` with `local-exec` and the Azure CLI to read Azure state. Imperative lookups bypass state tracking, credential handling, and plan-time validation. Use a provider data source, or `azapi_resource` and `azapi_resource_action` when `azurerm` has no data source:

```hcl
data "azapi_resource" "storage_account" {
  type      = "Microsoft.Storage/storageAccounts@2023-05-01"
  name      = var.storage_account_name
  parent_id = azurerm_resource_group.this.id
}
```

## Resource Naming

Resource names follow [Azure naming conventions](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming):

* Hyphens allowed: `${var.prefix}-{abbrev}-${var.environment}-${var.instance}`
* No hyphens: `${var.prefix}{abbrev}${var.environment}${var.instance}`
* Length restricted: `substr("${var.prefix}{abbrev}${random_id.suffix.hex}", 0, 24)`

## Provider Configuration

### Required Providers Block

Every module includes a `versions.tf` with required providers:

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = ">= 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6"
    }
  }
}
```

### Provider Features

Root modules configure provider features explicitly:

```hcl
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
}
```

## State Management

### Backend Configuration

Root modules include explicit backend configuration. Keep environment-specific values out of the committed configuration: supply them at init time with `-backend-config` flags, partial configuration files, or environment variables.

```hcl
terraform {
  backend "azurerm" {}
}
```

```bash
terraform init -backend-config=backend.dev.hcl
```

### State Management Practices

State files can be stored locally or in remote backends. Do not commit state files to the repository. When using remote backends, enable state locking and protect sensitive values through backend encryption.

## Validation and Formatting

### Pre-commit Checks

Run `terraform fmt -recursive`, `terraform validate`, and `terraform plan` before commits.

### Linting Tools

Use `terraform fmt` for formatting, `terraform validate` for configuration validation, `tflint` for extended linting, and `trivy config` or `checkov` for security scanning (`tfsec` is archived and folded into Trivy). Record scan suppressions inline with a rationale and a re-review trigger.

## Lifecycle Management

Use lifecycle blocks for resources requiring special handling:

```hcl
resource "azurerm_storage_account" "this" {
  // ...

  lifecycle {
    prevent_destroy       = true // Protect critical resources
    create_before_destroy = true // Zero-downtime replacement
  }
}
```

Treat `ignore_changes` as a deliberate governance decision, not a convenience. Ignoring `tags` can conceal ownership, cost-center, or policy drift applied outside Terraform. When `ignore_changes` is required, scope it to the specific attributes an external system owns and record the owning system in a comment.

## Documentation Requirements

Every Terraform module includes a README.md documenting module purpose, required and optional inputs, outputs, usage examples, and prerequisites.
