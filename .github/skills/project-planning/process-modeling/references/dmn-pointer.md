---
description: 'Cite-only pointer to OMG DMN 1.4 - names the specification the BRD Builder uses for decision logic and decision tables, links to the OMG catalog, and does not redistribute the notation text - Brought to you by microsoft/hve-core'
---

# OMG DMN 1.4 - Cite-Only Pointer

This document is a cite-only pointer. It names the Decision Model and Notation (DMN) version 1.4 specification published by the Object Management Group (OMG) and the BRD Builder's posture toward it; it does not redistribute the specification's text, notation glyph descriptions, metamodel diagrams, FEEL grammar, or normative tables.

## What DMN 1.4 Is

DMN 1.4 is the OMG standard notation for decision logic. It defines a graphical language for decision requirements diagrams (DRDs) that show how decisions, input data, business knowledge, and knowledge sources combine, and it defines the tabular notation (decision tables) and expression language (FEEL) used to encode the rule logic behind each decision. The BRD Builder uses DMN 1.4 whenever a requirement is determined from a set of inputs by a documented rule set rather than by a procedural sequence.

The BRD Builder references DMN 1.4 in two ways:

* As the notation family selected by the [`process-modeling`](../SKILL.md#notation-selection) decision when a requirement is decision- or rule-oriented.
* As the upstream source of all syntactic and semantic detail. The BRD Builder never reproduces DMN's glyphs, decision-table conventions, FEEL grammar, or metamodel in this repository; readers are pointed at the OMG specification for any normative content.

## Why Cite-Only

The DMN 1.4 specification is published by the OMG under terms that permit reference and citation but not unrestricted redistribution. Embedding the specification's text, the notation glyph descriptions, the decision-table hit-policy semantics, or the metamodel diagrams is therefore out of scope for this repository.

The BRD Builder's posture is:

* Reference DMN 1.4 by name and version when explaining why a requirement is captured as a decision table, a DRD, or a FEEL expression.
* Do not paraphrase the specification's normative text. Any wording in this repository that describes DMN behavior is original Microsoft content and is kept brief and orientational.
* When a stakeholder needs the canonical definition of a construct, link them to the OMG catalog entry below.

## Upstream Source

[https://www.omg.org/spec/DMN/1.4/](https://www.omg.org/spec/DMN/1.4/) (accessed 2026-05-25) - OMG specification page, where the current revision, formal documents, and license terms are obtained.

## License

This pointer file is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The DMN 1.4 specification is the property of Object Management Group, Inc. and is subject to the publisher's terms at the upstream source.

> Brought to you by microsoft/hve-core

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
