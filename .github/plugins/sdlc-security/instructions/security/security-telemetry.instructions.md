---
description: Telemetry evidence for security plans, supply-chain plans, and supply-chain reviews
applyTo: '**/.copilot-tracking/security-plans/**, **/.copilot-tracking/sssc-plans/**, **/.copilot-tracking/sssc-reviews/**'
---

# Security Telemetry

* In security plans, link observable STRIDE scenarios to documented security events and their actual log severity. Trace service-boundary operations; use counters for counts and histograms with documented units for duration. Treat unbounded values as unsuitable metric labels.
* In supply-chain plans, require build and release resource attributes (`vcs.*`, `ci.*`) on the corresponding controls.
* In supply-chain reviews, flag findings that rely on build or release telemetry without corresponding `vcs.*` or `ci.*` evidence.
* Use published semantic conventions or established service instrumentation. Redact secrets, tokens and personal data from attributes, logs and examples. Record a gap when evidence is unavailable; never invent telemetry.
