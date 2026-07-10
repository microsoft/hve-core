---
name: rai-standards
description: "Consolidated Responsible AI standards reference: NIST AI RMF 1.0, AI STRIDE threat-modeling overlay, EU AI Act risk tiers, and an open-standards catalog with phase mapping"
license: mixed
user-invocable: false
metadata:
  authors: "NIST (AI RMF, public domain); EU (AI Act, paraphrased with attribution); Microsoft (AI STRIDE overlay)"
  spec_version: "NIST AI 100-1 v1.0; EU AI Act 2024/1689"
  last_updated: "2024"
  content_based_on: "https://doi.org/10.6028/NIST.AI.100-1; https://eur-lex.europa.eu/eli/reg/2024/1689"
---

# RAI Standards Skill

This skill is the reusable standards package for the RAI Planner. It consolidates the embedded NIST AI RMF content, the AI STRIDE threat-modeling overlay, and a paraphrased EU AI Act reference so the phase playbook can stay focused on workflow and orchestration.

## Attribution and licensing posture

- NIST AI RMF 1.0 is a U.S. Government document and is reproduced here as public-domain reference material with attribution.
- EU AI Act content in this skill is paraphrased and attributed rather than quoted verbatim, consistent with the open legal-text posture used in the repository.
- The AI STRIDE overlay is Microsoft-authored reference material for threat-modeling reuse in the RAI workflow.

## Framework index

- [NIST AI RMF - Govern](references/nist-ai-rmf-govern.md)
- [NIST AI RMF - Map](references/nist-ai-rmf-map.md)
- [NIST AI RMF - Measure](references/nist-ai-rmf-measure.md)
- [NIST AI RMF - Manage](references/nist-ai-rmf-manage.md)
- [AI STRIDE overlay](references/ai-stride-overlay.md)
- [EU AI Act overview](references/eu-ai-act.md)

## NIST AI RMF trustworthiness characteristics

| Key                      | Characteristic                 | Description                                                        |
|--------------------------|--------------------------------|--------------------------------------------------------------------|
| validReliable            | Valid and Reliable             | Base characteristic for correctness, robustness, and stability     |
| safe                     | Safe                           | Safety and harm prevention under normal and adversarial conditions |
| secureResilient          | Secure and Resilient           | Resistance to attack, misuse, and failure                          |
| accountableTransparent   | Accountable and Transparent    | Governance, auditability, and decision provenance                  |
| explainableInterpretable | Explainable and Interpretable  | Understandability of model behavior and outputs                    |
| privacyEnhanced          | Privacy-Enhanced               | Protection of personal data and confidentiality                    |
| fairBiasManaged          | Fair with Harmful Bias Managed | Bias detection, mitigation, and equitable outcomes                 |

## Phase-to-framework mapping

| RAI phase                       | Primary standards package      | Notes                                                      |
|---------------------------------|--------------------------------|------------------------------------------------------------|
| Phase 1 Scoping                 | NIST AI RMF Govern + Map       | Context, purpose, stakeholders, and policy framing         |
| Phase 2 Risk Classification     | NIST AI RMF Govern             | Governance culture, DEI&A, and stakeholder engagement      |
| Phase 3 Standards Mapping       | NIST AI RMF Govern + Measure   | Core standards mapping and TEVV alignment                  |
| Phase 4 Security Model Analysis | AI STRIDE overlay + Measure    | Threat modeling and overlap with security analysis         |
| Phase 5 Impact Assessment       | NIST AI RMF Manage             | Risk prioritization, mitigation, and monitoring            |
| Phase 6 Review and Handoff      | NIST AI RMF Manage + EU AI Act | Regulatory review, incident response, and evidence handoff |

## Customer extension pattern

The default framework remains NIST AI RMF 1.0. When a customer supplies an additional framework, preserve the default NIST mapping as a baseline and layer the custom framework on top with explicit attribution. This keeps the planner interoperable while allowing organizations to add ISO, sector, or regional references without rewriting the core playbook.

## Open-standards catalog

Use the links below as the reference catalog for open standards and governance resources. Do not reproduce normative text verbatim when the license posture does not allow it.

- NIST AI RMF 1.0: https://doi.org/10.6028/NIST.AI.100-1
- EUR-Lex EU AI Act: https://eur-lex.europa.eu/eli/reg/2024/1689
- ISO/IEC 42001 (AI management systems): https://www.iso.org/standard/81230.html
- ISO/IEC 23894 (AI risk management): https://www.iso.org/standard/77304.html
- ISO/IEC 42005 (AI impact assessment): https://www.iso.org/standard/88144.html
