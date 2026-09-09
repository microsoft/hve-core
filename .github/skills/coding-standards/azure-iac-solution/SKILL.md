---
name: azure-iac-solution
description: >
  Design, generate, and review Azure infrastructure as code with Azure Verified Modules (AVM)
  as the default implementation path. Covers intent extraction, AVM catalogue discovery,
  module selection evidence, exception handling, and review of Bicep and Terraform solutions.
  Use when a request involves designing or implementing Azure infrastructure, converting
  architecture into Bicep or Terraform, reviewing Azure IaC, or modernizing raw resources
  into reusable modules.
license: MIT
user-invocable: true
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-09-10"
---

# Azure IaC Solution

## Overview

Azure Verified Modules (AVM) is Microsoft's Infrastructure as Code module strategy. AVM
publishes resource, pattern, and utility modules for Bicep and Terraform through the public
registries, codifying Azure guidance and Well-Architected practices so solutions compose
reviewed modules instead of recreating resources ad hoc.

This skill owns the architecture-to-module composition policy. The `bicep` and `terraform`
instruction files own language syntax and defer module sourcing to this skill.

## When to Use

* Designing or implementing Azure infrastructure
* Converting an architecture description into Bicep or Terraform
* Reviewing Azure IaC for module reuse and governance gaps
* Modernizing handwritten Azure resources into reusable modules

## Module Sourcing Hierarchy

Apply this hierarchy per capability. Stop at the first tier that satisfies the requirement.
AVM-first is not AVM-only: a native resource is not wrong, an unrecorded one is.

| Tier | Source                                                                                                      | Use when                                                                                                                                                                                                                              |
|------|-------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1    | AVM pattern module (`Azure/avm-ptn-*/azurerm`, `br/public:avm/ptn/*`)                                       | The architecture closely matches the pattern topology, the module exposes the required security and operational controls, and it introduces no unwanted resources or coupling                                                         |
| 2    | AVM resource modules (`Azure/avm-res-*/azurerm`, `br/public:avm/res/*`), plus utility modules (`avm-utl-*`) | The solution needs custom composition across several resources, or a pattern module is too opinionated for the workload                                                                                                               |
| 3    | Native `azurerm`, `azapi`, or Bicep resources                                                               | No AVM module exists for the resource type, the published module lacks a required capability, a preview API is essential, import or brownfield constraints make module adoption impractical, or the caller requires low-level control |
| 4    | Local module                                                                                                | Genuine solution-specific reuse exists beyond a thin wrapper around one AVM module                                                                                                                                                    |

Every tier 3 choice is recorded in the module decision record with its rationale.

Public-registry consumption is the default. Where organizational review is required, resolve
the same modules through a synchronized private registry rather than maintaining internal
copies or wrappers.

## Discovery Rules

* Resolve module names, versions, and lifecycle status from the AVM module index and the
  registry at execution time using the procedure in
  [module-discovery.md](references/module-discovery.md). Never guess names or versions from
  model knowledge.
* Adopt only modules whose index status is `Available`. `Proposed` modules are not yet
  published; `Orphaned` modules have no maintainer; `Deprecated` modules are being retired.
  Report any of these states to the user instead of adopting silently.
* Pin the resolved version. AVM Terraform modules are pre-1.0, so a `~> MAJOR.MINOR` constraint
  admits breaking minor releases; pin `~> 0.10.0` (patch-only) or the exact version. Bicep
  references pin the tag: `br/public:avm/res/storage/storage-account:0.33.0`.
* Track available upgrades separately from adoption.

## Module Decision Record

Produce the decision record before generating code and confirm it with the user. AVM
positions AI as an assistant: humans own the architecture decision, so do not proceed from
record to implementation without that confirmation. Persist the record with the
implementation plan, or at `infra/module-decisions.yaml` when no plan exists, so reviewers
can re-evaluate exceptions later. Resolve every `<placeholder>` at execution time.

<!-- <example-module-decision-record> -->
```yaml
capabilities:
  - name: container-app-environment
    requirement: Private application hosting with central diagnostics
    implementation:
      kind: avm-resource-module
      source: Azure/avm-res-app-managedenvironment/azurerm
      version: "<resolved-version>"
      status: Available
    rationale: Existing AVM module covers the required resource and extensions

  - name: unsupported-preview-feature
    requirement: Capability only exposed by a preview API
    implementation:
      kind: azapi-resource
      api_version: "<verified-api-version>"
    rationale: No AVM module covers this resource type (index checked <date>)
    follow_up: Re-evaluate when AVM support becomes available
```
<!-- </example-module-decision-record> -->

## Workflow

1. Read repository and deployment context, then extract architectural intent and
   non-functional requirements.
2. Map intent to required Azure capabilities.
3. For each capability, discover candidate modules and assign a tier using the hierarchy.
4. Produce the module decision record and obtain user confirmation.
5. Generate Bicep or Terraform.
6. Validate code, module interfaces, and requirement coverage.
7. Report residual risks, preview dependencies, and exceptions.

## Review Checklist

When reviewing Azure IaC, flag:

* Handwritten Azure resources where an `Available` AVM module exists
* Local modules that wrap one AVM module without adding a meaningful contract
* Unpinned or minor-floating module references
* `Orphaned` or `Deprecated` AVM dependencies
* Direct resources with no recorded exception, or an exception whose reason no longer holds
* Missing decisions for managed identity, diagnostic settings, private networking, locks,
  RBAC, or telemetry
* Differences between the agreed infrastructure specification and the generated code

## References

| File                                                  | Covers                                             | Purpose                                                        |
|-------------------------------------------------------|----------------------------------------------------|----------------------------------------------------------------|
| [module-discovery.md](references/module-discovery.md) | Module index, registry lookups, version resolution | Procedure for resolving names, status, and versions at runtime |

## Troubleshooting

| Symptom                             | Check                                                                                                   |
|-------------------------------------|---------------------------------------------------------------------------------------------------------|
| AVM module not found                | Search the index by resource type; if absent, record a tier 3 exception                                 |
| Module version rejected by registry | Re-resolve the version from the registry; do not pin versions recalled from model knowledge             |
| Pattern module too opinionated      | Drop to AVM resource modules and compose them in the solution root                                      |
| Review flags a deliberate exception | Verify the exception and its rationale appear in the module decision record; update the record if stale |
