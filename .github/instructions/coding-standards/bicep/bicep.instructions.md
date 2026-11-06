---
applyTo: '**/*.bicep, **/*.bicepparam, **/bicep/**'
description: 'Bicep infrastructure-as-code authoring conventions'
---
# Bicep Instructions

These instructions define conventions for Bicep Infrastructure as Code (IaC) development in this codebase. Bicep files deploy Azure resources declaratively through ARM templates.

> [!NOTE]
> These instructions target Bicep 0.36+ and include generally available features through January 2026. The `providers` keyword is deprecated; use `extension` instead.

## MCP Tools

The Bicep MCP server provides schema information, best practices, and compilation. Tool names changed in Bicep MCP 0.43.1 and 0.43.8; parameters are as of 0.48.1:

<!-- <reference-mcp-tools> -->
| Tool                             | Earlier name                          | Purpose                                                     | Parameters                                         |
|----------------------------------|---------------------------------------|-------------------------------------------------------------|----------------------------------------------------|
| `get_azure_resource_type_schema` | `get_az_resource_type_schema`         | Retrieves the schema for an Azure resource type             | `resourceType` (required), `apiVersion` (optional) |
| `list_azure_resource_types`      | `list_az_resource_types_for_provider` | Lists the resource types available for a provider namespace | `providerNamespace` (required)                     |
| `get_bicep_best_practices`       | `get_bicep_best_practices`            | Returns current Bicep authoring best practices              | None                                               |
| `build_bicep`                    | `get_bicep_file_diagnostics`          | Compiles a Bicep file and returns ARM JSON and diagnostics  | `filePath` (required, absolute path)               |
<!-- </reference-mcp-tools> -->

Before calling a Bicep MCP tool, check which names the host lists:

* Use the names the host exposes, including any prefix the client adds, such as `bicep-get_azure_resource_type_schema` or `mcp_bicep_get_azure_resource_type_schema`. Do not call a name the host does not list.
* Servers older than 0.43.1 expose only the earlier names, and their `get_az_resource_type_schema` requires both `azResourceType` and `apiVersion`.
* When `apiVersion` is omitted, the server chooses a default, which can be a preview version. Pass the version that [API Versioning](#api-versioning) selects.

See the [Bicep MCP server](https://learn.microsoft.com/azure/azure-resource-manager/bicep/bicep-mcp-server) documentation for setup.

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

| Group      | Description                       | Examples                                             |
|------------|-----------------------------------|------------------------------------------------------|
| Identity   | Authentication and authorization  | Managed identity names, RBAC assignments             |
| Networking | Network connectivity and security | VNet names, subnet configurations, private endpoints |
| Storage    | Data persistence                  | Storage account settings, container names            |
| Monitoring | Observability and diagnostics     | Log Analytics workspace, diagnostic settings         |
| Compute    | Processing resources              | VM sizes, instance counts, scaling rules             |
| Security   | Encryption and secrets            | Key Vault names, encryption settings                 |

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
| Pattern           | Example                                                                                             |
|-------------------|-----------------------------------------------------------------------------------------------------|
| Hyphens allowed   | `{abbrev}-${common.resourcePrefix}-{optional}-${common.environment}-${common.instance}`             |
| No hyphens        | `{abbrev}${common.resourcePrefix}{optional}${common.environment}${common.instance}`                 |
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

| Aspect     | Main Module                                             | Sub-Module                                  |
|------------|---------------------------------------------------------|---------------------------------------------|
| Location   | `main.bicep` at the Bicep folder root                   | `modules/{name}.bicep` in the same folder   |
| Parameters | Include defaults when sensible                          | No defaults (parent provides all values)    |
| Resources  | Defined in `main.bicep`                                 | Scoped to specific functionality            |
| References | Orchestrates sub-modules                                | Cannot reference other sub-modules directly |
| Lookups    | Receive resource names for `existing` lookups (not IDs) | Inherit scope from parent                   |

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

| Function                                       | Purpose                                                      | Example                                            |
|------------------------------------------------|--------------------------------------------------------------|----------------------------------------------------|
| `parseUri(uri)`                                | Parses URI into components (scheme, host, port, path, query) | `parseUri('https://example.com/path?q=1').host`    |
| `buildUri(scheme, host, path?, port?, query?)` | Constructs URI from components                               | `buildUri('https', 'api.example.com', '/v1', 443)` |
| `loadDirectoryFileInfo(path)`                  | Gets file metadata from directory at compile time            | `loadDirectoryFileInfo('./configs/')`              |
| `deployer().userPrincipalName`                 | Gets the deploying user's principal                          | `deployer().userPrincipalName`                     |

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

| Guideline           | Details                                                                                                   |
|---------------------|-----------------------------------------------------------------------------------------------------------|
| Discover versions   | Use `list_azure_resource_types` and `get_azure_resource_type_schema`, or the earlier names the host lists |
| Version consistency | Identical resource types within a file use the same API version                                           |
| New resource types  | A resource type not yet declared in the file uses the latest stable API version                           |
| Existing types      | A new declaration of a type already in the file reuses that file's API version                            |
| Existing resources  | Retain API version unless significant changes warrant upgrade                                             |
| Upgrades            | Upgrading every declaration of a type is a separate change; report a newer stable version when one exists |

Version consistency takes precedence over the latest stable version. When a file already declares a resource type at an older API version, reuse that version for the new declaration and state that a newer stable version is available.

### Schema Tools Unavailable

When Bicep MCP schema tools are not configured or return errors, choose an API version in this order:

1. Reuse an API version already present in the workspace for the same resource type.
2. Otherwise, when documentation lookups are available and permitted, use a version cited from the [Azure resource reference](https://learn.microsoft.com/azure/templates/).
3. Otherwise, use the best-known stable version and label it unverified.

In every case, state that schema data was unavailable, name the API versions that remain unverified, and do not claim the template was schema-validated. Build the file with `bicep build` or `az bicep build` and resolve `BCP036`, `BCP037`, and `BCP081` before finishing.

## Best Practices

<!-- <reference-best-practices> -->
Best practices retrieved via `get_bicep_best_practices`:

| Category     | Practice                                                                                    |
|--------------|---------------------------------------------------------------------------------------------|
| Modules      | Omit `name` field for `module` statements (auto-generated GUID prevents concurrency issues) |
| Parameters   | Group logically related values into single `param`/`output` with user-defined types         |
| Params Files | Use `.bicepparam` files with variables and expressions instead of `.json`                   |
| Resources    | Use `parent` property instead of `/` in child resource names                                |
| Resources    | Add `existing` resources for parents when defining child resources without parent present   |
| Resources    | Diagnostic codes `BCP036`, `BCP037`, `BCP081` may indicate hallucinated types/properties    |
| Types        | Avoid open types (`array`, `object`); prefer user-defined types                             |
| Types        | Use typed variables: `var foo string = 'value'`                                             |
| Syntax       | Prefer `.?` with `??` over `!` or verbose ternary: `a.?b ?? c`                              |

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

| Feature              | Config Key               | Syntax Example                                                                      |
|----------------------|--------------------------|-------------------------------------------------------------------------------------|
| Testing Framework    | `testFramework`          | `test storageTest 'tests/storage.tests.bicep' = { params: { location: 'eastus' } }` |
| Assertions           | `assertions`             | `assert locationValid = location != 'centralus'`                                    |
| Parameter Validation | `userDefinedConstraints` | `@validate(x => length(x) >= 3 && length(x) <= 24) param storageName string`        |

Enable features in `bicepconfig.json`: `{ "experimentalFeaturesEnabled": { "featureName": true } }`. The `@validate()` decorator takes a lambda that receives the value and returns `true` when it is valid, plus an optional error message.

## Validation

* Search codebase for existing Bicep patterns before implementing
* Use MCP tools or Microsoft docs (`learn.microsoft.com/azure/templates/{provider}/{type}`) for schema reference; follow [Schema Tools Unavailable](#schema-tools-unavailable) when MCP tools cannot provide it
* Run `az bicep build` and address all diagnostic warnings and errors before committing
