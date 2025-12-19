# Bicep Coding Standards

You are an expert in Bicep Infrastructure as Code (IaC) with deep knowledge of Azure resources.

This document contains coding standards and best practices for Bicep development in this project.

You MUST ALWAYS meticulously follow these Bicep standards and conventions without deviation.

<!-- <table-of-contents> -->
## Table of Contents

- [Bicep Coding Standards](#bicep-coding-standards)
  - [Table of Contents](#table-of-contents)
  - [Coding Standards](#coding-standards)
    - [Bicep General Conventions](#bicep-general-conventions)
      - [File and Naming Standards](#file-and-naming-standards)
      - [Documentation and Comments](#documentation-and-comments)
      - [Parameters and Types](#parameters-and-types)
      - [Resource Naming](#resource-naming)
      - [Outputs](#outputs)
      - [Resource Scoping](#resource-scoping)
      - [Component-Specific Conventions](#component-specific-conventions)
      - [Enforcing Conventions](#enforcing-conventions)
    - [API Versioning](#api-versioning)
    - [Reference and Validation](#reference-and-validation)
  - [Bicep Type System](#bicep-type-system)
    - [Core Types](#core-types)
    - [Component Types](#component-types)
  - [File Organization](#file-organization)
    - [Bicep Metadata and Documentation](#bicep-metadata-and-documentation)
    - [Main File Organization](#main-file-organization)
<!-- </table-of-contents> -->

## Coding Standards

### Bicep General Conventions

<!-- <bicep-general-conventions> -->
#### File and Naming Standards

- You MUST use `kebab-case` for file/folder names, `camelCase` for parameters, and `PascalCase` for types
- You MUST add metadata information at the top of each file
- You MUST NEVER use hardcoded values for resource names, locations, etc.

#### Documentation and Comments

- You MUST use `@description()` for all parameters and types
  - Provide descriptive short sentences ending with a period
  - Explain non-obvious behaviors: `'The description. (Updates a something not obvious when set)'`
- You MUST organize files with clear section headers using `/* */` comments with whitespace

#### Parameters and Types

- You MUST use `types.bicep` for related parameter types
- You MUST use `??` and/or `.?` instead of ternary operators with null checks
- You MUST organize parameters by function grouping and alphabetically within groups
- You MUST start boolean parameters with `should` or `is`
- You MUST NOT add defaults to required parameters
- You MUST NOT default a parameter to `''`; use `null` instead
- You MUST use `@secure()` for sensitive parameters
- You MUST prefer simple name parameters with existing resources:

```bicep
param identityName string?
resource identity '...@2024-11-30' existing = if (!empty(identityName)) {
  name: identityName!
}
```

#### Resource Naming

- You MUST follow [Azure resource naming conventions](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming)
- You MUST use these patterns:
  - Hyphens allowed: `{abbreviation}-${common.resourcePrefix}-{optional}-${common.environment}-${common.instance}`
  - No hyphens: `{abbreviation}${common.resourcePrefix}{optional}${common.environment}${common.instance}`
  - Length restricted: `'{abbreviation}${uniqueString(common.resourcePrefix, {optional}, common.environment, common.instance)}'`

#### Outputs

- You MUST provide meaningful and factual descriptions with `@description()`
- You MUST use conditional expressions for outputs that depend on conditional resources
- You MUST make outputs nullable when appropriate using the `?` type modifier

#### Resource Scoping

- You MUST assume `targetScope = 'resourceGroup'` EXCEPT FOR blueprints
- You MUST NOT set `scope:` with any `id` string
- You MUST use `existing =` for existing resources
- You MUST use an internal module to change resource group scope

#### Component-Specific Conventions

For Components ONLY:

- You MUST provide defaults for parameters that can have defaults
- You MUST place resources in `main.bicep`
- You MUST NEVER reference another component directly
- You MUST NEVER reference another component's internal modules directly
- You MUST receive resource names to use with `existing` INSTEAD OF resource ids

For Internal modules ONLY:

- You MUST NEVER provide defaults for parameters
- You MUST place resources in `{component_name}/bicep/modules/{module_name}.bicep`
- You MUST NEVER use a component or another component's internal modules

#### Enforcing Conventions

You MUST ALWAYS ensure bicep conventions are being followed and suggest updates to conventions when user changes conflict with them.
<!-- </bicep-general-conventions> -->

### API Versioning

- You MUST use the same API version for identical resource types throughout the codebase
  - You SHOULD use the tool `#azureBicepGetResourceSchema` to get the latest API version
- You MUST use the existing API version when modifying existing resources
- You MUST use the latest API version for new resources
- You MUST update resources to use the latest API version when making significant changes

### Reference and Validation

- You MUST ALWAYS search the codebase for existing Bicep resources to use as a reference
- When no reference exists:
  1. Use VS Code's API Tooling for ARM reference and version information
  2. Fallback to using Microsoft documentation: `https://learn.microsoft.com/azure/templates/{provider-namespace}/{resource-type}`
- You MUST ALWAYS verify and fix all validation issues

## Bicep Type System

### Core Types

<!-- <types-core-bicep-example> -->
```bicep
@export()
@description('Common settings for the components.')
type Common = {
  @description('Prefix for all resources in this module')
  resourcePrefix: string

  @description('Location for all resources in this module')
  location: string

  @description('Environment for all resources in this module: dev, test, or prod')
  environment: string

  @description('Instance identifier for naming resources: 001, 002, etc...')
  instance: string
}
```
<!-- </types-core-bicep-example> -->

### Component Types

<!-- <types-bicep-example> -->
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
<!-- </types-bicep-example> -->

You MUST:

- Use `@export()` for all types and default values
- Use `@description()` for all elements
- Use `@secure()` for sensitive parameters
- Provide sensible defaults for all types
- Use type literals (e.g., 'K3s' | 'K8s') for parameters with known values

## File Organization

### Bicep Metadata and Documentation

Every Bicep file MUST include metadata at the top:

```bicep
metadata name = 'Component or Blueprint Name'
metadata description = 'Description of what this component does and how it works.'
```

### Main File Organization

<!-- <component-main-bicep-example> -->
```bicep
metadata name = 'Azure IoT Operations'
metadata description = 'Deploys Azure IoT Operations extensions, instances, and configurations on Azure Arc-enabled Kubernetes clusters.'

import * as core from './types.core.bicep'
import * as types from './types.bicep'

/*
  Common Parameters
*/

@description('The common component configuration.')
param common core.Common

/*
  Azure IoT Operations Init Parameters
*/

@description('The settings for the Azure IoT Operations Platform Extension.')
param aioPlatformConfig types.AioPlatformExtension = types.aioPlatformExtensionDefaults

/*
  Resources
*/

resource example 'example@1.2.3' = if (shouldCreateExample) {
  name: 'example-name'
}

/*
  Modules
*/

module exampleInternalModule 'modules/example-internal-module.bicep' = {
  name: '${deployment().name}-eim0'
  params: {
    common: common
    // ...other parameters
  }
}

/*
  Outputs
*/

@description('The ADR Schema Registry Name.')
output schemaRegistryName string? = exampleInternalModule.outputs.schemaRegistryName
```
<!-- </component-main-bicep-example> -->

You MUST follow this organization:

1. Metadata and imports at the top
2. Common parameters section
3. Component-specific parameters grouped by functionality
4. Local variables (if needed)
5. Resources section
6. Modules section
7. Outputs section

Each section MUST be clearly separated with comment headers using `/* */` notation with whitespace.
