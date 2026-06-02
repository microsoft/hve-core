<!--
hve-core ADR Creator - MADR v4 frontmatter overlay
====================================================
The upstream MADR v4.0.0 template (`madr-v4.md`) is preserved byte-identical
under CC0-1.0 per GP-17 and therefore cannot carry hve-core extension fields
in its own frontmatter. This overlay defines the additional fields the ADR
Creator injects when rendering an ADR. Merge this overlay on top of the
upstream MADR frontmatter (do not replace MADR's own keys).

Validation: the merged frontmatter is validated by
`scripts/linting/schemas/adr-frontmatter.schema.json` and by the skill's
`scripts/validate_frontmatter.py`.
-->
---
# Required hve-core extensions
id: "{NNNN}"                         # 4-digit zero-padded, scoped to project_slug (GP-16)
title: "{short decision-focused title}"
status: "{proposed | accepted | rejected | deprecated | superseded}"
date: "{YYYY-MM-DD}"
deciders:                            # required, minItems 1 (replaces MADR's optional `decision-makers`)
  - "{role-or-person}"

# Optional hve-core extensions
tags: []                             # free-form classification
supersedes: null                     # scalar NNNN string or null (GP-06 single-parent)
superseded-by: null                  # scalar NNNN string or null
related: []                          # list of {path, relation, note?}; relation in {informational, influenced-by, influences}
asr_triggers: []                     # list of {kind, evidence, note?}; kind in cost|performance|security|compliance|availability|scalability|maintainability|evolvability (GP-07)

# Optional provenance (adopt-template lifecycle only)
migrated-from: null
migrated-on: null
migrated-by: null
original-id: null
---
