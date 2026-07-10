---
title: Standards Cross-Reference
description: Standards mapping patterns and control-family references used by the security-planning skill.
---

# Standards Cross-Reference

This reference captures the standards mapping and control reference patterns used in the Security Planner workflow.

## Mapping approach

Map each bucket finding to the most relevant controls and guidance from the shared security standards references already maintained in this repository.

Preferred references:

* OWASP Top 10 for application security failure modes
* OWASP LLM Top 10 for AI-enabled system risks
* Supply-chain security guidance for dependency, artifact, and provenance controls
* Existing security-planning standards references used by the planner workflow

## Suggested mapping output

Use a compact mapping table like this:

| Bucket              | Finding                      | Control family       | Example standards     |
|---------------------|------------------------------|----------------------|-----------------------|
| data                | Unencrypted backup storage   | Data protection      | OWASP A02, NIST SC-28 |
| web/UI/reporting    | Input validation gaps        | Application security | OWASP A03, NIST SI-10 |
| devops/platform-ops | Secret exposure in pipelines | Identity and access  | NIST AC-2, NIST IA-5  |

## Guidance

* Keep mappings tied to the actual component and threat scenario.
* Prefer existing shared skills and references over re-embedding long standards tables.
* Use the mapping to support threat mitigation and backlog prioritization.
