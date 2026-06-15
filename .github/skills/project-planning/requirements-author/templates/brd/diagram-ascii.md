---
description: "ASCII Process Diagram Fragment for BRD - Brought to you by microsoft/hve-core"
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

## Optional: Technical Context via Architecture Diagram Builder

{{arch_diagram_ref}}

*Guidance*: Reference external architecture diagrams via `arch-diagram-builder` subagent if this process depends on infrastructure or system integration details. Otherwise, leave blank.

---

> Brought to you by microsoft/hve-core
