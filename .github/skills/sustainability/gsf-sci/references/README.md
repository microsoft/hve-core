# References

This directory holds **runtime-fetch dataset references** for the gsf-sci/v1
bundle. Per DD-03 in the Sustainability Planner planning log, no carbon-intensity
literals or grid-mix values are embedded in this Framework Skill; consumers
fetch values from the upstream sources at runtime.

Datasets referenced by SCI items:

* **Electricity Maps** — <https://app.electricitymaps.com/> — grid-mix carbon
  intensity (location-based) for the SCI `I` variable.
* **WattTime** — <https://www.watttime.org/> — marginal emissions data for
  carbon-aware scheduling.
* **Ember** — <https://ember-energy.org/> — open electricity data for
  long-range grid-mix trends.

Each dataset is fetched at runtime under its own licence; this directory does
not redistribute their content.
