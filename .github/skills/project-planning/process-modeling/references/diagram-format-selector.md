---
description: 'Mermaid-first format selector matrix for BRD diagrams with draw.io and ASCII fallbacks across BPMN, DMN, and UML notation families - Brought to you by microsoft/hve-core'
---

# Diagram Format Selector

This file gives the BRD Builder a single matrix for choosing how to render a diagram once the notation family (BPMN, DMN, or UML) has been selected with the parent [`process-modeling`](../SKILL.md) skill. The matrix is original HVE-Core content; it does not reproduce notation glyphs or normative text from the upstream OMG specifications.

## Selection Principle

The BRD Builder prefers diagrams that live next to the prose they describe. The selection follows three rules in order:

1. **Mermaid first.** If Mermaid has a diagram type that expresses the chosen notation at the required fidelity, embed Mermaid inline in the BRD markdown.
2. **draw.io fallback.** If the requirement needs BPMN or DMN constructs Mermaid cannot render (collaboration pools with message flows, full DMN decision-requirements diagrams, advanced gateways), author the diagram in draw.io, save as `.drawio.svg`, and reference it from the BRD with an image link.
3. **ASCII for low fidelity only.** ASCII blocks are reserved for early Discover-phase sketches captured in conversation transcripts. Every ASCII sketch carried into Define is upgraded to Mermaid (or draw.io) before Define exit.

A diagram is never embedded as a binary screenshot; the BRD must contain either a Mermaid block (rendered by GitHub and most markdown viewers) or a vector `.drawio.svg` (editable round-trip in draw.io).

## Format Selector Matrix

| notation | use_when | tooling | embed_method |
| --- | --- | --- | --- |
| BPMN 2.0 - lane swimlane with sequential activities and exclusive or parallel gateways | A single pool, up to four lanes, no message flows between pools | Mermaid `flowchart` (with subgraphs as lanes) | Fenced ```` ```mermaid ```` block inline in the BRD section |
| BPMN 2.0 - choreography of two or more participants with message flows, intermediate events, or compensation | Collaboration across pools, message exchange, timer or compensation events | draw.io with the bpmn.io shape library | `.drawio.svg` saved under the BRD asset folder and linked from the BRD section |
| DMN 1.4 - single decision driven by a small input set | Up to one decision node and up to two input data nodes, no business knowledge model | Markdown decision table augmented by a Mermaid `flowchart` showing the inputs feeding the decision | Mermaid block plus a sibling markdown table inline in the BRD section |
| DMN 1.4 - decision requirements diagram with multiple decisions, knowledge sources, or business knowledge models | Two or more decisions, knowledge sources, or knowledge models that interact | draw.io with a DMN shape library | `.drawio.svg` saved under the BRD asset folder and linked from the BRD section |
| UML 2.5.1 - class or component structure | Up to roughly twelve classes or components with attributes and relationships | Mermaid `classDiagram` or `flowchart` for components | Fenced ```` ```mermaid ```` block inline in the BRD section |
| UML 2.5.1 - sequence interaction | Two to six lifelines with synchronous, asynchronous, or return messages | Mermaid `sequenceDiagram` | Fenced ```` ```mermaid ```` block inline in the BRD section |
| UML 2.5.1 - state machine | Finite states with named transitions, optional composite states | Mermaid `stateDiagram-v2` | Fenced ```` ```mermaid ```` block inline in the BRD section |
| UML 2.5.1 - use case | Actors and use cases with associations, includes, and extends | Mermaid `flowchart` with actor and use-case styling | Fenced ```` ```mermaid ```` block inline in the BRD section |
| Any notation - early conversational sketch before a tool is opened | A stakeholder describes the flow verbally in chat or in a working draft | ASCII block characters | Fenced ```` ```text ```` block in the working draft, tagged with `TODO: upgrade to Mermaid before Define exit` |

## Embed Conventions

* Mermaid blocks live in the BRD markdown immediately under the requirement or section heading they illustrate, with a one-sentence caption above the fenced block.
* `.drawio.svg` assets live under `docs/brds/<brd-id>/assets/` and are referenced with relative markdown image links. The `.drawio.svg` format preserves an editable round-trip in draw.io while still rendering as a static SVG on GitHub.
* ASCII sketches use box-drawing characters from the ASCII range only (`+`, `-`, `|`, `>`, `<`, `o`) so they remain legible in plain-text consoles and review tools.
* Every diagram, regardless of format, references the requirement identifier or section identifier it supports (for example, `<!-- supports: FR-014, FR-015 -->`) so the [`traceability-naming`](../../traceability-naming/SKILL.md) matrix can join diagrams to requirements.

## Anti-Patterns

The BRD Builder rejects:

* Binary screenshots of whiteboards, modeling tools, or rendered diagrams pasted into the BRD without an editable source.
* Mermaid blocks larger than roughly twenty-five nodes or six lanes; refactor into multiple smaller diagrams or escalate to draw.io.
* draw.io exports saved as raster `.png` or `.jpg`; only `.drawio.svg` is accepted because it preserves the editable source.
* ASCII diagrams in the published BRD; ASCII is a transient sketch format and is upgraded before Define exit.

## License

Original content in this file is licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), copyright (C) Microsoft Corporation. The notation families named in the matrix (BPMN 2.0, DMN 1.4, UML 2.5.1) remain the property of Object Management Group, Inc. and are referenced by name and version only.

> Brought to you by microsoft/hve-core

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
