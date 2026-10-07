---
title: Security Planning Reference Index
description: Navigation catalog for the Security Planning skill references.
---

# Security Planning Reference Index

This index is the entry point for the reusable security-planning skill. It summarizes durable planning, plan-drift, TM7, and Threat Dragon references shared by Security Planner, Security Reviewer, and Code Review.

## Reference catalog

| File                                                         | Purpose                                                                                                                           | Source basis                                                                                                |
|--------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------|
| [operational-buckets.md](operational-buckets.md)             | Bucket definitions, classification guidance, and GS overlay                                                                       | Operational bucket guidance from the Security Planner instruction set                                       |
| [stride-model.md](stride-model.md)                           | STRIDE methodology, AI extensions, risk matrix, and DFD guidance                                                                  | Security model guidance from the Security Planner instruction set                                           |
| [standards-cross-reference.md](standards-cross-reference.md) | Standards mapping and control references for bucket analysis                                                                      | Standards mapping guidance and existing shared security skills                                              |
| [nist-control-families.md](nist-control-families.md)         | NIST control-family references and AI RMF mapping                                                                                 | NIST mapping guidance from the planning instruction set                                                     |
| [data-classification.md](data-classification.md)             | Public-safe asset classification, sensitivity, and retention guidance                                                             | Threat-model schema extension for optional classification hints                                             |
| [threat-model-review.md](threat-model-review.md)             | Threat-model completeness checklist, PASS/INCOMPLETE verdict, and gap-list output                                                 | Reviewer checklist and Phase 6 gap-closure plan                                                             |
| [backlog-formats.md](backlog-formats.md)                     | Prioritization formats and work-item categories for security backlog handoff                                                      | Backlog handoff guidance from the Security Planner instruction set                                          |
| [drift-input-contracts.md](drift-input-contracts.md)         | Baseline extraction, normalized current-finding forms, evidence scope, and input-drift handling                                   | Repository-original plan-to-current-evidence correlation contract                                           |
| [drift-comparison-model.md](drift-comparison-model.md)       | Default exclusions, five-category evidence preconditions, matching order, and handoff signals                                     | Repository-original comparison model derived from the Security Planner and Reviewer contracts               |
| [drift-report-contract.md](drift-report-contract.md)         | Canonical report body and destination adaptations for direct use, Reviewer, Planner, and Code Review                              | Repository-original output contract                                                                         |
| [drift-worked-examples.md](drift-worked-examples.md)         | Synthetic baseline, finding, edge-case, and caller-regression scenarios                                                           | Repository-original behavior fixtures                                                                       |
| [tm7-generation.md](tm7-generation.md)                       | TM7 input schema, dual-output generation contract, mapping contract, template-profile guidance, CLI surface, and operator runbook | TM7 wire facts extracted from a genuine TMT reference export and verified against the tool's own serializer |
| [threat-dragon-generation.md](threat-dragon-generation.md)   | Threat Dragon v2.6.2 export contract: CLI surface, spec-to-native mapping, threat placement, canvas attributes, and validation    | Vendored Threat Dragon v2.6.2 schema and loader behavior verified against the pinned upstream release       |

## Usage notes

* Use this skill for durable planning and plan-drift knowledge, not for caller orchestration logic.
* Keep instruction files thin and delegate detailed reference lookups to the skill references.
* Prefer shared skills such as `owasp-top-10`, `owasp-llm`, and `backlog-templates` when the content already exists there.
* Use the drift references only with caller-supplied current-state findings; they do not replace security assessment or finding verification.

## Attribution

This skill consolidates content previously scattered across Security Planner instruction files and intentionally avoids duplication of the shared security skills already maintained elsewhere in the repository.

Upstream sources summarized by this reference set, each cited in the file that summarizes it:

| Upstream source                                                         | License class                       | Reference file                 |
|-------------------------------------------------------------------------|-------------------------------------|--------------------------------|
| STRIDE threat model (Microsoft SDL)                                     | Microsoft Learn documentation terms | `stride-model.md`              |
| Microsoft Purview sensitivity labels and data classification categories | Microsoft Learn documentation terms | `data-classification.md`       |
| Open Threat Model (OTM)                                                 | CC BY-SA 4.0                        | `tm7-generation.md`            |
| OWASP Threat Dragon v2.6.2 JSON schema                                  | Apache-2.0                          | `threat-dragon-generation.md`  |
| NIST SP 800-53 control families                                         | Public domain (17 U.S.C. § 105)     | `nist-control-families.md`     |
| OWASP, NIST, and MITRE cross-references                                 | See each entry                      | `standards-cross-reference.md` |

Original content in this skill is licensed under the repository's license.
