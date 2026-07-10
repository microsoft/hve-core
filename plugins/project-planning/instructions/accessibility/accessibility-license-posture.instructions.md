---
description: "Accessibility-specific overlay mapping accessibility standards onto the repository licensing posture"
applyTo: '**/.github/skills/accessibility/**, **/.copilot-tracking/accessibility/**'
---

# Accessibility Standards License Posture

This overlay applies the repository-wide [Licensing Posture](../hve-core/licensing-posture.instructions.md) to accessibility framework SKILL packages and accessibility tracking artifacts. It maps each accessibility standard onto a source class defined there and adds the accessibility-specific gating hook. Read the general posture for the source-class rules, attribution blocks, and operational rules; this file only records what is accessibility-specific.

## Source-class mapping

| Upstream source                             | Source class                        | Reproduction rule                                                          |
|---------------------------------------------|-------------------------------------|----------------------------------------------------------------------------|
| WCAG 2.2                                    | W3C Document License                | Verbatim permitted with W3C attribution; paraphrase preferred              |
| WAI-ARIA Authoring Practices Guide (APG)    | W3C Document License                | Verbatim permitted with W3C attribution; adapted code samples attributed   |
| Cognitive Accessibility (COGA)              | W3C Document License                | Verbatim permitted with W3C attribution; cited as guidance, not normative  |
| Section 508 / US Access Board ICT standards | Public domain (US government works) | Verbatim legally permitted; paraphrase preferred for stylistic consistency |
| EN 301 549 (CEN / CENELEC / ETSI)           | Restricted standards (cite-only)    | Never reproduced; cite the official ETSI portal only                       |

## Accessibility-specific rules

* Section 508 reference files follow the same skeleton as the paraphrased W3C-licensed reference files for visual consistency across frameworks, even though verbatim reproduction is legally permitted.
* EN 301 549 reference files vendor only stable clause identifiers as `## Clause <id>` headers, a paraphrased summary, and a link to the official ETSI page.
* Accessibility assessor checks flag verbatim EN 301 549 text as a license violation and surface it as a gating finding during framework SKILL review.

## Source References

* W3C Document License: <https://www.w3.org/Consortium/Legal/2015/doc-license>
* US Access Board, Section 508 ICT Refresh: <https://www.access-board.gov/ict/>
* ETSI EN 301 549 portal: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>
