---
applyTo: '**/bicep/**'
description: 'Instructions for Bicep infrastructure as code implementation - Brought to you by microsoft/hve-core'
maturity: stable
---
# Bicep Instructions

These instructions define conventions for Bicep Infrastructure as Code (IaC) development in this codebase. Bicep files deploy Azure resources declaratively through ARM templates.

> [!NOTE]
> These instructions target Bicep 0.36+ and include generally available features through January 2026. The `providers` keyword is deprecated; use `extension` instead.

## MCP Tools

Bicep MCP tools provide schema information and best practices:

<!-- <reference-mcp-tools> -->
| Tool | Purpose | Parameters |
|------|---------|------------|
| `mcp_bicep_experim_get_az_resource_type_schema` | Retrieves the schema for a specific Azure resource type and API version | `azResourceType`, `apiVersion` (both required) |
| `mcp_bicep_experim_list_az_resource_types_for_provider` | Lists all available resource types for a provider namespace | `providerNamespace` (required) |
| `mcp_bicep_experim_get_bicep_best_practices` | Returns current Bicep authoring best practices | None |
<!-- </reference-mcp-tools> -->

## Project Structure

Organize Bicep files in a dedicated folder (e.g., `infra/`, `deploy/`, or environment-specific names):

<!-- <example-project-structure> -->
```text
main.bicep                    # Main orchestration
main.bicepparam               # Parameter values
types.bicep                   # Shared type definitions
README.md                     # Documentation
modules/                      # Reusable sub-modules
  networking.bicep
  storage.bicep
  compute.bicep
```
<!-- </example-project-structure> -->

File organization:

* `main.bicep` - Primary resource definitions and orchestration
* `types.bicep` - Shared type definitions and default values
* `modules/` - Reusable sub-modules for logical grouping

## Coding Standards

### File and Naming

* File and folder names: `kebab-case`
* Parameters: `camelCase`
* Types: `PascalCase`
* Metadata information appears at the top of each file
* Hardcoded values for resource names, locations, or other configurable items are not permitted

### Documentation and Comments

Every parameter and type includes a `@description()` decorator:

* Descriptions are short sentences ending with a period
* Non-obvious behaviors are explained: `'The description. (Updates a something not obvious when set)'`

Section headers use `/* */` comment blocks with whitespace for visual separation.

### Parameters and Types

<!-- <conventions-parameters> -->
Parameter conventions:

* Define related parameter types in `types.bicep`
* Use `??` (null coalescing) and `.?` (safe dereference) instead of ternary operators with null checks
* Organize parameters by functional grouping, then alphabetically within groups

Functional groupings organize parameters by their purpose:

| Group | Description | Examples |
| ----- | ----------- | -------- |
| Identity | Authentication and authorization | Managed identity names, RBAC assignments |
| Networking | Network connectivity and security | VNet names, subnet configurations, private endpoints |
| Storage | Data persistence | Storage account settings, container names |
| Monitoring | Observability and diagnostics | Log Analytics workspace, diagnostic settings |
| Compute | Processing resources | VM sizes, instance counts, scaling rules |
| Security | Encryption and secrets | Key Vault names, encryption settings |

* Boolean parameters start with `should` or `is`
* Required parameters have no defaults
* Empty string defaults are not permitted; use `null` instead
* Sensitive parameters include `@secure()`

For existing resources, prefer name parameters over resource IDs:

```bicep
param identityName string?
resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = if (!empty(identityName)) {
  name: identityName!
}
```
<!-- </conventions-parameters> -->

### Resource Naming

Resource names follow [Azure naming conventions](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming):

<!-- <conventions-resource-naming> -->
| Pattern | Example |
|---------|---------|
| Hyphens allowed | `{abbrev}-${common.resourcePrefix}-{optional}-${common.environment}-${common.instance}` |
| No hyphens | `{abbrev}${common.resourcePrefix}{optional}${common.environment}${common.instance}` |
| Length restricted | `'{abbrev}${uniqueString(common.resourcePrefix, {optional}, common.environment, common.instance)}'` |
<!-- </conventions-resource-naming> -->

### Outputs

* Every output includes a meaningful `@description()`
* Conditional resources require conditional output expressions
* Nullable outputs use the `?` type modifier: `output id string? = condition ? resource.id : null`

### Resource Scoping

* Default `targetScope` is `'resourceGroup'`; use `'subscription'` or `'managementGroup'` for cross-resource-group or policy deployments
* Use symbolic references for `scope:` (not ID strings): `scope: resourceGroup('networking-rg')`
* Existing resources use `existing =` syntax
* Cross-resource-group deployments use sub-modules with `scope:` property

## Module Conventions

| Aspect | Main Module | Sub-Module |
| ------ | ----------- | ---------- |
| Location | `bicep/main.bicep` | `bicep/modules/{name}.bicep` |
| Parameters | Include defaults when sensible | No defaults (parent provides all values) |
| Resources | Defined in `main.bicep` | Scoped to specific functionality |
| References | Orchestrates sub-modules | Cannot reference other sub-modules directly |
| Lookups | Receive resource names for `existing` lookups (not IDs) | Inherit scope from parent |

## Type System

### Shared Types

Types define configuration with `@export()` for reuse across modules:

<!-- <example-types> -->
```bicep
@export()
@description('Common deployment configuration.')
type DeploymentConfig = {
  @description('Resource name prefix.')
  prefix: string

  @description('Azure region for resources.')
  location: string

  @description('Environment: dev, test, or prod.')
  environment: 'dev' | 'test' | 'prod'
}

@export()
var deploymentDefaults = {
  prefix: 'myapp'
  location: 'eastus2'
  environment: 'dev'
}
```
<!-- </example-types> -->

Type conventions:

* All types and default values include `@export()` and `@description()`
* Sensitive values include `@secure()`
* Type literals (e.g., `'dev' | 'test' | 'prod'`) constrain parameters with known valid values
* Use `@sealed()` to prevent extra properties on configuration types (strict enforcement)
* Use `@discriminator('propertyName')` for type-safe unions with multiple variants (e.g., `@discriminator('type') type pet = cat | dog`)
* Prefer `resourceInput<>` and `resourceOutput<>` over open `object` types for resource configurations

### Resource-Derived Types

Resource-derived types provide compile-time validation for resource inputs and outputs:

<!-- <example-resource-derived-types> -->
```bicep
@description('Storage account input configuration.')
type storageAccountInput = resourceInput<'Microsoft.Storage/storageAccounts@2023-05-01'>

@description('Storage account output properties.')
type storageAccountOutput = resourceOutput<'Microsoft.Storage/storageAccounts@2023-05-01'>

@description('Accepts any valid storage account configuration.')
param storageConfig storageAccountInput
```
<!-- </example-resource-derived-types> -->

Resource-derived types validate property names and types against the resource schema at compile time.

## User-Defined Functions

<!-- <example-user-defined-functions> -->
```bicep
@export()
@description('Generates a storage account name within the 3-24 character Azure limit.')
func getStorageAccountName(prefix string, environment string, instance string) string =>
  take('st${prefix}${environment}${instance}', 24)
```
<!-- </example-user-defined-functions> -->

Function conventions:

* All exported functions include `@export()` and `@description()`
* Place shared functions in a `functions.bicep` file within the module
* Use lambda syntax (`=>`) for single-expression functions
* Function names follow `camelCase` naming
* Import shared functions using standard syntax: `import { functionName } from 'shared/functions.bicep'`

## Built-in Functions

Bicep 0.36+ includes these additional built-in functions:

| Function | Purpose | Example |
| -------- | ------- | ------- |
| `parseUri(uri)` | Parses URI into components (scheme, host, port, path, query) | `parseUri('https://example.com/path?q=1').host` |
| `buildUri(scheme, host, path?, port?, query?)` | Constructs URI from components | `buildUri('https', 'api.example.com', '/v1', 443)` |
| `loadDirectoryFileInfo(path)` | Gets file metadata from directory at compile time | `loadDirectoryFileInfo('./configs/')` |
| `deployer().userPrincipalName` | Gets the deploying user's principal | `deployer().userPrincipalName` |

## Resource Decorators

Use `@onlyIfNotExists()` for idempotent deployments where existing resources must be preserved. The decorator creates resources only when they do not already exist.

## File Organization

Every Bicep file includes metadata at the top:

```bicep
metadata name = 'Module Name'
metadata description = 'Description of what this module deploys and how it works.'
```

Section order with `/* */` comment headers:

1. Metadata and imports
2. Common parameters
3. Module-specific parameters (grouped by functionality)
4. Variables (when needed)
5. Resources
6. Modules
7. Outputs

## API Versioning

| Guideline | Details |
| --------- | ------- |
| Discover versions | Use `mcp_bicep_experim_list_az_resource_types_for_provider` and `get_az_resource_type_schema` |
| Version consistency | Identical resource types within a file use the same API version |
| New resources | Use the latest stable API version |
| Existing resources | Retain API version unless significant changes warrant upgrade |

## Best Practices

<!-- <reference-best-practices> -->
Best practices retrieved via `mcp_bicep_experim_get_bicep_best_practices`:

| Category | Practice |
| -------- | -------- |
| Modules | Omit `name` field for `module` statements (auto-generated GUID prevents concurrency issues) |
| Parameters | Group logically related values into single `param`/`output` with user-defined types |
| Params Files | Use `.bicepparam` files with variables and expressions instead of `.json` |
| Resources | Use `parent` property instead of `/` in child resource names |
| Resources | Add `existing` resources for parents when defining child resources without parent present |
| Resources | Diagnostic codes `BCP036`, `BCP037`, `BCP081` may indicate hallucinated types/properties |
| Types | Avoid open types (`array`, `object`); prefer user-defined types |
| Types | Use typed variables: `var foo string = 'value'` |
| Syntax | Prefer `.?` with `??` over `!` or verbose ternary: `a.?b ?? c` |

Parameters Files (`.bicepparam`) support variables and expressions:

<!-- <example-bicepparam> -->
```bicep
using 'main.bicep'

var rgPrefix = 'myapp'
param resourceGroupName = '${rgPrefix}-rg'
param tags = { environment: 'prod', costCenter: 'engineering' }
param location = 'eastus2'
```
<!-- </example-bicepparam> -->
<!-- </reference-best-practices> -->

## Experimental Features

> [!CAUTION]
> Experimental features require explicit opt-in via `bicepconfig.json` and may change or be removed in future releases.

| Feature | Config Key | Syntax Example |
| ------- | ---------- | -------------- |
| Testing Framework | `testFramework` | `test storageTest 'tests/storage.tests.bicep' = { params: { location: 'eastus' } }` |
| Assertions | `assertions` | `assert locationValid = location != 'centralus'` |
| Parameter Validation | `userDefinedConstraints` | `@validate(length(value) >= 3 && length(value) <= 24) param storageName string` |

Enable features in `bicepconfig.json`: `{ "experimentalFeaturesEnabled": { "featureName": true } }`

## Validation

* Search codebase for existing Bicep patterns before implementing
* Use MCP tools or Microsoft docs (`learn.microsoft.com/azure/templates/{provider}/{type}`) for schema reference
* Run `az bicep build` and address all diagnostic warnings and errors before committing
