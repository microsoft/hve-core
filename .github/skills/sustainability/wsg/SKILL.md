---
name: wsg
description: W3C Web Sustainability Guidelines (WSG 1.0) success criteria for the Sustainability Planner agent
license: W3C-CFSA
content_based_on: https://w3c.github.io/sustyweb/
---

# WSG Framework Skill (wsg/v1)

Framework Skill bundle delivering W3C Web Sustainability Guidelines (WSG) 1.0 success criteria as `criterion` items consumable by the Sustainability Planner.

## Skill layout

* `index.yml` — manifest declaring framework `wsg`, version `1.0`, license `W3C-CFSA`, `surfaceFilter: [web]`.
* `items/*.yml` — per-criterion items; every item carries `metadata.normativeStatus: informative` (WSG is a non-normative Community Group note).

## Loading contract

Loaded by the Sustainability Planner during Phase 3 (Standards Mapping) only when `state.surfaces` includes `web`. Bundle is skipped otherwise.

## Third-Party Attribution

Content adapted from the W3C Sustainable Web Design Community Group "Web Sustainability Guidelines (WSG) 1.0" under the W3C Community Final Specification Agreement (W3C-CFSA). Attribution required.
