---
description: 'Mermaid-first format selector matrix for BRD diagrams with ASCII and none options - Brought to you by microsoft/hve-core'
---

# Diagram Format Selector

This file gives the BRD Builder a single matrix for choosing how to render a diagram once the notation family (BPMN, DMN, or UML) has been selected with the parent [`process-modeling`](process-modeling.md) skill. The matrix is original HVE-Core content; it does not reproduce notation glyphs or normative text from the upstream OMG specifications.

## Selection Principle

The BRD Builder prefers diagrams that live next to the prose they describe. Diagram references are optional. The selection follows three rules in order:

1. **Mermaid first.** If Mermaid has a diagram type that expresses the chosen notation at the required fidelity, embed Mermaid inline in the BRD markdown.
2. **ASCII for low fidelity only.** ASCII blocks are reserved for early Discover-phase sketches captured in conversation transcripts or console-only review.
3. **No diagram.** If a diagram would add ceremony without clarifying the requirement, set `diagram_format: none` and keep the process prose explicit.

A diagram is never embedded as a binary screenshot. When a diagram is present, the BRD contains either a Mermaid block or a plain-text ASCII block.

## Format Selector Matrix

| notation | use_when | tooling | embed_method |
| --- | --- | --- | --- |
| BPMN-style lane flow with sequential activities and exclusive or parallel gateways | A single process view, up to four lanes | Mermaid `flowchart` with subgraphs as lanes | Fenced ```` ```mermaid ```` block inline in the BRD section |
| Decision logic driven by a small input set | One decision with a compact set of inputs | Markdown decision table augmented by a Mermaid `flowchart` | Mermaid block plus a sibling markdown table inline in the BRD section |
| UML 2.5.1 - class or component structure | Up to roughly twelve classes or components with attributes and relationships | Mermaid `classDiagram` or `flowchart` for components | Fenced ```` ```mermaid ```` block inline in the BRD section |
| UML 2.5.1 - sequence interaction | Two to six lifelines with synchronous, asynchronous, or return messages | Mermaid `sequenceDiagram` | Fenced ```` ```mermaid ```` block inline in the BRD section |
| UML 2.5.1 - state machine | Finite states with named transitions, optional composite states | Mermaid `stateDiagram-v2` | Fenced ```` ```mermaid ```` block inline in the BRD section |
| UML 2.5.1 - use case | Actors and use cases with associations, includes, and extends | Mermaid `flowchart` with actor and use-case styling | Fenced ```` ```mermaid ```` block inline in the BRD section |
| Any notation - early conversational sketch before a tool is opened | A stakeholder describes the flow verbally in chat or in a working draft | ASCII block characters | Fenced ```` ```text ```` block in the working draft |
| Any notation - no diagram needed | The prose is clearer than a diagram or no renderer is available | None | `diagram_format: none` with explicit process prose |

## Embed Conventions

* Mermaid blocks live in the BRD markdown immediately under the requirement or section heading they illustrate, with a one-sentence caption above the fenced block.
* ASCII sketches use box-drawing characters from the ASCII range only (`+`, `-`, `|`, `>`, `<`, `o`) so they remain legible in plain-text consoles and review tools.
* Every diagram, regardless of format, references the requirement identifier or section identifier it supports (for example, `<!-- supports: FR-014, FR-015 -->`) so the [`traceability-naming`](traceability-naming.md) matrix can join diagrams to requirements.

## Anti-Patterns

The BRD Builder rejects:

* Binary screenshots of whiteboards, modeling tools, or rendered diagrams pasted into the BRD without an editable source.
* Mermaid blocks larger than roughly twenty-five nodes or six lanes; refactor into multiple smaller diagrams or use prose with `diagram_format: none`.
* External diagram exports as required BRD inputs.
* ASCII diagrams in the approved BRD when a Mermaid diagram would be clearer for the intended reviewers.

## License

Original content in this file is licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), copyright (C) Microsoft Corporation. The notation families named in the matrix (BPMN 2.0, DMN 1.4, UML 2.5.1) remain the property of Object Management Group, Inc. and are referenced by name and version only.

> Brought to you by microsoft/hve-core

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
