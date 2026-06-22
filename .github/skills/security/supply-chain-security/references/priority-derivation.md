---
description: Work item priority derivation from Scorecard risk level with execution ordering for supply chain backlog generation
---

# Priority Derivation

Derive work item priority from the Scorecard risk level:

| Risk Level | Priority | Execution Order |
|------------|----------|-----------------|
| Critical   | P1       | First           |
| High       | P2       | Second          |
| Medium     | P3       | Third           |
| Low        | P4       | Fourth          |

Within the same priority level, order items by adoption type (reusable workflow first, new capability last).

## Non-Scorecard Gaps

Some gaps have no Scorecard risk level — for example, NTIA SBOM minimum-element gaps and SLSA build-level gaps. For these, derive priority from the qualitative concern level (see [adoption-categories.md](adoption-categories.md)):

| Concern  | Priority | Execution Order |
|----------|----------|-----------------|
| High     | P2       | Second          |
| Moderate | P3       | Third           |
| Low      | P4       | Fourth          |

P1 is reserved for Critical Scorecard risk. Within the same priority level, order items by effort ascending (S before M before L before XL) so lower-effort gaps execute first.
