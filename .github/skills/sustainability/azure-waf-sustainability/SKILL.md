---
name: azure-waf-sustainability
description: Azure Well-Architected Framework Sustainability checklist controls for the Sustainability Planner agent
license: CC-BY-4.0+MIT
content_based_on: https://learn.microsoft.com/azure/well-architected/sustainability/
---

# Azure WAF Sustainability Framework Skill (azure-waf-sustainability/v1)

Framework Skill bundle delivering the Azure Well-Architected Framework Sustainability checklist as discrete `pattern` items.

## Skill layout

* `index.yml` — manifest declaring framework `azure-waf-sustainability`, version `1.0`, license `CC-BY-4.0` (docs) + `MIT` (code), `surfaceFilter: [cloud]`, `status: draft` pending VERIFY-FETCH (planning log WI-01) of the `MicrosoftDocs/well-architected` LICENSE.
* `items/*.yml` — checklist items grouped by sustainability pillar (design, build, operate, monitor); each `itemKind: pattern`.

## Loading contract

Loaded by the Sustainability Planner during Phase 3 only when `state.surfaces` includes `cloud`.

## Third-Party Attribution

Documentation adapted from the Microsoft Learn "Azure Well-Architected Framework — Sustainability" pages under CC-BY-4.0; reference code samples (where reproduced) under MIT. Status `draft` pending verification of the upstream `MicrosoftDocs/well-architected` repository LICENSE (planning log WI-01).
