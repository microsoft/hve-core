---
description: 'Versioned contract for seeding a BRD business goal, assumptions, and open questions from a committed outcome hypothesis'
---

# Outcome Hypothesis-to-BRD Handoff V1

`OUTCOME_HYPOTHESIS_TO_BRD_HANDOFF_V1` carries one validated outcome
hypothesis into BRD Discover. It preserves the source artifact and gives
requirements-author a complete, typed seed for one receiver-assigned
`BG-###` record.

## Eligibility

The producer emits a handoff only when:

* the complete outcome hypothesis has been presented and persisted with
  status `Committed`;
* the lagging indicator has a numeric baseline, numeric target, units,
  measurement period, measurement source, and owner;
* the goal statement includes the target and timeframe, and its lagging target
  exactly matches the indicator-table target;
* the timeframe is anchored to an event or date;
* the hypothesis passes its investability and assumption validation; and
* no required seed value contains `TBD`, `Unknown`, `Owner TBD`, `Date TBD`,
  or an empty value.

Draft, Provisional, and unpersisted hypotheses are ineligible. Draft and
Provisional are the producer's only non-committed states. Ineligibility does
not invalidate the hypothesis document. It only prevents BRD handoff.

`open_questions` may be empty. For every emitted question, the producer uses
the unique `Q1`-style source ID from the source template row and copies its
producer-owned values without inference. Placeholder values for an assumption
or emitted question are ineligible. Do not emit a fake `None` question or
invent a missing source ID, owner, or target date.

## Delivery boundary

After persistence, the producer computes the source hash, validates the
payload, and returns the YAML inline. It does not create a second artifact
unless the user explicitly requests and confirms a destination.

Requirements-author accepts the YAML inline or from a user-supplied artifact
path. It validates the payload before copying any value into the BRD. A failed
payload remains rejected structured input and is not reinterpreted as
unstructured evidence.

## Format

```yaml
schema_version: OUTCOME_HYPOTHESIS_TO_BRD_HANDOFF_V1
handoff_id: <SOURCE_ARTIFACT_STEM>-to-brd-<ISO_8601_BASIC_TIMESTAMP>
handoff_at: <ISO_8601_TIMESTAMP>
source:
  title: <HYPOTHESIS_TITLE>
  status: Committed
  authored_at: <ISO_8601_DATE>
  artifact_path: <WORKSPACE_RELATIVE_PATH>
  artifact_sha256: <LOWERCASE_SHA256>
business_goal_seed:
  statement: <MEASURABLE_GOAL_STATEMENT_WITH_TARGET_AND_TIMEFRAME>
  kpi: <LAGGING_INDICATOR_NAME_AND_DEFINITION>
  baseline:
    value: <NUMBER>
    unit: <UNIT>
    measurement_period: <PERIOD>
  target:
    value: <NUMBER>
    unit: <UNIT>
  timeframe: <EVENT_OR_DATE_ANCHORED_WINDOW>
  measurement_source: <LAGGING_KPI_SYSTEM_OR_DASHBOARD>
  owner: <NAMED_PERSON_OR_ROLE>
assumptions:
  - source_id: A1
    statement: <ASSUMPTION>
    evidence_status: <Untested|Partially supported|Evidenced>
    impact_if_false: <IMPACT>
open_questions:
  - source_id: Q1
    question: <QUESTION_OR_RESOLUTION_GAP>
    why_it_matters: <IMPACT>
    owner: <NAMED_PERSON_OR_ROLE>
    target_date: <ISO_8601_DATE>
```

## Field ownership

### Producer fields

| Payload field                           | Outcome hypothesis source                          |
|-----------------------------------------|----------------------------------------------------|
| `source.title`                          | Document title                                     |
| `source.status`                         | Document status                                    |
| `source.authored_at`                    | Persisted artifact's actual `ms.date`              |
| `business_goal_seed.statement`          | Complete expected-outcome statement                |
| `business_goal_seed.kpi`                | Lagging indicator name and definition              |
| `business_goal_seed.baseline`           | Lagging indicator baseline value, unit, and period |
| `business_goal_seed.target`             | Lagging indicator target value and unit            |
| `business_goal_seed.timeframe`          | Expected Outcomes `Within` clause                  |
| `business_goal_seed.measurement_source` | Lagging indicator source                           |
| `business_goal_seed.owner`              | Lagging indicator owner                            |
| `assumptions[]`                         | Assumptions table                                  |
| `open_questions[]`                      | Open Questions and Resolution Gaps template rows   |

### Computed fields

| Payload field            | Computation                                                         |
|--------------------------|---------------------------------------------------------------------|
| `handoff_id`             | Persisted source filename stem, `-to-brd-`, and UTC basic timestamp |
| `handoff_at`             | UTC ISO 8601 timestamp when the validated payload is returned       |
| `source.artifact_path`   | Workspace-relative path confirmed during persistence                |
| `source.artifact_sha256` | Lowercase SHA-256 of the persisted source bytes                     |

The contract does not define a hypothesis identifier family. Producers must
not invent a `hypothesis_id`.

### Receiver fields

Requirements-author owns:

* the next available `BG-###` identifier;
* MoSCoW priority;
* field-level `accepted` or `revised` dispositions;
* the current BRD value and revision rationale;
* assumption mitigation; and
* each BRD Open Question status.

## Validation rules

1. `schema_version` equals `OUTCOME_HYPOTHESIS_TO_BRD_HANDOFF_V1`.
2. `handoff_id` uses the persisted source filename stem and the
   `-to-brd-<ISO_8601_BASIC_TIMESTAMP>` suffix.
3. `handoff_at` is an ISO 8601 UTC timestamp.
4. `source.status` equals `Committed`.
5. `source.authored_at` is an ISO 8601 date.
6. `source.artifact_path` is workspace-relative.
7. `source.artifact_sha256` contains 64 lowercase hexadecimal characters.
8. Every `business_goal_seed` field is present and non-empty.
9. Baseline and target values are numeric and have non-empty units.
10. The baseline measurement period is non-empty.
11. The timeframe is anchored to an event or date.
12. The measurement source names the lagging KPI system, query, or dashboard.
13. The owner names a person or accountable role.
14. The target exactly matches the lagging target in the source artifact's
    canonical Expected Outcomes statement and indicator table.
15. Required seed fields reject placeholders, including `TBD`, `Unknown`,
    `Owner TBD`, and `Date TBD`.
16. `assumptions` contains three to seven entries with unique `source_id`
    values. Every producer-owned required field is present, non-placeholder,
    and copied from the source.
17. `open_questions` is present and may be empty. Every emitted entry has a
    unique `source_id` copied from a unique `Q1`-style template row, and every
    producer-owned field is present and non-placeholder. Each emitted
    `target_date` is ISO 8601 `YYYY-MM-DD`. Reject the handoff rather than
    inventing a missing ID, owner, or date, or emitting a placeholder or fake
    `None` row.

### Rejection examples

| Invalid input                                                                | Rejection                      |
|------------------------------------------------------------------------------|--------------------------------|
| `schema_version: OUTCOME_HYPOTHESIS_TO_BRD_HANDOFF_V2`                       | Unsupported schema version     |
| `source.status: Provisional`                                                 | Source is not committed        |
| Missing `business_goal_seed.baseline`                                        | Required seed field is absent  |
| `business_goal_seed.target.value: TBD`                                       | Target is not numeric          |
| Missing `business_goal_seed.measurement_source`                              | Measurement source is absent   |
| Source statement and indicator-table targets differ                          | Canonical target diverges      |
| Missing `business_goal_seed.owner`                                           | Required owner is absent       |
| `business_goal_seed.owner: Owner TBD`                                        | Owner is a placeholder         |
| A SHA-256 value containing uppercase or fewer than 64 hexadecimal characters | Source hash is invalid         |
| An emitted question lacks a `Q1`-style source ID from the template           | Open-question source is absent |
| An emitted question has `Owner TBD` or a non-ISO `target_date`               | Open-question value is invalid |

## BRD receipt

After validation, BRD Discover:

1. assigns the next stable `BG-###` identifier;
2. writes distinct statement, KPI, baseline, target, timeframe, measurement
   source, and owner values into the Business Goals section;
3. records each source value as `accepted` or `revised`;
4. records the current BRD value and a rationale for every revision;
5. maps assumptions into the Key Assumptions register and adds mitigation;
6. maps questions into Open Questions and initializes status to `Open` unless
   Discover explicitly confirms another BRD status; and
7. records the handoff ID, source path, source hash, measurement source, and
   every field disposition in the provenance subsection.

Discover cannot exit until every imported seed field has a disposition and
the receipt is internally consistent.

## Precedence

Before Discover accepts the handoff, the validated payload is authoritative
for imported seed values. Discover may explicitly accept or revise those
values. After Discover exits, the BRD is authoritative.

A later hypothesis change cannot mutate the BRD implicitly. It requires a new
validated handoff and explicit Discover re-entry, with a new receipt and
disposition record.

## Example

```yaml
schema_version: OUTCOME_HYPOTHESIS_TO_BRD_HANDOFF_V1
handoff_id: 2026-08-12-claims-cycle-time-outcome-hypothesis-to-brd-20260813T141500Z
handoff_at: "2026-08-13T14:15:00Z"
source:
  title: Reduce Claims Cycle Time
  status: Committed
  authored_at: "2026-08-12"
  artifact_path: docs/planning/outcome-hypotheses/2026-08-12-claims-cycle-time-outcome-hypothesis.md
  artifact_sha256: 9b74c9897bac770ffc029102a200c5de1f3a4d9f0ea2c95c3b56a17e1d5fa1c4
business_goal_seed:
  statement: Reduce average claim adjudication time by 30% within 12 months of launch.
  kpi: 30-day rolling average adjudication time
  baseline:
    value: 10
    unit: days
    measurement_period: trailing 90 days
  target:
    value: 7
    unit: days
  timeframe: within 12 months of launch
  measurement_source: Claims Operations adjudication dashboard
  owner: Claims Operations Lead
assumptions:
  - source_id: A1
    statement: Intake automation covers the highest-volume claim categories.
    evidence_status: Partially supported
    impact_if_false: Cycle-time improvement will be smaller than predicted.
  - source_id: A2
    statement: Review staffing remains stable during the measurement window.
    evidence_status: Untested
    impact_if_false: Staffing changes will confound attribution.
  - source_id: A3
    statement: The adjudication dashboard retains consistent event definitions.
    evidence_status: Evidenced
    impact_if_false: Baseline and post-launch measurements will not be comparable.
open_questions:
  - source_id: Q1
    question: Which claim categories should be excluded from the initial comparison?
    why_it_matters: Category mix could bias the measured cycle-time change.
    owner: Claims Analytics Lead
    target_date: "2026-09-15"
```
