---
name: privacy-by-design
description: "Privacy by Design (PbD) knowledge base for assessing proactive privacy practices against the 7 Foundation Principles, with data retention and disposal lifecycle checks and cross-jurisdictional mappings (GDPR, CCPA, APP)."
license: mixed
user-invocable: false
metadata:
  authors: "Ann Cavoukian (IPC Ontario — 7 Foundation Principles); GDPR Art. 25 (Data Protection by Design and by Default); OAIC (Australian Privacy Principles); Microsoft (planning synthesis)"
  spec_version: "1.0"
  framework_revision: "1.0.0"
  last_updated: "2026-08-09"
  content_based_on: "https://www.ipc.on.ca/wp-content/uploads/resources/7foundationalprinciples.pdf; https://gdpr-info.eu/art-25-gdpr/; https://www.oaic.gov.au/privacy/australian-privacy-principles"
---

# Privacy by Design — Skill Entry

This `SKILL.md` is the **entrypoint** for the Privacy by Design skill.

The skill encodes the **7 Foundation Principles of Privacy by Design** (Cavoukian, 2009) as structured, machine-readable references that the Privacy Planner and Privacy Reviewer agents can query to identify, assess, and improve adherence to proactive privacy practices across the software lifecycle. It extends the existing `privacy-standards` skill with principle-level assessment criteria, data retention and disposal checklists, and cross-jurisdictional regulatory mappings.

> [!NOTE]
> This skill is a planning aid, not legal advice. Its standards summaries support privacy reasoning and review preparation; they do not substitute for qualified legal counsel or a formal regulatory interpretation.

## When to use this skill

Use when you need to:

- Assess a system, feature, or data flow against the 7 PbD Foundation Principles
- Verify that privacy is embedded proactively (not bolted on after incidents)
- Check data retention schedules, disposal methods, and legal hold procedures
- Map privacy requirements across GDPR Art. 25, CCPA/CPRA, and Australian Privacy Principles
- Generate per-principle PASS/FAIL/PARTIAL findings with severity ratings

Do not use for:

- General privacy standards mapping without principle assessment (use `privacy-standards`)
- Security threat modeling (use `security-planning` or OWASP skills)
- RAI assessment (use `rai-planner`)

## Normative references (PbD 7 Foundation Principles)

1. [00 Principle Index](references/00-principle-index.md)
2. [01 Proactive Not Reactive](references/01-proactive-not-reactive.md)
3. [02 Privacy as the Default](references/02-privacy-as-the-default.md)
4. [03 Privacy Embedded into Design](references/03-privacy-embedded-into-design.md)
5. [04 Full Functionality](references/04-full-functionality.md)
6. [05 End-to-End Security](references/05-end-to-end-security.md)
7. [06 Visibility and Transparency](references/06-visibility-and-transparency.md)
8. [07 Respect for User Privacy](references/07-respect-for-user-privacy.md)

## Supplementary references

- [Data Retention and Disposal](references/data-retention-and-disposal.md)
- [Cross-Jurisdictional Mapping](references/cross-jurisdictional-mapping.md)

## Skill layout

- `SKILL.md` — this file (skill entrypoint).
- `references/` — the PbD normative documents and supplementary material.
  - `00-principle-index.md` — index of all principle identifiers, categories, source mappings, and cross-references.
  - `01` through `07` — one document per PbD Foundation Principle.
  - `data-retention-and-disposal.md` — Principle 05 deep-dive: retention schedules, disposal methods, legal holds.
  - `cross-jurisdictional-mapping.md` — regulatory equivalence matrix across GDPR, CCPA/CPRA, and APP.

## Citation-field vocabulary

Use these fields when capturing a finding so the reviewer can assert a stable source-control reference:

- `pbd_principle`: Principle number (1–7) with short name, e.g., `PbD-01 Proactive Not Reactive`
- `gdpr_article`: GDPR article reference, e.g., `Art. 25`
- `app_principle`: Australian Privacy Principle number, e.g., `APP 1`
- `ccpa_section`: CCPA/CPRA section reference

## Finding severity conventions

| Severity | Meaning |
|----------|---------|
| HIGH | Principle is violated with direct risk to data subjects |
| MEDIUM | Principle is partially met; gaps exist that could lead to non-compliance |
| LOW | Minor gap; principle intent is largely met but documentation or controls could improve |

## Finding verdict conventions

| Verdict | Meaning |
|---------|---------|
| PASS | Principle is fully satisfied with observable evidence |
| PARTIAL | Some indicators met but gaps remain |
| FAIL | Principle is not satisfied; corrective action required |

## Integration with Privacy Planner and Reviewer

This skill complements `privacy-standards` (which provides NIST PF, GDPR, CCPA, OWASP backbone). The Privacy Reviewer agent loads both skills:

- `privacy-standards` — standards mapping, data-flow reasoning, DPIA thresholds
- `privacy-by-design` — principle-level assessment, retention/disposal checks, cross-jurisdictional equivalence

No agent modification is required; the agent loads this skill on demand when PbD assessment is invoked.

## Attribution and licensing posture

### Cavoukian PbD Foundation Principles

- **Author**: Dr. Ann Cavoukian, Information and Privacy Commissioner of Ontario
- **Source**: <https://www.ipc.on.ca/wp-content/uploads/resources/7foundationalprinciples.pdf>
- **Modifications**: Principles restructured into agent-consumable assessment checklists with cross-references to GDPR, CCPA, and APP; original principle text paraphrased with attribution
- **Note**: The 7 Foundation Principles are widely referenced in academic and regulatory literature; content here is paraphrased for planning use

### GDPR Art. 25 (Data Protection by Design and by Default)

- **Source**: <https://gdpr-info.eu/art-25-gdpr/>
- **Modifications**: Mapped to PbD principles as regulatory equivalence; paraphrased with attribution

### Australian Privacy Principles (APP)

- **Source**: <https://www.oaic.gov.au/privacy/australian-privacy-principles>
- **Copyright**: © Commonwealth of Australia
- **Modifications**: Mapped to PbD principles as cross-jurisdictional equivalence; paraphrased with attribution

### CCPA/CPRA

- **Source**: <https://oag.ca.gov/privacy/ccpa>
- **Modifications**: Mapped to PbD principles as cross-jurisdictional equivalence; paraphrased with attribution
