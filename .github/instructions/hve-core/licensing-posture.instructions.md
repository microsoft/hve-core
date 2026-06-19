---
description: "Repository posture for licensing, reproduction, and attribution of third-party standards in skills and tracking artifacts"
applyTo: '**/skills/**, **/.copilot-tracking/**'
---

# Licensing Posture

Skill packages and tracking artifacts across this repository cite, paraphrase, or reproduce reference text from upstream standards, frameworks, and guidance documents. Each upstream source carries different licensing terms for quotation, paraphrase, and redistribution. This posture defines what may be reproduced verbatim, what must be paraphrased, and what attribution is required when authoring reference material.

The posture is enforced at authoring time rather than at runtime. Contributors apply the rules when writing or editing reference text, and review and assessor checks treat license violations as gating findings.

## Scope

These rules apply to any file that summarizes, quotes, or reproduces upstream standards material under either tree:

* `.github/skills/**` — skill packages, including `references/*.md` files and `templates/*.md` files that paraphrase, quote, or vendor upstream text.
* `.copilot-tracking/**` — tracking artifacts, including planning notes, review logs, and excerpts pasted into tracking files during a session.

Domain-specific overlays (for example, accessibility frameworks or RAI standards) map their particular standards onto the source classes defined here and add any domain-specific gating hooks. The default rule everywhere is **paraphrase-first**: prefer paraphrased prose with a source link, and reserve verbatim quotation for cases where the source license explicitly permits it or the source is in the public domain.

## Source Classes

Map every upstream source to one of the classes below, then follow that class's rule.

### Repository original content (CC BY 4.0)

Original prose authored for this repository — review criteria, anchors, indicators, taxonomies, templates, and explanatory material — is Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Where original content names a standard's characteristics or categories, the accompanying criteria are original content and not reproductions of the standard's definitions; the authoritative definitions remain with the cited standard.

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

### Creative Commons (CC BY, CC0)

CC-licensed sources (for example, OWASP materials under CC BY, OpenTelemetry Semantic Conventions under CC BY 4.0, MADR templates under CC0) follow the applicable original license terms for any reproduced text, diagrams, tables, or examples.

* CC BY: prefer paraphrase and a source link; reproduce only the minimum text necessary for a specific technical point, with attribution.
* CC0: verbatim reproduction is permitted; preserve attribution to the source for provenance even though CC0 does not require it.

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
* Verbatim text is permitted only for public-domain, W3C, and CC0 sources, each with the required attribution.
* Verbatim text is forbidden for restricted standards (ISO, IEC, ETSI) under any circumstance, including short partial quotes, table rows, and figure captions.
* When the licensing posture for a specific snippet is ambiguous, paraphrase rather than quote.
* Preserve standards identifiers verbatim (clause numbers, control IDs, criterion IDs); identifiers are facts, not licensed prose.
* Treat long or substantial excerpts as a license-risk finding during review.

## Source References

* CC BY 4.0: <https://creativecommons.org/licenses/by/4.0/>
* W3C Document License: <https://www.w3.org/Consortium/Legal/2015/doc-license>
* US public-domain rule, 17 U.S.C. § 105: <https://www.govinfo.gov/app/details/USCODE-2022-title17/USCODE-2022-title17-chap1-sec105>
