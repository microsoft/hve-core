---
title: Module Selection
description: Rationale and worked examples for the AVM sourcing hierarchy and suitability test in the azure-iac-solution skill
author: microsoft/hve-core
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - azure
  - avm
  - bicep
  - terraform
  - coding-standards
estimated_reading_time: 5
---

# Module Selection

## Rationale

Handwritten Azure resources reimplement cross-cutting concerns independently in every
project: diagnostic settings, role assignments, private endpoints, locks, managed identities,
and telemetry. AVM modules already encode these decisions and keep them current, so composing
them reduces both authoring effort and governance drift.

The hierarchy exists to make the default cheap and the exception explicit. A direct resource
is not wrong; an unrecorded direct resource is.

## Worked Example: Pattern Module Fit

A workload needs an application landing zone: a Container Apps environment with a private
network, central logging, and a managed identity per app.

1. Intent captured: private hosting, central diagnostics, per-app identity.
2. Catalogue search finds an AVM pattern module covering Container Apps environments with
   logging integration.
3. The pattern exposes the required diagnostic and identity controls and introduces no
   unwanted resources.
4. Decision: adopt the pattern module, pinned to the current registry version.

## Worked Example: Native Resource Exception

A workload needs a capability exposed only by a preview API for a resource type with no AVM
coverage.

1. Intent captured: the capability is a hard requirement, not a preference.
2. Catalogue search finds no AVM resource module for the type.
3. Decision: implement with `azapi_resource`, record the preview API version and a follow-up
   to re-evaluate when AVM support ships.

## Reviewing the Decision Later

An exception is valid only while its reason holds. When reviewing a solution that records
`kind: azapi-resource` with rationale "No compatible AVM interface was found", check the
catalogue again: if AVM coverage now exists, the correct follow-up is a migration work item,
not a permanent exception.
