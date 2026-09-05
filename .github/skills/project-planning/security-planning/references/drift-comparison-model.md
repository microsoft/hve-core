---
title: Security Plan Drift Comparison Model
description: Evidence preconditions, exclusion rules, five drift categories, and recommendation-only handoff signals.
ms.date: 2026-09-04
ms.topic: reference
---

# Security Plan Drift Comparison Model

This model defines exclusion filtering, evidence preconditions, mutually exclusive categories, and recommendation-only handoffs.

## Default exclusions

Filter normalized current-state records before classification.

Excluded path prefixes:

* `.copilot-tracking/`
* `docs/planning/`
* `docs/adrs/`
* `.github/agents/`
* `.github/prompts/`
* `.github/instructions/`
* `.github/skills/`

Excluded file globs:

* `*.prompt.md`
* `*.agent.md`
* `*.instructions.md`
* `SKILL.md`

An explicit caller scope wins over an overlapping exclusion. Record each overlapping prefix as an opted-in prefix and retain findings under that prefix. Always report `Filtered findings: N`, including when $N = 0$.

## Category preconditions

| Category                 | Required plan evidence                                              | Required current-state evidence                                                             | Insufficient-evidence condition                                                                               |
|--------------------------|---------------------------------------------------------------------|---------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------|
| Validated controls       | Control or mitigation bound to a bucket or threat identity          | Repository-derived `PASS`, or an explicit implementation citation at a covered location     | Evidence is plan-mode, diff-scoped, code-review scoped, outside the scanned scope, or has no covered location |
| Control drift            | Expected control with a plan reference                              | `FAIL` or `PARTIAL` at a location mapped to the control or component                        | Neither side has a resolvable component or location                                                           |
| Residual planned risk    | Threat identity recorded as open, accepted, or deferred             | Matching current finding or observed absence of remediation                                 | Threat facts are unresolved                                                                                   |
| Newly introduced threats | Extractable plan threats, controls, buckets, and backlog identities | Current finding with no matching plan identity                                              | Relevant plan facts are unresolved, so absent and unextracted cannot be distinguished                         |
| Obsolete plan items      | Plan item naming a component, path, or standard                     | Current evidence covering the location and showing the item is gone or no longer applicable | Current evidence never covered the referenced location or supplies no location                                |

Render every suppressed category as `Insufficient evidence: <reason>`. Do not silently omit it and do not count it as zero findings.

Conformant VULN_REPORT_V1 Form A evidence omits Location on `PASS` rows. With Form A alone, render validated controls and obsolete plan items as insufficient evidence rather than inferring locations. Control drift, residual planned risks, and newly introduced threats remain eligible when their `FAIL` or `PARTIAL` records satisfy the table above. Direct Form B evidence with explicit covered locations remains eligible for all five categories.

## Matching order

For each retained current-state record:

1. Match an explicit plan threat or backlog identity.
2. Match a named control or mitigation.
3. Match a component and operational bucket.
4. Match a standards mapping or skill-to-plan facet.
5. Treat the record as unmatched only when the relevant plan facts are extractable.

Prefer explicit identities over semantic text similarity. When only semantic similarity is available, state the match as proposed and include the uncertainty in notes.

A similarity-only proposal occupies no drift category. Record it under Limitations and insufficient evidence as unassessed input until explicit plan identity, component, control, bucket, standard, or backlog evidence resolves the match. Do not also treat it as unmatched for the newly introduced threats category.

## Classification rules

### Validated controls

Emit when the plan expects a control and repository-scoped evidence confirms the implementation at a covered location. Cite the plan control or threat identity, finding identity, location, and evidence pointer.

### Control drift and regressions

Emit when repository-scoped evidence shows an expected control is missing, weaker, or inconsistent. Preserve the producer's severity and verification verdict. Do not re-rate severity.

### Residual planned risks

Emit when a plan already records a risk as open, accepted, or deferred and current evidence shows it remains. This category does not mean the risk is newly introduced.

When a threat is open and names an expected control, classify a current failure of that control as control drift. Classify an accepted or deferred threat that remains present as residual planned risk. Do not emit the same plan threat in both categories.

### Newly introduced threats

Emit when a current finding has no match in extractable plan threats, controls, components, buckets, standards mappings, or backlog items. Never emit from absence when the relevant plan facts are unresolved.

### Obsolete plan items

Emit when current evidence covered the referenced location and shows the component, path, control, or standard no longer applies. Repository-wide evidence is normally required; diff absence is insufficient.

## Skill-to-plan facets

Use these mappings only as matching evidence and handoff signals. They do not replace explicit plan identities.

| Current skill                             | Expected baseline facet                                                                              | Suggested handoff when absent |
|-------------------------------------------|------------------------------------------------------------------------------------------------------|-------------------------------|
| `owasp-top-10`                            | Web/UI/reporting bucket with an OWASP web mapping                                                    | Security Planner              |
| `owasp-infrastructure`                    | Infrastructure or platform bucket with infrastructure or CIS mapping                                 | Security Planner              |
| `owasp-cicd`                              | Build or DevOps/platform-ops bucket with CI/CD mapping                                               | SSSC Planner                  |
| `secure-by-design`                        | Cross-cutting security design mapping                                                                | Security Planner              |
| `owasp-llm`, `owasp-agentic`, `owasp-mcp` | Non-empty AI components and `raiEnabled: true`                                                       | RAI Planner                   |
| Supply-chain finding                      | Build or DevOps/platform-ops facet with dependency, SBOM, provenance, signing, or integrity controls | SSSC Planner                  |

## Recommendation-only handoffs

Recommend follow-up without dispatch:

* Security Planner when control drift, obsolete items, or baseline incompleteness is present
* SSSC Planner when unmatched build, dependency, SBOM, provenance, or signing findings exist and no matching SSSC plan state is present
* RAI Planner when AI findings are present and the baseline explicitly shows missing AI planning, or when an AI plan is absent and current evidence supports the signal

When an AI state field is missing because of schema drift, suppress the RAI handoff rather than treating the missing value as empty or false.
