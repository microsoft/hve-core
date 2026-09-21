---
title: Threat Model Completeness Review
description: Public checklist and verdict format for reviewing whether a threat-model spec satisfies the schema-backed completeness requirements.
ms.date: 2026-08-05
ms.topic: reference
---

# Threat Model Completeness Review

This reference defines a public, schema-backed checklist for reviewing threat-model completeness. It is intended for the planner or reviewer flow that evaluates whether a threat-model spec includes the evidence needed to be considered review-ready.

## Machine-checkable checklist

The checklist below is keyed to the schema fields documented in the TM7 generation reference. A reviewer can evaluate each item directly from the relevant fields in the threat-model spec.

| ID      | Check                                                                                  | Schema fields                                                                                                                                                             | Pass condition                                                                                                                                                                 |
|---------|----------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| RGAP-01 | Context, functional, and operational representations are present.                      | `representations.context_diagrams`, `representations.functional_scenarios`, `representations.operational_views`                                                           | All three collections contain at least one entry.                                                                                                                              |
| RGAP-02 | Every data flow carries the required metadata.                                         | `data_flows[].ordinal`, `data_flows[].transport`, `data_flows[].encryption`, `data_flows[].authentication`, `data_flows[].authorization`, `data_flows[].data_sensitivity` | Every flow entry has each field present and non-empty.                                                                                                                         |
| RGAP-03 | Every threat is reviewable and traceable.                                              | `threats[].state`, `threats[].target_ref`, `threats[].mitigation_ids` or explicit justification                                                                           | Every threat has `state` and `target_ref`; each has at least one linked mitigation or a clear rationale for why none is required.                                              |
| RGAP-04 | Abuse cases and linked security evidence are present.                                  | `abuse_cases[]`, `abuse_cases[].evil_user_story`, `abuse_cases[].flow_ids`, `abuse_cases[].mitigation_ids`, `security_test_cases[]`                                       | Each abuse case includes an evil user story and links to at least one flow and one mitigation; when a case is actionable, it maps to at least one relevant security test case. |
| RGAP-05 | Security test cases cover the required classes.                                        | `security_test_cases[].test_type`, `security_test_cases[].expected_result`                                                                                                | The set includes at least one case for each of `negative-input`, `malformed-message`, `multi-step-logic`, and `authorization`, and each has an expected result.                |
| RGAP-06 | Diagram elements and flows are anchored to threats or explicitly marked as non-threat. | threat `target_ref` values, `data_flows[]`, and representation element references                                                                                         | Every diagram element or flow referenced in the model is either cited by at least one threat or carries an explicit `no threat` justification.                                 |
| RGAP-07 | Threat semantics and TM7 placement are coherent.                                       | `threats[].target_ref`, `threats[].interaction_ref`, optional `threats[].placement_override`                                                                              | Each semantic target is a source or target endpoint of its placement interaction. A non-endpoint placement has `placement_override.reviewed: true` and a non-empty rationale.  |
| RGAP-08 | An authored base reconciles with the portable specification when one is supplied.      | representation surface ownership, `data_flows[]`, and authored TM7 surfaces, elements, and connectors                                                                     | Each required connector exists on the expected surface, has non-null GUIDs, and connects the authored identities corresponding to the declared source and target.              |

## Verdict format

Return one verdict for the model:

```text
PASS
- No gaps detected.

INCOMPLETE
- RGAP-02: Flows flow-03 and flow-07 are missing `encryption`.
- RGAP-05: No case of type `authorization` is present.
```

Use `PASS` when every applicable checklist item passes. Use `INCOMPLETE` when one or more applicable items fail. Emit only the failing item IDs, keyed to the checklist above. Record a conditional item whose precondition is absent as `N/A` with the reason, and treat it as neither a pass nor a failure.

## Review notes

* INCOMPLETE handling follows the existing autonomy tier of the agent that is performing the review.
* RGAP-01 through RGAP-07 are portable specification checks. RGAP-08 is conditional and applies only when the workflow supplies an authored TM7 base.
* Internal review-gate steps such as uploading the artifact to an internal portal or scheduling an internal review are not part of this public checklist. Those steps belong in a private overlay referenced by `state.overlayConfigPath`.
