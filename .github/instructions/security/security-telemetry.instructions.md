---
description: Telemetry evidence for security plans, supply-chain plans, and supply-chain reviews
applyTo: '**/.copilot-tracking/security-plans/**, **/.copilot-tracking/sssc-plans/**, **/.copilot-tracking/sssc-reviews/**'
---

# Security Telemetry

* In security plans, require security-event emission and cross-reference STRIDE entries with the log severity levels in `telemetry-foundations`.
* In supply-chain plans, require build and release resource attributes (`vcs.*`, `ci.*`) on the corresponding controls.
* In supply-chain reviews, flag findings that rely on build or release telemetry without corresponding `vcs.*` or `ci.*` evidence.
