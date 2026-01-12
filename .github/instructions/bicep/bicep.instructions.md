---
applyTo: '**/bicep/**'
description: 'Instructions for Bicep infrastructure as code implementation - Brought to you by microsoft/hve-core'
maturity: stable
---
# Bicep Instructions

These instructions define conventions for Bicep Infrastructure as Code (IaC) development in this codebase. Bicep files deploy Azure resources declaratively through ARM templates.

## MCP Tools

Bicep MCP tools provide schema information and best practices:

<!-- <reference-mcp-tools> -->
| Tool | Purpose |
|------|---------|
| `mcp_bicep_experim_get_az_resource_type_schema` | Retrieves the schema for a specific Azure resource type and API version |
| `mcp_bicep_experim_list_az_resource_types_for_provider` | Lists all available resource types for a provider namespace |
| `mcp_bicep_experim_get_bicep_best_practices` | Returns current Bicep authoring best practices |
| `mcp_bicep_experim_list_avm_metadata` | Lists all Azure Verified Modules with versions and documentation |
<!-- </reference-mcp-tools> -->

## Project Structure

### Component Structure

Components are reusable Bicep modules for specific Azure resource deployments:

<!-- <example-component-structure> -->
```text
src/
  100-edge/
    110-iot-ops/
      bicep/                          # Component module
        main.bicep                    # Main orchestration file
        types.bicep                   # Component-specific types with defaults
        types.core.bicep              # Core shared types
        README.md                     # Auto-generated documentation
        modules/
          iot-ops-init.bicep          # Internal module
          iot-ops-instance.bicep      # Internal module
```
<!-- </example-component-structure> -->

File organization within components:

* `main.bicep` - Primary resource definitions and orchestration
* `types.core.bicep` - Core type definitions shared across components
* `types.bicep` - Component-specific types and default values
* `modules/` - Internal modules for the component

### Blueprint Structure

Blueprints compose multiple components into complete infrastructure stamps:

<!-- <example-blueprint-structure> -->
```text
blueprints/
  full-multi-node-cluster/
    bicep/                            # Blueprint module
      main.bicep                      # Calls component modules only
      types.core.bicep                # Core types for the blueprint
    README.md                         # Deployment instructions
```
<!-- </example-blueprint-structure> -->

Blueprints call component modules but never reference internal modules directly.

### CI Directories

CI configurations reference component modules for validation:

<!-- <example-ci-directory> -->
```bicep
import * as core from '../../bicep/types.core.bicep'

/*
  Common Parameters
*/

@description('The common component configuration.')
param common core.Common

/*
  Modules
*/

module ci '../../bicep/main.bicep' = {
  params: {
    common: common
  }
}
```
<!-- </example-ci-directory> -->

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
* Nullable outputs use the `?` type modifier

### Resource Scoping

* Default `targetScope` is `'resourceGroup'` except for blueprints
* The `scope:` property does not use ID strings directly
* Existing resources use `existing =` syntax
* Resource group scope changes use internal modules

## Component Conventions

<!-- <conventions-components> -->
Components follow these rules:

* Parameters that can have defaults include defaults
* Resources belong in `main.bicep`
* Components do not reference other components directly
* Components do not reference another component's internal modules
* Components receive resource names for `existing` lookups rather than resource IDs
<!-- </conventions-components> -->

## Internal Module Conventions

<!-- <conventions-internal-modules> -->
Internal modules follow these rules:

* Parameters have no defaults (parent component provides all values)
* Files are located at `{component}/bicep/modules/{module-name}.bicep`
* Internal modules do not reference components or other components' internal modules
<!-- </conventions-internal-modules> -->

## Type System

### Core Types

The `Common` type provides shared configuration across components:

<!-- <example-types-core> -->
```bicep
@export()
@description('Common settings for the components.')
type Common = {
  @description('Prefix for all resources in this module.')
  resourcePrefix: string

  @description('Location for all resources in this module.')
  location: string

  @description('Environment for all resources in this module: dev, test, or prod.')
  environment: string

  @description('Instance identifier for naming resources: 001, 002, etc.')
  instance: string
}
```
<!-- </example-types-core> -->

### Component Types

Component types define configuration with sensible defaults:

<!-- <example-types-component> -->
```bicep
@export()
@description('The settings for the Azure IoT Operations Extension.')
type AioExtension = {
  @description('The common settings for the extension.')
  release: Release

  settings: {
    @description('The namespace in the cluster where Azure IoT Operations will be installed.')
    namespace: string

    @description('The distro for Kubernetes for the cluster.')
    kubernetesDistro: 'K3s' | 'K8s' | 'MicroK8s'

    @description('The length of time in minutes before an operation for an agent times out.')
    agentOperationTimeoutInMinutes: int
  }
}

@export()
var aioExtensionDefaults = {
  release: {
    version: '1.0.9'
    train: 'stable'
  }
  settings: {
    namespace: 'azure-iot-operations'
    kubernetesDistro: 'K3s'
    agentOperationTimeoutInMinutes: 120
  }
}
```
<!-- </example-types-component> -->

Type conventions:

* All types and default values include `@export()`
* All elements include `@description()`
* Sensitive values include `@secure()`
* Type literals (e.g., `'K3s' | 'K8s'`) constrain parameters with known valid values

## File Organization

Every Bicep file includes metadata at the top:

```bicep
metadata name = 'Component or Blueprint Name'
metadata description = 'Description of what this component does and how it works.'
```

Main file sections appear in this order:

<!-- <example-main-organization> -->
```bicep
metadata name = 'Azure IoT Operations'
metadata description = 'Deploys Azure IoT Operations extensions and instances on Arc-enabled Kubernetes clusters.'

import * as core from './types.core.bicep'
import * as types from './types.bicep'

/*
  Common Parameters
*/

@description('The common component configuration.')
param common core.Common

/*
  Component Parameters
*/

@description('The settings for the Azure IoT Operations Platform Extension.')
param aioPlatformConfig types.AioPlatformExtension = types.aioPlatformExtensionDefaults

/*
  Variables
*/

var deploymentPrefix = '${deployment().name}'

/*
  Resources
*/

resource example 'Microsoft.Example/resources@2024-01-01' = if (shouldCreateExample) {
  name: 'example-${common.resourcePrefix}-${common.environment}-${common.instance}'
}

/*
  Modules
*/

module exampleInternalModule 'modules/example-internal-module.bicep' = {
  params: {
    common: common
  }
}

/*
  Outputs
*/

@description('The ADR Schema Registry Name.')
output schemaRegistryName string? = exampleInternalModule.outputs.schemaRegistryName
```
<!-- </example-main-organization> -->

Section order:

1. Metadata and imports
2. Common parameters
3. Component-specific parameters (grouped by functionality)
4. Variables (when needed)
5. Resources
6. Modules
7. Outputs

Each section has a `/* */` comment header with whitespace separation.

## API Versioning

API version selection follows these guidelines:

* Use `mcp_bicep_experim_list_az_resource_types_for_provider` to discover available API versions
* Use `mcp_bicep_experim_get_az_resource_type_schema` to get the schema for a specific version
* Identical resource types within a file use the same API version
* New resources use the latest stable API version
* Existing resources retain their API version unless significant changes warrant an upgrade

## Azure Verified Modules

Before implementing custom Bicep modules, check for existing Azure Verified Modules:

* Use `mcp_bicep_experim_list_avm_metadata` to list available modules
* AVM modules provide tested, Microsoft-supported implementations
* Prefer AVM modules over custom implementations when functionality aligns
* Document the decision when choosing custom implementation over AVM

## Best Practices

<!-- <reference-best-practices> -->
Current Bicep best practices (retrieved via `mcp_bicep_experim_get_bicep_best_practices`):

General:

* Omit the `name` field for `module` statements (auto-generated GUID prevents concurrency issues)
* Group logically related values into single `param` or `output` with user-defined types
* Generate Bicep parameters files (`*.bicepparam`) instead of ARM parameters files (`*.json`)

Resources:

* Use the `parent` property instead of `/` characters in child resource `name` properties
* Add `existing` resources for parents when defining child resources without the parent present
* Use symbolic names (`foo.id`, `foo.properties.id`) instead of `resourceId()` or `reference()` functions
* Diagnostic codes `BCP036`, `BCP037`, or `BCP081` may indicate hallucinated resource types or properties

Types:

* Avoid open types (`array`, `object`) in favor of user-defined types
* Use typed variables with `@export()`: `var foo string = 'value'`
* Use `resourceInput<'type@version'>` and `resourceOutput<'type@version'>` for resource-derived types

Security:

* Apply `@secure()` to any `param` or `output` containing sensitive data

Syntax:

* Prefer safe-dereference (`.?`) with coalesce (`??`) over null assertion (`!`) or verbose ternary expressions: `a.?b ?? c`
<!-- </reference-best-practices> -->

## Reference and Validation

When no codebase reference exists for a resource type:

1. Use MCP tools to retrieve the official schema
2. Reference Microsoft documentation: `https://learn.microsoft.com/azure/templates/{provider-namespace}/{resource-type}`

Validation:

* Search the codebase for existing Bicep patterns before implementing
* Run `az bicep build` to verify syntax
* Address all diagnostic warnings and errors before committing
