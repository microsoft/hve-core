---
title: Data tiers and pipeline invariants
description: Bronze, Silver, and Gold tier semantics, Bronze-to-Silver validation placement, malformed routing, and the recovery and testability invariants that support them
---

## Source

Microsoft CSE Code-with-Engineering-Playbook, [Data and DataOps Fundamentals](https://microsoft.github.io/code-with-engineering-playbook/design/design-patterns/data-heavy-design-guidance/), documentation licensed CC BY 4.0. Content below is derived from that page and has been changed. Tier names, storage-area names, and artifact classes are preserved as identifiers; the definitions, the validation-placement rule, the replay rationale, and the surrounding guidance are paraphrased. `THIRD-PARTY-NOTICES` carries the attribution CC BY 4.0 requires. Statements labelled HVE Core are repository guidance, not playbook rules.

## The quality model has three tiers

Upstream describes a widely used data-quality model built from three tiers, and recommends partitioning the lake along them.

| Tier     | Definition                                                                                                                     | Optimized for        | Typical consumer             |
|----------|--------------------------------------------------------------------------------------------------------------------------------|----------------------|------------------------------|
| `bronze` | Landing zone for source data as received, with at most minimal shaping. Held immutable and append-only.                        | Writes and ingestion | Pipeline replay and recovery |
| `silver` | Cleaned, partly processed data meeting a declared schema and declared data invariants, and possibly carrying extra enrichment. | Analysis             | Data scientists              |
| `gold`   | Heavily processed data tuned for reads, usually laid out as conventional fact and dimension tables.                            | Reads                | Business users               |

## Three further storage areas are named, and they are not tiers

Upstream separately lists further areas worth keeping apart when a lake is organized: malformed data, intermediate sandbox data, and libraries, packages, and binaries.

These are storage areas, not members of the quality model. A workflow may record `malformed` or `sandbox` alongside the three tiers as a practical convenience, but describing five upstream tiers overstates the source.

## Validation belongs at the Bronze-to-Silver boundary

Check the data as soon as it is usable. Put validation on the hop from Bronze into Silver, so what arrives in Silver satisfies a named schema and the invariants declared for it. Screening at that point also keeps surprise changes in the incoming data from breaking the pipeline downstream.

Records that fail the check are diverted into a store set aside for malformed data, where they can be investigated.

### Why not before Bronze landing

Adding validation before data lands in Bronze is tempting and is explicitly not recommended upstream. Bronze earns its place by mirroring the source system as faithfully as it can, and that fidelity is what makes two different replays possible:

1. **Replay to test validation logic.** The pipeline can be re-run against a faithful source copy while validation rules are developed or corrected.
2. **Replay to recover from corruption.** When a bug in transformation code corrupts downstream data, the pipeline is replayed from the faithful copy after the fix is deployed.

Both purposes matter. Summarizing them as a single "replayability" benefit removes the reason a team cannot simply re-ingest from the source system.

### Refusal with alternative

When asked to place validation before Bronze landing, do not silently comply and do not refuse without a path forward. State the faithful-copy rationale and the two replay purposes, then offer the Bronze-to-Silver boundary with malformed-record routing as the correct placement.

## Pipeline invariants

### Replayability and idempotency

Make pipelines re-playable and idempotent. Silver and Gold data can be corrupted by unintended bugs or unexpected input changes; replayability allows recovery by deploying a code fix and re-running the pipeline. Idempotency ensures replay does not duplicate data.

### Transformation separated from data access

Ensure transformation code is testable. Abstracting transformation code away from data-access code is the key enabler for unit tests that target transformation logic. The upstream example of this separation is moving transformation code out of notebooks and into packages. Running tests against notebooks is possible, but extracting into packages speeds the feedback cycle and increases developer productivity.

### Source-control scope

Every artifact needed to build the pipeline from scratch belongs in source control:

* Infrastructure-as-code artifacts
* Database objects such as schema definitions, functions, and stored procedures
* Reference and application data
* Data pipeline definitions
* Data validation and transformation logic

New code entering the repository is reviewed both automatically, through linting and credential scanning, and by peers. Changes move through dev, test, and production via a safe, repeatable CI/CD process.

### Secure configuration

Sensitive configuration such as database connection strings lives in a central secure location, accessible to the appropriate services within a specific environment. On Azure this is typically a Key Vault per environment that services query at runtime.

### Observability includes data

Monitor infrastructure, pipelines, **and data**. Beyond base infrastructure and pipeline runs, the malformed record store is named as a common area that should have data monitoring. See [validation-drift-and-observability.md](validation-drift-and-observability.md) for the signal-selection boundary.

## Tier consequences (HVE Core)

Upstream defines the tiers and states one placement rule. It does not enumerate what each tier permits or forbids. The table below is HVE Core guidance derived from the upstream definitions, offered so tier assignment produces decidable behavior.

| Value       | Permitted                                                                    | Forbidden                                                                                            | Directly upstream-backed?                                                   |
|-------------|------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------|
| `bronze`    | Append-only ingestion; faithful source copy; origin for both replay purposes | Validation assertions at landing; in-place transformation; mutation that breaks faithful-copy status | The validation refusal is upstream. The remaining consequences are derived. |
| `silver`    | Schema conformance; declared invariants; augmentation; analysis consumption  | Marking complete without a declared schema and invariants; accepting unvalidated Bronze input        | Derived                                                                     |
| `gold`      | Read-optimized serving; fact and dimension shape                             | Presenting a renamed Silver table as Gold without read optimization or fact and dimension shape      | Derived                                                                     |
| `malformed` | Receiving validation failures; being treated as a monitored signal           | Being treated as a quality tier; being discarded rather than monitored                               | Routing and monitoring are upstream. Tier exclusion is derived.             |
| `sandbox`   | Exploratory and intermediate work                                            | Carrying downstream guarantees; being consumed as if Silver or Gold                                  | Derived                                                                     |

## Notebook-to-package extraction (HVE Core)

The invariant is upstream: move transformation logic out of notebooks and into packages so it can be unit tested. Upstream states no threshold.

Any trigger a workflow applies, such as a cell-length limit or duplicated transformation logic across cells, is a repository convention. Offer extraction to a package function with a matching test stub, and attribute the threshold to the convention rather than to the playbook.

## Derived dataset persistence and versioning (HVE Core)

Upstream sets the tier semantics and the replay invariant. The following storage conventions are repository guidance for curated and derived datasets produced during analysis work.

Persist curated or derived datasets in a columnar format rather than a row-oriented text format. Columnar storage preserves types across a write-and-read cycle, which text formats do not, and analysis reads are overwhelmingly column-selective.

Name a derived dataset so its content and lineage are readable from the filename:

```text
<entity>-<scope>-<transform>-v<major>.<minor>.<extension>
```

Use lowercase and hyphens throughout. Increment the minor version for an additive change that leaves existing columns and their meaning intact. Increment the major version when the schema changes in a way that could break a consumer: a removed column, a renamed column, a changed type, or a changed unit.

The distinction matters because consumers pin to what they read. An additive change is safe to pick up silently; a breaking change must be visible in the name so a stale consumer fails loudly rather than reading a column that no longer means what it did.

Derived datasets are not Bronze. They carry the guarantees of the tier they were produced from, and exploratory derivations belong in the sandbox area rather than in a tier that implies downstream guarantees.

## Adjacent guidance

Upstream also covers isolation levels and concurrency control on the same page: choose isolation levels deliberately, treat eventual consistency as a last resort behind batching, sharding, and caching, and prefer optimistic concurrency using a version increment or ETag over two-phase locking. This is relevant when the engagement touches transactional stores and is otherwise peripheral to pipeline work.
