---
description: "Required posture for licensing and reproduction of accessibility standards reference text"
applyTo: '**/.github/skills/accessibility/**, **/.copilot-tracking/accessibility/**'
---

# Accessibility Standards License Posture

Accessibility framework SKILL packages and accessibility tracking artifacts cite normative reference text from upstream accessibility standards. Each upstream standard carries different licensing terms for reproduction, redistribution, and quotation.

Reference files inside framework SKILL packages routinely paste, paraphrase, or summarise criteria text, and the licensing terms of the upstream standard determine which of those is permitted. The per-framework rules below define what may be reproduced verbatim, what must be paraphrased, and what attribution is required when authoring reference material.

The posture is enforced at authoring time rather than at runtime. Contributors apply the rules when writing or editing reference files, and accessibility assessor checks treat license violations as gating findings during framework SKILL review.

## Scope

These rules apply to any file located under either of these trees:

* `.github/skills/accessibility/**` — framework SKILL packages, including `references/*.md` files that paraphrase or quote upstream criteria text.
* `.copilot-tracking/accessibility/**` — accessibility tracking artifacts, including planning notes, review logs, and excerpts pasted into tracking files during a session.

The rules cover five frameworks: WCAG 2.2, ARIA APG, Cognitive Accessibility (COGA), Section 508, and EN 301 549. Each framework has its own section below.

## WCAG 2.2

Web Content Accessibility Guidelines 2.2 is published under the W3C Document License (2015-05-13 revision). Full text reproduction is permitted when accompanied by the W3C copyright attribution line and a link to the source document.

Paraphrased prose is preferred for navigation and brevity in `references/*.md` files, because long verbatim blocks make reference files harder to scan during review. Verbatim normative quotes are permitted when precision matters, and each verbatim quote must carry the canonical source URL for the specific success criterion plus the W3C copyright attribution line.

Attribution block for any verbatim W3C quote:

```markdown
> <verbatim quote>
>
> — W3C, <document title>, <https://www.w3.org/TR/...>. Copyright © W3C® (MIT, ERCIM, Keio, Beihang). Used under the W3C Document License.
```

## ARIA APG

The WAI-ARIA Authoring Practices Guide is published under the W3C Document License on the same terms as WCAG 2.2. Paraphrased prose is preferred for pattern summaries and keyboard interaction tables. Verbatim normative quotes are permitted with the canonical source URL for the specific pattern or section plus the W3C copyright attribution line. Code samples from APG reference implementations may be adapted; attribution is required when an adapted sample is recognisably derived from an APG example.

## Cognitive Accessibility (COGA)

The W3C Cognitive Accessibility Working Group Note is published under the W3C Document License on the same terms as WCAG 2.2 and ARIA APG. Paraphrased prose is preferred for user-need summaries and design pattern descriptions.

Verbatim normative quotes are permitted with the canonical source URL for the specific section plus the W3C copyright attribution line. Note that COGA content is a Working Group Note rather than a Recommendation, and reference files cite it as guidance rather than as a normative requirement.

## Section 508

Section 508 of the Rehabilitation Act and the US Access Board ICT Refresh standard are works of the United States federal government. They are in the public domain in the United States under 17 U.S.C. § 105, and verbatim reproduction is legally unrestricted.

The authoring rule for this repository is nevertheless paraphrase-only for stylistic consistency across frameworks. Section 508 reference files read like EN 301 549 and WCAG 2.2 reference files rather than like a public-domain text dump, which keeps the framework SKILLs visually consistent and easier to maintain.

Every Section 508 reference file cites the official US Access Board URL for the criterion it summarises, regardless of whether the prose is paraphrased or quoted.

Section 508 reference files follow the same skeleton as EN 301 549 reference files: a heading for each criterion identifier, a paraphrased summary in the contributor's own words, and a source link to the US Access Board page that defines the criterion.

## EN 301 549

EN 301 549 is published jointly by CEN, CENELEC, and ETSI. The PDF is available as a free download via the ETSI portal, but redistribution of the full PDF or of substantial extracts requires explicit ETSI permission. The authoring rule is strict paraphrase-only. Reference files vendor only:

* Stable clause identifiers rendered as `## Clause <id>` markdown headers.
* Paraphrased clause summaries written in the contributor's own words.
* A link to the official ETSI PDF or HTML page that contains the normative text.

Verbatim ETSI EN 301 549 text is a licensing violation and is reverted at review time. The rule applies to entire clauses, partial sentences, table rows, and figure captions equally. When a contributor needs to reference exact ETSI wording, they paraphrase and link rather than quote. Accessibility assessor checks flag verbatim ETSI text as a gating finding regardless of length.

Permitted reference file skeleton for EN 301 549:

```markdown
## Clause 9.1.1.1

Paraphrased summary of the clause requirement in the contributor's own words.

Source: ETSI EN 301 549 v3.2.1, Clause 9.1.1.1. See <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>.
```

## Operational Rules

* Every `references/*.md` file cites the upstream source URL for the standard it summarises.
* Verbatim text is permitted only for WCAG 2.2, ARIA APG, and Cognitive Accessibility (COGA), and each verbatim quote carries the W3C copyright attribution line plus a link to the specific source section.
* Verbatim text is forbidden for EN 301 549 under any circumstance, including short partial quotes, table rows, and figure captions.
* Verbatim text is discouraged for Section 508 even though it is legally permitted; paraphrase is preferred for stylistic consistency with the other framework reference files.
* Paraphrased criteria text is the default posture for all five frameworks.
* When the licensing posture for a specific snippet is ambiguous, paraphrase rather than quote.
* Accessibility assessor checks flag verbatim EN 301 549 text as a license violation and surface it as a gating finding during framework SKILL review.

## Source References

* W3C Document License: <https://www.w3.org/Consortium/Legal/2015/doc-license>
* US Access Board, Section 508 ICT Refresh: <https://www.access-board.gov/ict/>
* ETSI EN 301 549 portal: <https://www.etsi.org/deliver/etsi_en/301500_301599/301549/>
