---
description: 'RACI accountability matrix and its widely used variants (RASCI, RACI-VS, DACI) tabulated with letter definitions, selection guidance, and authoring rules used by the BRD Builder'
---

# RACI and Variants

A RACI matrix assigns one or more accountability letters per stakeholder per row, where each row is a requirement, process step, decision, or downstream artifact. RACI and its variants are generic project-management techniques in widespread industry use; no single publisher owns the construct. The tabulations, selection guidance, and authoring rules in this file are original Microsoft content.

## Canonical RACI

| Letter | Name        | Definition                                                                                                       |
|--------|-------------|------------------------------------------------------------------------------------------------------------------|
| R      | Responsible | The party that performs the work to complete the row. One or more per row.                                       |
| A      | Accountable | The single party answerable for the row being completed correctly. Exactly one per row.                          |
| C      | Consulted   | Parties whose two-way input is sought before the row is completed. Zero or more per row.                         |
| I      | Informed    | Parties who receive one-way notification after the row is completed or materially changes. Zero or more per row. |

Canonical rules enforced by the BRD Builder quality rubric:

* Every row has exactly one `A`. Two `A` letters on the same row is a defect; zero `A` letters is a defect.
* Every row has at least one `R`. A row with no `R` is a defect (no one is doing the work).
* `A` and `R` may be the same party, in which case the cell is marked `A/R`.
* `C` implies a real two-way conversation, not a notification. If only one-way notification is intended, use `I`.
* The same row should not list both `C` and `I` for the same party; choose one.

## Variants

The BRD Builder supports four variants beyond canonical RACI. Each variant adds or replaces letters; the canonical rules above carry through unchanged unless noted in the variant's row.

### RASCI

Adds `Support` between `Responsible` and `Consulted`.

| Letter | Name        | Definition                                                                            |
|--------|-------------|---------------------------------------------------------------------------------------|
| R      | Responsible | Same as canonical RACI.                                                               |
| A      | Accountable | Same as canonical RACI.                                                               |
| S      | Support     | Parties who provide resources, hand-offs, or auxiliary work to the `R`. Zero or more. |
| C      | Consulted   | Same as canonical RACI.                                                               |
| I      | Informed    | Same as canonical RACI.                                                               |

Use RASCI when the row's work depends on auxiliary parties whose contribution is more than `Consulted` (they perform sub-tasks) but who are not the primary `Responsible` party.

### RACI-VS

Adds `Verifier` and `Signatory` to canonical RACI.

| Letter | Name        | Definition                                                                                                             |
|--------|-------------|------------------------------------------------------------------------------------------------------------------------|
| R      | Responsible | Same as canonical RACI.                                                                                                |
| A      | Accountable | Same as canonical RACI.                                                                                                |
| C      | Consulted   | Same as canonical RACI.                                                                                                |
| I      | Informed    | Same as canonical RACI.                                                                                                |
| V      | Verifier    | Party that checks the completed work against the acceptance criteria before sign-off. Zero or one per row.             |
| S      | Signatory   | Party that authorizes release or hand-off after verification. Exactly one when the row carries a formal sign-off gate. |

Use RACI-VS when the BRD partition requires a formal verification step distinct from the `Accountable` owner (for example, compliance or QA verification) and a separate sign-off authority.

### DACI

Decision-focused variant. The matrix records who decides, not who executes.

| Letter | Name        | Definition                                                                                         |
|--------|-------------|----------------------------------------------------------------------------------------------------|
| D      | Driver      | Party that drives the decision to closure (frames the question, gathers input, calls the meeting). |
| A      | Approver    | Party with final decision authority. Exactly one per row.                                          |
| C      | Contributor | Parties whose input materially shapes the decision. Zero or more per row.                          |
| I      | Informed    | Parties notified of the decision after it is made. Zero or more per row.                           |

Use DACI when the row records a one-off decision rather than ongoing execution. Common BRD use: scope-boundary decisions, partition allocations, and prioritization-scheme selection.

## Variant Selection

The BRD Builder picks a variant per matrix based on what the matrix is recording.

| Recording                                                           | Variant |
|---------------------------------------------------------------------|---------|
| Day-to-day execution of a requirement, process step, or deliverable | RACI    |
| Execution where auxiliary supporting parties materially contribute  | RASCI   |
| Execution with a formal verification step and sign-off authority    | RACI-VS |
| A one-off decision rather than ongoing work                         | DACI    |

The default is RACI. A non-default variant is recorded in the matrix header so readers know which letter set applies.

## Authoring Rules

* One matrix per partition. Mixing variants in a single matrix is not allowed.
* Rows reference an identifier owned by [`traceability-naming`](traceability-naming.md). Free-text rows without an identifier are not allowed in the final BRD.
* Columns are stakeholders or stakeholder roles drawn from the Discover-phase stakeholder roster. Anonymous columns ("the team") are not allowed.
* Empty cells are valid and mean "no role for this stakeholder on this row". Empty cells are not a defect.
* When a stakeholder has the same role across every row of a matrix, the column is still listed; do not collapse it into a footnote.

## Pitfalls

* Two `Accountable` parties on the same row. Pick one; the second moves to `Consulted` or `Verifier`.
* Listing a stakeholder as both `C` and `I` on the same row. Pick one.
* Using `Consulted` when only one-way notification is intended. Use `I`.
* Using RACI on a one-off decision row. Use DACI; the asymmetry of `Driver` vs `Approver` is the reason DACI exists.
* Treating the matrix as a substitute for the Mendelow grid. RACI assigns accountability; engagement cadence is owned by the [Mendelow matrix reference](mendelow-matrix.md).

## License

This reference file is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). RACI and its named variants are generic project-management techniques in widespread industry use and are not the property of any single publisher.


