---
name: swd
description: Sustainable Web Design (SWD) v4 estimating-digital-emissions methodology controls for the Sustainability Planner agent
license: CC-BY-4.0
content_based_on: https://sustainablewebdesign.org/estimating-digital-emissions/
---

# SWD Framework Skill (swd/v4)

Framework Skill bundle delivering the Sustainable Web Design (SWD) v4 "Estimating Digital Emissions" methodology as discrete controls.

## Skill layout

* `index.yml` — manifest declaring framework `swd`, version `4.0`, license `CC-BY-4.0`, `surfaceFilter: [web]`, `status: draft` pending VERIFY-FETCH (planning log WI-01).
* `items/*.yml` — methodology controls; no embedded carbon-intensity literals (planning log DD-03 — runtime fetch only).

## Loading contract

Loaded by the Sustainability Planner during Phase 3 only when `state.surfaces` includes `web`. Each control instructs the consumer to fetch grid-carbon-intensity values at runtime from Electricity Maps, WattTime, or Ember rather than rely on embedded constants.

## Third-Party Attribution

Methodology adapted from the Sustainable Web Design Community "Estimating Digital Emissions" (https://sustainablewebdesign.org/estimating-digital-emissions/) under CC-BY-4.0.
