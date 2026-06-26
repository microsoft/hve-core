---
name: security-planning
description: Security planning reference set for operational buckets, STRIDE analysis, standards mapping, NIST control families, and backlog scaffolding.
license: MIT
user-invocable: true
---

# Security Planning

This skill packages the durable security-planning reference material used by the Security Planner: operational bucket guidance, STRIDE analysis patterns, standards cross-references, NIST control-family references, and security-specific backlog formats.

## When to use

Use this skill when you need to:

* Classify application components into the operational security buckets used during planning.
* Evaluate threats with STRIDE-based analysis, including AI-specific extensions when `raiEnabled` is true.
* Map bucket findings to standards references and control families without re-embedding long standard tables.
* Derive security-specific backlog priorities and RAI work item categories for Phase 5 handoff.

## Skill layout

Load the reference file that matches the phase or topic you need.

| Reference                                                                          | Topic                                                                   |
|------------------------------------------------------------------------------------|-------------------------------------------------------------------------|
| [references/00-index.md](references/00-index.md)                                   | Navigation catalog and consolidated attribution                         |
| [references/operational-buckets.md](references/operational-buckets.md)             | Operational bucket definitions, GS overlay, and classification guidance |
| [references/stride-model.md](references/stride-model.md)                           | STRIDE methodology, AI extensions, risk matrix, and data-flow analysis  |
| [references/standards-cross-reference.md](references/standards-cross-reference.md) | Bucket-to-standards mapping table and component mapping output format   |
| [references/nist-control-families.md](references/nist-control-families.md)         | NIST 800-53 priority tiers and NIST AI RMF subcategory mappings         |
| [references/backlog-formats.md](references/backlog-formats.md)                     | Security-specific prioritization and RAI work item categories           |

## Attribution

The durable reference content in this skill is organized by reference file and summarized in [references/00-index.md](references/00-index.md). See that index for the consolidated attribution and delegation notes.
