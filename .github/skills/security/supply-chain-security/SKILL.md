---
name: supply-chain-security
description: Software supply chain security reference for OpenSSF Scorecard, SLSA, Sigstore, SBOM, and posture/backlog taxonomies.
license: MIT
user-invocable: true
---

# Supply Chain Security

This skill packages the durable software supply chain security (SSSC) reference material: open-standard catalogs, the combined capabilities inventory, and the classification taxonomies used to assess a repository's posture and turn gaps into prioritized work items.

## When to use

Use this skill when you need to:

* Assess a repository against the 27 combined supply chain capabilities from hve-core and physical-ai-toolchain.
* Map posture against OpenSSF Scorecard, SLSA v1.0, OpenSSF Best Practices Badge, Sigstore (cosign), or NTIA SBOM minimum elements.
* Classify a gap by adoption category, effort size, or qualitative concern level.
* Derive work item priority and execution order from Scorecard risk levels.

## Skill layout

Load the reference file for the topic you need. Each file holds the verbatim standard catalog or taxonomy.

| Reference                                                                      | Topic                                                           |
|--------------------------------------------------------------------------------|-----------------------------------------------------------------|
| [references/00-index.md](references/00-index.md)                               | Navigation catalog for every reference in this skill            |
| [references/openssf-scorecard.md](references/openssf-scorecard.md)             | OpenSSF Scorecard 20 checks with risk levels and score ranges   |
| [references/slsa-levels.md](references/slsa-levels.md)                         | SLSA v1.0 Build track levels L0 through L3                      |
| [references/best-practices-badge.md](references/best-practices-badge.md)       | OpenSSF Best Practices Badge Passing, Silver, and Gold criteria |
| [references/sigstore-maturity.md](references/sigstore-maturity.md)             | Sigstore (cosign) adoption maturity levels                      |
| [references/sbom-elements.md](references/sbom-elements.md)                     | NTIA SBOM minimum elements and format guidance                  |
| [references/capabilities-inventory.md](references/capabilities-inventory.md)   | 27 combined capabilities across hve-core, PAT, and shared sets  |
| [references/adoption-categories.md](references/adoption-categories.md)         | Six adoption categories, effort sizing, and concern levels      |
| [references/scorecard-check-mapping.md](references/scorecard-check-mapping.md) | Full 20-check implementation and adoption reference mapping     |
| [references/priority-derivation.md](references/priority-derivation.md)         | Risk level to priority and execution order derivation           |

## Attribution

Standard catalogs in this skill derive from their respective upstream projects. Per-reference attribution appears at the bottom of each reference file. See [references/00-index.md](references/00-index.md) for the consolidated attribution summary.


