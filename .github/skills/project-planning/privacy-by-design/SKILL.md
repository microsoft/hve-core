---
name: privacy-by-design
description: Privacy assessment reference set for PbD principles, retention/disposal verification, cross-jurisdictional mapping, and codebase signal detection.
license: MIT
user-invocable: false
---

# Privacy-by-Design Assessment

This skill packages the durable privacy-by-design assessment material used by the Privacy Reviewer and Privacy Planner: 7 Foundational Principles assessment criteria, retention and disposal verification checks, cross-jurisdictional obligation mappings (GDPR/APP/CCPA), codebase signal patterns, and structured finding formats with mandatory legal citations.

## When to use

Use this skill when you need to:

*   Assess codebases against the 7 Foundational Principles of Privacy by Design with PASS/FAIL/PARTIAL findings and severity ratings.
*   Verify data retention periods are purpose-linked and disposal methods meet regulatory requirements under Principle 05.
*   Map privacy findings to enforceable obligations across GDPR Art. 25, Australian Privacy Principles (APP 1, 3, 6, 8, 11), and CCPA/CPRA in a single pass.
*   Detect applicable codebase signals (consent flows, collection endpoints, storage configs, deletion handlers) to determine skill applicability.
*   Emit structured findings with verbatim legal citations for compliance reviewer traceability.

> [!NOTE]
> This skill complements (does not replace) `privacy-standards`. Load both skills simultaneously: use `privacy-standards` for data-flow reasoning, DPIA thresholds, and the NIST/GDPR/CCPA/OWASP backbone; use THIS skill for principle-by-principle assessment depth and APP coverage.

## Skill layout

Load the reference file that matches the assessment phase or topic you need.

| Reference | Topic |
| :--- | :--- |
| [references/00-index.md](references/00-index.md) | Navigation catalog and consolidated attribution |
| [references/pbd-seven-principles.md](references/pbd-seven-principles.md) | 7 PbD Principles with PASS/FAIL/PARTIAL criteria and severity guidance |
| [references/retention-and-disposal.md](references/retention-and-disposal.md) | Principle 05 lifecycle verification: retention, secure deletion, legal holds |
| [references/cross-jurisdictional-mapping.md](references/cross-jurisdictional-mapping.md) | Principle-to-obligation mapping table for GDPR, APP, and CCPA/CPRA |
| [references/codebase-signals.md](references/codebase-signals.md) | Profiler trigger patterns for consent, collection, storage, and deletion |
| [references/finding-formats.md](references/finding-formats.md) | Structured output schema with mandatory verbatim citation requirements |

## Attribution

The durable reference content in this skill is organized by reference file and summarized in [references/00-index.md](references/00-index.md). See that index for consolidated attribution, legal source provenance, and delegation notes.
