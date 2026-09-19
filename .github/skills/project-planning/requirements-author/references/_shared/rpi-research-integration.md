---
description: 'Shared bounded rpi-research activation, receipt, disposition, and source-authority contract for BRD and PRD authoring'
---

# Requirements Research Integration

## Purpose

Use `rpi-research` when a named BRD or PRD decision depends on bounded external evidence that the conversation, supplied references, and current requirements artifact do not provide. Research supplies evidence; the active builder retains lifecycle state, user decisions, requirement authority, and every phase gate.

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
* Explicit questions and evidence criteria.
* Market, jurisdiction, audience, product-version, source, and date boundaries that apply, plus non-goals.
* Regulatory, licensing, schedule, solution or product boundary, and user-confirmation constraints.
* Relevant conversation, document, state, requirements, stakeholder, and reference evidence.
* Requested outputs and an output mode of `analysis`, `comparison`, or caller-requested `convergence`.

Use the default Research evidence root. The builder does not create a second research artifact.

## Return and Authority

Read the completed primary research artifact before using any finding. Keep that artifact authoritative for research questions, evidence IDs, and Research disposition. The BRD or PRD remains authoritative for requirement wording and document decisions.

For every material finding used or considered by the builder:

1. Record the Research artifact and traceability receipt in session state.
2. Give the finding one document-owned disposition: `incorporated`, `revised`, `rejected`, `deferred`, or `retained-assumption`.
3. Record affected document sections or stable requirement IDs and the disposition rationale.
4. Preserve unresolved evidence as an open question or unvalidated assumption.

`Blocked` or `Needs clarification` Research cannot satisfy a lifecycle gate or support an evidence-dependent conclusion. Record the smallest unresolved gap and stop only the dependent work. If `rpi-research` or a required lookup capability is unavailable, do not replace it with training-data claims.

Research cannot approve a requirement, validate user need, grant signoff, override a signed-off BRD, issue a feasibility verdict, or choose a product decision reserved for the user or owning workflow.

## Session Receipt Contract

Initialize `researchReceipts` only when Research is first activated. Preserve unknown state fields and prior receipts. Each activation appends one receipt; later reconciliation updates that receipt rather than creating another receipt for the same gap and artifact.

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