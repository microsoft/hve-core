<!--
Variant: mermaid
Selected when: state.userPreferences.diagramFormat == "mermaid"
Purpose: lightweight starting scaffold for Mermaid flowchart diagrams in ADRs
IaC-derived diagrams: when the ADR diagram is derived from infrastructure source files (Terraform, Bicep, ARM), author it with the architecture-diagrams skill using mermaid output and embed that result in place of this scaffold; that skill owns the Mermaid conventions, arrow types, and subgraph boundaries.
-->

# Diagram (Mermaid)

```mermaid
flowchart LR
    componentA[<componentA>] --> componentB[<componentB>]
    componentB --> componentC[<componentC>]
```
