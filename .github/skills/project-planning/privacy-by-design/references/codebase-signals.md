---
title: Codebase Signal Detection Patterns
description: Codebase signal framing and profiler trigger guidance for privacy-by-design assessment applicability.
---

# Codebase Signal Detection Patterns

This reference summarizes the codebase signal patterns the Codebase Profiler subagent uses to determine when the privacy-by-design skill is applicable.

## Signal category framing

Common signal categories to detect during profiling include:

-   **Consent & Collection** — UI consent flows, opt-in/opt-out toggles, data ingestion endpoints
-   **Storage & Retention** — Database schemas with TTL/expiry fields, IaC lifecycle policies, backup configs
-   **Deletion & DSR** — Erasure endpoints, anonymization functions, right-to-be-forgotten handlers
-   **Transparency & Audit** — Privacy notice files, processing record logs, audit trail configurations
-   **Cross-Border Transfer** — Geo-routing logic, data residency configs, international transfer mechanisms

## Profiler overlay

When assessing AI/ML components or AI-integrated systems, also consider privacy-specific AI signals such as:

-   Training data provenance and PII presence in datasets
-   Model memorization risk indicators (e.g., verbatim training data reproduction)
-   Inference endpoint input/output logging containing PII
-   RAG pipeline vector store retention and purge mechanisms
-   Content filter bypass patterns that may expose sensitive data

## Mapping usage

Use the signal-category references to align skill activation with actual codebase evidence. The Profiler should auto-load this skill when ANY signal from any category is detected. Signals are additive; detection of one signal does not exclude others.

> [!NOTE]
> Signal detection determines *applicability*, not compliance. A detected signal triggers the full PbD assessment pipeline; absence of signals means this skill is not loaded. Always cross-reference detected signals with `pbd-seven-principles.md` for actual PASS/FAIL/PARTIAL assessment.
