---
name: azure-iac-solution
description: >
  Design, generate, and review Azure infrastructure as code with Azure Verified Modules (AVM)
  as the default implementation path. Covers intent extraction, AVM catalogue discovery,
  module selection evidence, exception handling, and review of Bicep and Terraform solutions.
  Use when a request involves designing or implementing Azure infrastructure, converting
  architecture into Bicep or Terraform, reviewing Azure IaC, modernizing raw resources into
  reusable modules, or selecting between Bicep, Terraform, AzureRM, and AzAPI.
license: MIT
user-invocable: true
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-09-09"
---

# Azure IaC Solution

## Overview

Azure Verified Modules (AVM) is Microsoft's Infrastructure as Code module strategy. AVM
publishes resource and pattern modules for Bicep and Terraform through the public registries,
codifying common Azure guidance and Well-Architected practices so solutions compose reviewed
modules instead of recreating resources ad hoc.

This skill owns the architecture-to-module composition workflow. The `bicep` and `terraform`
instruction files own language syntax, formatting, and safe expressions; they defer module
sourcing decisions to this skill. Keep language guidance small and this skill focused on
selection evidence, exceptions, and review.

## When to Use

* Designing or implementing Azure infrastructure
* Converting an architecture description into Bicep or Terraform
* Reviewing Azure IaC for module reuse and governance gaps
* Modernizing handwritten Azure resources into reusable modules
* Generating an Azure deployment plan
* Selecting between Bicep, Terraform, AzureRM, and AzAPI

## Module Sourcing Hierarchy

Apply this hierarchy in order. Stop at the first tier that satisfies the requirement.

1. Express and validate architectural intent: capture the required capabilities, security
   posture, naming and tagging expectations, and operational requirements before writing code.
2. Search for an applicable AVM pattern module (`avm-ptn-*` in Terraform, `br/public:avm/ptn/`
   in Bicep).
3. Compose available AVM resource modules (`avm-res-*` in Terraform, `br/public:avm/res/`
   in Bicep).
4. Use native AzureRM, AzAPI, or Bicep resources only for the remaining gaps.
5. Create local modules only when there is genuine solution-specific reuse beyond a thin
   wrapper.
6. Record why AVM was not used for every direct-resource exception.

Public-registry consumption is the recommended default. Where organizational review is
required, resolve the same modules through a synchronized private registry rather than
maintaining internal copies or wrappers.

## Module Suitability Test

AVM-first is not AVM-only. Choose the implementation tier per capability.

Use an AVM pattern module when:

* The architecture closely matches the pattern's intended topology
* The module exposes the required security and operational controls
* The pattern does not introduce unwanted resources or coupling
* The organization accepts the pattern's lifecycle and interface

Use AVM resource modules when:

* The solution needs custom composition across several resources
* A pattern module is too opinionated for the workload
* Individual resource modules cover the required capabilities cleanly
* Cross-resource dependencies remain understandable

Use native resources when:

* No AVM module exists for the resource type
* Required functionality is unavailable in the published AVM version
* A preview or new API is essential
* Import or brownfield constraints make module adoption impractical
* The caller explicitly requires low-level control

## Discovery Rules

* Resolve module sources, versions, and lifecycle status from the registry at execution time.
  Never guess module names or versions from model knowledge.
* Inspect module status before adoption. AVM modules carry lifecycle states (available,
  orphaned, deprecated); an entry in the catalogue is not automatically a production
  dependency.
* Pin module versions (`version = "~> x.y"` in Terraform, a tagged `br/public:` reference in
  Bicep) and track available upgrades separately from adoption.

## Module Decision Record

Produce a decision record before implementation. Resolve every `<placeholder>` from the
registry at execution time.

<!-- <example-module-decision-record> -->
```yaml
capabilities:
  - name: container-app-environment
    requirement: Private application hosting with central diagnostics
    implementation:
      kind: avm-resource-module
      source: avm/res/app/managed-environment
      version: "<resolved-version>"
    rationale: Existing AVM module covers the required resource and extensions

  - name: unsupported-preview-feature
    requirement: Capability only exposed by a preview API
    implementation:
      kind: azapi-resource
      api_version: "<verified-api-version>"
    rationale: No compatible AVM interface was found
    follow_up: Re-evaluate when AVM support becomes available
```
<!-- </example-module-decision-record> -->

## Workflow

1. Read repository and deployment context
2. Extract architectural intent and non-functional requirements
3. Identify required Azure capabilities
4. Search the current AVM catalogue
5. Select pattern modules where the fit is strong
6. Select resource modules for remaining capabilities
7. Identify gaps requiring native resources
8. Produce the module decision record
9. Generate Bicep or Terraform
10. Validate code, module interfaces, and requirement coverage
11. Report residual risks, preview dependencies, and exceptions

## Review Checklist

When reviewing Azure IaC, flag:

* Handwritten Azure resources where a suitable AVM module exists
* Local modules that merely wrap one AVM module without adding a meaningful contract
* Unpinned module references
* Deprecated or orphaned AVM dependencies
* Direct resources with no recorded implementation exception
* Missing decisions for managed identity, diagnostic settings, private networking, locks,
  RBAC, or telemetry
* Differences between the agreed infrastructure specification and the generated code
* Module upgrades that change interfaces or resource behavior

Do not reject native resources outright. Require a reason and check whether that reason
remains valid.

## References

| File                                                  | Covers                               | Purpose                                                               |
|-------------------------------------------------------|--------------------------------------|-----------------------------------------------------------------------|
| [module-selection.md](references/module-selection.md) | Sourcing hierarchy, suitability test | Rationale and worked examples for pattern, resource, and native tiers |

## Troubleshooting

| Symptom                             | Check                                                                                                    |
|-------------------------------------|----------------------------------------------------------------------------------------------------------|
| AVM module not found                | Confirm the resource type has AVM coverage in the current catalogue; fall back to AzAPI for preview APIs |
| Module version rejected by registry | Re-resolve the version from the registry; do not pin versions recalled from model knowledge              |
| Pattern module too opinionated      | Drop to AVM resource modules and compose them in the solution root instead                               |
| Review flags a deliberate exception | Verify the exception and its rationale appear in the module decision record; update the record if stale  |

## Contributing

Follow these conventions when extending this skill:

* Keep the sourcing hierarchy and suitability test in SKILL.md as the authoritative policy.
* Reference files under `references/` carry worked examples and rationale; update the
  References table when adding one.
* Keep registry-specific syntax (Terraform namespace, Bicep `br/public:` paths) accurate
  against the current AVM documentation rather than freezing stale examples.
