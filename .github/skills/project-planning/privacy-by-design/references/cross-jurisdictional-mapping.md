---
title: Cross-Jurisdictional Obligation Mapping
description: Principle-to-obligation mapping patterns and verbatim citation references used by the privacy-by-design skill.
---

# Cross-Jurisdictional Obligation Mapping

This reference captures the enforceable obligation mapping and verbatim citation patterns used in the Privacy Reviewer workflow.

## Mapping Approach

Map each PbD principle finding to the most relevant enforceable obligations across GDPR, Australian Privacy Principles (APP), and CCPA/CPRA. Every finding MUST carry at least one verbatim citation from this table.

Preferred references:

-   GDPR Article 25 (Data Protection by Design and by Default) as primary anchor
-   Australian Privacy Principles 1, 3, 6, 8, 11 for APAC coverage
-   CCPA/CPRA sections for US consumer privacy rights
-   Existing `privacy-standards` skill references for NIST PF and OWASP Privacy Risks backbone

## Suggested Mapping Output

Use a compact mapping table like this:

| PbD Principle | Finding | Jurisdiction | Verbatim Citation |
| :--- | :--- | :--- | :--- |
| 2. Default | Opt-out default for secondary processing | GDPR | gdpr_article_25_2 |
| 5. Lifecycle | No automated deletion after purpose fulfilled | APP | app_11_2 |
| 7. User-Centric | DSR fulfillment exceeds 45-day limit | CCPA | ccpa_1798_105_c |
| 6. Transparency | Processing purposes not disclosed at collection | Multi | gdpr_article_13; app_5_1 |

## Full Obligation Matrix

| PbD Principle | GDPR | Australian APP | CCPA/CPRA |
| :--- | :--- | :--- | :--- |
| 1. Proactive | Art. 25(1), Art. 35 | APP 1.2, APP 11.1 | §1798.100(a) |
| 2. Default | Art. 25(2) | APP 3.1, APP 3.2 | §1798.100(b) |
| 3. Embedded | Art. 25(1) | APP 1.2 | §1798.105(d) |
| 4. Positive-Sum | Art. 5(1)(c), Art. 25 | APP 3.1 | §1798.100(a) |
| 5. Lifecycle | Art. 5(1)(e), Art. 17, Art. 32 | APP 11.2 | §1798.105(d) |
| 6. Transparency | Art. 5(1)(a), Art. 12-14 | APP 1.3, APP 5 | §1798.100(a), §1798.110 |
| 7. User-Centric | Art. 7, Art. 15-22 | APP 6, APP 8, APP 12 | §1798.105, §1798.110, §1798.115 |

## Guidance

-   Keep mappings tied to the actual codebase evidence and principle being assessed.
-   Prefer existing `privacy-standards` references over re-embedding full legal text.
-   Use the mapping to support compliance reviewer traceability and backlog prioritization.
-   When a finding spans multiple jurisdictions, cite ALL applicable obligations separated by semicolon in the finding’s `Citation` field.
-   Never paraphrase legal references; use the EXACT verbatim citation format from this table.
