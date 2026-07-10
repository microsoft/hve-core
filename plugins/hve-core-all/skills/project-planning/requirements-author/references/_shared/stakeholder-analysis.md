---
description: 'Stakeholder identification and engagement vocabulary for the BRD Builder - Mendelow Power/Interest grid and RACI accountability variants'
---

# Stakeholder Analysis — Skill Entry

## Overview

This skill establishes how the BRD Builder identifies, classifies, and engages the people and groups whose needs, authority, or operational involvement shape a business initiative. It covers three complementary patterns:

* the Mendelow Power/Interest grid for engagement strategy;
* RACI and its widely used variants for accountability assignment;
* IIBA BABOK v3 through the central cite-only standards registry for broader business-analysis vocabulary.

The skill is consumed by:

* the `BRD Author` skill (Discover-phase stakeholder capture and Define-phase accountability mapping);
* the BRD Builder agent's Discover-phase stakeholder coaching (when surfacing missing voices or unclear ownership during interviews);
* the BRD-phase instruction files for Discover and Define.

This file is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). External frameworks listed in the [cite-only registry](#cite-only-registry) are referenced by name and clause only; their prose is not embedded.

## When to Apply

Apply this skill in the following situations:

* Building the Discover-phase stakeholder roster (Primary / Secondary / Hidden) and choosing how each cohort is engaged through the BRD cycle.
* Deciding whether an identified party should be interviewed, kept informed, monitored, or treated as a sign-off authority.
* Assigning accountability for a business requirement, process step, decision, or downstream artifact.
* Resolving accountability ambiguity surfaced by the quality rubric (for example, multiple `Accountable` parties on the same item, or a `Responsible` party without a named `Accountable` party).
* Pointing a reader at the canonical industry vocabulary for stakeholder analysis without redistributing third-party prose.

## Pattern Selector

The BRD Builder picks one of the three patterns below based on the question being answered. Each row lists the canonical reference in this skill.

| Question being answered                                                     | Pattern                                   | Reference                                                          |
|-----------------------------------------------------------------------------|-------------------------------------------|--------------------------------------------------------------------|
| How should we engage this stakeholder cohort across the BRD cycle?          | Mendelow Power/Interest grid              | [mendelow-matrix.md](mendelow-matrix.md)                           |
| Who is accountable, responsible, consulted, or informed for this item?      | RACI (or a variant: RASCI, RACI-VS, DACI) | [raci-patterns.md](raci-patterns.md)                               |
| Where does the broader BA vocabulary for stakeholders live authoritatively? | IIBA BABOK v3 (cite-only)                 | [standards-excerpts.md](standards-excerpts.md#iiba-babok-guide-v3) |

The three patterns are complementary. A given stakeholder typically has a Mendelow quadrant assignment that drives engagement cadence and a RACI letter (or variant) for each requirement, decision, or process step they touch. BABOK is named when a reader asks for the upstream definition of the vocabulary; its text is never embedded.

## Pattern Summaries

### Mendelow Power/Interest Grid

A two-axis grid that places each stakeholder against their `power` to affect the initiative and their `interest` in its outcome, yielding four engagement quadrants. Original HVE-Core captions accompany each quadrant in [mendelow-matrix.md](mendelow-matrix.md) and are the source of the action guidance the BRD Builder emits.

Use the grid to set engagement cadence (interview depth, review involvement, sign-off authority) per cohort, and to surface the `Hidden` tier of stakeholders whose high power and low current interest can derail an initiative late in the cycle.

### RACI and Variants

A matrix that assigns one or more accountability letters per stakeholder per item. The BRD Builder enforces the canonical RACI rules (exactly one `Accountable`; one or more `Responsible`; zero or more `Consulted` and `Informed`) and supports four widely used variants tabulated in [raci-patterns.md](raci-patterns.md):

* RACI - Responsible, Accountable, Consulted, Informed.
* RASCI - adds `Support`.
* RACI-VS - adds `Verifier` and `Signatory`.
* DACI - decision-focused (Driver, Approver, Contributor, Informed).

The variant is selected per partition based on whether the matrix records day-to-day execution (RACI / RASCI), formal review and sign-off (RACI-VS), or decision rights (DACI). The default is RACI.

### BABOK v3 (Cite-Only)

The IIBA Business Analysis Body of Knowledge v3 is the canonical industry reference for stakeholder analysis vocabulary. Per [standards-excerpts.md](standards-excerpts.md#iiba-babok-guide-v3), the BRD Builder names BABOK and links to the publisher when a reader asks for the upstream definition; no BABOK text is embedded.

## Cite-Only Registry

The frameworks below are referenced by the BRD Builder by name only. Their text is not embedded in this repository. When the workflow needs to point a reader at a source, it links to the upstream publisher.

* IIBA BABOK v3 - Business Analysis Body of Knowledge, Stakeholders and Stakeholder Analysis vocabulary. See [standards-excerpts.md](standards-excerpts.md#iiba-babok-guide-v3).
* PMI *Business Analysis for Practitioners* - PMI BA Practice Guide, stakeholder identification and engagement planning. Referenced by name only; no embedded text.

DO NOT QUOTE prose definitions, lists, or tables from any framework above. When a paraphrase is needed, write it as original Microsoft content and cite the framework by name.

## Decision Tree

Use this quick-select when a stakeholder question arises:

1. Are we deciding how to engage a stakeholder cohort across the BRD cycle? If yes, place them on the Mendelow grid and apply the quadrant caption.
2. Are we assigning accountability for a specific requirement, process step, or decision? If yes, use a RACI (or variant) row and enforce the one-`Accountable` rule.
3. Is the matrix recording a one-off decision rather than ongoing execution? If yes, use DACI.
4. Does the matrix need an explicit reviewer or sign-off authority distinct from the accountable owner? If yes, use RACI-VS.
5. Does the matrix need to record supporting parties who do work without owning it? If yes, use RASCI.
6. Is a reader asking for the canonical industry definition of a term? If yes, point them at the BABOK pointer and link out.

## References

Internal:

* [mendelow-matrix.md](mendelow-matrix.md) - Power/Interest grid with original HVE-Core engagement captions.
* [raci-patterns.md](raci-patterns.md) - RACI, RASCI, RACI-VS, and DACI variants tabulated with definitions and selection guidance.
* [standards-excerpts.md](standards-excerpts.md) - Cite-only registry for IIBA BABOK v3 and related standards.
* [`requirements-definition`](requirements-definition.md) - Foundational requirements vocabulary (FR / AC / NFR / CON / BR) used alongside stakeholder assignments.
* [`traceability-naming`](traceability-naming.md) - Identifier schema used to anchor RACI rows to requirements, decisions, and processes.

External (cite-only, no embedded text):

* IIBA BABOK v3 - [https://www.iiba.org/standards-and-resources/babok/](https://www.iiba.org/standards-and-resources/babok/)
* PMI Business Analysis for Practitioners - [https://www.pmi.org/standards/business-analysis](https://www.pmi.org/standards/business-analysis)

## License

Original content in this skill is licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), copyright (C) Microsoft Corporation. Third-party frameworks listed in the [cite-only registry](#cite-only-registry) are referenced by name only and remain the property of their respective rights holders.


