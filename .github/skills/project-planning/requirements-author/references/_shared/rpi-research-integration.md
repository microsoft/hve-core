---
description: 'Shared segmented RPI depth-point, invocation-state, authority, and Research contract for BRD and PRD authoring'
---

# Requirements RPI Integration

## Purpose

Use an RPI segment at a designated builder-phase depth point when Research, dependency-ordered planning, or interruption-safe drafting materially improves the active BRD or PRD work. Each segment runs as its own RPI task and returns evidence to the active builder. The builder remains responsible for conversation, document artifacts, state, requirement decisions, quality review, and every lifecycle gate.

## Depth-Point Contract

Name depth points by builder phase rather than capability. One phase may offer more than one capability when each addresses a different demonstrated need.

| Builder depth point | Eligible capability                              | Demonstrated need                                                                                                      | RPI does not establish                                                   |
|---------------------|--------------------------------------------------|------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------|
| BRD Discover        | `rpi-research`                                   | A named external evidence gap affects a load-bearing assumption, constraint, stakeholder decision, or candidate metric | User need, stakeholder ownership, requirement approval, or Discover exit |
| BRD Define          | `rpi-plan`, then `rpi-implement`                 | Substantial authoring has dependencies, contested traceability, or material interruption risk                          | BRD structure, content quality, approval, or Define exit                 |
| PRD Discover        | `rpi-research`                                   | A named external evidence gap affects a target-user assumption or candidate success metric                             | Direct user evidence, product need, or Discover exit                     |
| PRD Build           | `rpi-research`; `rpi-plan`, then `rpi-implement` | A bounded current-fact gap affects content, or substantial authoring needs dependency and progress control             | Product authority, PRD structure, content quality, or Build exit         |

Keep simple or adequately evidenced work on the builder's direct path. No segment auto-activates. Before activation, tell the user:

* The active builder phase and demonstrated gap or work need.
* The proposed capability, purpose, expected artifact, and expected interaction cost.
* What the segment will not establish and which builder gate remains authoritative.
* The direct path available if the user adjusts, defers, rejects, or skips the segment.

Run each accepted capability activation as a distinct RPI task and invocation record. Use `<document-slug>-<document-kind>-<phase>-<sequence>` as the lower-kebab-case task slug, where `sequence` is a session-local, zero-padded monotonic number. Plan and Implement use different sequence values even when they serve the same builder phase. A revised or re-entered phase uses the next sequence and never reuses a task whose critique or Review budget was consumed.

`RPI Researcher` may isolate one bounded source-gathering lane when parallel or high-volume retrieval would crowd out the active `rpi-research` context. Its return is an unverified suggestion. The active Research phase reads every selected source and remains the sole owner of evidence IDs, findings, recommendations, decisions, and the primary Research artifact.

## Activation Boundary

Activate Research only when all of these conditions hold:

* One named market, regulatory, product, API, comparable-solution, or other external evidence gap affects a current BRD or PRD decision.
* The missing evidence cannot be resolved from the current document, conversation, or already processed references.
* The question can be bounded by audience, intended use, evidence criteria, source and date scope, non-goals, and constraints.

Do not activate Research for ordinary requirements elicitation, user confirmation, stakeholder ownership, or product discovery that requires direct user evidence. Adequate evidence skips Research.

## Research Brief

Provide `rpi-research` with:

* The named gap ID, topic, and BRD or PRD decision purpose.
* The stakeholders, authors, approvers, and intended document use.
* Stakeholder roles and register IDs instead of personal names when supplying stakeholder context to Research.
* Explicit questions and evidence criteria.
* Market, jurisdiction, audience, product-version, source, and date boundaries that apply, plus non-goals.
* Regulatory, licensing, schedule, solution or product boundary, and user-confirmation constraints.
* Relevant conversation, document, state, requirements, stakeholder, and reference evidence.
* Requested outputs and an output mode of `analysis`, `comparison`, or caller-requested `convergence`.

Pass the builder session directory as the trusted alternate Research evidence root. The builder does not create a second research artifact.

## Return and Authority

Read the completed primary research artifact before using any finding. Keep that artifact authoritative for research questions, evidence IDs, and Research disposition. The BRD or PRD remains authoritative for requirement wording and document decisions.

For every material finding used or considered by the builder:

1. Record the Research artifact and traceability receipt in session state.
2. Give the finding one document-owned disposition: `incorporated`, `revised`, `rejected`, `deferred`, or `retained-assumption`.
3. Record affected document sections or stable requirement IDs and the disposition rationale.
4. Preserve unresolved evidence as an open question or unvalidated assumption.

`Blocked` or `Needs clarification` Research cannot satisfy a lifecycle gate or support an evidence-dependent conclusion. Record the smallest unresolved gap and stop only the dependent work. If `rpi-research` or a required lookup capability is unavailable, do not replace it with training-data claims.

Research cannot approve a requirement, validate user need, grant signoff, override a signed-off BRD, issue a feasibility verdict, or choose a product decision reserved for the user or owning workflow.

For a returning Plan or Implement segment, read the canonical artifact before using its result. A Plan sequences authoring work and dependencies without replacing the BRD or PRD template. Implement tracks drafting against an approved same-phase Plan without issuing a content-quality verdict. Plan and Implement have separate invocation IDs and task slugs; the Implement entry identifies its accepted Plan entry through `dependsOnInvocationId`. The existing BRD or PRD Quality Reviewer remains the sole content-quality verdict owner.

Record the user's return disposition as `accepted`, `revised`, `rejected`, `deferred`, or `not-required`. Record the segment's gate relationship separately as `supports`, `does-not-satisfy`, or `not-applicable`. A segment supplies evidence to the builder but never owns the builder's gate verdict.

## Invocation State Contract

Initialize `rpiInvocations` only when the first segmented activation is proposed. Preserve unknown state fields, existing `researchReceipts`, and prior invocations. Existing `researchReceipts` remain readable and continue to project into the document; do not delete, migrate, or duplicate them. Every new capability activation appends exactly one `rpiInvocations` entry, and later reconciliation updates that entry rather than appending another for the same invocation. A Research entry is the canonical receipt for a new Research activation.

The following field names and values are binding:

```json
{
  "rpiInvocations": [
    {
      "invocationId": "discover-01",
      "phase": "discover",
      "capability": "rpi-research|rpi-plan|rpi-implement",
      "taskSlug": "claims-automation-brd-discover-01",
      "dependsOnInvocationId": null,
      "gapId": "stable-builder-gap-id",
      "questionIds": ["Q1"],
      "evidenceIds": ["C1"],
      "artifactPaths": {
        "research": "",
        "plan": "",
        "critique": "",
        "changes": ""
      },
      "segmentStatus": "proposed|running|completed|blocked|skipped|unresolved",
      "userDisposition": "accepted|revised|rejected|deferred|not-required",
      "gateEffect": "supports|does-not-satisfy|not-applicable",
      "outcome": "human-readable result",
      "notEstablished": "",
      "findingDispositions": [
        {
          "evidenceIds": ["C1"],
          "affectedTargets": ["BRD or PRD section or requirement ID"],
          "disposition": "incorporated|revised|rejected|deferred|retained-assumption",
          "rationale": "document-owned reason"
        }
      ],
      "unresolvedItems": []
    }
  ]
}
```

Field rules:

* `invocationId` is stable within one builder session and combines the phase with its sequence.
* `phase` uses the owning builder's phase name rather than a capability name.
* `capability` identifies the activated RPI entry point. A Plan's mandatory critique is recorded in `artifactPaths.critique`, not as another invocation.
* `taskSlug` is unique to the activation and follows the depth-point slug convention.
* `dependsOnInvocationId` is `null` unless this capability consumes another invocation. An Implement entry names the accepted same-phase Plan invocation it executes.
* `gapId` is stable for the builder-owned gap or authoring need.
* `questionIds` and `evidenceIds` contain the exact stable identifiers from a Research artifact. Use empty arrays for non-Research capabilities; never infer or renumber identifiers during reconciliation.
* `artifactPaths` is capability-keyed. `rpi-research` may use the builder session directory as a trusted alternate root. Plan, Critique, Implement, Review, and Challenge retain their canonical `.copilot-tracking` roots; the builder stores pointers rather than relocating those artifacts.
* `segmentStatus` records lifecycle state. `completed` records execution only and does not imply user acceptance or gate satisfaction.
* `userDisposition` records the user's decision about the returned work. `completed` may pair with any value except `not-required`.
* `gateEffect` records only the segment's relationship to the owning phase gate. `blocked` and `unresolved` always use `does-not-satisfy`. `skipped` uses `not-applicable` only when the builder records adequate alternate evidence or no material gap; otherwise it uses `does-not-satisfy` and preserves the unresolved item. A completed segment normally uses `supports` or `not-applicable`.
* `outcome` is a concise result, not a copied artifact body.
* `notEstablished` carries the segment's limits with the invocation.
* `findingDispositions` retains the existing Research disposition shape so document projection remains stable. Use an empty array for non-Research capabilities.
* `unresolvedItems` contains concise gap identifiers or questions, not duplicated evidence bodies.

## Legacy Research Receipt Compatibility

Preserve unknown state fields and prior `researchReceipts`. Do not initialize or append this legacy array for a new Research activation; the `rpiInvocations` Research entry is its canonical receipt. When resuming an activation represented only by a legacy receipt, keep it readable and update that receipt in place rather than creating a duplicate invocation or receipt.

```json
{
  "researchReceipts": [
    {
      "gapId": "stable-builder-gap-id",
      "artifactPath": ".copilot-tracking/research/YYYY-MM-DD/task-research.md",
      "researchDisposition": "executed|reused|satisfied-and-skipped",
      "questionIds": ["Q1"],
      "evidenceIds": ["C1"],
      "findingDispositions": [
        {
          "evidenceIds": ["C1"],
          "affectedTargets": ["BRD or PRD section or requirement ID"],
          "disposition": "incorporated|revised|rejected|deferred|retained-assumption",
          "rationale": "document-owned reason"
        }
      ],
      "unresolvedItems": []
    }
  ]
}
```

Field rules:

* `gapId` is stable within one builder session.
* `artifactPath` is the workspace-relative primary Research artifact path.
* `questionIds` and `evidenceIds` preserve the Research artifact's identifiers without copying its prose.
* `findingDispositions` contains one row for every material finding the builder considered.
* `affectedTargets` uses document section names or stable requirement IDs when they exist.
* `unresolvedItems` contains concise gap identifiers or questions, not duplicated evidence bodies.

## Document Projection

Project the receipt into the BRD or PRD Research Finding Dispositions table. The document table is the human-readable decision record; state retains resumable pointers and machine-shaped fields.

Keep feasibility candidate dispositions separate. A feasibility handoff proposes requirement candidates through its own contract, while ordinary Research findings support or challenge document decisions.

Do not copy complete Research findings into `BRD_TO_PRD_HANDOFF_V1`. The handoff already binds the authoritative BRD by path and SHA-256. A new handoff version requires a demonstrated downstream consumer that cannot use the bound BRD and its Research disposition table.

## License

This reference is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).