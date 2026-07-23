---
title: Index of MCSB Control Domains
description: Index of Microsoft Cloud Security Benchmark v2 control-domain identifiers, categories, framework crosswalk, and per-domain reference structure.
---

# Index of MCSB Control Domains

This document is the index for the Microsoft Cloud Security Benchmark (MCSB) skill. Each entry is a control domain — a family of related security controls that MCSB applies across Azure resources. The domain taxonomy is the durable, structurally stable layer of MCSB; individual control identifiers and their per-service applicability are volatile and retrieved at runtime (see [lookup-playbook.md](lookup-playbook.md)).

The two-letter domain identifiers below (NS, IM, PA, …) are the assessable grain for planning and review. Finer per-service control identifiers are not enumerated here and are fetched at runtime.

This skill targets **MCSB v2** (preview), retrieval-dated 2026-07-21. MCSB v2 replaces v1's Governance and Strategy (`GS`) domain with Artificial Intelligence Security (`AI`), and maps to NIST SP 800-53 Rev. 5 and CIS Controls v8.1.

## Control domain catalog

| ID | Domain                               | Category                    | Reference                                                           |
|----|--------------------------------------|-----------------------------|--------------------------------------------------------------------|
| NS | Network Security                     | Network                     | [01-network-security.md](01-network-security.md)                   |
| IM | Identity Management                  | Identity                    | [02-identity-management.md](02-identity-management.md)             |
| PA | Privileged Access                    | Access Control              | [03-privileged-access.md](03-privileged-access.md)                 |
| DP | Data Protection                      | Data                        | [04-data-protection.md](04-data-protection.md)                     |
| AM | Asset Management                     | Governance                  | [05-asset-management.md](05-asset-management.md)                   |
| LT | Logging and Threat Detection         | Detection and Response      | [06-logging-threat-detection.md](06-logging-threat-detection.md)   |
| IR | Incident Response                    | Detection and Response      | [07-incident-response.md](07-incident-response.md)                 |
| PV | Posture and Vulnerability Management | Posture                     | [08-posture-vulnerability-management.md](08-posture-vulnerability-management.md) |
| ES | Endpoint Security                    | Endpoint                    | [09-endpoint-security.md](09-endpoint-security.md)                 |
| BR | Backup and Recovery                  | Resilience                  | [10-backup-recovery.md](10-backup-recovery.md)                     |
| DS | DevOps Security                      | DevOps                      | [11-devops-security.md](11-devops-security.md)                     |
| AI | Artificial Intelligence Security     | AI                          | [12-ai-security.md](12-ai-security.md)                             |

## Cross-reference matrix

Each domain document follows a consistent structure:

1. Identifier and category — the two-letter domain prefix and its grouping.
2. Objective — what the domain covers and why it matters for Azure resources.
3. Assessment checklist — observable indicators that Azure resources satisfy the domain.
4. Controls and mitigations — defensive measures and implementation guidance.
5. Anti-patterns — common configurations that indicate a gap.
6. Framework crosswalk — representative NIST 800-53 Rev. 5 families and CIS Controls v8.1.
7. Volatile lookup — how to fetch per-service control identifiers at runtime.

## Consolidated framework crosswalk

Representative domain-grain alignment (authored aggregation; Microsoft publishes mappings per control). Version-pinned to NIST SP 800-53 Rev. 5 and CIS Controls v8.1.

| ID | Representative NIST 800-53 Rev. 5 families | Representative CIS Controls v8.1 |
|----|--------------------------------------------|----------------------------------|
| NS | AC, CA, CM, SC, SI                         | 9, 12, 13                        |
| IM | AC, IA, RA, SC, SI                         | 3, 5, 6, 8, 12, 16               |
| PA | AC, AU, CA, CP, IA, IR                     | 4, 5, 6, 8, 17                   |
| DP | AC, IA, RA, SC, SI                         | 3                                |
| AM | AC, CM, PM, RA, SA, SC, SI                 | 1, 2, 4, 5, 6, 10, 15            |
| LT | AU, IA, SI                                 | 6, 8, 13, 17                     |
| IR | AU, CP, IR, RA, SI                         | 1, 8, 13, 17                     |
| PV | CA, CM, RA, SC, SI                         | 4, 7, 15, 18                     |
| ES | IR, SI                                     | 7, 8, 10, 13                     |
| BR | AU, CP, SC, SI                             | 3, 8, 11                         |
| DS | AC, AU, CA, CM, PL, RA, SA, SI, SR         | 4, 6, 7, 8, 14, 16               |
| AI | AC, AU, CA, CM, IA, IR, RA, SA, SI         | 5, 6, 8, 13, 15, 16, 18          |

## Attribution

The reference files in this skill are original prose authored for this repository that paraphrase the publicly documented structure of the Microsoft Cloud Security Benchmark. MCSB documentation is published on Microsoft Learn under the Microsoft Learn Terms of Use, not a Creative Commons license. This skill paraphrases the taxonomy and authors its own representative checklists and crosswalk; it does not reproduce Microsoft prose, tables, or the benchmark dataset verbatim, and the citation below is a provenance reference rather than a license grant.

> Microsoft, "Overview of the Microsoft cloud security benchmark," Microsoft Learn, accessed 2026-07-21, <https://learn.microsoft.com/en-us/security/benchmark/azure/overview>.
