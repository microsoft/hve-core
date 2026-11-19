---
description: 'Decision aid for adding process, decision, and structural diagrams to a BRD with notation guidance (BPMN / DMN / UML) and a Mermaid-first format selector'
---

# Process Modeling — Skill Entry

## Overview

This skill tells the BRD Builder when a written requirement is better expressed (or supplemented) by a diagram, which industry notation family the diagram belongs to, and which rendering format to embed in the BRD markdown. It defers all syntactic and metamodel detail to the upstream OMG specifications, which are referenced by name and version only.

The skill is consumed by:

* the `BRD Author` skill during the Define phase when capturing flows, decisions, or structural relationships;
* the BRD Quality Reviewer when verifying that complex behavior has a visual representation;
* the BRD-phase instruction file for Define when the conversation reaches a process-heavy requirement.

This file is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The OMG specifications listed in the [cite-only registry](#cite-only-registry) are referenced by name and version only; their prose, notation glyph definitions, and metamodel diagrams are not embedded.

## When to Apply

Add a diagram to a BRD when written requirements alone leave the behavior ambiguous, the decision logic combinatorial, or the structural relationships hard to enumerate. Typical triggers:

* A business process crosses more than two roles or systems and the sequence matters.
* A decision is driven by more than three inputs or by a tabular rule set.
* A workflow has parallel paths, compensating actions, or timers that change the outcome.
* Stakeholders disagree about who performs which step, or where the handoff between teams occurs.
* A constraint references an external system whose interface is named but not yet pictured in the BRD.

Do not add a diagram for one-actor, one-step behaviors that read cleanly as a numbered list. The BRD Builder defaults to prose plus a numbered list; a diagram is added only when the trigger above is met or a stakeholder requests one.

## Notation Selection

The BRD Builder selects a notation family from the candidate triggered by the requirement. Each family is owned by an OMG specification; the BRD Builder does not invent notation.

* **Process and orchestration** - a sequence of activities across roles, gateways, events, and message flows. Use BPMN vocabulary when helpful; cite [standards-excerpts.md](standards-excerpts.md#omg-bpmn-202) for the upstream standard.
* **Decision logic** - a determination produced from a set of inputs by a documented rule, often expressed as a decision table. Use DMN vocabulary when helpful; cite [standards-excerpts.md](standards-excerpts.md#omg-dmn-15) for the upstream standard.
* **Structural, behavioral, or interaction modeling** outside of process flow - classes, components, sequence, state, use case. Use UML vocabulary when helpful; cite [standards-excerpts.md](standards-excerpts.md#omg-uml-251) for the upstream standard.

When a requirement combines categories (for example, a BPMN process whose gateway is driven by a DMN decision table), each category is modeled in its own notation and the two diagrams are cross-referenced by requirement identifier.

## Format Selection

After the notation family is chosen, the rendering format is selected with the original HVE-Core matrix in [diagram-format-selector.md](diagram-format-selector.md).
The matrix is Mermaid first: every diagram that Mermaid can express is embedded inline in the BRD markdown. ASCII is reserved for low-fidelity sketches captured during early Discover-phase conversations. If neither Mermaid nor ASCII is appropriate, set `diagram_format: none` and describe the process in prose.

The selector resolves three questions in order:

1. Does Mermaid have a diagram type that expresses the process at the required fidelity? If yes, embed Mermaid in the BRD markdown.
2. Is this an early sketch, console-only review, or no-rendering environment? If yes, capture an ASCII block and tag it for promotion to Mermaid when useful.
3. If neither format is appropriate, set `diagram_format: none` and keep the requirement prose explicit enough for review.

## Cite-Only Registry

The notation specifications below are referenced by name and version only. Their text, glyph definitions, and metamodel diagrams are not embedded in this repository.

* OMG BPMN 2.0 - Business Process Model and Notation. See [standards-excerpts.md](standards-excerpts.md#omg-bpmn-202).
* OMG DMN 1.5 - Decision Model and Notation. See [standards-excerpts.md](standards-excerpts.md#omg-dmn-15).
* OMG UML 2.5.1 - Unified Modeling Language. See [standards-excerpts.md](standards-excerpts.md#omg-uml-251).

DO NOT QUOTE prose definitions, syntax tables, glyph descriptions, or metamodel diagrams from any specification above. When a paraphrase is needed, write it as original Microsoft content and cite the specification by name, version, and section.

## References

Internal:

* [diagram-format-selector.md](diagram-format-selector.md) - HVE-Core selector matrix for Mermaid, ASCII, or no diagram.
* [standards-excerpts.md](standards-excerpts.md) - cite-only registry for OMG BPMN, DMN, and UML standards.
* [`requirements-definition`](requirements-definition.md) - vocabulary the diagrammed behavior is captured in.
* [`traceability-naming`](traceability-naming.md) - identifiers used to cross-reference diagrams and requirements.

External (cite-only, no embedded text):

* OMG BPMN 2.0 - [https://www.omg.org/spec/BPMN/2.0/](https://www.omg.org/spec/BPMN/2.0/)
* OMG DMN 1.4 - [https://www.omg.org/spec/DMN/1.4/](https://www.omg.org/spec/DMN/1.4/)
* OMG UML 2.5.1 - [https://www.omg.org/spec/UML/2.5.1/](https://www.omg.org/spec/UML/2.5.1/)

## License

Original content in this skill is licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), copyright (C) Microsoft Corporation. The OMG specifications listed in the [cite-only registry](#cite-only-registry) are referenced by name and version only and remain the property of Object Management Group, Inc.


