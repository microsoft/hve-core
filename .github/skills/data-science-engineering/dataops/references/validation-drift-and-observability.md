---
title: Validation, drift, and observability boundaries
description: The data-validation versus data-drift distinction with its correct source, the asymmetric remediation each triggers, and the ownership seam for telemetry and classification
---

## Sources

* Microsoft CSE Code-with-Engineering-Playbook, [ML Model Production Checklist](https://microsoft.github.io/code-with-engineering-playbook/ml-and-ai-projects/ml-model-checklist/#how-will-incoming-data-quality-be-monitored), documentation licensed CC BY 4.0. This is the source of the validation-versus-drift distinction.
* Microsoft CSE Code-with-Engineering-Playbook, [Data and DataOps Fundamentals, Observability](https://microsoft.github.io/code-with-engineering-playbook/design/design-patterns/data-heavy-design-guidance/#observability), documentation licensed CC BY 4.0.
* Microsoft CSE Code-with-Engineering-Playbook, [Observability in Machine Learning](https://microsoft.github.io/code-with-engineering-playbook/observability/ml-observability/), documentation licensed CC BY 4.0.

Content below is derived from the upstream pages and has been changed. Term names are preserved as identifiers; the validation-versus-drift definitions, the remediation pair, and the practice list are paraphrased. `THIRD-PARTY-NOTICES` carries the attribution CC BY 4.0 requires. The validation-versus-drift distinction comes from the ML Model Production Checklist, not from the DataOps Fundamentals page or the testing page; cite the checklist for it.

## Validation and drift are different mechanisms

**Data validation catches data that is simply wrong.** Upstream illustrates it with a value sitting outside the range it should occupy.

**Data drift detection surfaces genuine movement in the data.** These shifts faithfully reflect the phenomenon under study rather than being mistakes in it. Upstream illustrates it with users' preferences changing over time.

Both are worth monitoring. They are not the same signal and they do not share a response.

Before classifying an observed shift as drift, rule out an upstream ingestion or schema defect. A shift caused by a defect is a validation issue wearing drift's clothing, and routing it to retraining trains the model on corrupt data.

## The remediation is asymmetric

| Signal           | What it means                              | What it triggers               |
|------------------|--------------------------------------------|--------------------------------|
| Validation issue | The values themselves are wrong            | Reroute and repair the data    |
| Drift            | The world changed and the data reflects it | Adapt the model, or retrain it |

This asymmetry is the practical point of the distinction. Collapsing both into "trigger investigation" loses it.

## Data-validation practices

Upstream names three data-validation best practices:

* Run automated data-quality tests at every stage of the pipeline.
* Send records that fail those tests to a separate store where they can be diagnosed and put right.
* Observe the data end to end across freshness, distribution, volume, schema, and lineage.

"Each stage" means each transformation boundary from Bronze onward. It does not authorize assertions at Bronze landing, which stays a faithful copy of the source so that replay remains possible. See [data-tiers-and-pipeline-invariants.md](data-tiers-and-pipeline-invariants.md) for that rationale.

The re-routing practice is the same behavior the DataOps guidance describes as sending failed records to a malformed-data store.

## Drift monitoring

Understanding whether production data differs significantly from training-phase data matters, as does confirming that distribution information can be obtained for incoming data. Drift monitoring can indicate when changes occur and what their character is, such as abrupt versus gradual, and can guide an effective adaptation or retraining strategy.

Upstream questions worth asking include which kinds of drift have been experienced or are expected, whether a drift-detection strategy exists and matches those expectations, whether anomalies in input data raise warnings, and whether an adaptation strategy exists.

## What ML observability does and does not supply

The Observability in Machine Learning page frames observability across experimentation and production. It names model experimentation and tuning, production, training and retraining, performance over time and data drift, and data versioning. Observable targets include code, model, and data changes, evaluation metrics, parameters, dataset versions, source and notebook snapshots, run output and logs, and production service observability.

That page is **silent** on:

* Data validation entirely, including checks, failure conditions, and remediation
* The validation-versus-drift comparison
* Drift thresholds, alerting, ownership, and automatic remediation
* Distinct data-quality or feature-distribution monitoring as separate concerns
* Metric naming, instrument types, units, and schemas

Use it for lifecycle framing and drift awareness. Do not ground validation rules or quantitative controls in it.

## Which signals matter

This skill selects the signals worth observing for data and model work. Upstream supports monitoring infrastructure, pipelines, and data, and specifically names the malformed record store as an area needing data monitoring.

Signal categories worth selecting:

* Records failing the Bronze-to-Silver validation boundary
* Validation stage cost
* Pipeline replay frequency, as evidence that idempotency is exercised
* Model serving latency
* Feature or input distribution shift

## Ownership seam

Selecting a signal is not the same as naming it. Respect these boundaries.

| Concern                                                                | Owner                            | This skill's relationship                                    |
|------------------------------------------------------------------------|----------------------------------|--------------------------------------------------------------|
| Metric naming pattern, instrument types, units, cardinality discipline | `telemetry-foundations`          | Conform. Do not invent names, instruments, or units here.    |
| PII in emitted telemetry                                               | `telemetry-foundations` denylist | Obey. A denylisted field cannot become a dimension.          |
| Data sensitivity classification and DPIA thresholds                    | `privacy-standards`              | Read the classification. **Never decide what is sensitive.** |
| Which data and model signals matter                                    | This skill                       | Own.                                                         |

Drift monitoring invites high-cardinality dimensions such as per-column,
per-feature, per-source, and per-record. Cardinality discipline belongs to
`telemetry-foundations`, the OpenTelemetry-aligned metric, trace, log, unit,
and PII-safe instrumentation skill; apply its rules rather than restating them
here.

## Upstream silence on thresholds

No page in this source set prescribes a drift threshold, an alerting policy, an ownership model, or an automatic remediation trigger. Thresholds are engagement-specific. State that plainly rather than supplying a number that would read as playbook-backed.
