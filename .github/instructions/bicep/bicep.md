# Bicep Instructions

You are an expert in Bicep Infrastructure as Code (IaC) with deep knowledge of Azure resources.

Bicep is a domain-specific language (DSL) for deploying Azure resources declaratively. This document provides structural guidelines for Bicep development in this project.

You MUST reference [bicep-standards.md](bicep-standards.md) for detailed coding standards and conventions.

You MUST ALWAYS meticulously follow these Bicep standards and conventions without deviation.

<!-- <table-of-contents> -->
## Table of Contents

- [Project Structure](#project-structure)
  - [Bicep Component Structure](#bicep-component-structure)
  - [Bicep Blueprint Structure](#bicep-blueprint-structure)
  - [Bicep CI Directories](#bicep-ci-directories)
<!-- </table-of-contents> -->

## Project Structure

### Bicep Component Structure

<!-- <example-bicep-component-structure> -->
```plain
src/
  100-edge/
    110-iot-ops/
      bicep/               # COMPONENT MODULE
        main.bicep         # Main orchestration file
        types.bicep        # Component-specific types with defaults
        types.core.bicep   # Core shared types (Common)
        README.md          # Auto-generated, never by AI
        modules/
          iot-ops-init.bicep          # INTERNAL MODULE
          iot-ops-instance.bicep      # INTERNAL MODULE
```
<!-- </example-bicep-component-structure> -->

You MUST use consistent file organization:

- `main.bicep` - Primary resource definitions and orchestration
- `types.core.bicep` - Core type definitions
- `types.bicep` - Component-specific types and defaults
- `modules/` - Directory for internal modules

### Bicep Blueprint Structure

Blueprints compose multiple components into complete IaC stamps:

<!-- <example-bicep-blueprint-structure> -->
```plain
blueprints/
  full-multi-node-cluster/
    bicep/               # BLUEPRINT MODULE
      main.bicep         # Calls multiple COMPONENT MODULES but NEVER INTERNAL MODULES
      types.core.bicep   # Core types for the blueprint
    README.md            # Contains important deployment instructions
```
<!-- </example-bicep-blueprint-structure> -->

### Bicep CI Directories

<!-- <example-bicep-ci> -->
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
  name: '${deployment().name}-ci'
  params: {
    common: common
  }
}
```
<!-- </example-bicep-ci> -->
