---
description: "Repository posture for licensing, reproduction, and attribution of third-party standards in skills and tracking artifacts"
applyTo: '**/skills/**, **/.copilot-tracking/**'
---

# Licensing Posture

Skill packages and tracking artifacts across this repository cite, paraphrase, or reproduce reference text from upstream standards, frameworks, and guidance documents. Each upstream source carries different licensing terms for quotation, paraphrase, and redistribution. This posture defines what may be reproduced verbatim, what must be paraphrased, and what attribution is required when authoring reference material.

The posture is enforced at authoring time rather than at runtime. Contributors apply the rules when writing or editing reference text, and review and assessor checks treat license violations as gating findings.

## Scope

These rules apply to any file that summarizes, quotes, or reproduces upstream standards material under either tree:

* `.github/skills/**`: skill packages, including `references/*.md` files and `templates/*.md` files that paraphrase, quote, or vendor upstream text.
* `.copilot-tracking/**`: tracking artifacts, including planning notes, review logs, and excerpts pasted into tracking files during a session.

Domain-specific overlays (for example, accessibility frameworks or RAI standards) map their particular standards onto the source classes defined here and add any domain-specific gating hooks. The default rule everywhere is **paraphrase-first**: prefer paraphrased prose with a source link, and reserve verbatim quotation for cases where the source license explicitly permits it or the source is in the public domain.

## Source Classes

Map every upstream source to one of the classes below, then follow that class's rule.

When more than one class could apply, the most specific class governs, and where specificity is equal the more restrictive rule governs. A source named as an example inside a class is governed by that class. Creative Commons sources follow the Creative Commons class, not the permissive open-source class, even though CC licenses also grant rights on attribution. A dual-licensed source follows the more restrictive of its applicable classes.

### Repository original content (CC BY 4.0)

Original prose authored for this repository (review criteria, anchors, indicators, taxonomies, templates, and explanatory material) is Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Where original content names a standard's characteristics or categories, the accompanying criteria are original content and not reproductions of the standard's definitions; the authoritative definitions remain with the cited standard.

### Public domain (US government works)

US federal government publications (for example, NIST frameworks, Section 508 / US Access Board standards) are public domain under 17 U.S.C. § 105. Verbatim reproduction is legally unrestricted. The authoring rule is to preserve the source URL and official attribution whenever a verbatim excerpt is used. Paraphrase is preferred for stylistic consistency with sibling reference files.

Attribution block for any verbatim public-domain quote:

```markdown
> <verbatim quote>
>
> — <Agency>, <document title>, <source URL>. Public domain.
```

### W3C Document License

W3C specifications and notes (for example, WCAG, WAI-ARIA APG, COGA) are published under the W3C Document License. Paraphrased prose is preferred. Verbatim normative quotes are permitted when precision matters, and each carries the canonical source URL for the specific section plus the W3C copyright attribution line.

Attribution block for any verbatim W3C quote:

```markdown
> <verbatim quote>
>
> — W3C, <document title>, <https://www.w3.org/TR/...>. Copyright © W3C® (MIT, ERCIM, Keio, Beihang). Used under the W3C Document License.
```

### Creative Commons (CC BY, CC BY-SA, CC0)

CC-licensed sources (for example, OWASP materials under CC BY, the Microsoft Code With Engineering Playbook documentation under CC BY 4.0, OpenTelemetry Semantic Conventions under CC BY 4.0, the Scrum Guide and Kanban Guide under CC BY-SA 4.0, MADR templates under CC0) follow the applicable original license terms for any reproduced text, diagrams, tables, or examples.

* CC BY: prefer paraphrase and a source link; reproduce only the minimum text necessary for a specific technical point, with attribution. Record the source in `THIRD-PARTY-NOTICES` at the repository root with its license, source URLs, and usage scope, and indicate that the content has been changed.
* CC BY-SA: paraphrase-first, with the same minimum-necessary limit on quotation. ShareAlike propagates to derivative prose, so any reference file built from a CC BY-SA source carries an attribution block naming the copyright holder, the official source URL, and the CC BY-SA license it inherits.
* CC0: verbatim reproduction is permitted; preserve attribution to the source for provenance even though CC0 does not require it.

When an upstream source states its own license inconsistently, follow the more restrictive statement and record the inconsistency in the reference file's attribution block.

### Permissive open-source licenses (MIT, Apache-2.0, BSD, and similar)

Permissively licensed sources (for example, OpenSSF Scorecard under Apache-2.0) grant rights to use, copy, modify, and redistribute without restriction, conditioned on preserving the copyright and permission notice in all copies or substantial portions. Verbatim reproduction is permitted when that notice requirement is met. This class covers any open-source license granting those rights on notice alone, including ISC and similar terms, not only the three named.

Paraphrase remains preferred for stylistic consistency, so that a reference file reads as repository guidance rather than a mirror of upstream. Reproduce verbatim only when paraphrase would distort a named requirement, checklist item, or technical term, or when short factual statements have too little expressive range for paraphrase to be meaningful. Reproducing a whole upstream page or section is outside this allowance even when the license permits it.

Requirements for any verbatim or lightly edited reproduction:

* Preserve the upstream copyright and permission notice, which is the condition the license attaches to redistribution.
* Record the source in `THIRD-PARTY-NOTICES` at the repository root with its license, source URLs, and usage scope.
* Cite the specific upstream page in the reference file.
* Describe the reproduction accurately. Do not claim prose is paraphrased when it is reproduced or lightly edited, and do not present reproduced content as repository-original.

### Mixed-content packages

A skill package that combines third-party-derived content with repository-original content declares a compound SPDX expression naming every license present in the package, for example `Apache-2.0 AND CC-BY-4.0`, and allocates licenses per file in its attribution section. Declaring only one license misrepresents the other body of content. Never declare a non-SPDX placeholder such as `mixed`; the frontmatter field is an SPDX expression and a placeholder tells a consumer nothing.

At package level, `AND` is the conjunction a redistributor faces: whoever redistributes the whole package complies with every named license. That is the correct reading for a mixed package. It is not a claim that every file carries every license, which is what the per-file allocation table exists to state. Use `OR` only for a genuine recipient choice.

A license that imposes no obligation adds no term. Public-domain source material, including U.S. Government works, and paraphrase-only use of open legal text produce repository-original expression, so neither appears in the expression. A derivative of a copyleft source does appear, because ShareAlike propagates.

Allocate by material class, following the per-file practice used by the [Linux kernel licensing rules](https://docs.kernel.org/process/license-rules.html) and the documentation-versus-code split published by [Kubernetes](https://kubernetes.io/docs/contribute/style/style-guide/). The attribution section names each file or directory and the license that governs it. Where derived and original material share one file, mark the boundary inline.

When every body of content carries the same license, declare that single license rather than a degenerate compound expression. The attribution section still identifies which content is third-party-derived.

### Open legal text (statutes and regulations)

Open legal text published by governments and their institutions (for example, EU regulations on EUR-Lex) is paraphrase-first with explicit attribution to the official source. Use the official publication page as the source of truth for clause references, prefer paraphrased summaries, and keep any verbatim excerpt minimal and clearly attributed.

### Restricted standards (cite-only)

Standards published under restrictive redistribution terms (for example, ISO, IEC, and ETSI / CEN / CENELEC standards such as EN 301 549) are **never reproduced** in this repository. Treat them as reference-only:

* Do not paste source text into reference files.
* Do not reproduce tables, clauses, figure captions, or excerpts in full or in part.
* Cite the official catalog or publisher page instead of copying source text.
* Use paraphrase and links to the official catalog entry when discussing the standard.

Verbatim restricted-standard text is a licensing violation and is reverted at review time, regardless of length.

## Operational Rules

* Every `references/*.md` file cites the official upstream source URL for the standard or guidance it summarises.
* Paraphrased prose is the default posture for all sources.
* Verbatim text is permitted only for public-domain, W3C, CC0, and permissively licensed sources, each with the required attribution and notice.
* Describe any reproduction accurately in every source class. Do not claim prose is paraphrased when it is reproduced or lightly edited, and do not present reproduced content as repository-original.
* Do not reproduce an entire upstream page, section, or document regardless of license. Treat a long or substantial excerpt as a gating license-risk finding, not an advisory one.
* Verbatim text is forbidden for restricted standards (ISO, IEC, ETSI) under any circumstance, including short partial quotes, table rows, and figure captions.
* A derivative of a CC BY-SA source carries the ShareAlike notice and its source attribution into this repository.
* A skill package whose reference content spans more than one license declares a compound SPDX expression naming every license present, plus a per-file allocation table, rather than a single identifier that covers only part of the package or a non-SPDX placeholder such as `mixed`.
* When the licensing posture for a specific snippet is ambiguous, paraphrase rather than quote.
* Preserve standards identifiers verbatim (clause numbers, control IDs, criterion IDs); identifiers are facts, not licensed prose.
* Treat long or substantial excerpts as a license-risk finding during review.

## Source References

* CC BY 4.0: <https://creativecommons.org/licenses/by/4.0/>
* CC BY-SA 4.0: <https://creativecommons.org/licenses/by-sa/4.0/>
* W3C Document License: <https://www.w3.org/Consortium/Legal/2015/doc-license>
* US public-domain rule, 17 U.S.C. § 105: <https://www.govinfo.gov/app/details/USCODE-2022-title17/USCODE-2022-title17-chap1-sec105>
