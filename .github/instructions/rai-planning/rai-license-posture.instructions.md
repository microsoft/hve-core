---
description: "RAI-specific overlay mapping RAI standards onto the repository licensing posture"
applyTo: '**/.github/skills/rai**/**, **/.copilot-tracking/rai-plans/**'
---

# RAI Standards License Posture

This overlay applies the repository-wide [Licensing Posture](../hve-core/licensing-posture.instructions.md) to RAI skill packages and RAI planning artifacts. It maps each RAI standard onto a source class defined there and adds the RAI-specific gating hook. Read the general posture for the source-class rules, attribution blocks, and operational rules; this file only records what is RAI-specific.

## Source-class mapping

| Upstream source                      | Source class                        | Reproduction rule                                                           |
|--------------------------------------|-------------------------------------|-----------------------------------------------------------------------------|
| NIST AI RMF 1.0                      | Public domain (US government works) | Verbatim permitted with NIST attribution; paraphrase preferred              |
| EU AI Act, Regulation (EU) 2024/1689 | Open legal text                     | Paraphrase-first with attribution to the official EU source                 |
| OWASP AI / OWASP Top 10              | Creative Commons (CC BY)            | Paraphrase and link; reproduce only the minimum necessary, with attribution |
| ISO 42001, ISO 27005, ISO/IEC 42030  | Restricted standards (cite-only)    | Never reproduced; cite the official catalog page only                       |

## RAI-specific rules

* RAI review checks treat license violations as gating findings during framework review.
* When licensing posture for a specific snippet is ambiguous, paraphrase rather than quote.

## Source References

* NIST AI RMF 1.0: <https://www.nist.gov/itl/ai-risk-management-framework>
* EU AI Act, Regulation (EU) 2024/1689: <https://eur-lex.europa.eu/eli/reg/2024/1689/oj>
* OWASP AI: <https://owasp.org/www-project-ai-security-and-privacy-guide/>
* OWASP Top 10: <https://owasp.org/www-project-top-ten/>
* ISO 42001: <https://www.iso.org/standard/77520.html>
* ISO 27005: <https://www.iso.org/standard/80585.html>
* ISO/IEC 42030: <https://www.iso.org/standard/42030>
