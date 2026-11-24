---
name: privacy-by-design
description: "Privacy by Design (PbD) knowledge base for assessing proactive privacy practices against the 7 Foundation Principles, with data retention and disposal lifecycle checks and cross-jurisdictional mappings (GDPR, CCPA, APP)."
license: CC-BY-4.0
user-invocable: false
metadata:
  authors: "Ann Cavoukian (IPC Ontario, 7 Foundation Principles); GDPR Art. 25 (Data Protection by Design and by Default); OAIC (Australian Privacy Principles); Microsoft (planning synthesis)"
  spec_version: "1.0"
  framework_revision: "1.1.0"
  last_updated: "2026-10-27"
  content_based_on: "https://www.ipc.on.ca/sites/default/files/legacy/2018/01/pbd.pdf; https://eur-lex.europa.eu/eli/reg/2016/679/oj; https://www.oaic.gov.au/privacy/australian-privacy-principles"
---

# Privacy by Design

This `SKILL.md` is the **entrypoint** for the Privacy by Design skill.

The skill provides structured assessment references for the 7 Foundation Principles of Privacy by Design (Cavoukian, 2009). Consumers that explicitly load it can assess privacy practices across the software lifecycle. It complements `privacy-standards` with principle-level criteria, retention and disposal checks, regulatory mappings, a finding schema and implementation patterns. Current agent wiring is described under Integration below.

> [!NOTE]
> This skill is a planning aid, not legal advice. Its standards summaries support privacy reasoning and review preparation; they do not substitute for qualified legal counsel or a formal regulatory interpretation.

## Goal

Produce an evidence-based assessment against the 7 PbD Foundation Principles, with per-principle verdicts, explicit evidence gaps, deficiency severity, and remediation for established deficiencies. Assessment labels describe this planning rubric, not legal certification.

## Success criteria

- All 7 principles have a verdict, evidence completeness, and severity (`N/A` when no deficiency is established).
- Each FAIL or PARTIAL finding includes a specific, actionable remediation.
- Findings use the structured schema defined in `finding-schema.md`.
- Cross-jurisdictional obligations are identified for the applicable regulatory scope.
- Retention and disposal are assessed for any system that stores personal data.
- An overall assessment verdict (COMPLIANT / PARTIALLY_COMPLIANT / NON_COMPLIANT / INCOMPLETE) is determined without treating missing evidence as a failed control.
- Finding, principle, checklist and severity counts reconcile under the [finding schema](references/finding-schema.md).

## When to use this skill

Use when you need to:

- Assess a system, feature, or data flow against the 7 PbD Foundation Principles
- Verify that privacy is embedded proactively (not bolted on after incidents)
- Check data retention schedules, disposal methods, and legal hold procedures
- Map privacy requirements across GDPR Art. 25, CCPA/CPRA, and Australian Privacy Principles
- Generate per-principle PASS/PARTIAL/FAIL/INSUFFICIENT_EVIDENCE results with evidence-backed severity
- Identify code-level and configuration-level privacy patterns or anti-patterns
- Produce backlog items from privacy assessment findings

Do not use for:

- General privacy standards mapping without principle assessment (use `privacy-standards`)
- Security threat modeling (use `security-planning` or OWASP skills)
- RAI assessment (use `rai-planner`)
- Legal advice or regulatory compliance certification

## Stop rules

- Stop the assessment if the system boundary cannot be established.
- Stop and escalate if processing occurs in a jurisdiction not covered by this skill's mappings.
- Do not fabricate evidence; record `INSUFFICIENT_EVIDENCE` and the evidence needed. Continue supported checks without inventing deficiency remediation for unknowns.
- Do not provide legal opinions; frame all findings as planning guidance requiring qualified review.
- Do not duplicate security findings that the `security-planning` skill already covers; cross-reference them.

## Normative references (PbD 7 Foundation Principles)

1. [00 Principle Index](references/00-principle-index.md)
2. [01 Proactive Not Reactive](references/01-proactive-not-reactive.md)
3. [02 Privacy as the Default](references/02-privacy-as-the-default.md)
4. [03 Privacy Embedded into Design](references/03-privacy-embedded-into-design.md)
5. [04 Full Functionality](references/04-full-functionality.md)
6. [05 End-to-End Security](references/05-end-to-end-security.md)
7. [06 Visibility and Transparency](references/06-visibility-and-transparency.md)
8. [07 Respect for User Privacy](references/07-respect-for-user-privacy.md)

## Operational references

- [Assessment Protocol](references/assessment-protocol.md) — step-by-step protocol for conducting a PbD assessment
- [Finding Schema](references/finding-schema.md) — structured output format for findings and backlog handoff
- [Implementation Patterns](references/implementation-patterns.md) — pragmatic code-level and architecture-level verification patterns

## Supplementary references

- [Data Retention and Disposal](references/data-retention-and-disposal.md) — Principle 05 deep-dive: retention schedules, disposal methods, legal holds
- [Cross-Jurisdictional Mapping](references/cross-jurisdictional-mapping.md) — regulatory equivalence matrix across GDPR, CCPA/CPRA, and APP
- [Industry Privacy Profiles](references/industry-privacy-profiles.md) — sector-specific principle priorities, checks, and `.pbd-config.yml` customization

## Skill layout

- `SKILL.md` — this file (skill entrypoint).
- `references/` — the PbD normative documents, operational guides, and supplementary material.
  - `00-principle-index.md` — index of all principle identifiers, categories, source mappings, and cross-references.
  - `01` through `07` — one document per PbD Foundation Principle with checklist, controls, anti-patterns, and regulatory mappings.
  - `assessment-protocol.md` — phased assessment protocol for agents conducting PbD reviews.
  - `finding-schema.md` — YAML-based finding and summary schema for structured output.
  - `implementation-patterns.md` — code-level and configuration-level patterns agents can verify.
  - `data-retention-and-disposal.md` — Principle 05 deep-dive: retention schedules, disposal methods, legal holds.
  - `cross-jurisdictional-mapping.md` — regulatory equivalence matrix across GDPR, CCPA/CPRA, and APP.
  - `industry-privacy-profiles.md` — telco, healthcare, financial sector profiles with `.pbd-config.yml` customization schema.

## Citation-field vocabulary

Use these fields when capturing a finding so the reviewer can assert a stable source-control reference:

- `pbd_principle`: Principle number (1–7) with short name, e.g., `PbD-01 Proactive Not Reactive`
- `gdpr_article`: GDPR article reference, e.g., `Art. 25`
- `app_principle`: Australian Privacy Principle number, e.g., `APP 1`
- `ccpa_section`: CCPA/CPRA section reference

## Finding severity conventions

| Severity | Meaning                                                                                               |
|----------|-------------------------------------------------------------------------------------------------------|
| CRITICAL | Established deficiency with severe direct risk, or FAIL under an effective CRITICAL industry priority |
| HIGH     | Principle is violated with direct risk to data subjects                                               |
| MEDIUM   | Principle is partially met; gaps exist that could lead to non-compliance                              |
| LOW      | Minor gap; principle intent is largely met but documentation or controls could improve                |
| N/A      | No deficiency established, including PASS and unknown-only results                                    |

Data sensitivity informs the impact of a proven deficiency; it does not create one. Preserve CRITICAL in records and summaries. CRITICAL and HIGH map to P1, with CRITICAL ordered first; MEDIUM maps to P2 and LOW to P3. PASS and unknown-only results do not create remediation backlog items.

## Finding verdict conventions

| Verdict               | Meaning                                                                                                   |
|-----------------------|-----------------------------------------------------------------------------------------------------------|
| PASS                  | All applicable checks are MET, with no unresolved evidence or anti-patterns                               |
| PARTIAL               | A deficiency is established but the FAIL threshold is not met                                             |
| FAIL                  | More than half of applicable checks are NOT MET, or an uncompensated critical anti-pattern is established |
| INSUFFICIENT_EVIDENCE | No deficiency established, but unknown evidence or zero applicable checks prevents PASS                   |

Apply the ordered rules in the [assessment protocol](references/assessment-protocol.md). Record evidence completeness independently so a proven deficiency is not hidden by unknown checks. Suppressions require a documented applicability reason and do not count as MET.

## Overall assessment verdicts

| Verdict             | Condition                                                                                     |
|---------------------|-----------------------------------------------------------------------------------------------|
| NON_COMPLIANT       | One or more principles are FAIL; retain any evidence gaps separately                          |
| INCOMPLETE          | No FAIL, but any principle or applicable retention/jurisdiction check has incomplete evidence |
| PARTIALLY_COMPLIANT | Complete evidence, no FAIL, and at least one PARTIAL                                          |
| COMPLIANT           | Complete evidence and all 7 principles PASS                                                   |

Evaluate these rows in order. Never use `null` for a verdict or interpret an unknown jurisdictional baseline as met or failed.

## Integration with Privacy Planner and Reviewer

This skill complements `privacy-standards` (which provides the NIST PF, GDPR, CCPA, OWASP backbone). A consumer performing PbD assessment should explicitly load both:

- `privacy-standards` — standards mapping, data-flow reasoning, DPIA thresholds
- `privacy-by-design` — principle-level assessment, retention/disposal checks, cross-jurisdictional equivalence, implementation pattern verification

The current Privacy Planner and Privacy Reviewer do not explicitly load `privacy-by-design`. This skill supplies assessment knowledge, not automatic integration; dedicated agent wiring is outside this skill change. It remains background-only (`user-invocable: false`).

## Interaction with other skills

| Skill               | Relationship                                                                                  |
|---------------------|-----------------------------------------------------------------------------------------------|
| `privacy-standards` | Provides data inventory, DPIA thresholds, and standards backbone; PbD builds on top           |
| `security-planning` | Security controls overlap with PbD-05; reference rather than duplicate                        |
| `rai-planner`       | RAI data-use concerns feed into PbD-04 (full functionality) and PbD-07 (user respect)         |
| `secure-by-design`  | SBD-11 (Secure Deprecation) aligns with PbD-05 lifecycle; cross-reference for decommissioning |

## Attribution and licensing posture

`SKILL.md` and `references/` contain original assessment guidance and paraphrased summaries under CC BY 4.0. The cited publications remain authoritative and retain their own rights; this license does not relicense upstream text. Principle names and legal identifiers are preserved for traceability. No upstream document is reproduced or bundled.

### Cavoukian PbD Foundation Principles

- **Author**: Dr. Ann Cavoukian, Information and Privacy Commissioner of Ontario
- Source: <https://www.ipc.on.ca/sites/default/files/legacy/2018/01/pbd.pdf>
- **Modifications**: Principles restructured into agent-consumable assessment checklists with cross-references to GDPR, CCPA, and APP; original principle text paraphrased with attribution
- **Note**: The 7 Foundation Principles are widely referenced in academic and regulatory literature; content here is paraphrased for planning use

### GDPR Art. 25 (Data Protection by Design and by Default)

- Source: <https://eur-lex.europa.eu/eli/reg/2016/679/oj>
- **Modifications**: Mapped to PbD principles as regulatory equivalence; paraphrased with attribution

### Australian Privacy Principles (APP)

- **Source**: <https://www.oaic.gov.au/privacy/australian-privacy-principles>
- **Copyright**: © Commonwealth of Australia
- **Modifications**: Mapped to PbD principles as cross-jurisdictional equivalence; paraphrased with attribution

### CCPA/CPRA

- **Source**: <https://oag.ca.gov/privacy/ccpa>
- **Modifications**: Mapped to PbD principles as cross-jurisdictional equivalence; paraphrased with attribution
