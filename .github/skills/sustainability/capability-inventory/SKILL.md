---
name: capability-inventory
description: Workload archetype capability inventory cross-walking sustainability framework controls for the Sustainability Planner agent
license: MIT
content_based_on: hve-core authored
---

# Capability Inventory Framework Skill (capability-inventory/v1)

Framework Skill bundle delivering workload-archetype capability items that cross-walk into the upstream sustainability framework bundles (gsf-sci, gsf-principles, swd, wsg, azure-waf-sustainability).

## Skill layout

* `index.yml` — manifest declaring framework `capability-inventory`, version `1.0`, license `MIT`, `surfaceFilter: [cloud, web, ml, fleet]`.
* `items/*.yml` — seven workload archetypes: containerized-cloud-service, static-web-frontend, interactive-spa, batch-data-pipeline, ml-training-job, ml-inference-service, iot-fleet. Each item declares `appliesTo` surfaces and a `covers` cross-walk into upstream framework item ids.

## Loading contract

Loaded by the Sustainability Planner during Phase 2 (Workload Assessment) to classify the workload, then re-consulted in Phase 3 (Standards Mapping) to drive selective loading of upstream framework items via `covers`.

## Cross-Walk Semantics

`covers[]` lists upstream framework item ids that apply to this archetype. The Planner uses these references to scope which controls to evaluate, avoiding noise from non-applicable items.
