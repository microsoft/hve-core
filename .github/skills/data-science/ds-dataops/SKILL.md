---
name: ds-dataops
description: "DataOps and DS/MLOps testing reference for data tiering, Bronze-to-Silver validation placement, pipeline invariants, pytest categories, and validation-versus-drift. Use when designing, reviewing, or generating data pipelines, transformation code, data validation, or data-science test suites."
license: CC-BY-4.0
user-invocable: false
metadata:
  authors: "Microsoft (Code With Engineering Playbook); Microsoft (planning synthesis)"
  spec_version: "1.0"
  last_updated: "2026-08-01"
  content_based_on: "https://microsoft.github.io/code-with-engineering-playbook/design/design-patterns/data-heavy-design-guidance/; https://microsoft.github.io/code-with-engineering-playbook/ml-and-ai-projects/testing-data-science-and-mlops-code/; https://microsoft.github.io/code-with-engineering-playbook/ml-and-ai-projects/ml-model-checklist/; https://microsoft.github.io/code-with-engineering-playbook/observability/ml-observability/"
---

# DataOps Reference Pack

## Goal

Ground pipeline and test generation in the Microsoft CSE engineering playbook so that data tier semantics, validation placement, recovery invariants, and DS/MLOps test technique are applied consistently and attributed accurately.

## Inputs

* The pipeline, transformation, validation, or test work under discussion
* The tier of each dataset involved, when the consuming workflow records one
* Existing test layout, package structure, and data-access boundaries
* A data classification produced elsewhere, when sensitivity matters

## Reference index

Read only the reference that matches the active concern.

| Reference                                                                                 | Read this when                                                                                                                                                     |
|-------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [data-tiers-and-pipeline-invariants.md](references/data-tiers-and-pipeline-invariants.md) | Assigning tier meaning, placing validation, routing malformed records, or asserting replay, idempotency, testability, source-control, and configuration invariants |
| [testing-data-science-and-mlops.md](references/testing-data-science-and-mlops.md)         | Writing or reviewing tests for data loading, transformation, model load or predict, data validation, or model robustness                                           |
| [validation-drift-and-observability.md](references/validation-drift-and-observability.md) | Distinguishing data validation from drift detection, choosing remediation, or deciding which data and model signals matter                                         |
| [provenance.md](references/provenance.md)                                                 | Confirming what is upstream guidance, what is HVE Core derivation, and where upstream is silent                                                                    |

## Success criteria

* Tier language distinguishes the three upstream quality tiers from the additional storage areas.
* Validation is placed at the Bronze-to-Silver boundary, and the faithful-copy rationale with both replay purposes travels with that placement whether or not the request challenges it.
* Test guidance names the operation category, its technique, and where mocking stops.
* Validation and drift keep their distinct definitions and their distinct remediation paths.
* Every claim traces to an attributed upstream source or is labelled as HVE Core guidance.

## Constraints

* This skill generates code, assertions, and review guidance. It does not execute pipelines, transformation engines, or telemetry backends.
* Reproduce only the minimum text necessary for a specific technical point, and paraphrase everything else. Attribute every reference and describe accurately what each reference reproduces.
* Label HVE Core derivations as such. Do not present a derived consequence or a repository convention as upstream guidance.
* Where upstream is silent, say so rather than inventing an upstream-sounding rule.

## Ownership boundaries

This skill decides *which* data and model signals matter. It does not own the vocabulary, the classification, or the surrounding workflow.

| Concern                                                                                      | Owner                   |
|----------------------------------------------------------------------------------------------|-------------------------|
| Metric names, instrument types, units, cardinality discipline, and the PII emission denylist | `telemetry-foundations` |
| Data sensitivity classification and DPIA thresholds                                          | `privacy-standards`     |
| Entity semantics, relationships, and which tier a dataset is recorded as                     | The calling workflow    |
| Feasibility assessment and go/no-go recommendation                                           | The calling workflow    |

No repository artifact currently owns the last two rows. When the caller supplies neither, state the gap rather than deciding tier assignment or feasibility here.

This skill never decides what is sensitive. It reads a classification produced elsewhere.

## Stop rules

* Stop and route metric naming, units, and cardinality to
  `telemetry-foundations`, the OpenTelemetry-aligned vocabulary and
  instrumentation skill. Route data sensitivity to `privacy-standards`, the
  privacy classification and DPIA-threshold reference.
* Stop and state the gap when the request depends on guidance the playbook does not provide, such as a drift threshold or an alerting policy.
* Stop and offer the correct placement when asked to validate before Bronze landing, rather than complying or refusing without an alternative.

## Attribution

This pack declares `CC-BY-4.0` because both bodies of content it holds carry that license.

Source pages are Microsoft CSE Code With Engineering Playbook documentation licensed CC BY 4.0. The upstream project applies MIT through a separate `LICENSE-CODE` file to code samples only, which this pack does not reproduce. The references derive from those documentation pages and have been changed: upstream guidance is paraphrased, and only identifiers and structural names are carried across as facts. `THIRD-PARTY-NOTICES` carries the attribution CC BY 4.0 requires and states that the content has been changed. Each reference cites its own upstream URL and states what it reproduces.

Content labelled as HVE Core derivation is repository-original material under CC BY 4.0. See [provenance.md](references/provenance.md) for the consolidated source map and derivation labels.
