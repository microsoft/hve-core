---
title: Design Intent Record contract
description: Field contract for the human-authored Design Intent Record that declares what a surface must convey and binds each claim to the check that settles it
---

# Design Intent Record contract

A Design Intent Record states what a surface must convey and binds every claim to a check that settles it. It is human-authored, committed source in the consuming project at `design-intent/<surface-id>.intent.yaml`, and no generator rewrites it.

This reference names the fields an author must supply. It is a companion to the design intent verification section of the skill entry, which covers how a record is verified and what the outcomes mean.

## Record fields

| Field           | Required | Notes                                                                                               |
|-----------------|----------|-----------------------------------------------------------------------------------------------------|
| `schemaVersion` | Yes      | Fixed at `"1.1"`                                                                                    |
| `surfaceId`     | Yes      | Lower-kebab-case. Must equal the filename stem and a surface declared in `a11y-runtime.config.json` |
| `title`         | Yes      | Short human-readable name for the surface decision                                                  |
| `owner`         | Yes      | Accountable person or team                                                                          |
| `status`        | Yes      | `proposed`, `accepted`, or `retired`                                                                |
| `decidedOn`     | Yes      | ISO 8601 calendar date                                                                              |
| `decidedBy`     | Yes      | Non-empty list of people or roles                                                                   |
| `version`       | Yes      | Integer revision counter starting at 1                                                              |
| `intents`       | Yes      | Non-empty list; see below                                                                           |
| `tooling`       | No       | Note about the authoring or design tooling behind the decision                                      |
| `groundedIn`    | No       | Source references; identifiers and metadata only, never criterion prose                             |

## Intent fields

Each entry in `intents` declares one thing the surface must communicate.

| Field          | Required | Notes                                                |
|----------------|----------|------------------------------------------------------|
| `id`           | Yes      | `INT-` followed by three or more digits              |
| `conveys`      | Yes      | One sentence naming what the design must communicate |
| `rationale`    | Yes      | Original human reasoning. Never copied standard text |
| `audience`     | Yes      | Non-empty list of who depends on this                |
| `evidence`     | Yes      | `observed`, `reported`, or `assumed`                 |
| `binding`      | Yes      | Object carrying `state`                              |
| `expectations` | Yes      | Non-empty list; see below                            |

`binding.state` names an interaction state. `default` is every surface's implicit base state; any other value must be declared for that surface in `a11y-runtime.config.json`. Selectors stay canonical in the runtime config and are never copied into a record.

Note that when a surface declares any states, the harness runs those states rather than additionally running the implicit `default`. A record binding to `default` on such a surface will legitimately report `untested`.

## Expectation fields

Each entry in `expectations` binds one claim to the check that settles it.

| Field      | Required | Notes                                                                           |
|------------|----------|---------------------------------------------------------------------------------|
| `id`       | Yes      | `EXP-` followed by three or more digits                                         |
| `method`   | Yes      | See the method and assertion pairing below                                      |
| `assert`   | Yes      | An exact runtime probe id, or the literal `custom`                              |
| `detail`   | Yes      | What the check establishes, in the author's words                               |
| `criteria` | Yes      | Non-empty list of `framework:criterionId` references carrying no criterion text |
| `role`     | Yes      | `decides` or `informs`                                                          |
| `blocking` | Yes      | Boolean. Only a blocking expectation can fail a build                           |
| `override` | No       | Human-authoritative outcome; see below                                          |

### Pairing `method` with `assert`

These pairings are enforced, so a mismatch fails validation:

* `assert: probe-axe` requires `method: axe-auto`.
* Any other probe id requires `method: runtime-automation`.
* `assert: custom` is informational by default: `role: informs` and `blocking: false`.
* A user-invoked manual review path uses `assert: custom`, `role: decides`, and `blocking: true`. Without an override it remains uncovered; a complete passed or failed override settles it.

An expectation with `role: informs` can never be blocking.

### Human override

An `override` records a human verdict that no generator may alter. It requires `outcome`, `rationale`, `reviewedBy`, and `reviewedOn`. Use it where a person has established something automation cannot, such as a screen-reader review on a platform the harness cannot drive.

Authority constraints apply. `override` is always valid for `assert: custom` and is otherwise valid only on a deciding expectation (`role: decides`).

For a deciding custom expectation, the base observation is `untested`. A complete passed override settles it, a complete failed override blocks, and a missing override remains uncovered. Incomplete overrides are invalid under the schema. Manual review has no automatic expiry; users replace or remove it explicitly.

The override lives on the authored record and stays readable without any generated artifact. The verification artifact keeps its `outcome` field as the observed run result and never merges the override into it. It also emits `effectiveOutcome`, which applies fail-safe precedence: either observed or human `failed` yields `failed`; human `passed` settles only `untested`, `cantTell`, or `inapplicable`; otherwise the observed outcome remains. `overrideConflict` is `true` only when observed and human outcomes are each `passed` or `failed` and differ.

A conclusive conflict fails the gate. The shipped `verify-intent` command returns design-intent drift and writes one `Warning:` line to stderr for each conflicting assertion, so CI cannot stay green while the artifact reports a current failure against an older human pass.

The shipped Python verifier rejects duplicate YAML keys, validates the complete authored schema, and enforces semantic checks for dates, filename and runtime-config bindings, duplicate identifiers, method pairing, and probe adequacy before writing an artifact. This repository's PowerShell validator independently enforces the same contract for source and generated-artifact validation.

## Version compatibility matrix

| Input or output       | Supported contract                 | CLI behavior                                                                                               | Migration and rejection behavior                                                                                       |
|-----------------------|------------------------------------|------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------|
| Authored record       | `schemaVersion: "1.1"`             | `verify-intent` accepts the record after schema and semantic validation                                    | Existing complete overrides remain valid and unchanged. Any other authored schema version fails before artifact write. |
| Verification artifact | `schemaVersion: "1.1"`             | The Python adapter emits 1.1 with observed `outcome`, fail-safe `effectiveOutcome`, and `overrideConflict` | The repository validator accepts 1.1. Any other verification schema version fails schema validation.                   |
| Manual review         | Existing 1.0 `override` object     | Passed review settles an unresolved observation; failed review blocks; no review remains uncovered         | No second object or automatic expiry is introduced. Users replace or remove the existing override explicitly.          |
| Conclusive conflict   | Authored 1.0 plus verification 1.1 | A blocking conflict returns design-intent drift and emits a warning                                        | A human pass never masks a current observed failure.                                                                   |

## Choosing what to declare

A record earns its place by capturing decisions a generic checker would never make. Restating a WCAG criterion adds ceremony without information; the criteria references already carry that.

Declare the claims that are specific to this surface: what the shape of a chart must communicate, which grouping the structure must preserve, what a state change must announce. Graphics and diagram meaning has no runtime probe, so those claims use `assert: custom` and resolve through recorded human review.
