---
title: Privacy-by-Design Assessment Reference Index
---

# Privacy-by-Design Assessment Reference Index

This index is the entry point for the reusable privacy-by-design skill. It summarizes the durable reference files that carry the detailed assessment knowledge consumed by the Privacy Reviewer and Privacy Planner agents.

## Reference catalog

| File | Purpose | Source basis |
| :--- | :--- | :--- |
| [pbd-seven-principles.md](pbd-seven-principles.md) | 7 PbD Principles with PASS/FAIL/PARTIAL criteria and severity guidance | Ann Cavoukian’s 7 Foundational Principles of Privacy by Design |
| [retention-and-disposal.md](retention-and-disposal.md) | Principle 05 lifecycle verification: retention, secure deletion, legal holds | GDPR Art. 5(1)(e)/17/32; APP 11.2; CCPA §1798.105(d) |
| [cross-jurisdictional-mapping.md](cross-jurisdictional-mapping.md) | Principle-to-obligation mapping table for GDPR, APP, and CCPA/CPRA | GDPR Art. 25; Australian Privacy Principles 1,3,6,8,11; CCPA/CPRA |
| [codebase-signals.md](codebase-signals.md) | Profiler trigger patterns for consent, collection, storage, and deletion | Codebase signal detection requirements from Issue #2594 |
| [finding-formats.md](finding-formats.md) | Structured output schema with mandatory verbatim citation requirements | Standards-cited findings requirement from Issue #2594 |

## Usage notes

-   Use this skill for durable assessment knowledge, not for orchestration logic.
-   Keep instruction files thin and delegate detailed reference lookups to the skill references.
-   Always load `privacy-standards` alongside this skill for data-flow reasoning, DPIA thresholds, and the NIST/GDPR/CCPA/OWASP backbone.
-   Every finding emitted MUST include a verbatim legal citation from `cross-jurisdictional-mapping.md`.

## Attribution

This skill consolidates Privacy by Design assessment content aligned with Ann Cavoukian’s foundational principles and intentionally complements (does not duplicate) the existing `privacy-standards` skill maintained elsewhere in the repository. Legal source provenance for all citations is documented in `cross-jurisdictional-mapping.md`.
