---
description: "Mermaid Process Diagram Fragment for BRD"
---

# Process Models — Mermaid Diagram Fragment

This fragment is used when `brd_frontmatter.diagram_format: "mermaid"` (default).

## Flowchart (BPMN-Style)

```mermaid
graph TD
    A["{{start_event}}"] --> B["{{activity_1}}"]
    B --> C{{"{{decision_point}}"}}
    C -->|{{option_a}}| D["{{activity_2a}}"]
    C -->|{{option_b}}| E["{{activity_2b}}"]
    D --> F["{{activity_3}}"]
    E --> F
    F --> G["{{end_event}}"]
```

## Legend

- **Rectangles**: Activities / tasks
- **Diamonds**: Decision points / gateways
- **Rounded Corners**: Start / End events

## Process Description

{{mermaid_diagram_description}}

*Guidance*: Explain the flow, decision criteria, swimlanes (if applicable), and key outcomes. 2-3 paragraphs recommended.

## Supporting Information

- **Trigger**: {{process_trigger}}
- **Actors**: {{actors_involved}}
- **Success Criteria**: {{success_criteria}}
- **Error Handling**: {{error_handling}}
