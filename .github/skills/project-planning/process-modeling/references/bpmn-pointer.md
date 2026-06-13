---
description: 'Cite-only pointer to OMG BPMN 2.0 - names the specification the BRD Builder uses for process and orchestration diagrams, links to the OMG catalog, and does not redistribute the notation text - Brought to you by microsoft/hve-core'
---

# OMG BPMN 2.0 - Cite-Only Pointer

This document is a cite-only pointer. It names the Business Process Model and Notation (BPMN) version 2.0 specification published by the Object Management Group (OMG) and the BRD Builder's posture toward it; it does not redistribute the specification's text, notation glyph descriptions, metamodel diagrams, or normative tables.

## What BPMN 2.0 Is

BPMN 2.0 is the OMG standard notation for business process diagrams. It defines a graphical language for modeling activities, events, gateways, sequence flows, message flows, pools, lanes, data objects, and the semantics that govern their execution. The BRD Builder uses BPMN 2.0 as the notation family of choice whenever a requirement describes a multi-step, multi-role process whose sequence and handoffs matter.

The BRD Builder references BPMN 2.0 in two ways:

* As the notation family selected by the [`process-modeling`](../SKILL.md#notation-selection) decision when a requirement is process- or orchestration-oriented.
* As the upstream source of all syntactic and semantic detail. The BRD Builder never reproduces BPMN's glyphs, metamodel, or execution semantics in this repository; readers are pointed at the OMG specification for any normative content.

## Why Cite-Only

The BPMN 2.0 specification is published by the OMG under terms that permit reference and citation but not unrestricted redistribution. Embedding the specification's text, the notation glyph descriptions, or the metamodel diagrams is therefore out of scope for this repository.

The BRD Builder's posture is:

* Reference BPMN 2.0 by name and version when explaining why a diagram uses pools, lanes, gateways, or message flows.
* Do not paraphrase the specification's normative text. Any wording in this repository that describes BPMN behavior is original Microsoft content and is kept brief and orientational.
* When a stakeholder needs the canonical definition of a construct, link them to the OMG catalog entry below.

## Upstream Source

[https://www.omg.org/spec/BPMN/2.0/](https://www.omg.org/spec/BPMN/2.0/) (accessed 2026-05-25) - OMG specification page, where the current revision, formal documents, and license terms are obtained.

## License

This pointer file is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The BPMN 2.0 specification is the property of Object Management Group, Inc. and is subject to the publisher's terms at the upstream source.

> Brought to you by microsoft/hve-core

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
