---
name: privacy-standards
description: "Privacy planning reference for data-flow reasoning, standards mapping, and DPIA thresholds"
license: CC-BY-4.0 AND CC-BY-SA-3.0
user-invocable: false
metadata:
  authors: "NIST (Privacy Framework and NISTIR 8062); GDPR and CCPA/CPRA sources; OWASP (privacy risks); Microsoft (planning synthesis)"
  spec_version: "NIST Privacy Framework v1.0; NISTIR 8062; GDPR; CCPA/CPRA; OWASP Top 10 Privacy Risks"
  last_updated: "2026-06-26"
  content_based_on: "https://www.nist.gov/privacy-framework; https://doi.org/10.6028/NIST.IR.8062; https://gdpr-info.eu; https://oag.ca.gov/privacy/ccpa; https://owasp.org/www-project-top-10-privacy-risks/"
---

## Privacy Standards Skill

This skill is the reusable privacy reference package for the Privacy Planner and Privacy Reviewer. It consolidates the privacy standards backbone, the core data-flow and classification heuristics, and the DPIA threshold logic needed to keep privacy reviews focused on workflow, evidence, and implementation readiness.

> [!NOTE]
> This skill is a planning aid, not legal advice. Its standards summaries support privacy reasoning and review preparation; they do not substitute for qualified legal counsel or a formal regulatory interpretation.

## Attribution and licensing posture

- NIST Privacy Framework and NISTIR 8062 are U.S. Government documents and are referenced here with attribution as public-domain reference material. Public-domain material carries no license obligation, so it adds no term to the package license expression.
- GDPR and CCPA/CPRA content is paraphrased and attributed rather than quoted verbatim, consistent with the repository's open legal-text posture. The paraphrase is this repository's own expression.
- OWASP privacy-risk material is adapted from the OWASP Top 10 Privacy Risks project, which is licensed CC BY-SA 3.0. ShareAlike propagates to that derivative, so it is the one file carrying a copyleft term.

The frontmatter expression is the conjunction of every license present in the package. The table states which license governs each file.

| Path                                       | License      | Origin                                                      |
|--------------------------------------------|--------------|-------------------------------------------------------------|
| `references/owasp-top-10-privacy-risks.md` | CC-BY-SA-3.0 | Adapted from OWASP Top 10 Privacy Risks v2.0 (CC BY-SA 3.0) |
| `references/nist-privacy-framework.md`     | CC-BY-4.0    | Adapted from NIST Privacy Framework v1.0 (public domain)    |
| `references/nistir-8062.md`                | CC-BY-4.0    | Adapted from NISTIR 8062 (public domain)                    |
| `references/gdpr.md`                       | CC-BY-4.0    | Paraphrase of GDPR, not reproduced                          |
| `references/ccpa-cpra.md`                  | CC-BY-4.0    | Paraphrase of CCPA/CPRA, not reproduced                     |
| `references/dpia-thresholds.md`            | CC-BY-4.0    | Repository-original planning synthesis                      |
| `references/data-governance-controls.md`   | CC-BY-4.0    | Repository-original planning synthesis                      |
| `SKILL.md` and remaining package content   | CC-BY-4.0    | Repository-original                                         |

## Framework index

- [NIST Privacy Framework](references/nist-privacy-framework.md)
- [NISTIR 8062](references/nistir-8062.md)
- [GDPR overview](references/gdpr.md)
- [CCPA/CPRA overview](references/ccpa-cpra.md)
- [OWASP Top 10 Privacy Risks](references/owasp-top-10-privacy-risks.md)
- [DPIA threshold heuristics](references/dpia-thresholds.md)
- [Data governance controls for release readiness](references/data-governance-controls.md)

## Privacy planning heuristics

- Start with a data inventory and map the personal data lifecycle: collection, transfer, storage, use, sharing, retention, and deletion.
- Separate the data categories from the processing purpose so the planner or reviewer can assess necessity, proportionality, and appropriate control selection.
- Identify whether the workflow involves sensitive data, automated decision-making, profiling, or cross-organization sharing, because these conditions often trigger a deeper review.
- Track the evidence trail for each privacy decision so the handoff can include the standards references, the supporting rationale, and the review context.

## Citation-field vocabulary

Use these fields when capturing a finding, control, or risk so the reviewer can assert a stable source-control reference:

- `gdpr_article`
- `ccpa_section`
- `nist_pf_category`
- `nistir8062_objective`
- `owasp_privacy_id`

## Phase-to-framework mapping

| Privacy phase         | Primary standards package                    | Notes                                                |
|-----------------------|----------------------------------------------|------------------------------------------------------|
| Phase 1 Capture       | NIST Privacy Framework + GDPR                | Context, scope, and legal basis framing              |
| Phase 2 Data Mapping  | NIST Privacy Framework + NISTIR 8062         | Data inventory, purpose, and minimization reasoning  |
| Phase 3 Risk and DPIA | GDPR + CCPA/CPRA + NISTIR 8062               | DPIA triggers, risk analysis, and proportionality    |
| Phase 4 Controls      | NIST Privacy Framework + OWASP Privacy Risks | Controls for collection, use, sharing, and retention |
| Phase 5 Impact        | GDPR + CCPA/CPRA + OWASP Privacy Risks       | Potential harm, mitigation, and monitoring           |
| Phase 6 Handoff       | All sources                                  | Evidence handoff, review notes, and action tracking  |

## Open-standards catalog

Use the links below as the reference catalog for open privacy standards and governance resources. Treat the material as planning and review guidance rather than a substitute for legal advice or formal regulatory interpretation.

- NIST Privacy Framework: https://www.nist.gov/privacy-framework
- NISTIR 8062: https://doi.org/10.6028/NIST.IR.8062
- GDPR: https://gdpr-info.eu
- CCPA/CPRA: https://oag.ca.gov/privacy/ccpa
- OWASP Top 10 Privacy Risks: https://owasp.org/www-project-top-10-privacy-risks/
