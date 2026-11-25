---
description: "ASCII Process Diagram Fragment for BRD"
---

# Process Models — ASCII Diagram Fragment

This fragment is used when `brd_frontmatter.diagram_format: "ascii"`.

## Text-Based Process Flow

```text
                    ┌─────────────────┐
                    │   {{start_node}}   │
                    └────────┬─────────┘
                             │
                    ┌────────▼─────────┐
                    │  {{process_1}}    │
                    └────────┬─────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
    ┌─────────▼─┐  ┌─────────▼─┐  ┌─────────▼─┐
    │ {{path_a}} │  │ {{path_b}} │  │ {{path_c}} │
    └─────────┬──┘  └─────────┬──┘  └─────────┬──┘
              │              │              │
              └──────────────┼──────────────┘
                             │
                    ┌────────▼─────────┐
                    │  {{process_2}}    │
                    └────────┬─────────┘
                             │
                    ┌────────▼─────────┐
                    │   {{end_node}}    │
                    └───────────────────┘
```

## Description

{{ascii_diagram_description}}

*Guidance*: Provide a brief narrative explanation of the process steps, decision points, and outcomes. Keep to 2-3 paragraphs.

## Optional: Technical Context via Architecture Diagrams Skill

{{arch_diagram_ref}}

*Guidance*: Show infrastructure or integration details only when supported by the source. Use the [diagram format selector](../../references/_shared/diagram-format-selector.md) for a local sketch or an available `architecture-diagrams` rendering. Otherwise, leave blank.
