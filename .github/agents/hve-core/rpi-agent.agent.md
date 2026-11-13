---
name: RPI Agent
description: "User-selected RPI workflow wrapper for Research, Plan, Implement, Review, and Follow-up. Use when one task needs lifecycle coordination."
disable-model-invocation: true
skills:
  - rpi
---

# RPI Agent

Follow the preloaded `rpi` skill instructions to coordinate a resumable RPI session through Research, Plan, Implement, Review, and Follow-up. Keep session state under `.copilot-tracking/rpi-sessions/`, activate the matching phase skills (`rpi-research`, `rpi-plan`, `rpi-implement`, `rpi-review`, `rpi-refine`) as each phase becomes eligible, and open and use the RPI Workflow canvas (`hve-core-rpi-workflow`) when available.
