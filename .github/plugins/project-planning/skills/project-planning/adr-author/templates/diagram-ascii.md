<!--
Variant: ascii
Selected when: state.userPreferences.diagramFormat == "ascii"
Purpose: lightweight starting scaffold for box-and-arrow diagrams in ADRs
IaC-derived diagrams: populate this scaffold from verified resources, connections, and boundaries in the supplied source. An available architecture-diagrams ASCII rendering can replace the scaffold.
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
