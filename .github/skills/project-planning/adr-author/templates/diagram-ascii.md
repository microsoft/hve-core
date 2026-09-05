<!--
Variant: ascii
Selected when: state.userPreferences.diagramFormat == "ascii"
Purpose: lightweight starting scaffold for box-and-arrow diagrams in ADRs
IaC-derived diagrams: when the ADR diagram is derived from infrastructure source files (Terraform, Bicep, ARM), author it with the architecture-diagrams skill using ascii output and embed that result in place of this scaffold; that skill owns the ASCII conventions, arrow types, and boundary notation.
-->

# Diagram (ASCII)

```text
+----------------+        <flow>        +----------------+
|  <component>   | -------------------> |  <component>   |
+----------------+                      +----------------+
        |                                       |
        | <flow>                                | <flow>
        v                                       v
+----------------+                      +----------------+
|  <component>   |                      |  <component>   |
+----------------+                      +----------------+
```
