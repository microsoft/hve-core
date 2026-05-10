---
title: Fixture base ADR
description: Pass fixture baseline.
affected_components:
  - scripts/linting/Validate-AdrConsistency.ps1
  - scripts/linting/Modules/AdrConsistency.psm1
success_criteria:
  - id: sc-1
    description: Validator runs in CI
    source: README.md
decisionMetadata:
  driverToTriggerMap:
    Coverage of frontmatter rules: ASR-frontmatter-drift
---

# 9999. Fixture base ADR

## Context

This ADR validates registry-driven consistency checks. It cites
`scripts/linting/Validate-AdrConsistency.ps1` and
`scripts/linting/Modules/AdrConsistency.psm1` directly so the affected-components
audit passes.

## Decision Drivers

* Coverage of frontmatter rules
* Coverage of body rules

## Considered Options

* Adopt registry-driven validation
* Keep ad-hoc reviewer checks

## Decision Outcome

Chosen option: Adopt registry-driven validation.

| Driver                        | Adopt registry-driven validation | Keep ad-hoc reviewer checks |
|-------------------------------|----------------------------------|-----------------------------|
| Coverage of frontmatter rules | yes                              | partial                     |
| Coverage of body rules        | yes                              | partial                     |

### Consequences

#### Good consequences

* Reviewer load drops without per-ADR drift checks.

#### Bad consequences

* Risk: Registry maintenance lags behind taxonomy growth.

#### Neutral consequences

* Validator output joins existing CI logs.

## Risks and Mitigations

| Risk                                             | Mitigation                              |
|--------------------------------------------------|-----------------------------------------|
| Registry maintenance lags behind taxonomy growth | Schedule registry reviews each release. |

## Confirmation

A focused pytest suite confirms each rule fires; the validator emits machine-readable JSON for CI.

## More Information

See `scripts/linting/Validate-AdrConsistency.ps1` and `scripts/linting/Modules/AdrConsistency.psm1` for canonical wiring.

## Affected Components

* scripts/linting/Validate-AdrConsistency.ps1
* scripts/linting/Modules/AdrConsistency.psm1
