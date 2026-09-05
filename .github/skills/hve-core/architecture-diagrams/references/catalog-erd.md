---
title: Catalog-driven entity relationship diagrams
description: Input authority, cardinality mapping, confidence rendering, and compatibility boundaries for DS_CATALOG_V1 diagrams
---

## Input authority

Use `data-catalog`, the durable data-catalog skill for declared entities,
relationships, identity, lineage, and model semantics, when a caller supplies a
`DS_CATALOG_V1` Markdown catalog. Parsed YAML frontmatter is semantic authority.
The renderer does not infer entities, endpoints, cardinalities, endpoint
minimums, join keys, or confidence from SQL, ORM definitions, naming
conventions, or prose.

A catalog that passes `data-catalog` validation is the expected input. The
renderer rejects an unsupported catalog version, a missing or non-string entity
ID or name, a duplicate entity or relationship ID, an identifier collision, an
unresolved endpoint, an unknown cardinality, a missing or invalid endpoint
minimum, an unknown confidence value, an empty basis, and any malformed
join-key declaration. It fails with `EXIT_ERROR` instead of omitting,
defaulting, truncating, inferring, or partially rendering a fact. The renderer
is a view over the catalog, not a second catalog validator or semantic owner.

## Multiplicity mapping

`cardinality` supplies the maximum on each side. `from_minimum` and
`to_minimum` supply the minimum. Both are required and neither is inferred.

| Catalog cardinality | `from` maximum | `to` maximum |
|---------------------|----------------|--------------|
| `one-to-one`        | one            | one          |
| `one-to-many`       | one            | many         |
| `many-to-many`      | many           | many         |

Each endpoint combines its declared minimum with its derived maximum:

| Minimum and maximum | Mermaid left | Mermaid right | ASCII  |
|---------------------|--------------|---------------|--------|
| `zero` and one      | `\|o`        | `o\|`         | `0..1` |
| `one` and one       | `\|\|`       | `\|\|`        | `1`    |
| `zero` and many     | `}o`         | `o{`          | `0..*` |
| `one` and many      | `}\|`        | `\|{`         | `1..*` |

## Identifiers, attributes, and labels

Mermaid node identifiers derive reversibly from declared entity IDs by escaping
every character outside `a-z0-9` as `_<hex>`, so distinct catalog IDs cannot
collide. Node labels use the customer-readable `name`. Relationship evidence in
Key Relationships preserves the exact declared relationship ID.

Entity attributes list only the declared join-key field names that the entity
participates in, deduplicated and in declaration order. The renderer never adds
a synthetic attribute and never emits `PK`, `FK`, uniqueness, or any other
constraint marker, because the catalog does not declare database key roles.

Relationship labels show the ordered join-key pairing as `from_field =
to_field`. A `confirmed` relationship carries no confidence marker. An
unconfirmed relationship appends exactly `(inferred)` or `(assumed)`. All
connectors are solid: Mermaid reserves dashed ER lines for non-identifying
relationships, which this catalog does not model, so confidence never uses the
line-style channel and no per-edge `style`, `class`, or `linkStyle` is emitted.

## Output contract

Catalog rendering produces this structure in both formats:

```markdown
## <Engagement> Data Model

[diagram in the selected format]

### Legend
[multiplicity, attribute, confidence, and connector meanings]

### Key Relationships
[every relationship with its declared ID, endpoints, multiplicity, ordered join keys, confidence, and basis]
```

When the catalog declares no relationships, both formats still render the
declared entities and state explicitly that no relationships are declared.

This contract is specific to catalog input. Infrastructure sources keep the
`<Name> Architecture` output contract and the flowchart conventions described
in the skill.

## Format behavior

Honor the existing caller preference contract. Mermaid output uses `erDiagram`.
ASCII output uses compact entity and relationship lines carrying the same
declared multiplicity, join-key, and confidence facts. Neither format changes
the catalog.

Execute `scripts/render_catalog_erd.py` with `--format mermaid` or
`--format ascii` when deterministic rendering is useful.

## Compatibility boundary

`DS_CATALOG_V1` is the only supported catalog input version. SQL DDL, Prisma,
SQLAlchemy, and other ORM sources remain outside this input type because they do
not carry the catalog's declared evidence confidence and engagement semantics.
Existing infrastructure-source workflows remain unchanged.

The Feasibility Study Interchange Profile is a separate producer contract owned
by `feasibility`, the evidence-led feasibility-study skill. A future
Functional Planner workstream owns adoption of that profile, version
negotiation, source-to-requirement mappings, and `FR-###` allocation. This skill
does not parse feasibility studies, claim current Functional Planner
compatibility, write back to source studies, or modify requirements artifacts.
